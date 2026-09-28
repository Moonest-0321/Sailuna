import AppKit
import CryptoKit
import Foundation

/// 建立帆夢與拾頁共用的 .shiye v1 完整快照；封包只供直接傳送，不提供另存入口。
@MainActor
enum BookJSONExporter {
    struct Manifest: Codable {
        let format: String
        let formatVersion: Int
        let generator: Generator
        let exportedAt: Date
        let requiredCapabilities: [String]
        let book: BookRecord
        let volumes: [VolumeRecord]
    }
    struct Generator: Codable { let app: String; let version: String }
    struct BookRecord: Codable {
        let id: UUID; let title: String; let author: String; let synopsis: String
        let language: String; let status: String; let tags: [String]; let sectionUnit: String
        let cover: String?; let wordCount: Int
    }
    struct VolumeRecord: Codable { let id: UUID; let index: Int; let title: String; let sections: [SectionRecord] }
    struct SectionRecord: Codable {
        let id: UUID; let index: Int; let title: String; let file: String
        let wordCount: Int; let updatedAt: Date; let contentHash: String
    }
    struct SectionContent: Codable { let id: UUID; let title: String; let blocks: [ContentBlock] }
    struct ContentBlock: Codable, Equatable { let type: String; let text: String? }
    struct Package {
        let data: Data
        let manifest: Manifest
        let entries: [String: Data]
    }
    enum PackageError: LocalizedError {
        case invalidStatus, invalidBook, tooLarge, unreadableCover, largeCover
        var errorDescription: String? {
            switch self {
            case .invalidStatus: "只有草稿首次發布、連載或完結作品可以傳送。"
            case .invalidBook: "請填寫書名與筆名，並至少建立一卷。"
            case .tooLarge: "作品超過發布容量上限（封包 24 MiB、單節 1 MiB、最多 4096 個檔案）。"
            case .unreadableCover: "無法讀取自訂封面，請重新設定封面後再傳送。"
            case .largeCover: "封面不得超過 4 MiB，長寬不得超過 4096 像素。"
            }
        }
    }
    static func makePackage(book: Book, categories: [String], status: BookStatus,
                            sectionUnit: BookTextSectionMarker, exportedAt: Date = Date()) throws -> Package {
        guard status == .ongoing || status == .completed else { throw PackageError.invalidStatus }
        guard !book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !book.volumes.isEmpty else { throw PackageError.invalidBook }
        guard book.volumes.count + book.volumes.reduce(0, { $0 + $1.sections.count }) <= 4094 else { throw PackageError.tooLarge }
        var entries: [String: Data] = [:]
        let cover = BookCoverStore.pngData(for: book)
        if BookCoverStore.hasCover(for: book) && cover == nil { throw PackageError.unreadableCover }
        if let cover {
            guard cover.count <= 4 * 1024 * 1024, let image = NSBitmapImageRep(data: cover),
                  image.pixelsWide <= 4096, image.pixelsHigh <= 4096 else { throw PackageError.largeCover }
            entries["cover.png"] = cover
        }
        let volumes = try book.volumes.sorted(by: ordered).enumerated().map { index, volume in
            let sections = try volume.sections.sorted(by: ordered).enumerated().map { sectionIndex, section in
                let file = "sections/\(section.id.uuidString).json"
                let content = SectionContent(id: section.id, title: normalized(section.title), blocks: contentBlocks(from: section.content))
                let bytes = try encode(content)
                guard bytes.count <= 1024 * 1024 else { throw PackageError.tooLarge }
                entries[file] = bytes
                return SectionRecord(id: section.id, index: sectionIndex + 1, title: normalized(section.title), file: file,
                    wordCount: section.wordCount, updatedAt: section.updatedAt, contentHash: "sha256:\(hash(bytes))")
            }
            return VolumeRecord(id: volume.id, index: index + 1, title: normalized(volume.title), sections: sections)
        }
        var tags: [String] = []
        for category in categories {
            let tag = normalized(category).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tag.isEmpty && !tags.contains(tag) { tags.append(tag) }
        }
        let unit: String = switch sectionUnit { case .section: "section"; case .zhang: "zhang"; case .chapter: "chapter" }
        let manifest = Manifest(format: "sailune.shiye-book", formatVersion: 1,
            generator: Generator(app: "Sailune", version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1"),
            exportedAt: exportedAt, requiredCapabilities: ["full-snapshot-v1"],
            book: BookRecord(id: book.id, title: normalized(book.title), author: normalized(book.author), synopsis: normalized(book.synopsis),
                language: "zh-Hant", status: status == .completed ? "completed" : "ongoing", tags: tags, sectionUnit: unit,
                cover: cover == nil ? nil : "cover.png", wordCount: volumes.flatMap(\.sections).reduce(0) { $0 + $1.wordCount }), volumes: volumes)
        let manifestData = try encode(manifest)
        guard manifestData.count <= 2 * 1024 * 1024 else { throw PackageError.tooLarge }
        entries["manifest.json"] = manifestData
        guard entries.count <= 4096, entries.values.reduce(0, { $0 + $1.count }) <= 24 * 1024 * 1024 else { throw PackageError.tooLarge }
        var zip = ZipBuilder()
        for path in entries.keys.sorted() { zip.addEntry(path, entries[path]!) }
        let bytes = zip.finalize()
        guard bytes.count <= 24 * 1024 * 1024 else { throw PackageError.tooLarge }
        return Package(data: bytes, manifest: manifest, entries: entries)
    }
    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    private static func ordered(_ lhs: Volume, _ rhs: Volume) -> Bool {
        lhs.sortOrder == rhs.sortOrder ? lhs.id.uuidString < rhs.id.uuidString : lhs.sortOrder < rhs.sortOrder
    }
    private static func ordered(_ lhs: Section, _ rhs: Section) -> Bool {
        lhs.sortOrder == rhs.sortOrder ? lhs.id.uuidString < rhs.id.uuidString : lhs.sortOrder < rhs.sortOrder
    }
    private static func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").precomposedStringWithCanonicalMapping
    }
    static func contentBlocks(from content: AttributedString) -> [ContentBlock] {
        let attributed = NSAttributedString(content)
        guard !attributed.string.isEmpty else { return [] }
        var offset = 0
        return attributed.string.components(separatedBy: "\n").map { paragraph in
            let length = (paragraph as NSString).length
            let font = length > 0 && offset < attributed.length ? attributed.attribute(.font, at: offset, effectiveRange: nil) as? NSFont : nil
            let isHeading = font.map { $0.pointSize == 18 && $0.fontDescriptor.symbolicTraits.contains(.bold) } ?? false
            offset += length + 1
            let text = normalized(paragraph).replacingOccurrences(of: "\n", with: "")
            return ContentBlock(type: text.isEmpty ? "blank" : isHeading ? "heading" : "paragraph", text: text.isEmpty ? nil : text)
        }
    }
    static func hash(_ bytes: Data) -> String { SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() }
}

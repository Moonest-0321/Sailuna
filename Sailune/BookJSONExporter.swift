import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// 供拾頁網站匯入的完整書籍快照。網站以書籍 UUID 判斷更新，接收時間由網站產生。
@MainActor
enum BookJSONExporter {
    struct Package: Codable {
        let format: String
        let version: Int
        let exportedAt: Date
        let contentHashAlgorithm: String
        let book: BookRecord
    }

    struct BookRecord: Codable {
        let id: UUID
        let title: String
        let author: String
        let synopsis: String
        let categories: [String]
        let publicationStatus: String
        let sectionUnit: String
        let createdAt: Date
        let updatedAt: Date
        let cover: CoverRecord?
        let volumes: [VolumeRecord]
    }

    struct CoverRecord: Codable {
        let mediaType: String
        let base64: String
    }

    struct VolumeRecord: Codable {
        let id: UUID
        let title: String
        let order: Int
        let sections: [SectionRecord]
    }

    struct SectionRecord: Codable {
        let id: UUID
        let title: String
        let order: Int
        let createdAt: Date
        let updatedAt: Date
        let wordCount: Int
        let contentHash: String
        let blocks: [ContentBlock]
    }

    struct ContentBlock: Codable {
        let type: String
        let text: String
    }

    static func exportRequest(
        book: Book,
        categories: [String],
        status: BookStatus,
        sectionUnit: BookTextSectionMarker,
        onSaved: @escaping (URL) -> Void
    ) throws -> SailuneExportRequest {
        guard status == .ongoing || status == .completed else {
            throw ExportError.invalidPublicationStatus
        }
        let package = makePackage(book: book, categories: categories, status: status, sectionUnit: sectionUnit)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(package)
        return SailuneExportRequest(
            document: SailuneExportDocument(data: data),
            contentType: .json,
            defaultFilename: filename(for: book.title),
            onSaved: onSaved
        )
    }

    private enum ExportError: LocalizedError {
        case invalidPublicationStatus

        var errorDescription: String? { "只有連載或完結作品可以匯出發布檔。" }
    }

    static func makePackage(
        book: Book,
        categories: [String],
        status: BookStatus,
        sectionUnit: BookTextSectionMarker,
        exportedAt: Date = Date()
    ) -> Package {
        // 預設封面可由網站依書名呈現；只有作者自訂封面需要傳送圖片位元組。
        let cover = BookCoverStore.pngData(for: book).map {
            CoverRecord(mediaType: "image/png", base64: $0.base64EncodedString())
        }
        let volumes = book.volumes.sorted(by: ordered).enumerated().map { index, volume in
            VolumeRecord(
                id: volume.id,
                title: volume.title,
                order: index,
                sections: volume.sections.sorted(by: ordered).enumerated().map { sectionIndex, section in
                    let blocks = contentBlocks(from: section.content)
                    return SectionRecord(
                        id: section.id,
                        title: section.title,
                        order: sectionIndex,
                        createdAt: section.createdAt,
                        updatedAt: section.updatedAt,
                        wordCount: section.wordCount,
                        contentHash: hash(blocks),
                        blocks: blocks
                    )
                }
            )
        }
        let publicationStatus: String
        switch status {
        case .ongoing: publicationStatus = "ongoing"
        case .completed: publicationStatus = "completed"
        case .draft: publicationStatus = "draft"
        case .delisted: publicationStatus = "delisted"
        }
        return Package(
            format: "sailune.reader-book",
            version: 1,
            exportedAt: exportedAt,
            contentHashAlgorithm: "sha256-sailune-blocks-v1",
            book: BookRecord(
                id: book.id,
                title: book.title,
                author: book.author,
                synopsis: book.synopsis,
                categories: categories,
                publicationStatus: publicationStatus,
                sectionUnit: sectionUnit.rawValue,
                createdAt: book.createdAt,
                updatedAt: book.updatedAt,
                cover: cover,
                volumes: volumes
            )
        )
    }

    private static func ordered(_ lhs: Volume, _ rhs: Volume) -> Bool {
        lhs.sortOrder == rhs.sortOrder ? lhs.id.uuidString < rhs.id.uuidString : lhs.sortOrder < rhs.sortOrder
    }

    private static func ordered(_ lhs: Section, _ rhs: Section) -> Bool {
        lhs.sortOrder == rhs.sortOrder ? lhs.id.uuidString < rhs.id.uuidString : lhs.sortOrder < rhs.sortOrder
    }

    private static func contentBlocks(from content: AttributedString) -> [ContentBlock] {
        let attributed = NSAttributedString(content)
        let text = attributed.string
        var offset = 0
        return text.components(separatedBy: "\n").map { paragraph in
            let length = (paragraph as NSString).length
            let font = length > 0 && offset < attributed.length
                ? attributed.attribute(.font, at: offset, effectiveRange: nil) as? NSFont
                : nil
            let isHeading = font.map { $0.pointSize == 18 && $0.fontDescriptor.symbolicTraits.contains(.bold) } ?? false
            offset += length + 1
            return ContentBlock(
                type: isHeading ? "sceneHeading" : "paragraph",
                text: paragraph.replacingOccurrences(of: "\r", with: "").precomposedStringWithCanonicalMapping
            )
        }
    }

    /// 每個區塊依序串接 type 與文字的 UTF-8 長度及位元組，避免分隔字元歧義。
    private static func hash(_ blocks: [ContentBlock]) -> String {
        var digestInput = Data("sailune-blocks-v1\n".utf8)
        for block in blocks {
            let type = Data(block.type.utf8)
            let text = Data(block.text.utf8)
            digestInput.append(contentsOf: "\(type.count):".utf8)
            digestInput.append(type)
            digestInput.append(contentsOf: "\(text.count):".utf8)
            digestInput.append(text)
        }
        return SHA256.hash(data: digestInput).map { String(format: "%02x", $0) }.joined()
    }

    private static func filename(for title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = title.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty ? "未命名作品" : cleaned) + ".json"
    }
}

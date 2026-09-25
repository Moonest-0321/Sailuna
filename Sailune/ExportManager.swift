import Foundation
import SwiftData
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SailuneExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .epub, .pdf, .data] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SailuneExportRequest: Identifiable {
    let id = UUID()
    let document: SailuneExportDocument
    let contentType: UTType
    let defaultFilename: String
}

private struct SailuneFileExporterModifier: ViewModifier {
    @Binding var request: SailuneExportRequest?
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: Binding(
                    get: { request != nil },
                    set: { if !$0 { request = nil } }
                ),
                document: request?.document,
                contentType: request?.contentType ?? .data,
                defaultFilename: request?.defaultFilename
            ) { result in
                request = nil
                switch result {
                case .success(let url):
                    NSWorkspace.shared.selectFile(
                        url.path,
                        inFileViewerRootedAtPath: url.deletingLastPathComponent().path
                    )
                case .failure(let error):
                    if (error as NSError).code != NSUserCancelledError {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .alert("匯出失敗", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(SailuneActionCopy.acknowledge, role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "未知錯誤")
            }
    }
}

extension View {
    func sailuneFileExporter(request: Binding<SailuneExportRequest?>) -> some View {
        modifier(SailuneFileExporterModifier(request: request))
    }
}

struct ExportManager {

    // MARK: - 匯出整本書為 TXT
    static func exportBookToTXT(book: Book, marker: BookTextSectionMarker = .section) -> String {
        var output = ""
        output += "\(book.title)\n"
        output += "作者：\(book.author)\n\n"
        if !book.synopsis.isEmpty {
            output += "\(book.synopsis)\n\n"
            output += "---\n\n"
        }
        let sortedVolumes = book.volumes.sorted { $0.sortOrder < $1.sortOrder }
        for (volumeIndex, volume) in sortedVolumes.enumerated() {
            output += "\(volumeHeading(volume.title, ordinal: volumeIndex + 1))\n\n"
            let sortedSections = volume.sections.sorted { $0.sortOrder < $1.sortOrder }
            for (sectionIndex, section) in sortedSections.enumerated() {
                output += "\(sectionHeading(section.title, ordinal: sectionIndex + 1, marker: marker))\n\n"
                output += parseAttributedStringToTXT(section.content)
                output += "\n\n"
            }
        }
        return removingHashCharacters(from: output)
    }

    // MARK: - 匯出單一卷為 TXT
    static func exportVolumeToTXT(volume: Volume, bookTitle: String, marker: BookTextSectionMarker = .section) -> String {
        var output = "\(bookTitle)\n\n"
        output += "\(volumeHeading(volume.title, ordinal: volume.sortOrder + 1))\n\n"
        let sortedSections = volume.sections.sorted { $0.sortOrder < $1.sortOrder }
        for (sectionIndex, section) in sortedSections.enumerated() {
            output += "\(sectionHeading(section.title, ordinal: sectionIndex + 1, marker: marker))\n\n"
            output += parseAttributedStringToTXT(section.content)
            output += "\n\n"
        }
        return removingHashCharacters(from: output)
    }

    // MARK: - 匯出單一節為 TXT
    static func exportSectionToTXT(section: Section, marker: BookTextSectionMarker = .section) -> String {
        var output = ""
        output += "\(sectionHeading(section.title, ordinal: section.sortOrder + 1, marker: marker))\n\n"
        output += parseAttributedStringToTXT(section.content)
        return removingHashCharacters(from: output)
    }

    private static func removingHashCharacters(from text: String) -> String {
        text.replacingOccurrences(of: "#", with: "")
    }

    private static func volumeHeading(_ title: String, ordinal: Int) -> String {
        "第\(spelledOrdinal(ordinal))卷 \(removingExistingOrdinal(from: title, unit: "卷"))"
    }

    private static func sectionHeading(_ title: String, ordinal: Int, marker: BookTextSectionMarker) -> String {
        "第\(spelledOrdinal(ordinal))\(marker.label) \(removingExistingOrdinal(from: title, unit: "章張節"))"
    }

    private static func spelledOrdinal(_ ordinal: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: ordinal)) ?? "\(ordinal)"
    }

    private static func removingExistingOrdinal(from title: String, unit: String) -> String {
        let pattern = #"^第\s*(?:[0-9]+|[〇零一二三四五六七八九十百千萬]+)["#
            + NSRegularExpression.escapedPattern(for: unit)
            + #"]\s*[:：、.．-]?\s*"#
        return title.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )
    }

    // MARK: - 核心解析：AttributedString → 純文字 TXT
    private static func parseAttributedStringToTXT(_ attrStr: AttributedString) -> String {
        var result = ""
        let nsAttrStr = NSAttributedString(attrStr)
        let fullRange = NSRange(location: 0, length: nsAttrStr.length)
        nsAttrStr.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            let substr = (nsAttrStr.string as NSString).substring(with: range)
            if let font = value as? NSFont {
                let isHeading = font.pointSize == 18 && font.fontDescriptor.symbolicTraits.contains(.bold)
                if isHeading {
                    let lines = substr.split(separator: "\n", omittingEmptySubsequences: false)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            result += "\(trimmed)\n"
                        } else {
                            result += "\n"
                        }
                    }
                } else {
                    result += substr
                }
            } else {
                result += substr
            }
        }
        return result
    }

    static func textExportRequest(defaultName: String, content: String) -> SailuneExportRequest {
        let cleanName = sanitizeFileName(defaultName)
        let fileType = "txt"
        let fileName = cleanName.lowercased().hasSuffix(".\(fileType)")
            ? cleanName
            : "\(cleanName).\(fileType)"
        return SailuneExportRequest(
            document: SailuneExportDocument(data: Data(content.utf8)),
            contentType: .plainText,
            defaultFilename: fileName
        )
    }

    private static func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名" : cleaned
    }
}

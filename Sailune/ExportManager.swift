import Foundation
import SwiftData
import AppKit
import UniformTypeIdentifiers

// 注意：舊版的 TextFileDocument 已刪除——它需要 import SwiftUI 且無人使用，是死碼。

struct ExportManager {

    // MARK: - 匯出整本書為 TXT
    static func exportBookToTXT(book: Book) -> String {
        var output = ""
        output += "# \(book.title)\n"
        output += "作者：\(book.author)\n\n"
        if !book.synopsis.isEmpty {
            output += "\(book.synopsis)\n\n"
            output += "---\n\n"
        }
        let sortedVolumes = book.volumes.sorted { $0.sortOrder < $1.sortOrder }
        for volume in sortedVolumes {
            output += "# \(volume.title)\n\n"
            let sortedSections = volume.sections.sorted { $0.sortOrder < $1.sortOrder }
            for section in sortedSections {
                output += "# \(section.title)\n\n"
                output += parseAttributedStringToTXT(section.content)
                output += "\n\n"
            }
        }
        return output
    }

    // MARK: - 匯出單一卷為 TXT
    static func exportVolumeToTXT(volume: Volume, bookTitle: String) -> String {
        var output = ""
        output += "# \(bookTitle) - \(volume.title)\n\n"
        let sortedSections = volume.sections.sorted { $0.sortOrder < $1.sortOrder }
        for section in sortedSections {
            output += "# \(section.title)\n\n"
            output += parseAttributedStringToTXT(section.content)
            output += "\n\n"
        }
        return output
    }

    // MARK: - 匯出單一節為 TXT
    static func exportSectionToTXT(section: Section) -> String {
        var output = ""
        output += "# \(section.title)\n\n"
        output += parseAttributedStringToTXT(section.content)
        return output
    }

    // MARK: - 核心解析：AttributedString → Markdown TXT（幕標題 = ##，PRD 5.3.2）
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
                            result += "## \(trimmed)\n"
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

    // MARK: - 存檔
    @MainActor
    static func presentSavePanel(for book: Book, defaultName: String, fileType: String, content: String) {
        let cleanName = sanitizeFileName(defaultName)
        let fileName = cleanName.lowercased().hasSuffix(".\(fileType.lowercased())")
            ? cleanName
            : "\(cleanName).\(fileType)"
        guard let data = content.data(using: .utf8) else {
            presentError(message: "無法將文字轉換為 UTF-8。")
            return
        }
        presentSavePanel(defaultFileName: fileName, fileType: fileType, data: data)
    }

    @MainActor
    static func presentSavePanel(defaultFileName: String, fileType: String, data: Data) {
        let panel = NSSavePanel()
        panel.title = "匯出 \(fileType.uppercased())"
        panel.nameFieldStringValue = defaultFileName
        if let contentType = UTType(filenameExtension: fileType) {
            panel.allowedContentTypes = [contentType]
        }
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        } catch {
            presentError(message: error.localizedDescription)
        }
    }

    @MainActor
    private static func presentError(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "匯出失敗"
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private static func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名" : cleaned
    }
}

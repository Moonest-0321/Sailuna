import Foundation
import SwiftData

nonisolated enum BookTextSectionMarker: String, CaseIterable, Identifiable, Sendable {
    case chapter = "章"
    case zhang = "張"
    case section = "節"

    var id: Self { self }
    var label: String { rawValue }
}

struct BookTextImportDocument: Equatable, Sendable {
    struct Volume: Equatable, Sendable {
        var title: String
        var sections: [Section]
    }

    struct Section: Equatable, Sendable {
        var title: String
        var content: String
    }

    var volumes: [Volume]
}

enum BookTextImportError: Error, Equatable, Sendable, LocalizedError {
    case invalidUTF8
    case emptyFile
    case textBeforeFirstVolume(line: Int)
    case sectionBeforeVolume(line: Int)
    case emptyVolumeTitle(line: Int)
    case emptySectionTitle(line: Int)
    case sectionHasNoBody(line: Int)
    case mixedSectionMarkers(line: Int, selected: String, found: String)
    case volumeHasNoSections(line: Int)
    case noVolumeMarker
    case noSectionMarker

    var errorDescription: String? {
        switch self {
        case .invalidUTF8: "檔案不是有效的 UTF-8 純文字。"
        case .emptyFile: "檔案沒有內容。"
        case .textBeforeFirstVolume(let line): "第 \(line) 行出現在第一個卷標記之前，無法判斷其所屬卷。"
        case .sectionBeforeVolume(let line): "第 \(line) 行出現節標記，但前面沒有卷標記。"
        case .emptyVolumeTitle(let line): "第 \(line) 行的卷標記沒有卷名。"
        case .emptySectionTitle(let line): "第 \(line) 行的節標記沒有標題。"
        case .sectionHasNoBody(let line): "第 \(line) 行的節標題後沒有內文。"
        case .mixedSectionMarkers(let line, let selected, let found):
            "第 \(line) 行使用「\(found)」標記；本次選用「\(selected)」，同一份檔案不可混用。"
        case .volumeHasNoSections(let line): "第 \(line) 行的卷沒有任何節。"
        case .noVolumeMarker: "找不到卷標記（例如「第一卷」）。"
        case .noSectionMarker: "找不到所選的節標記。"
        }
    }
}

nonisolated enum BookTextImportParser {
    private struct MarkerMatch {
        var kind: String
        var title: String
    }

    private struct VolumeDraft {
        var markerLine: Int
        var titleParts: [String]
        var sections: [BookTextImportDocument.Section] = []
        var sectionTitle: String?
        var sectionLine: Int?
        var bodyLines: [String] = []
        var hasStartedSections = false
    }

    static func parse(data: Data, marker: BookTextSectionMarker) -> Result<BookTextImportDocument, BookTextImportError> {
        guard let text = String(data: data, encoding: .utf8) else { return .failure(.invalidUTF8) }
        return parse(text: text, marker: marker)
    }

    static func parse(text: String, marker: BookTextSectionMarker) -> Result<BookTextImportDocument, BookTextImportError> {
        let lines = text.components(separatedBy: .newlines)
        guard lines.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return .failure(.emptyFile)
        }

        var result: [BookTextImportDocument.Volume] = []
        var current: VolumeDraft?
        var sawSectionMarker = false
        let hasVolumeMarker = lines.contains { line in
            guard let match = markerMatch(in: line.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
            return match.kind == "卷"
        }

        if !hasVolumeMarker {
            current = VolumeDraft(markerLine: 1, titleParts: [], hasStartedSections: true)
        }

        for (lineIndex, rawLine) in lines.enumerated() {
            let lineNumber = lineIndex + 1
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if let volumeMatch = markerMatch(in: line), volumeMatch.kind == "卷" {
                if let current {
                    do { result.append(try finalize(current)) }
                    catch let error as BookTextImportError { return .failure(error) }
                    catch { return .failure(.emptyVolumeTitle(line: current.markerLine)) }
                }
                current = VolumeDraft(
                    markerLine: lineNumber,
                    titleParts: volumeMatch.title.isEmpty ? [] : [volumeMatch.title]
                )
                continue
            }

            if let match = sectionMarker(in: line) {
                sawSectionMarker = true
                guard var volume = current else { return .failure(.sectionBeforeVolume(line: lineNumber)) }
                guard match.kind == marker.label else {
                    return .failure(.mixedSectionMarkers(line: lineNumber, selected: marker.label, found: match.kind))
                }
                do { try flushSection(in: &volume) }
                catch let error as BookTextImportError { return .failure(error) }
                catch { return .failure(.sectionHasNoBody(line: lineNumber)) }
                volume.hasStartedSections = true
                volume.sectionTitle = match.title.isEmpty ? "無" : match.title
                volume.sectionLine = lineNumber
                current = volume
                continue
            }

            guard var volume = current else {
                if !line.isEmpty { return .failure(.textBeforeFirstVolume(line: lineNumber)) }
                continue
            }
            if volume.hasStartedSections {
                volume.bodyLines.append(rawLine)
            } else if !line.isEmpty {
                volume.titleParts.append(line)
            }
            current = volume
        }

        guard let current else { return .failure(.noVolumeMarker) }
        guard sawSectionMarker else { return .failure(.noSectionMarker) }
        do { result.append(try finalize(current)) }
        catch let error as BookTextImportError { return .failure(error) }
        catch { return .failure(.emptyVolumeTitle(line: current.markerLine)) }
        return .success(.init(volumes: result))
    }

    private static func flushSection(in volume: inout VolumeDraft) throws {
        guard let title = volume.sectionTitle, volume.sectionLine != nil else { return }
        let content = volume.bodyLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        let resolvedContent = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "無" : content
        volume.sections.append(.init(title: title, content: resolvedContent))
        volume.sectionTitle = nil
        volume.sectionLine = nil
        volume.bodyLines = []
    }

    private static func finalize(_ draft: VolumeDraft) throws -> BookTextImportDocument.Volume {
        var draft = draft
        try flushSection(in: &draft)
        let title = draft.titleParts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let resolvedTitle = title.isEmpty ? "無" : title
        guard !draft.sections.isEmpty else { throw BookTextImportError.volumeHasNoSections(line: draft.markerLine) }
        return .init(title: resolvedTitle, sections: draft.sections)
    }

    private static func sectionMarker(in line: String) -> MarkerMatch? {
        guard let match = markerMatch(in: line), ["章", "張", "節"].contains(match.kind) else { return nil }
        return match
    }

    private static func markerMatch(in line: String) -> MarkerMatch? {
        let pattern = #"^第\s*(?:[0-9]+|[〇零一二三四五六七八九十百千萬]+)(卷|章|張|節)(?:[ \t:：、.．-]*)(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let kindRange = Range(match.range(at: 1), in: line),
              let titleRange = Range(match.range(at: 2), in: line) else { return nil }
        return MarkerMatch(
            kind: String(line[kindRange]),
            title: String(line[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

@MainActor
enum BookImportCoordinator {
    static func createBook(
        title: String,
        author: String,
        document: BookTextImportDocument,
        in container: ModelContainer
    ) throws -> UUID {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let book = Book(title: title, author: author)
        context.insert(book)

        for (volumeIndex, value) in document.volumes.enumerated() {
            let volume = Sailune.Volume(title: value.title, sortOrder: volumeIndex, book: book)
            context.insert(volume)
            book.volumes.append(volume)
            for (sectionIndex, sectionValue) in value.sections.enumerated() {
                let content = RichEditorLocalTextStyle.importedBody(sectionValue.content)
                let section = Sailune.Section(
                    title: sectionValue.title,
                    content: content,
                    sortOrder: sectionIndex,
                    wordCount: sectionValue.content.filter { !$0.isWhitespace }.count,
                    volume: volume
                )
                context.insert(section)
                volume.sections.append(section)
            }
        }

        do {
            try TimelineEngine.Bootstrap.ensure(for: book, in: context)
            return book.id
        } catch {
            context.rollback()
            throw error
        }
    }
}

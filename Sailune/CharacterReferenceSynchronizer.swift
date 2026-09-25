import AppKit
import Foundation
import SwiftData

@MainActor
enum CharacterReferenceSynchronizer {
    static func unlinkedCandidates(
        from oldName: String,
        to newName: String,
        sourceLabel: String,
        in book: Book
    ) async -> [UnlinkedReferenceCandidate] {
        let source = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !replacement.isEmpty, source != replacement else { return [] }

        var allCandidates: [UnlinkedReferenceCandidate] = []
        for (index, section) in WritingReferenceScanner.allSections(in: book).enumerated() {
            guard !Task.isCancelled else { return [] }
            if index > 0 && index.isMultiple(of: 4) {
                // 富文字橋接留在主執行緒，但分批讓出執行權，避免長篇小說改名時卡住介面。
                await Task.yield()
            }
            let attributed = NSAttributedString(section.content)
            let text = attributed.string as NSString
            var searchRange = NSRange(location: 0, length: text.length)

            while searchRange.length > 0 {
                guard !Task.isCancelled else { return [] }
                let range = text.range(of: source, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                guard range.location != NSNotFound else { break }
                var hasLink = false
                attributed.enumerateAttribute(.link, in: range) { value, _, stop in
                    if value != nil {
                        hasLink = true
                        stop.pointee = true
                    }
                }
                if !hasLink {
                    let previewStart = max(0, range.location - 14)
                    let previewEnd = min(text.length, NSMaxRange(range) + 14)
                    let preview = text.substring(with: NSRange(location: previewStart, length: previewEnd - previewStart))
                    allCandidates.append(UnlinkedReferenceCandidate(
                        section: section,
                        range: range,
                        sourceName: source,
                        replacement: replacement,
                        sourceLabel: sourceLabel,
                        preview: preview
                    ))
                }
                let next = NSMaxRange(range)
                searchRange = NSRange(location: next, length: text.length - next)
            }
        }
        return allCandidates
    }

    static func apply(_ candidates: [UnlinkedReferenceCandidate], in book: Book, context: ModelContext) throws -> Set<UUID> {
        let selected = candidates.filter(\.isSelected)
        guard !selected.isEmpty else { return [] }
        var changedSectionIDs = Set<UUID>()

        for (_, sectionCandidates) in Dictionary(grouping: selected, by: { $0.section.id }) {
            guard let section = sectionCandidates.first?.section else { continue }
            let attributed = NSMutableAttributedString(attributedString: NSAttributedString(section.content))
            var didChange = false

            for candidate in sectionCandidates.sorted(by: { $0.range.location > $1.range.location }) {
                guard NSMaxRange(candidate.range) <= attributed.length,
                      (attributed.string as NSString).substring(with: candidate.range)
                        .compare(candidate.sourceName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame else { continue }
                var hasLink = false
                attributed.enumerateAttribute(.link, in: candidate.range) { value, _, stop in
                    if value != nil {
                        hasLink = true
                        stop.pointee = true
                    }
                }
                guard !hasLink else { continue }
                let attributes = attributed.attributes(at: candidate.range.location, effectiveRange: nil)
                attributed.replaceCharacters(in: candidate.range, with: NSAttributedString(string: candidate.replacement, attributes: attributes))
                didChange = true
            }

            guard didChange else { continue }
            section.content = AttributedString(attributed)
            section.wordCount = attributed.string.filter { !$0.isWhitespace }.count
            section.updatedAt = Date()
            changedSectionIDs.insert(section.id)
        }

        guard !changedSectionIDs.isEmpty else { return [] }
        book.updatedAt = Date()
        try context.save()
        NotificationCenter.default.post(name: .sailuneCharacterReferencesChanged, object: changedSectionIDs)
        return changedSectionIDs
    }

    static func updateLinkedNames(
        for character: Character,
        from oldName: String,
        to newName: String,
        in book: Book,
        context: ModelContext
    ) throws {
        let old = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !old.isEmpty, !name.isEmpty else { return }
        try updateLinkedReferences(
            for: character,
            replacement: name,
            in: book,
            context: context
        ) { reference, linkedText in
            switch reference.source {
            case .canonical:
                return true
            case .alias:
                return false
            case .legacy:
                return linkedText.compare(old, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        }
    }

    static func updateLinkedAlias(
        _ alias: CharacterAlias,
        from oldName: String,
        to newName: String,
        in book: Book,
        context: ModelContext
    ) throws {
        guard let character = alias.character else { return }
        let old = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !old.isEmpty, !name.isEmpty else { return }
        try updateLinkedReferences(
            for: character,
            replacement: name,
            in: book,
            context: context
        ) { reference, linkedText in
            switch reference.source {
            case .alias(let aliasID):
                return aliasID == alias.id
            case .canonical:
                return false
            case .legacy:
                return linkedText.compare(old, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        }
    }

    private static func updateLinkedReferences(
        for character: Character,
        replacement: String,
        in book: Book,
        context: ModelContext,
        shouldReplace: (CharacterReference, String) -> Bool
    ) throws {
        var changedSectionIDs = Set<UUID>()

        for section in WritingReferenceScanner.allSections(in: book) {
            let attributed = NSMutableAttributedString(attributedString: NSAttributedString(section.content))
            var ranges: [NSRange] = []
            attributed.enumerateAttribute(.link, in: NSRange(location: 0, length: attributed.length)) { value, range, _ in
                guard let value,
                      let reference = CharacterReferenceLink.reference(from: value),
                      reference.characterID == character.id else { return }
                let linkedText = (attributed.string as NSString).substring(with: range)
                guard shouldReplace(reference, linkedText) else { return }
                ranges.append(range)
            }
            guard !ranges.isEmpty else { continue }

            for range in ranges.reversed() {
                let attributes = attributed.attributes(at: range.location, effectiveRange: nil)
                attributed.replaceCharacters(
                    in: range,
                    with: NSAttributedString(string: replacement, attributes: attributes)
                )
            }
            section.content = AttributedString(attributed)
            section.wordCount = attributed.string.filter { !$0.isWhitespace }.count
            section.updatedAt = Date()
            changedSectionIDs.insert(section.id)
        }

        guard !changedSectionIDs.isEmpty else { return }
        book.updatedAt = Date()
        try context.save()
        NotificationCenter.default.post(name: .sailuneCharacterReferencesChanged, object: changedSectionIDs)
    }
}

struct UnlinkedReferenceCandidate: Identifiable {
    let id = UUID()
    let section: Section
    let range: NSRange
    let sourceName: String
    let replacement: String
    let sourceLabel: String
    let preview: String
    var isSelected = false
}

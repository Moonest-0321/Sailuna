import AppKit
import Foundation

struct WritingReferenceScanner {
    struct CategorizedSections {
        let linked: [Section]
        let possible: [Section]
    }
    static func plainText(_ section: Section) -> String {
        NSAttributedString(section.content).string
    }

    static func contains(_ name: String, in section: Section) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return plainText(section).localizedCaseInsensitiveContains(trimmed)
    }

    static func sections(for character: Character, in book: Book) -> [Section] {
        sections(for: character, aliases: [], in: book)
    }

    static func sections(for character: Character, aliases: [CharacterAlias], in book: Book) -> [Section] {
        let names = characterNames(for: character, aliases: aliases)
        return allSections(in: book).filter { section in
            names.contains { contains($0, in: section) }
        }
    }

    static func containsLinkedReference(to characterID: UUID, in section: Section) -> Bool {
        linkedCharacterIDs(in: section).contains(characterID)
    }

    static func linkedCharacterIDs(in section: Section) -> Set<UUID> {
        let attributed = NSAttributedString(section.content)
        var ids = Set<UUID>()
        attributed.enumerateAttribute(.link, in: NSRange(location: 0, length: attributed.length)) { value, _, _ in
            if let value, let characterID = CharacterReferenceLink.characterID(from: value) {
                ids.insert(characterID)
            }
        }
        return ids
    }

    static func categorizedSections(
        for character: Character,
        aliases: [CharacterAlias],
        in book: Book
    ) async -> CategorizedSections {
        let names = characterNames(for: character, aliases: aliases)
        var linked: [Section] = []
        var possible: [Section] = []
        for (index, section) in allSections(in: book).enumerated() {
            guard !Task.isCancelled else { return CategorizedSections(linked: [], possible: []) }
            if index > 0 && index.isMultiple(of: 4) { await Task.yield() }

            let attributed = NSAttributedString(section.content)
            var hasLinkedReference = false
            attributed.enumerateAttribute(.link, in: NSRange(location: 0, length: attributed.length)) { value, _, stop in
                if let value, CharacterReferenceLink.characterID(from: value) == character.id {
                    hasLinkedReference = true
                    stop.pointee = true
                }
            }
            if hasLinkedReference {
                linked.append(section)
            } else if names.contains(where: { attributed.string.localizedCaseInsensitiveContains($0) }) {
                possible.append(section)
            }
        }
        return CategorizedSections(linked: linked, possible: possible)
    }

    static func contains(_ character: Character, aliases: [CharacterAlias], in section: Section) -> Bool {
        !matchingNames(for: character, aliases: aliases, in: section).isEmpty
    }

    static func matchingNames(for character: Character, aliases: [CharacterAlias], in section: Section) -> [String] {
        characterNames(for: character, aliases: aliases).filter { contains($0, in: section) }
    }

    static func characterNames(for character: Character, aliases: [CharacterAlias]) -> [String] {
        ([character.realName] + aliases
            .filter { $0.character?.id == character.id }
            .map(\.name))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func sections(for item: Item, in book: Book) -> [Section] {
        allSections(in: book).filter { contains(item.name, in: $0) }
    }

    static func allSections(in book: Book) -> [Section] {
        book.volumes.sorted { $0.sortOrder < $1.sortOrder }
            .flatMap { $0.sections.sorted { $0.sortOrder < $1.sortOrder } }
    }
}

struct InspectorSectionNameMatcher {
    static func matches(name: String, inText text: String) -> Bool {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return false }
        return text.localizedCaseInsensitiveContains(normalizedName)
    }

    static func matches(name: String, in section: Section?) -> Bool {
        guard let section else { return false }
        return matches(name: name, inText: WritingReferenceScanner.plainText(section))
    }
}

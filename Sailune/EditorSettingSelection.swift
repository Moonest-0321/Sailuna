import AppKit

enum EditorSettingsTarget: Hashable {
    case character(UUID)
    case item(UUID)
    case ability(UUID)
    case power(UUID)
    case place(UUID)
    case worldTerm(UUID)

    var id: UUID {
        switch self {
        case .character(let id), .item(let id), .ability(let id), .power(let id), .place(let id), .worldTerm(let id): id
        }
    }
}

struct EditorSettingsNameCandidate: Equatable {
    let target: EditorSettingsTarget
    let names: [String]
}

enum EditorSettingsMatcher {
    static func uniqueMatch(
        for selection: String,
        candidates: [EditorSettingsNameCandidate]
    ) -> EditorSettingsTarget? {
        let selectedName = normalized(selection)
        guard !selectedName.isEmpty else { return nil }

        var matches = Set<EditorSettingsTarget>()
        for candidate in candidates where candidate.names.contains(where: { matchesName($0, selectedName) }) {
            matches.insert(candidate.target)
            if matches.count > 1 { return nil }
        }
        return matches.first
    }

    private static func matchesName(_ candidate: String, _ selectedName: String) -> Bool {
        let candidateName = normalized(candidate)
        guard !candidateName.isEmpty else { return false }
        return candidateName.compare(
            selectedName,
            options: [.caseInsensitive, .diacriticInsensitive]
        ) == .orderedSame
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum StoryTagMarkerDefinition: CaseIterable, Identifiable {
    case main
    case branch
    case foreshadowing
    case revision
    case plannedAddition

    var id: StoryTagKind { kind }

    var kind: StoryTagKind {
        switch self {
        case .main: .main
        case .branch: .branch
        case .foreshadowing: .foreshadowing
        case .revision: .revision
        case .plannedAddition: .plannedAddition
        }
    }

    var title: String { kind.rawValue }

    var colorName: String {
        switch self {
        case .main: "systemRed"
        case .branch: "systemBlue"
        case .foreshadowing: "systemYellow"
        case .revision: "systemOrange"
        case .plannedAddition: "systemGreen"
        }
    }

    var color: NSColor {
        switch self {
        case .main: .systemRed
        case .branch: .systemBlue
        case .foreshadowing: .systemYellow
        case .revision: .systemOrange
        case .plannedAddition: .systemGreen
        }
    }

    var opacity: CGFloat {
        switch self {
        case .main, .branch: 0.58
        case .foreshadowing: 0.72
        case .revision: 0.16
        case .plannedAddition: 0.14
        }
    }

    static func definition(for kind: StoryTagKind) -> Self {
        switch kind {
        case .main: .main
        case .branch: .branch
        case .foreshadowing: .foreshadowing
        case .revision: .revision
        case .plannedAddition: .plannedAddition
        }
    }
}

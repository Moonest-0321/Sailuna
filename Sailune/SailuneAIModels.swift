import Foundation

struct SailuneAISectionAttachment: Codable, Identifiable {
    enum Kind: String, Codable {
        case section
        case characterProfile
        case characterSectionTemplate
        case readingSummary
        case settingAnalysis
        case characterComparison
    }

    let id: UUID
    let title: String
    let content: String
    let kind: Kind?

    init(id: UUID, title: String, content: String, kind: Kind? = .section) {
        self.id = id
        self.title = title
        self.content = content
        self.kind = kind
    }
}

enum SailuneAIReadingScope: Hashable {
    case section(UUID)
    case volume(UUID)
    case wholeBook
}

enum SailuneAISettingKind: String, CaseIterable, Identifiable, Hashable {
    case character = "角色"
    case item = "物品"
    case ability = "能力"
    case power = "勢力"

    var id: Self { self }
}

enum SailuneAISettingDimension: Hashable, Identifiable {
    case character(SailuneAICharacterCategory)
    case itemProfile
    case itemHistory
    case abilityProfile
    case abilityLevels
    case abilityHistory
    case powerProfile
    case powerMembership
    case powerRelations
    case powerGovernment
    case powerPurpose
    case powerAssets
    case powerAdvantages
    case powerHistory

    var id: String { title }

    var title: String {
        switch self {
        case .character(let category): category.rawValue
        case .itemProfile: "物品資料"
        case .itemHistory: "物品歷史"
        case .abilityProfile: "能力資料"
        case .abilityLevels: "能力等級"
        case .abilityHistory: "能力歷史"
        case .powerProfile: "勢力資料"
        case .powerMembership: "成員與職務"
        case .powerRelations: "勢力關係"
        case .powerGovernment: "政治與宗教"
        case .powerPurpose: "目的"
        case .powerAssets: "資產"
        case .powerAdvantages: "優勢"
        case .powerHistory: "沿革"
        }
    }

    static func all(for kind: SailuneAISettingKind) -> [SailuneAISettingDimension] {
        switch kind {
        case .character: SailuneAICharacterCategory.allCases.map(Self.character)
        case .item: [.itemProfile, .itemHistory]
        case .ability: [.abilityProfile, .abilityLevels, .abilityHistory]
        case .power: [.powerProfile, .powerMembership, .powerRelations, .powerGovernment, .powerPurpose, .powerAssets, .powerAdvantages, .powerHistory]
        }
    }
}

struct SailuneAISettingAnalysisSelection: Equatable {
    let scope: SailuneAIReadingScope
    let kind: SailuneAISettingKind
    let targetID: UUID
    let dimensions: Set<SailuneAISettingDimension>
}

struct SailuneAICharacterComparisonSelection: Equatable {
    let scope: SailuneAIReadingScope
    let characterID: UUID
    let categories: Set<SailuneAICharacterCategory>
}

enum SailuneAISubmission {
    case chat(String)
    case readQuestion(String, SailuneAIReadingScope)
    case summary(SailuneAIReadingScope)
    case characterSectionTemplate(String, SailuneAICharacterTemplateSelection)
    case settingAnalysis(SailuneAISettingAnalysisSelection)
    case characterComparison(SailuneAICharacterComparisonSelection)
}

enum SailuneAICharacterCategory: String, CaseIterable, Identifiable, Hashable {
    case summary = "摘要"
    case basic = "基本資訊"
    case power = "所屬勢力"
    case aliases = "別名"
    case abilities = "能力"
    case appearance = "外觀"
    case psychology = "心理"
    case items = "物品"
    case relationships = "關係"
    case events = "事件"

    var id: Self { self }
}

struct SailuneAICharacterTemplateSelection: Equatable {
    let sectionID: UUID
    let characterID: UUID
    let categories: Set<SailuneAICharacterCategory>
}

struct SailuneAIMessage: Codable, Identifiable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    let attachment: SailuneAISectionAttachment?
    let evidence: [SailuneAIEvidence]

    init(id: UUID = UUID(), role: Role, text: String, attachment: SailuneAISectionAttachment? = nil, evidence: [SailuneAIEvidence] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.attachment = attachment
        self.evidence = evidence
    }
}

struct SailuneAIEvidence: Codable, Identifiable {
    let id: UUID
    let quote: String
    let isVerified: Bool

    init(id: UUID = UUID(), quote: String, isVerified: Bool) {
        self.id = id
        self.quote = quote
        self.isVerified = isVerified
    }
}

struct SailuneAIChatRequest: Encodable {
    struct Turn: Encodable {
        let role: SailuneAIMessage.Role
        let text: String
        let attachment: SailuneAISectionAttachment?

        init(role: SailuneAIMessage.Role, text: String, attachment: SailuneAISectionAttachment? = nil) {
            self.role = role
            self.text = text
            self.attachment = attachment
        }
    }

    let sectionContent: String?
    let messages: [Turn]
}

struct SailuneAIChatResponse: Decodable {
    let answer: String
    let evidenceQuotes: [String]
}

enum SailuneAIResponseValidation {
    static func evidence(from quotes: [String], in sectionContent: String) -> [SailuneAIEvidence] {
        quotes.map { quote in
            let trimmed = quote.trimmingCharacters(in: .whitespacesAndNewlines)
            return SailuneAIEvidence(
                quote: trimmed,
                isVerified: !trimmed.isEmpty && sectionContent.contains(trimmed)
            )
        }
    }
}

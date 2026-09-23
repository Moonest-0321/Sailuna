import Foundation

struct SailuneAISectionAttachment: Codable, Identifiable {
    enum Kind: String, Codable {
        case section
        case characterProfile
        case characterSectionTemplate
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

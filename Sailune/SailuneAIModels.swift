import Foundation

struct SailuneAISectionAttachment: Codable, Identifiable {
    let id: UUID
    let title: String
    let content: String
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

import Foundation

struct SailuneAIConversation: Codable, Identifiable {
    let id: UUID
    var title: String
    var updatedAt: Date
    var messages: [SailuneAIMessage]

    init(id: UUID = UUID(), title: String = "新對話", updatedAt: Date = .now, messages: [SailuneAIMessage] = []) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

struct SailuneAIConversationArchive: Codable {
    var selectedConversationID: UUID
    var conversations: [SailuneAIConversation]
}

/// 對話依書籍 UUID 分檔，與 SwiftData schema 分離；完整備份及刪書會一併處理此目錄。
struct SailuneAIConversationStore {
    let directory: URL

    init(directory: URL = SailuneDataLocations.current.aiConversationsDirectory) {
        self.directory = directory
    }

    func load(bookID: UUID) throws -> SailuneAIConversationArchive? {
        let url = fileURL(for: bookID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(SailuneAIConversationArchive.self, from: Data(contentsOf: url))
    }

    func save(_ archive: SailuneAIConversationArchive, bookID: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(to: fileURL(for: bookID), options: .atomic)
    }

    func removeBook(bookID: UUID) throws {
        let url = fileURL(for: bookID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func fileURL(for bookID: UUID) -> URL {
        directory.appendingPathComponent("\(bookID.uuidString).json")
    }
}

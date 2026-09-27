import Foundation
import Observation

enum ForumBoard: String, CaseIterable, Codable, Identifiable {
    case announcements
    case writing
    case works
    case sailune
    case suggestions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .announcements: "官方公告"
        case .writing: "寫作交流"
        case .works: "作品交流"
        case .sailune: "帆夢交流"
        case .suggestions: "功能建議"
        }
    }

    var summary: String {
        switch self {
        case .announcements: "版本更新與重要消息"
        case .writing: "情節、人物、節奏與寫作卡關"
        case .works: "分享作品簡介或摘錄，交流回饋"
        case .sailune: "使用方法與問題排除"
        case .suggestions: "分享功能想法與使用問題"
        }
    }
}

struct ForumPost: Codable, Equatable, Identifiable {
    let id: UUID
    let board: ForumBoard
    var title: String
    var body: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        board: ForumBoard,
        title: String,
        body: String,
        createdAt: Date = .now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.board = board
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

struct ForumPostDocument: Codable, Equatable {
    var version: Int = 1
    var posts: [ForumPost] = []
}

@MainActor @Observable
final class LocalForumPostsStore {
    enum StoreError: LocalizedError, Equatable {
        case unavailable
        case emptyTitle
        case emptyBody
        case postNotFound
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unavailable: "論壇資料目前無法使用。請先還原有效備份，再重新開啟論壇。"
            case .emptyTitle: "請輸入文章標題。"
            case .emptyBody: "請輸入文章內文。"
            case .postNotFound: "找不到要修改的文章。"
            case .unsupportedVersion(let version): "不支援的論壇資料版本：\(version)"
            }
        }
    }

    private let url: URL
    private var document: ForumPostDocument
    private(set) var persistenceErrorMessage: String?
    private(set) var unavailableReason: String?
    private(set) var isUnavailable = false

    init(url: URL) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let loaded = try JSONDecoder().decode(ForumPostDocument.self, from: Data(contentsOf: url))
                guard loaded.version == 1 else { throw StoreError.unsupportedVersion(loaded.version) }
                document = loaded
            } catch {
                document = ForumPostDocument()
                isUnavailable = true
                unavailableReason = "無法讀取論壇文章：\(error.localizedDescription)"
                persistenceErrorMessage = unavailableReason
            }
        } else {
            document = ForumPostDocument()
        }
    }

    func posts(in board: ForumBoard) -> [ForumPost] {
        document.posts
            .filter { $0.board == board }
            .sorted {
                if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    func post(id: UUID) -> ForumPost? {
        document.posts.first { $0.id == id }
    }

    @discardableResult
    func create(board: ForumBoard, title: String, body: String, at date: Date = .now) throws -> ForumPost {
        try ensureAvailable()
        let cleanedTitle = try Self.validated(title: title, body: body)
        let cleanedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let post = ForumPost(board: board, title: cleanedTitle, body: cleanedBody, createdAt: date)
        var updated = document
        updated.posts.append(post)
        try persist(updated)
        return post
    }

    @discardableResult
    func update(id: UUID, title: String, body: String, at date: Date = .now) throws -> ForumPost {
        try ensureAvailable()
        let cleanedTitle = try Self.validated(title: title, body: body)
        let cleanedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = document.posts.firstIndex(where: { $0.id == id }) else { throw StoreError.postNotFound }
        var updated = document
        var post = updated.posts[index]
        post.title = cleanedTitle
        post.body = cleanedBody
        post.updatedAt = max(date, post.createdAt)
        updated.posts[index] = post
        try persist(updated)
        return post
    }

    func delete(id: UUID) throws {
        try ensureAvailable()
        guard document.posts.contains(where: { $0.id == id }) else { throw StoreError.postNotFound }
        var updated = document
        updated.posts.removeAll { $0.id == id }
        try persist(updated)
    }

    func clearPersistenceError() {
        persistenceErrorMessage = nil
    }

    private func ensureAvailable() throws {
        guard !isUnavailable else { throw StoreError.unavailable }
    }

    private static func validated(title: String, body: String) throws -> String {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { throw StoreError.emptyTitle }
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError.emptyBody }
        return cleanedTitle
    }

    private func persist(_ updated: ForumPostDocument) throws {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(updated).write(to: url, options: .atomic)
            document = updated
            persistenceErrorMessage = nil
        } catch {
            persistenceErrorMessage = "無法儲存論壇文章：\(error.localizedDescription)"
            throw error
        }
    }
}

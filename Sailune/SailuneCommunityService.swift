import Foundation
import Supabase

struct SharedForumPost: Decodable, Identifiable {
    let id: UUID
    let authorId: UUID
    let displayName: String
    let board: ForumBoard
    let title: String
    let body: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, board, title, body
        case authorId = "author_id"
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SharedTemplateSummary: Decodable, Identifiable {
    let id: UUID
    let ownerId: UUID
    let displayName: String
    let name: String
    let summary: String
    let formatVersion: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, summary
        case ownerId = "owner_id"
        case displayName = "display_name"
        case formatVersion = "format_version"
        case createdAt = "created_at"
    }
}

private struct NewForumPost: Encodable {
    let id: UUID
    let authorId: UUID
    let displayName: String
    let board: String
    let title: String
    let body: String

    enum CodingKeys: String, CodingKey {
        case id, board, title, body
        case authorId = "author_id"
        case displayName = "display_name"
    }
}

private struct NewSharedTemplate: Encodable {
    let id: UUID
    let ownerId: UUID
    let displayName: String
    let name: String
    let summary: String
    let formatVersion: Int
    let payload: AnyJSON

    enum CodingKeys: String, CodingKey {
        case id, name, summary, payload
        case ownerId = "owner_id"
        case displayName = "display_name"
        case formatVersion = "format_version"
    }
}

enum CommunityFailure: LocalizedError {
    case changedAccount
    case invalidTemplate

    var errorDescription: String? {
        switch self {
        case .changedAccount: "帳號或資料空間已切換，請重新開啟此頁。"
        case .invalidTemplate: "公開模板格式無效或不受此版本支援。"
        }
    }

    static func message(for error: Error) -> String {
        if let failure = error as? CommunityFailure { return failure.localizedDescription }
        if let response = error as? PostgrestError {
            if response.code == "PGRST205" || response.code == "PGRST106" {
                return "共享功能尚未啟用，請聯絡管理員。"
            }
            if response.message.contains("community_rate_limit") { return "操作太頻繁，請稍後再試。" }
            if response.code == "42501" || response.code == "PGRST301" { return "登入已失效或沒有權限，請重新登入。" }
            if response.code == "23505" { return "這份內容已存在，請重新載入後確認。" }
            if response.code == "23514" || response.code == "22001" { return "內容格式或長度不符合公開限制，請檢查後重試。" }
            return "共享服務無法完成操作，請稍後重試。"
        }
        if let failure = error as? PublicationFailure {
            if case .connection = failure { return "無法連接共享服務，請檢查網路後重試。" }
            return failure.localizedDescription
        }
        if error is WorkspaceError { return error.localizedDescription }
        return "無法連接共享服務，請檢查網路後重試。"
    }
}

/// 唯一的共享資料寫入入口。每次呼叫都重新核對工作區與 Supabase Session。
@MainActor
final class SailuneCommunityService {
    private static let communitySchema = "sailune_community"
    private let workspace: WorkspaceCoordinator
    private let auth: SailuneAccountAuthService

    init(workspace: WorkspaceCoordinator, auth: SailuneAccountAuthService) {
        self.workspace = workspace
        self.auth = auth
    }

    private func authorizedClient() async throws -> (PostgrestClient, UUID, UUID) {
        let account = try workspace.requireSignedInAccount(auth: auth)
        let generation = workspace.generation
        let client = try await auth.communityClient(expectedUserID: account.userID)
        try verify(accountID: account.userID, generation: generation)
        return (client.schema(Self.communitySchema), account.userID, generation)
    }

    private func verify(accountID: UUID, generation: UUID) throws {
        guard workspace.generation == generation,
              workspace.currentAccount?.userID == accountID,
              workspace.canUseSignedInFeatures(auth: auth) else {
            throw CommunityFailure.changedAccount
        }
    }

    func listPosts(board: ForumBoard) async throws -> [SharedForumPost] {
        let (client, accountID, generation) = try await authorizedClient()
        let posts: [SharedForumPost] = try await client.from("community_forum_posts")
            .select("id,author_id,display_name,board,title,body,created_at,updated_at")
            .eq("board", value: board.rawValue).eq("hidden", value: false)
            .order("created_at", ascending: false).limit(100).execute().value
        try verify(accountID: accountID, generation: generation)
        return posts
    }

    func isAdmin() async throws -> Bool {
        let (client, accountID, generation) = try await authorizedClient()
        let result: Bool = try await client.rpc("is_admin").execute().value
        try verify(accountID: accountID, generation: generation)
        return result
    }

    func createPost(id: UUID, board: ForumBoard, title: String, body: String, displayName: String) async throws {
        let (client, accountID, generation) = try await authorizedClient()
        let post = NewForumPost(id: id, authorId: accountID, displayName: displayName,
                               board: board.rawValue, title: title, body: body)
        do {
            try await client.from("community_forum_posts").insert(post).execute()
        } catch {
            let insertionError = error
            do {
                let existingPosts: [SharedForumPost] = try await client.from("community_forum_posts")
                    .select("id,author_id,display_name,board,title,body,created_at,updated_at")
                    .eq("id", value: id).execute().value
                guard let existing = existingPosts.first else { throw insertionError }
                guard existing.authorId == accountID, existing.board == board,
                      existing.title == title, existing.body == body else { throw insertionError }
            } catch { throw insertionError }
        }
        try verify(accountID: accountID, generation: generation)
    }

    func updatePost(id: UUID, title: String, body: String) async throws {
        let (client, accountID, generation) = try await authorizedClient()
        let updated: [SharedForumPost] = try await client.from("community_forum_posts")
            .update(["title": title, "body": body]).eq("id", value: id)
            .select("id,author_id,display_name,board,title,body,created_at,updated_at").execute().value
        guard !updated.isEmpty else { throw WorkspaceError.identityMismatch }
        try verify(accountID: accountID, generation: generation)
    }

    func hidePost(id: UUID) async throws {
        let (client, accountID, generation) = try await authorizedClient()
        let updated: [SharedForumPost] = try await client.from("community_forum_posts")
            .update(["hidden": true]).eq("id", value: id)
            .select("id,author_id,display_name,board,title,body,created_at,updated_at").execute().value
        guard !updated.isEmpty else { throw WorkspaceError.identityMismatch }
        try verify(accountID: accountID, generation: generation)
    }

    func listTemplates(query: String) async throws -> [SharedTemplateSummary] {
        let (client, accountID, generation) = try await authorizedClient()
        var request = client.from("community_templates")
            .select("id,owner_id,display_name,name,summary,format_version,created_at")
            .eq("hidden", value: false)
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty { request = request.ilike("name", pattern: "%\(search)%") }
        let templates: [SharedTemplateSummary] = try await request
            .order("created_at", ascending: false).limit(100).execute().value
        try verify(accountID: accountID, generation: generation)
        return templates
    }

    func publishedTemplateIDs() async throws -> Set<UUID> {
        let (client, accountID, generation) = try await authorizedClient()
        let templates: [SharedTemplateSummary] = try await client.from("community_templates")
            .select("id,owner_id,display_name,name,summary,format_version,created_at")
            .eq("owner_id", value: accountID).eq("hidden", value: false)
            .limit(1000).execute().value
        try verify(accountID: accountID, generation: generation)
        return Set(templates.map(\.id))
    }

    func publishTemplate(_ template: BookTemplateDocument, displayName: String) async throws {
        let (client, accountID, generation) = try await authorizedClient()
        let sanitized = template.withoutWritingStructure()
        guard sanitized.formatVersion == BookTemplateDocument.currentVersion else { throw CommunityFailure.invalidTemplate }
        let raw = try JSONEncoder().encode(sanitized)
        guard raw.count <= 4_500_000 else { throw CommunityFailure.invalidTemplate }
        let payload = try JSONDecoder().decode(AnyJSON.self, from: raw)
        let submission = NewSharedTemplate(id: sanitized.id, ownerId: accountID,
            displayName: displayName, name: sanitized.name, summary: "設定集・地圖・時間軸",
            formatVersion: sanitized.formatVersion, payload: payload)
        do {
            try await client.from("community_templates").insert(submission).execute()
        } catch {
            let insertionError = error
            do {
                let existing: [String: AnyJSON] = try await client.from("community_templates")
                    .select("owner_id,payload,hidden").eq("id", value: sanitized.id).single().execute().value
                guard existing["owner_id"] == .string(accountID.uuidString.lowercased()),
                      existing["payload"] == payload else { throw insertionError }
                if existing["hidden"] == .bool(true) {
                    let reopened: [SharedTemplateSummary] = try await client.from("community_templates")
                        .update(["hidden": false]).eq("id", value: sanitized.id)
                        .select("id,owner_id,display_name,name,summary,format_version,created_at").execute().value
                    guard reopened.count == 1 else { throw insertionError }
                }
            } catch { throw insertionError }
        }
        try verify(accountID: accountID, generation: generation)
    }

    func hideTemplate(id: UUID) async throws {
        let (client, accountID, generation) = try await authorizedClient()
        let updated: [SharedTemplateSummary] = try await client.from("community_templates")
            .update(["hidden": true]).eq("id", value: id)
            .select("id,owner_id,display_name,name,summary,format_version,created_at").execute().value
        guard !updated.isEmpty else { throw WorkspaceError.identityMismatch }
        try verify(accountID: accountID, generation: generation)
    }

    func downloadTemplate(id: UUID) async throws -> BookTemplateDocument {
        let (client, accountID, generation) = try await authorizedClient()
        let detail: [String: AnyJSON] = try await client.from("community_templates")
            .select("payload").eq("id", value: id).eq("hidden", value: false)
            .single().execute().value
        try verify(accountID: accountID, generation: generation)
        guard let payload = detail["payload"] else { throw CommunityFailure.invalidTemplate }
        let template = try JSONDecoder().decode(BookTemplateDocument.self, from: JSONEncoder().encode(payload))
        guard template.formatVersion == BookTemplateDocument.currentVersion,
              !template.containsWritingStructure else { throw CommunityFailure.invalidTemplate }
        return template
    }
}

import Foundation
import SwiftData

enum BookStatus: String, CaseIterable, Codable, Identifiable {
    case ongoing = "連載"
    case completed = "完結"
    case draft = "草稿"

    var id: String { rawValue }

    var publicationTitle: String { self == .ongoing ? "發布中" : rawValue }
}

/// Publication state lives beside the released V5 store so its schema stays immutable.
@MainActor @Observable
final class BookPublicationStore {
    private let url: URL
    private(set) var statuses: [UUID: BookStatus]

    init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            statuses = try JSONDecoder().decode([UUID: BookStatus].self, from: Data(contentsOf: url))
        } else {
            statuses = [:]
        }
    }

    func status(for bookID: UUID) -> BookStatus { statuses[bookID] ?? .draft }

    func advance(_ bookID: UUID) throws {
        let next: BookStatus
        switch status(for: bookID) {
        case .draft: next = .ongoing
        case .ongoing: next = .completed
        case .completed: return
        }
        var updated = statuses
        updated[bookID] = next
        try save(updated)
        statuses = updated
    }

    func remove(_ bookID: UUID) throws {
        guard statuses[bookID] != nil else { return }
        var updated = statuses
        updated.removeValue(forKey: bookID)
        try save(updated)
        statuses = updated
    }

    private func save(_ value: [UUID: BookStatus]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}

@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""       // 書名
    var author: String = ""      // 作者
    var synopsis: String = ""    // 簡介
    // V6.0c 暫不改動已發布的 V5 主 store；正式持久化會另行建立相容 schema。
    @Transient var status: BookStatus = .draft
    // PRD 提到「隨機柔和底色」，我們用 Data 儲存顏色的 RGBA 資料。
    // 設為可選 (?) 是因為新建時可能還沒算出顏色。
    var coverColorData: Data? = nil
    var createdAt: Date = Date()     // 建立時間
    var updatedAt: Date = Date()     // 最後修改時間
    var currentEra: Era?
    @Relationship(deleteRule: .cascade, inverse: \Timeline.book)
    var timelines: [Timeline] = []
    // 【核心關聯】一本書包含很多卷 (Volume)
    // deleteRule: .cascade「級聯刪除」：書被刪，裡面的卷也自動刪。
    // inverse: 指向 Volume 的 book 屬性，雙向關聯。
    @Relationship(deleteRule: .cascade, inverse: \Volume.book)
    var volumes: [Volume] = []
    // ✅ 正確寫法：明確宣告關聯與反向綁定
    @Relationship(deleteRule: .cascade, inverse: \Character.book)
    var characters: [Character] = []
    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        synopsis: String = "",
        status: BookStatus = .draft,
        coverColorData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        volumes: [Volume] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.synopsis = synopsis
        self.status = status
        self.coverColorData = coverColorData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.volumes = volumes
    }
}

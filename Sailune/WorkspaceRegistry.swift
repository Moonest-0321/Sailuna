import Foundation
import CryptoKit

/// 本機工作區登錄只保存識別與清理進度，不保存 Session。
struct WorkspaceAccount: Codable, Identifiable, Equatable {
    let id: String
    let userID: UUID
    let environment: String
    var email: String
    var penName: String
    var isDeleting = false
}

struct WorkspaceRegistryDocument: Codable {
    var version = 1
    var accounts: [WorkspaceAccount] = []
    var selectedID = "guest"
    var didMigrateLegacy = false
}

final class WorkspaceRegistry {
    let root: URL
    private(set) var document: WorkspaceRegistryDocument
    private let write: (Data, URL) throws -> Void
    var url: URL { root.appendingPathComponent("workspaces.json") }

    init(root: URL, write: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) throws {
        self.root = root
        self.write = write
        let url = root.appendingPathComponent("workspaces.json")
        if FileManager.default.fileExists(atPath: url.path) {
            document = try JSONDecoder().decode(WorkspaceRegistryDocument.self, from: Data(contentsOf: url))
            guard document.version == 1, document.accounts.count <= 2,
                  Set(document.accounts.map(\.id)).count == document.accounts.count,
                  document.accounts.allSatisfy({ $0.id == Self.accountID(userID: $0.userID, environment: $0.environment) }),
                  document.selectedID == "guest" || document.accounts.contains(where: { $0.id == document.selectedID }) else {
                throw WorkspaceError.invalidRegistry
            }
        } else { document = WorkspaceRegistryDocument() }
    }

    nonisolated static func accountID(userID: UUID, environment: String) -> String {
        let digest = SHA256.hash(data: Data(environment.utf8)).map { String(format: "%02x", $0) }.joined()
        return "\(digest)-\(userID.uuidString)"
    }

    func directory(for id: String) throws -> URL {
        guard id == "guest" || document.accounts.contains(where: { $0.id == id }) else { throw WorkspaceError.unknownAccount }
        let directory = root.appendingPathComponent(id, isDirectory: true)
        try Self.rejectSymbolicLinks(at: directory)
        return directory
    }

    /// 檢查全部父目錄，避免受管理位置透過 symlink 指向其他資料。
    static func rejectSymbolicLinks(at url: URL) throws {
        var candidate = url.standardizedFileURL
        while candidate.path != "/" {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: candidate.path)
                if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                    // macOS 的 /var、/tmp、/etc 為固定系統別名；工作區本身的連結仍拒絕。
                    let systemAliases = ["/var": "/private/var", "/tmp": "/private/tmp", "/etc": "/private/etc"]
                    let destination = try FileManager.default.destinationOfSymbolicLink(atPath: candidate.path)
                    let absoluteDestination = destination.hasPrefix("/") ? destination : "/" + destination
                    guard systemAliases[candidate.path] == absoluteDestination else {
                        throw WorkspaceError.unsafePath
                    }
                }
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                // 尚未建立的資料目錄可以安全建立，仍需檢查父目錄。
            }
            candidate.deleteLastPathComponent()
        }
    }

    func update(_ operation: (inout WorkspaceRegistryDocument) throws -> Void) throws {
        var updated = document
        try operation(&updated)
        try Self.rejectSymbolicLinks(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try write(JSONEncoder().encode(updated), url)
        document = updated
    }

    @discardableResult
    func register(userID: UUID, environment: String, email: String) throws -> WorkspaceAccount {
        let id = Self.accountID(userID: userID, environment: environment)
        if let account = document.accounts.first(where: { $0.id == id }) {
            guard !account.isDeleting else { throw WorkspaceError.deletionPending }
            try update { doc in
                if let index = doc.accounts.firstIndex(where: { $0.id == id }) { doc.accounts[index].email = email }
            }
            return document.accounts.first(where: { $0.id == id }) ?? account
        }
        guard document.accounts.count < 2 else { throw WorkspaceError.accountLimit }
        let account = WorkspaceAccount(id: id, userID: userID, environment: environment, email: email, penName: "")
        try update { $0.accounts.append(account) }
        return account
    }

    func markDeleting(_ id: String) throws {
        guard document.accounts.contains(where: { $0.id == id }) else { throw WorkspaceError.unknownAccount }
        try update { doc in
            if let index = doc.accounts.firstIndex(where: { $0.id == id }) { doc.accounts[index].isDeleting = true }
            if doc.selectedID == id { doc.selectedID = "guest" }
        }
    }

    /// 清理全部完成後才移除登錄；失敗保留名額及重試入口。
    func finishDeletion(_ id: String, remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) throws {
        guard document.accounts.contains(where: { $0.id == id && $0.isDeleting }) else { throw WorkspaceError.deletionPending }
        let directory = try directory(for: id)
        if FileManager.default.fileExists(atPath: directory.path) { try remove(directory) }
        try update { $0.accounts.removeAll { $0.id == id } }
    }
}

enum WorkspaceError: LocalizedError {
    case invalidRegistry, unknownAccount, unsafePath, accountLimit, deletionPending
    case busy, saveFailed, identityMismatch, publicationRequiresAccount
    var errorDescription: String? {
        switch self {
        case .invalidRegistry: "資料空間登錄無效，原資料未被覆寫。"
        case .unknownAccount: "找不到此資料空間。"
        case .unsafePath: "資料空間路徑不安全，已停止操作。"
        case .accountLimit: "最多保留兩個帳號，請先移除一個帳號。"
        case .deletionPending: "此帳號資料清理未完成，請重試刪除。"
        case .busy: "目前操作尚未完成，請稍後再切換資料空間。"
        case .saveFailed: "目前內容尚未成功保存，已停止切換。"
        case .publicationRequiresAccount: "未登入空間無法發布，請先切換至已登入帳號。"
        case .identityMismatch: "請登入此資料空間的帳號後再發布。"
        }
    }
}

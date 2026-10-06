import Auth
import Foundation
import OSLog

/// Session 只存鑰匙圈；帳號 key 與工作區使用相同的環境／UUID 身分，不能由 Email 推測。
nonisolated final class SailuneAccountSessionStore: @unchecked Sendable {
    let storage: SailuneAuthStorage
    let environment: String

    init(storage: SailuneAuthStorage, environment: String) {
        self.storage = storage
        self.environment = environment
    }

    func key(for userID: UUID) -> String {
        "sailune.account-session." + WorkspaceRegistry.accountID(userID: userID, environment: environment)
    }

    func save(_ session: Session) throws {
        try storage.store(key: key(for: session.user.id), value: JSONEncoder().encode(session))
    }

    func remove(userID: UUID) throws {
        try storage.remove(key: key(for: userID))
    }

    func scopedStorage(userID: UUID) -> SailuneScopedAuthStorage {
        SailuneScopedAuthStorage(storage: storage, key: key(for: userID))
    }

    /// V12.1 先前只有一個 SDK Session。先保存真正作者的帳號 key，再移除舊 key，重試可冪等。
    func migrateLegacySession() throws {
        guard let host = URL(string: environment)?.host else { return }
        let legacyKey = "sb-\(host.split(separator: ".")[0])-auth-token"
        for sourceKey in [legacyKey, "supabase.session"] {
            guard let data = try storage.retrieve(key: sourceKey) else { continue }
            let session: Session
            do { session = try decodeLegacySession(data) }
            catch {
                // 舊 SDK 也將無法解碼的 Session 視為缺失；保留原件，但不能因此封鎖新 OTP。
                Logger(subsystem: "Sailune", category: "AuthStorage").error("舊版 Session 無法解碼，保留原件；可重新登入建立帳號 Session。")
                continue
            }
            // 舊 SDK 的全域 key 沒有專案命名空間，需核對 JWT issuer 才能認領。
            if sourceKey == "supabase.session", !belongsToEnvironment(session) { continue }
            let destinationKey = key(for: session.user.id)
            if let existing = try storage.retrieve(key: destinationKey) {
                do {
                    let saved = try JSONDecoder().decode(Session.self, from: existing)
                    guard saved.user.id == session.user.id else { throw WorkspaceError.identityMismatch }
                } catch {
                    Logger(subsystem: "Sailune", category: "AuthStorage").error("帳號 Session 無法核對，保留新舊原件；須重新登入。")
                    continue
                }
            } else {
                try save(session)
            }
            try storage.remove(key: sourceKey)
        }
    }

    private func belongsToEnvironment(_ session: Session) -> Bool {
        let parts = session.accessToken.split(separator: ".")
        guard parts.count == 3 else { return false }
        var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded) else { return false }
        do {
            let payload = try JSONDecoder().decode(TokenIssuer.self, from: data)
            return payload.iss == environment.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/auth/v1"
        } catch { return false }
    }

    private func decodeLegacySession(_ data: Data) throws -> Session {
        do { return try JSONDecoder().decode(Session.self, from: data) }
        catch {
            do { return try AuthClient.Configuration.jsonDecoder.decode(Session.self, from: data) }
            catch {
                do { return try JSONDecoder().decode(LegacySession.self, from: data).session }
                catch { return try AuthClient.Configuration.jsonDecoder.decode(LegacySession.self, from: data).session }
            }
        }
    }

    private struct LegacySession: Decodable { let session: Session }
    private struct TokenIssuer: Decodable { let iss: String }
}

/// SDK 各 client 只能讀寫自己的 key，不能透過 SDK 的舊版 migration 認領另一帳號。
nonisolated final class SailuneScopedAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let storage: SailuneAuthStorage
    let key: String
    private let lock = NSLock()
    private var isValid = true

    init(storage: SailuneAuthStorage, key: String) { self.storage = storage; self.key = key }
    func invalidate() { lock.withLock { isValid = false } }

    func retrieve(key: String) throws -> Data? {
        try lock.withLock {
            guard isValid, key == self.key else { return nil }
            return try storage.retrieve(key: key)
        }
    }

    func store(key: String, value: Data) throws {
        try lock.withLock {
            guard isValid, key == self.key else { throw CancellationError() }
            try storage.store(key: key, value: value)
        }
    }

    func remove(key: String) throws {
        try lock.withLock {
            guard isValid, key == self.key else { return }
            try storage.remove(key: key)
        }
    }
}

/// OTP 成功前只讓 SDK 暫存 Session，不覆蓋任何已登入帳號的鑰匙圈資料。
nonisolated final class SailunePendingAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

import Auth
import Foundation
import LocalAuthentication
import Security
import OSLog

/// SDK migration/read retries share one gate. Only an explicit foreground retry may show UI.
/// Cached bytes live only in memory; every changed credential is persisted before it is cached.
nonisolated final class SailuneAuthStorage: AuthLocalStorage, @unchecked Sendable {
    struct Failure: Error, Sendable {
        let status: OSStatus
    }

    typealias Operation = @Sendable (String, Data?, Bool) throws -> Data?
    private let lock = NSLock()
    private let read: Operation
    private let write: Operation
    private let delete: Operation
    private var cache: [String: Data] = [:]
    private var missing: Set<String> = []
    private var blocked: Failure?
    private var interactive = false
    private var onFailure: (@Sendable () -> Void)?

    init(read: @escaping Operation = SailuneAuthStorage.readKeychain,
         write: @escaping Operation = SailuneAuthStorage.writeKeychain,
         delete: @escaping Operation = SailuneAuthStorage.deleteKeychain) {
        self.read = read
        self.write = write
        self.delete = delete
    }

    var failure: Failure? { lock.withLock { blocked } }

    func setFailureHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.withLock { onFailure = handler }
    }

    func beginUserRetry() {
        lock.withLock {
            blocked = nil
            cache.removeAll()
            missing.removeAll()
            interactive = true
        }
    }

    func endUserRetry() { lock.withLock { interactive = false } }

    func retrieve(key: String) throws -> Data? {
        try access("read") {
            if let data = cache[key] { return data }
            if missing.contains(key) { return nil }
            let data = try read(key, nil, interactive)
            if let data { cache[key] = data } else { missing.insert(key) }
            return data
        }
    }

    func store(key: String, value: Data) throws {
        _ = try access("write") {
            if cache[key] == value { return nil }
            _ = try write(key, value, interactive)
            cache[key] = value
            missing.remove(key)
            return nil
        }
    }

    func remove(key: String) throws {
        _ = try access("delete") {
            if !missing.contains(key) { _ = try delete(key, nil, interactive) }
            cache.removeValue(forKey: key)
            missing.insert(key)
            return nil
        }
    }

    private func access(_ name: String, _ operation: () throws -> Data?) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if let blocked { throw blocked }
        do { return try operation() }
        catch {
            let failure = (error as? Failure) ?? Failure(status: errSecInternalComponent)
            Logger(subsystem: "Sailune", category: "AuthStorage").error("Keychain \(name, privacy: .public) failed; background access blocked, OSStatus=\(failure.status, privacy: .public)")
            blocked = failure
            cache.removeAll()
            missing.removeAll()
            interactive = false
            // Handler schedules UI work; it must not re-enter storage while the lock is held.
            onFailure?()
            throw failure
        }
    }

    private static func query(_ key: String, _ interactive: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "supabase.gotrue.swift",
            kSecAttrAccount as String: key
        ]
        if !interactive {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }
        return query
    }

    private static func readKeychain(_ key: String, _ data: Data?, _ interactive: Bool) throws -> Data? {
        var query = query(key, interactive)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw Failure(status: status) }
        guard let bytes = result as? Data else { throw Failure(status: errSecDecode) }
        return bytes
    }

    private static func writeKeychain(_ key: String, _ data: Data?, _ interactive: Bool) throws -> Data? {
        let query = query(key, interactive)
        let attributes = [kSecValueData as String: data ?? Data()]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data ?? Data()
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Failure(status: status) }
        return nil
    }

    private static func deleteKeychain(_ key: String, _ data: Data?, _ interactive: Bool) throws -> Data? {
        let status = SecItemDelete(query(key, interactive) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
        return nil
    }
}

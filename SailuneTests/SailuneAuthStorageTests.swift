import XCTest
import Security
import Supabase
@testable import Sailune

nonisolated private final class AuthStorageFixture: @unchecked Sendable {
    let lock = NSLock()
    var values: [String: Data] = [:]
    var calls = 0
    var status: OSStatus = errSecSuccess
    var interactiveCalls = 0

    func operation(_ key: String, _ data: Data?, _ interactive: Bool) throws -> Data? {
        try lock.withLock {
            calls += 1
            if interactive { interactiveCalls += 1 }
            if status != errSecSuccess { throw SailuneAuthStorage.Failure(status: status) }
            if let data { values[key] = data }
            return values[key]
        }
    }
    func storage() -> SailuneAuthStorage {
        SailuneAuthStorage(read: operation, write: operation, delete: { [self] key, data, interactive in
            _ = try operation(key, data, interactive)
            _ = lock.withLock { values.removeValue(forKey: key) }
            return nil
        })
    }
}

final class SailuneAuthStorageTests: XCTestCase {
    nonisolated func testRealKeychainBackendPersistsReopensAndDeletesIsolatedItem() async throws {
        guard ProcessInfo.processInfo.environment["SAILUNE_REAL_KEYCHAIN_TEST"] == "1" else {
            throw XCTSkip("Opt-in real keychain test; previous host run terminated before completion")
        }
        try await Task.detached {
        let key = "sailune-v111-test-" + UUID().uuidString
        let storage = SailuneAuthStorage()
        let bytes = Data("isolated-test-credential".utf8)
        try storage.store(key: key, value: bytes)
        defer {
            do { try SailuneAuthStorage().remove(key: key) }
            catch { XCTFail("Isolated keychain cleanup failed") }
        }
        XCTAssertEqual(try SailuneAuthStorage().retrieve(key: key), bytes)
        try storage.store(key: key, value: Data("updated-test-credential".utf8))
        XCTAssertEqual(try SailuneAuthStorage().retrieve(key: key), Data("updated-test-credential".utf8))
        try storage.remove(key: key)
        XCTAssertNil(try SailuneAuthStorage().retrieve(key: key))
        }.value
    }

    func testSDKMigrationAndRepeatedSessionReadsDoNotBypassFailureGate() {
        let fixture = AuthStorageFixture()
        fixture.status = errSecUserCanceled
        let storage = fixture.storage()
        let client = SupabaseClient(supabaseURL: URL(string: "https://example.invalid")!,
                                    supabaseKey: "test", options: .init(auth: .init(storage: storage, autoRefreshToken: false)))
        for _ in 0..<100 { XCTAssertNil(client.auth.currentSession) }
        XCTAssertEqual(fixture.calls, 1)
        XCTAssertEqual(storage.failure?.status, errSecUserCanceled)
    }

    func testDenialCancellationAndReadFailureBlockAllRepeatedOperations() throws {
        for status in [errSecAuthFailed, errSecUserCanceled, errSecInteractionNotAllowed, errSecNotAvailable] {
            let fixture = AuthStorageFixture()
            fixture.status = status
            let storage = fixture.storage()
            XCTAssertThrowsError(try storage.retrieve(key: "session"))
            for _ in 0..<100 {
                XCTAssertThrowsError(try storage.retrieve(key: "session"))
                XCTAssertThrowsError(try storage.store(key: "session", value: Data([1])))
                XCTAssertThrowsError(try storage.remove(key: "session"))
            }
            XCTAssertEqual(fixture.calls, 1)
            XCTAssertEqual(fixture.interactiveCalls, 0)
            XCTAssertEqual(storage.failure?.status, status)
        }
    }

    func testExplicitRetryAllowsAccessAndCachesMigrationReads() throws {
        let fixture = AuthStorageFixture()
        fixture.status = errSecUserCanceled
        let storage = fixture.storage()
        XCTAssertThrowsError(try storage.retrieve(key: "session"))
        fixture.status = errSecSuccess
        fixture.values["session"] = Data([1])
        storage.beginUserRetry()
        XCTAssertEqual(try storage.retrieve(key: "session"), Data([1]))
        storage.endUserRetry()
        for _ in 0..<100 { XCTAssertEqual(try storage.retrieve(key: "session"), Data([1])) }
        XCTAssertEqual(fixture.calls, 2)
        XCTAssertEqual(fixture.interactiveCalls, 1)
        XCTAssertNil(storage.failure)
    }

    func testChangedCredentialsPersistAndRestoreInNewInstance() throws {
        let fixture = AuthStorageFixture()
        let storage = fixture.storage()
        XCTAssertNil(try storage.retrieve(key: "session"))
        try storage.store(key: "session", value: Data([1]))
        try storage.store(key: "session", value: Data([1]))
        try storage.store(key: "session", value: Data([2]))
        XCTAssertEqual(fixture.calls, 3)
        XCTAssertEqual(try fixture.storage().retrieve(key: "session"), Data([2]))
        try storage.remove(key: "session")
        XCTAssertNil(try fixture.storage().retrieve(key: "session"))
    }

    func testWriteAndDeleteFailuresDiscardCacheAndRemainBlocked() throws {
        for deleting in [false, true] {
            let fixture = AuthStorageFixture()
            fixture.values["session"] = Data([1])
            let storage = fixture.storage()
            _ = try storage.retrieve(key: "session")
            fixture.status = errSecAuthFailed
            if deleting { XCTAssertThrowsError(try storage.remove(key: "session")) }
            else { XCTAssertThrowsError(try storage.store(key: "session", value: Data([2]))) }
            XCTAssertThrowsError(try storage.retrieve(key: "session"))
            XCTAssertEqual(fixture.calls, 2)
            XCTAssertEqual(fixture.values["session"], Data([1]))
        }
    }

    func testCancelDuringExplicitRetryDoesNotPromptAgain() throws {
        let fixture = AuthStorageFixture()
        fixture.status = errSecUserCanceled
        let storage = fixture.storage()
        storage.beginUserRetry()
        XCTAssertThrowsError(try storage.retrieve(key: "session"))
        XCTAssertThrowsError(try storage.retrieve(key: "legacy"))
        storage.endUserRetry()
        XCTAssertEqual(fixture.calls, 1)
        XCTAssertEqual(fixture.interactiveCalls, 1)
    }
}

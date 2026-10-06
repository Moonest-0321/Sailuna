import Auth
import Foundation
import Security
import Supabase
import XCTest
@testable import Sailune

nonisolated final class AccountSessionFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    var writeStatus: OSStatus = errSecSuccess
    var deleteStatus: OSStatus = errSecSuccess

    func value(_ key: String) -> Data? { lock.withLock { values[key] } }
    func seed(_ key: String, data: Data) { lock.withLock { values[key] = data } }
    func storage() -> SailuneAuthStorage {
        SailuneAuthStorage(read: { [self] key, _, _ in value(key) }, write: { [self] key, data, _ in
            try lock.withLock {
                guard writeStatus == errSecSuccess else { throw SailuneAuthStorage.Failure(status: writeStatus) }
                values[key] = data
                return nil
            }
        }, delete: { [self] key, _, _ in
            try lock.withLock {
                guard deleteStatus == errSecSuccess else { throw SailuneAuthStorage.Failure(status: deleteStatus) }
                values.removeValue(forKey: key)
                return nil
            }
        })
    }
}

nonisolated private final class AccountSessionProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (AccountSessionProtocol) throws -> (Int, Data)?)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let response = try Self.handler?(self) else { return }
            finish(status: response.0, data: response.1)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    func finish(status: Int, data: Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

nonisolated private final class HeldSessionRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var request: AccountSessionProtocol?
    let started = XCTestExpectation(description: "舊帳號 Session 續期已送出")
    func hold(_ request: AccountSessionProtocol) {
        lock.withLock { self.request = request }
        started.fulfill()
    }
    func finish() {
        lock.withLock { request }?.finish(status: 400,
            data: Data(#"{"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token"}"#.utf8))
    }
}

@MainActor
final class AccountSessionTests: XCTestCase {
    private let endpoint = URL(string: "https://accounts.example")!

    private func session(userID: UUID = UUID(), email: String = "a@example.test", expired: Bool = false) throws -> Session {
        let expiry = Date().timeIntervalSince1970 + (expired ? -300 : 3600)
        let payload = try JSONSerialization.data(withJSONObject: ["iss": endpoint.absoluteString + "/auth/v1", "exp": expiry, "sub": userID.uuidString])
        let encoded = payload.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return Session(accessToken: "eyJhbGciOiJIUzI1NiJ9.\(encoded).test-signature", tokenType: "bearer",
            expiresIn: 3600, expiresAt: expiry, refreshToken: "test-refresh-\(userID.uuidString)",
            user: User(id: userID, appMetadata: [:], userMetadata: [:], aud: "authenticated", email: email,
                       createdAt: Date(), updatedAt: Date()))
    }

    private func account(_ session: Session) -> WorkspaceAccount {
        WorkspaceAccount(id: WorkspaceRegistry.accountID(userID: session.user.id, environment: endpoint.absoluteString),
            userID: session.user.id, environment: endpoint.absoluteString, email: session.user.email!, penName: "")
    }

    private func service(_ fixture: AccountSessionFixture, storage: SailuneAuthStorage? = nil) -> SailuneAccountAuthService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountSessionProtocol.self]
        let auth = SailuneAccountAuthService(supabaseURL: endpoint, publishableKey: "test-publishable",
            storage: storage ?? fixture.storage(), httpSession: URLSession(configuration: configuration))
        addTeardownBlock { await auth.restoreSession(for: nil) }
        return auth
    }

    private func coordinator() throws -> WorkspaceCoordinator {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AccountSessionTests-\(UUID().uuidString)")
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return WorkspaceCoordinator(legacyLocations: SailuneDataLocations(mainStore: root.appendingPathComponent("Sailune-v5.store")))
    }

    func testOTPForTwoAccountsThenForumSwitchesAndReopensWithoutAnotherOTP() async throws {
        let fixture = AccountSessionFixture()
        let auth = service(fixture)
        let workspace = try coordinator()
        let first = try session()
        let second = try session(email: "b@example.test")
        for signedIn in [first, second] {
            let response = try AuthClient.Configuration.jsonEncoder.encode(signedIn)
            AccountSessionProtocol.handler = { request in
                switch request.request.url!.lastPathComponent {
                case "otp": return (200, Data("{}".utf8))
                case "verify": return (200, response)
                default: throw URLError(.unsupportedURL)
                }
            }
            await auth.sendCode(to: signedIn.user.email!)
            XCTAssertNil(auth.errorMessage)
            let verified = await auth.verifyCode("123456", for: signedIn.user.email!)
            XCTAssertTrue(verified, auth.errorMessage ?? "")
            workspace.openAuthenticatedAccount(auth: auth)
            XCTAssertTrue(workspace.canUseSignedInFeatures(auth: auth))
        }
        for selected in [first, second, first, second] {
            await workspace.switchTo(account(selected).id, auth: auth)
            XCTAssertEqual(auth.signedInUserID, selected.user.id)
            XCTAssertTrue(workspace.canUseSignedInFeatures(auth: auth))
            let expectedHeader = "Bearer " + selected.accessToken
            AccountSessionProtocol.handler = { request in
                XCTAssertEqual(request.request.value(forHTTPHeaderField: "Authorization"), expectedHeader)
                XCTAssertEqual(request.request.url!.lastPathComponent, "community_forum_posts", "切換後不得重新呼叫 OTP")
                return (200, Data("[]".utf8))
            }
            let posts = try await SailuneCommunityService(workspace: workspace, auth: auth).listPosts(board: .writing)
            XCTAssertTrue(posts.isEmpty)
        }
        await auth.restoreSession(for: nil)
        let reopened = service(fixture)
        await reopened.restoreSession(for: account(second))
        XCTAssertEqual(reopened.signedInUserID, second.user.id)
        let client = try await reopened.communityClient(expectedUserID: second.user.id)
        XCTAssertEqual(client.auth.currentSession?.accessToken, second.accessToken)
        await reopened.restoreSession(for: account(first))
        XCTAssertEqual(reopened.signedInUserID, first.user.id)
    }

    func testLegacyMigrationUsesStoredUUIDAndPreservesNewerSessionAndRetriesFailedWrite() throws {
        let fixture = AccountSessionFixture()
        let original = try session()
        let legacyKey = "sb-accounts-auth-token"
        fixture.seed(legacyKey, data: try JSONEncoder().encode(original))
        fixture.writeStatus = errSecAuthFailed
        let storage = fixture.storage()
        let store = SailuneAccountSessionStore(storage: storage, environment: endpoint.absoluteString)
        XCTAssertThrowsError(try store.migrateLegacySession())
        XCTAssertNotNil(fixture.value(legacyKey), "成功保存前不能清原憑證")
        fixture.writeStatus = errSecSuccess
        storage.beginUserRetry()
        try store.migrateLegacySession()
        storage.endUserRetry()
        XCTAssertNil(fixture.value(legacyKey))
        XCTAssertEqual(try JSONDecoder().decode(Session.self, from: XCTUnwrap(fixture.value(store.key(for: original.user.id)))).user.id, original.user.id)
        var newer = original
        newer.refreshToken = "newer-test-refresh"
        try store.save(newer)
        try storage.store(key: legacyKey, value: JSONEncoder().encode(original))
        try store.migrateLegacySession()
        try store.migrateLegacySession()
        XCTAssertEqual(try JSONDecoder().decode(Session.self, from: XCTUnwrap(fixture.value(store.key(for: original.user.id)))).refreshToken, newer.refreshToken)
    }

    func testScopedSDKClientsCannotClaimGlobalLegacyOrOverwriteAfterInvalidation() async throws {
        let fixture = AccountSessionFixture()
        let signedIn = try session()
        fixture.seed("supabase.session", data: try JSONEncoder().encode(signedIn))
        let store = SailuneAccountSessionStore(storage: fixture.storage(), environment: "https://another.example")
        try store.migrateLegacySession()
        XCTAssertNotNil(fixture.value("supabase.session"))
        let scoped = store.scopedStorage(userID: UUID())
        let client = SupabaseClient(supabaseURL: endpoint, supabaseKey: "test", options: .init(
            auth: .init(storage: scoped, storageKey: scoped.key, autoRefreshToken: false)))
        XCTAssertNil(client.auth.currentSession)
        XCTAssertNotNil(fixture.value("supabase.session"))
        scoped.invalidate()
        XCTAssertThrowsError(try scoped.store(key: scoped.key, value: Data([1])))
        XCTAssertNil(fixture.value(scoped.key))
    }

    func testUnreadableLegacySessionDoesNotBlockNewOTPOrDeleteOriginal() async throws {
        let fixture = AccountSessionFixture()
        let original = Data("unreadable-test-session".utf8)
        fixture.seed("sb-accounts-auth-token", data: original)
        let signedIn = try session()
        let response = try AuthClient.Configuration.jsonEncoder.encode(signedIn)
        AccountSessionProtocol.handler = { request in
            (200, request.request.url!.lastPathComponent == "verify" ? response : Data("{}".utf8))
        }
        let auth = service(fixture)
        await auth.sendCode(to: signedIn.user.email!)
        XCTAssertNil(auth.errorMessage)
        let verified = await auth.verifyCode("123456", for: signedIn.user.email!)
        XCTAssertTrue(verified)
        XCTAssertEqual(auth.signedInUserID, signedIn.user.id)
        XCTAssertEqual(fixture.value("sb-accounts-auth-token"), original)
    }

    func testWrappedLegacyMigrationCanRetryCleanupAfterDestinationIsSaved() throws {
        let fixture = AccountSessionFixture()
        let original = try session()
        let encoded = try AuthClient.Configuration.jsonEncoder.encode(original)
        fixture.seed("supabase.session", data: Data("{\"session\":\(String(decoding: encoded, as: UTF8.self))}".utf8))
        let storage = fixture.storage()
        let store = SailuneAccountSessionStore(storage: storage, environment: endpoint.absoluteString)
        fixture.deleteStatus = errSecAuthFailed
        XCTAssertThrowsError(try store.migrateLegacySession())
        XCTAssertNotNil(fixture.value(store.key(for: original.user.id)))
        XCTAssertNotNil(fixture.value("supabase.session"))
        fixture.deleteStatus = errSecSuccess
        storage.beginUserRetry()
        try store.migrateLegacySession()
        storage.endUserRetry()
        XCTAssertNil(fixture.value("supabase.session"))
        XCTAssertEqual(try JSONDecoder().decode(Session.self, from: XCTUnwrap(fixture.value(store.key(for: original.user.id)))).user.id, original.user.id)
    }

    func testRefreshRotatesOnlySelectedAccountAndSignOutPreservesOtherAccount() async throws {
        let fixture = AccountSessionFixture()
        let expired = try session(expired: true)
        var renewed = try session(userID: expired.user.id)
        renewed.refreshToken = "rotated-test-refresh"
        let second = try session(email: "b@example.test")
        let store = SailuneAccountSessionStore(storage: fixture.storage(), environment: endpoint.absoluteString)
        try store.save(expired)
        try store.save(second)
        let response = try AuthClient.Configuration.jsonEncoder.encode(renewed)
        let expectedHeader = "Bearer " + renewed.accessToken
        AccountSessionProtocol.handler = { request in
            if request.request.url!.lastPathComponent == "logout" {
                XCTAssertEqual(request.request.value(forHTTPHeaderField: "Authorization"), expectedHeader)
                return (204, Data())
            }
            XCTAssertEqual(request.request.url!.lastPathComponent, "token")
            return (200, response)
        }
        let auth = service(fixture)
        await auth.restoreSession(for: account(expired))
        XCTAssertEqual(auth.signedInUserID, expired.user.id)
        XCTAssertEqual(try JSONDecoder().decode(Session.self, from: XCTUnwrap(fixture.value(store.key(for: expired.user.id)))).refreshToken, renewed.refreshToken)
        await auth.signOut(localOnly: true)
        XCTAssertNil(auth.errorMessage)
        XCTAssertNil(auth.signedInUserID)
        XCTAssertNil(fixture.value(store.key(for: expired.user.id)))
        XCTAssertNotNil(fixture.value(store.key(for: second.user.id)))
        await auth.restoreSession(for: account(second))
        XCTAssertEqual(auth.signedInUserID, second.user.id)
    }

    func testGuestAndWrongUUIDStayBlockedAndDoNotEraseAccountSessions() async throws {
        let fixture = AccountSessionFixture()
        let saved = try session()
        let store = SailuneAccountSessionStore(storage: fixture.storage(), environment: endpoint.absoluteString)
        try store.save(saved)
        let auth = service(fixture)
        await auth.restoreSession(for: account(saved))
        do { _ = try await auth.communityClient(expectedUserID: UUID()); XCTFail("不得借用另一帳號 Session") }
        catch PublicationFailure.login {}
        await auth.restoreSession(for: nil)
        XCTAssertNil(auth.signedInUserID)
        do { _ = try await auth.communityClient(expectedUserID: saved.user.id); XCTFail("Guest 不得借用保存的 Session") }
        catch PublicationFailure.login {}
        XCTAssertNotNil(fixture.value(store.key(for: saved.user.id)))
        await auth.restoreSession(for: account(saved))
        XCTAssertEqual(auth.signedInUserID, saved.user.id)
    }

    func testRefreshFailureInOneAccountDoesNotInvalidateOtherAccount() async throws {
        let fixture = AccountSessionFixture()
        let expired = try session(expired: true)
        let valid = try session(email: "b@example.test")
        let store = SailuneAccountSessionStore(storage: fixture.storage(), environment: endpoint.absoluteString)
        try store.save(expired)
        try store.save(valid)
        AccountSessionProtocol.handler = { _ in (400, Data(#"{"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token"}"#.utf8)) }
        let auth = service(fixture)
        await auth.restoreSession(for: account(expired))
        XCTAssertNil(auth.signedInUserID)
        XCTAssertNotNil(auth.errorMessage)
        await auth.restoreSession(for: account(valid))
        XCTAssertEqual(auth.signedInUserID, valid.user.id)
        _ = try await auth.communityClient(expectedUserID: valid.user.id)
        XCTAssertNotNil(fixture.value(store.key(for: valid.user.id)))
    }

    func testTransientRefreshFailureKeepsIdentityAndOffersRetry() async throws {
        let fixture = AccountSessionFixture()
        let expired = try session(expired: true)
        let store = SailuneAccountSessionStore(storage: fixture.storage(), environment: endpoint.absoluteString)
        try store.save(expired)
        AccountSessionProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let auth = service(fixture)
        await auth.restoreSession(for: account(expired))
        XCTAssertEqual(auth.signedInUserID, expired.user.id)
        do { _ = try await auth.communityClient(expectedUserID: expired.user.id); XCTFail("應提示重試") }
        catch PublicationFailure.connection {}
        XCTAssertEqual(auth.signedInUserID, expired.user.id)
    }

    func testOldRefreshFailureAfterSwitchCannotClearNewAccountIdentity() async throws {
        let fixture = AccountSessionFixture()
        let first = try session()
        let second = try session(email: "b@example.test")
        let storage = fixture.storage()
        let store = SailuneAccountSessionStore(storage: storage, environment: endpoint.absoluteString)
        try store.save(first)
        try store.save(second)
        let auth = service(fixture, storage: storage)
        await auth.restoreSession(for: account(first))
        let held = HeldSessionRequest()
        AccountSessionProtocol.handler = { request in held.hold(request); return nil }
        try store.save(session(userID: first.user.id, expired: true))
        let previous = Task { try await auth.communityClient(expectedUserID: first.user.id) }
        await fulfillment(of: [held.started], timeout: 5)
        await auth.restoreSession(for: account(second))
        held.finish()
        do { _ = try await previous.value; XCTFail("舊回呼應拒絕") }
        catch WorkspaceError.identityMismatch {}
        XCTAssertEqual(auth.signedInUserID, second.user.id)
    }

    func testRemovingInactiveAccountPreservesCurrentSessionAndReopen() async throws {
        let fixture = AccountSessionFixture()
        let first = try session()
        let second = try session(email: "b@example.test")
        let store = SailuneAccountSessionStore(storage: fixture.storage(), environment: endpoint.absoluteString)
        try store.save(first)
        try store.save(second)
        let auth = service(fixture)
        await auth.restoreSession(for: account(first))
        await auth.restoreSession(for: account(second))
        try await auth.removeAccountSession(account(first))
        XCTAssertNil(fixture.value(store.key(for: first.user.id)))
        XCTAssertNotNil(fixture.value(store.key(for: second.user.id)))
        XCTAssertEqual(auth.signedInUserID, second.user.id)
        let reopened = service(fixture)
        await reopened.restoreSession(for: account(second))
        XCTAssertEqual(reopened.signedInUserID, second.user.id)
        await reopened.restoreSession(for: account(first))
        XCTAssertNil(reopened.signedInUserID)
    }

    func testFailedWorkspaceSaveKeepsOriginalAccountAndItsLogin() async throws {
        let fixture = AccountSessionFixture()
        let first = try session()
        let second = try session(email: "b@example.test")
        let store = SailuneAccountSessionStore(storage: fixture.storage(), environment: endpoint.absoluteString)
        try store.save(first)
        try store.save(second)
        let workspace = try coordinator()
        workspace.openAccount(userID: first.user.id, environment: endpoint.absoluteString, email: first.user.email!)
        workspace.openAccount(userID: second.user.id, environment: endpoint.absoluteString, email: second.user.email!)
        let auth = service(fixture)
        await workspace.switchTo(account(first).id, auth: auth)
        let participant = UUID()
        workspace.registerParticipant(id: participant) { throw WorkspaceError.saveFailed }
        await workspace.switchTo(account(second).id, auth: auth)
        XCTAssertEqual(workspace.selectedID, account(first).id)
        XCTAssertEqual(auth.signedInUserID, first.user.id)
        XCTAssertTrue(workspace.canUseSignedInFeatures(auth: auth))
        XCTAssertNotNil(workspace.errorMessage)
        workspace.unregisterParticipant(id: participant)
    }
}

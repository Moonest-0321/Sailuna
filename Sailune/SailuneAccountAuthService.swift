import Auth
import Foundation
import Observation
import Supabase

/// 管理拾頁共用的 Email OTP Session；Supabase SDK 將 Session 保存在 macOS 鑰匙圈。
@MainActor
@Observable
final class SailuneAccountAuthService {
    private(set) var signedInEmail: String?
    private(set) var signedInUserID: UUID?
    private(set) var environmentID: String?
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    private let storage: SailuneAuthStorage
    private let sessions: SailuneAccountSessionStore?
    private let httpSession: URLSession
    private var didRestore = false
    private var didMigrateSessions = false
    private var selectedAccount: WorkspaceAccount?
    private var selectionGeneration = UUID()
    private(set) var needsKeychainRetry = false

    private var client: SupabaseClient?
    private var loginClient: SupabaseClient?
    @ObservationIgnored private var accountClients: [UUID: AccountClient] = [:]
    private var publicationConfiguration: (URL, String)?

    private struct AccountClient {
        let client: SupabaseClient
        let storage: SailuneScopedAuthStorage
    }

    var isConfigured: Bool { publicationConfiguration != nil }

    private static func requiresLogin(after error: Error) -> Bool {
        guard let authError = error as? AuthError else { return false }
        return [.sessionNotFound, .sessionExpired, .refreshTokenNotFound,
                .refreshTokenAlreadyUsed, .invalidCredentials].contains(authError.errorCode)
    }

    convenience init(bundle: Bundle = .main) {
        #if DEBUG
        // XCTest host 不可碰正式鑰匙圈；Auth 專項透過下方 initializer 注入隔離儲存與 HTTP。
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil {
            self.init(supabaseURL: nil, publishableKey: "", storage: SailuneAuthStorage())
            return
        }
        #endif
        let endpoint = bundle.object(forInfoDictionaryKey: "SailuneSupabaseURL") as? String ?? ""
        let publishableKey = bundle.object(forInfoDictionaryKey: "SailuneSupabasePublishableKey") as? String ?? ""
        self.init(supabaseURL: URL(string: endpoint), publishableKey: publishableKey, storage: SailuneAuthStorage())
    }

    init(supabaseURL: URL?, publishableKey: String, storage: SailuneAuthStorage, httpSession: URLSession = .shared) {
        self.storage = storage
        self.httpSession = httpSession
        guard let url = supabaseURL,
              url.scheme == "https",
              url.host != nil,
              !publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            sessions = nil
            return
        }

        environmentID = url.absoluteString
        publicationConfiguration = (url, publishableKey)
        sessions = SailuneAccountSessionStore(storage: storage, environment: url.absoluteString)
        storage.setFailureHandler { [weak self] in
            Task { @MainActor [weak self] in await self?.reportStorageFailure() }
        }
    }

    private func makeClient(storage: any AuthLocalStorage, key: String) -> SupabaseClient? {
        guard let (url, publishableKey) = publicationConfiguration else { return nil }
        return SupabaseClient(supabaseURL: url, supabaseKey: publishableKey, options: .init(
            auth: .init(storage: storage, storageKey: key, autoRefreshToken: false),
            global: .init(session: httpSession)))
    }

    private func accountClient(userID: UUID) -> SupabaseClient? {
        if let existing = accountClients[userID] { return existing.client }
        guard let sessions else { return nil }
        let scopedStorage = sessions.scopedStorage(userID: userID)
        guard let client = makeClient(storage: scopedStorage, key: scopedStorage.key) else { return nil }
        accountClients[userID] = AccountClient(client: client, storage: scopedStorage)
        return client
    }

    private func migrateSessionsIfNeeded() throws {
        guard !didMigrateSessions, let sessions else { return }
        try sessions.migrateLegacySession()
        didMigrateSessions = true
    }

    private func reportStorageFailure() async {
        guard storage.failure != nil else { return }
        signedInEmail = nil; signedInUserID = nil
        needsKeychainRetry = true
        errorMessage = "無法存取登入鑰匙圈，已停止背景重試。請按「重試鑰匙圈授權」。"
        for entry in accountClients.values { await entry.client.auth.stopAutoRefresh() }
    }

    func retryKeychainAccess() async {
        guard !isWorking else { return }
        storage.beginUserRetry()
        defer { storage.endUserRetry() }
        needsKeychainRetry = false
        errorMessage = nil
        didRestore = false
        await restoreSession(for: selectedAccount)
    }

    func restoreSession(for account: WorkspaceAccount?) async {
        guard isConfigured, !isWorking,
              !didRestore || selectedAccount?.id != account?.id else { return }
        didRestore = true
        isWorking = true
        defer { isWorking = false }
        await client?.auth.stopAutoRefresh()
        selectionGeneration = UUID()
        selectedAccount = account
        signedInEmail = nil; signedInUserID = nil
        client = nil
        errorMessage = nil
        do { try migrateSessionsIfNeeded() }
        catch {
            if storage.failure != nil { await reportStorageFailure() }
            else { errorMessage = "無法讀取保存的登入資料，請重新登入。" }
            return
        }
        guard let account else { return }
        guard account.environment == environmentID,
              let client = accountClient(userID: account.userID) else {
            errorMessage = WorkspaceError.identityMismatch.localizedDescription
            return
        }
        self.client = client
        let hadSavedSession = client.auth.currentSession != nil
        do {
            let session = try await client.auth.session
            guard storage.failure == nil else { await reportStorageFailure(); return }
            guard session.user.id == account.userID else { throw WorkspaceError.identityMismatch }
            signedInUserID = session.user.id
            signedInEmail = session.user.email
            await client.auth.startAutoRefresh()
        } catch {
            if storage.failure != nil { await reportStorageFailure() }
            else if Self.requiresLogin(after: error) {
                signedInEmail = nil; signedInUserID = nil
                if hadSavedSession || error as? AuthError != .sessionMissing { errorMessage = "登入已失效，請重新登入。" }
            } else {
                // 已保存的 Session 暫時無法續期時仍保留身分，後續社群操作可重試。
                if let cached = client.auth.currentSession, cached.user.id == account.userID {
                    signedInUserID = cached.user.id
                    signedInEmail = cached.user.email
                    await client.auth.startAutoRefresh()
                }
                errorMessage = error is WorkspaceError ? error.localizedDescription : "暫時無法確認登入狀態，請檢查網路後重試。"
            }
        }
    }

    func sendCode(to email: String) async {
        guard isConfigured else {
            errorMessage = "登入服務尚未設定。"
            return
        }
        guard !isWorking else { return }
        guard storage.failure == nil else { await reportStorageFailure(); return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try migrateSessionsIfNeeded()
            if loginClient == nil { loginClient = makeClient(storage: SailunePendingAuthStorage(), key: "sailune.pending-auth") }
            guard let client = loginClient else { throw PublicationFailure.configuration }
            try await client.auth.signInWithOTP(email: email)
            if storage.failure != nil { await reportStorageFailure() }
        } catch {
            if storage.failure != nil { await reportStorageFailure(); return }
            errorMessage = safeMessage(for: error, isVerification: false)
        }
    }

    func verifyCode(_ code: String, for email: String) async -> Bool {
        guard let client = loginClient, let sessions else {
            errorMessage = "登入服務尚未設定。"
            return false
        }
        guard !isWorking else { return false }
        guard storage.failure == nil else { await reportStorageFailure(); return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
            guard storage.failure == nil else { await reportStorageFailure(); return false }
            guard let session = response.session else { throw AuthError.sessionMissing }
            // 停用舊 client 的存取，避免前一次續期回呼覆蓋這次新登入的 Session。
            if let previous = accountClients.removeValue(forKey: session.user.id) {
                previous.storage.invalidate()
                await previous.client.auth.stopAutoRefresh()
            }
            try sessions.save(session)
            await self.client?.auth.stopAutoRefresh()
            selectionGeneration = UUID()
            selectedAccount = WorkspaceAccount(id: WorkspaceRegistry.accountID(userID: session.user.id, environment: sessions.environment),
                userID: session.user.id, environment: sessions.environment, email: response.user.email ?? email, penName: "")
            self.client = accountClient(userID: session.user.id)
            didRestore = true
            loginClient = nil
            signedInUserID = response.user.id
            signedInEmail = response.user.email ?? email
            await self.client?.auth.startAutoRefresh()
            return true
        } catch {
            if storage.failure != nil { await reportStorageFailure(); return false }
            errorMessage = safeMessage(for: error, isVerification: true)
            return false
        }
    }

    func signOut(localOnly: Bool = false) async {
        guard !isWorking else { return }
        guard storage.failure == nil else { await reportStorageFailure(); return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            if let client { try await client.auth.signOut(scope: localOnly ? .local : .global) }
            guard storage.failure == nil else { await reportStorageFailure(); return }
            await client?.auth.stopAutoRefresh()
            if let account = selectedAccount { try removeSavedSession(for: account) }
            clearActiveIdentity()
        } catch {
            if storage.failure != nil { await reportStorageFailure(); return }
            if client?.auth.currentSession == nil { signedInEmail = nil; signedInUserID = nil }
            errorMessage = "無法退出登入，請稍後再試。"
        }
    }

    /// 移除此裝置帳號只清該 UUID 的登入資料，不能登出另一個仍在使用的帳號。
    func removeAccountSession(_ account: WorkspaceAccount) async throws {
        guard !isWorking else { throw WorkspaceError.busy }
        isWorking = true
        defer { isWorking = false }
        try migrateSessionsIfNeeded()
        if let entry = accountClients[account.userID], account.environment == environmentID {
            await entry.client.auth.stopAutoRefresh()
        }
        try removeSavedSession(for: account)
        if selectedAccount?.id == account.id { clearActiveIdentity() }
    }

    private func removeSavedSession(for account: WorkspaceAccount) throws {
        let store = SailuneAccountSessionStore(storage: storage, environment: account.environment)
        if account.environment == environmentID, let entry = accountClients.removeValue(forKey: account.userID) {
            entry.storage.invalidate()
        }
        try store.remove(userID: account.userID)
    }

    private func clearActiveIdentity() {
        selectionGeneration = UUID()
        client = nil
        selectedAccount = nil
        didRestore = false
        signedInEmail = nil; signedInUserID = nil
    }

    func publicationCredentials(for bookID: UUID, penName: String, expectedUserID: UUID) async throws -> PublicationCredentials {
        guard let (url, key) = publicationConfiguration else { throw PublicationFailure.configuration }
        let (client, session, generation) = try await validatedClient(expectedUserID: expectedUserID)
        do {
            let _: UUID = try await client.rpc("ensure_publication_author_v1", params: [
                "p_book_id": bookID.uuidString, "p_pen_name": penName
            ]).execute().value
        } catch let error as PostgrestError {
            guard generation == selectionGeneration else { throw WorkspaceError.identityMismatch }
            if error.message.contains("publication_author_unbound") { throw PublicationFailure.authorUnbound }
            if error.message.contains("publication_not_owner") { throw PublicationFailure.notOwner }
            if error.message.contains("publication_invalid_pen_name") { throw PublicationFailure.invalidPackage("請填寫有效的筆名後重試。") }
            if error.code == "42501" || error.code == "PGRST301" {
                signedInEmail = nil; signedInUserID = nil; throw PublicationFailure.login
            }
            throw PublicationFailure.connection
        } catch {
            guard generation == selectionGeneration else { throw WorkspaceError.identityMismatch }
            throw PublicationFailure.connection
        }
        guard generation == selectionGeneration else { throw WorkspaceError.identityMismatch }
        return PublicationCredentials(supabaseURL: url, publishableKey: key, token: session.accessToken, userID: session.user.id)
    }

    func communityClient(expectedUserID: UUID) async throws -> SupabaseClient {
        let (client, _, _) = try await validatedClient(expectedUserID: expectedUserID)
        return client
    }

    private func validatedClient(expectedUserID: UUID) async throws -> (SupabaseClient, Session, UUID) {
        guard isConfigured else { throw PublicationFailure.configuration }
        guard selectedAccount?.userID == expectedUserID, let client else { throw PublicationFailure.login }
        let generation = selectionGeneration
        guard storage.failure == nil else { await reportStorageFailure(); throw PublicationFailure.login }
        let session: Session
        do { session = try await client.auth.session }
        catch {
            guard generation == selectionGeneration else { throw WorkspaceError.identityMismatch }
            if storage.failure != nil {
                await reportStorageFailure()
                throw PublicationFailure.login
            }
            if Self.requiresLogin(after: error) {
                signedInEmail = nil; signedInUserID = nil
                throw PublicationFailure.login
            }
            // 暫時連線失敗不等於登出；保留身分讓論壇顯示錯誤與重試入口。
            throw PublicationFailure.connection
        }
        guard generation == selectionGeneration else { throw WorkspaceError.identityMismatch }
        guard storage.failure == nil else { await reportStorageFailure(); throw PublicationFailure.login }
        guard session.user.id == expectedUserID else { throw WorkspaceError.identityMismatch }
        signedInUserID = session.user.id
        signedInEmail = session.user.email
        return (client, session, generation)
    }

    func requirePublicationLogin() { signedInEmail = nil; signedInUserID = nil }

    private func safeMessage(for error: Error, isVerification: Bool) -> String {
        if let authError = error as? AuthError {
            if !isVerification && authError.errorCode == .emailAddressNotAuthorized {
                return "Supabase 尚未設定自訂 SMTP；目前只能寄給 Supabase 專案組織成員的 Email。"
            }
            if authError.errorCode == .overEmailSendRateLimit {
                return "驗證碼寄送次數已達限制，請稍後再試；Supabase 預設寄信服務每小時最多寄送 2 封。"
            }
            if !isVerification && authError.errorCode == .otpDisabled {
                return "Supabase 專案尚未啟用 Email 驗證碼登入。"
            }
            if isVerification && (authError.errorCode == .otpExpired || authError.errorCode == .invalidCredentials) {
                return "驗證碼錯誤或已過期，可重新寄送。"
            }
        }
        return isVerification ? "無法連線，請重試。" : "無法寄送驗證碼，請稍後重試。"
    }
}

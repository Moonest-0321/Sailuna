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

    private let storage = SailuneAuthStorage()
    private var didRestore = false
    private(set) var needsKeychainRetry = false

    private let client: SupabaseClient?
    private var publicationConfiguration: (URL, String)?

    var isConfigured: Bool { client != nil }

    init(bundle: Bundle = .main) {
        let endpoint = bundle.object(forInfoDictionaryKey: "SailuneSupabaseURL") as? String ?? ""
        let publishableKey = bundle.object(forInfoDictionaryKey: "SailuneSupabasePublishableKey") as? String ?? ""
        guard let url = URL(string: endpoint),
              url.scheme == "https",
              url.host != nil,
              !publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            client = nil
            return
        }

        environmentID = url.absoluteString
        publicationConfiguration = (url, publishableKey)
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: publishableKey,
            options: SupabaseClientOptions(
                auth: .init(storage: storage, autoRefreshToken: false)
            )
        )
        storage.setFailureHandler { [weak self] in
            Task { @MainActor [weak self] in await self?.reportStorageFailure() }
        }
    }

    private func reportStorageFailure() async {
        guard storage.failure != nil else { return }
        signedInEmail = nil; signedInUserID = nil
        needsKeychainRetry = true
        errorMessage = "無法存取登入鑰匙圈，已停止背景重試。請按「重試鑰匙圈授權」。"
        await client?.auth.stopAutoRefresh()
    }

    func retryKeychainAccess() async {
        guard !isWorking else { return }
        storage.beginUserRetry()
        defer { storage.endUserRetry() }
        needsKeychainRetry = false
        errorMessage = nil
        didRestore = false
        await restoreSession()
    }

    func restoreSession() async {
        guard let client, !didRestore, !isWorking else { return }
        didRestore = true
        isWorking = true
        defer { isWorking = false }
        do {
            let session = try await client.auth.session
            guard storage.failure == nil else { await reportStorageFailure(); return }
            signedInUserID = session.user.id
            signedInEmail = session.user.email
            await client.auth.startAutoRefresh()
        } catch {
            signedInEmail = nil; signedInUserID = nil
            if storage.failure != nil { await reportStorageFailure() }
            else if let authError = error as? AuthError, authError == .sessionMissing {
                // No saved login is normal on first launch.
            } else { errorMessage = "無法恢復登入，請稍後重試登入。" }
        }
    }

    func sendCode(to email: String) async {
        guard let client else {
            errorMessage = "登入服務尚未設定。"
            return
        }
        guard !isWorking else { return }
        guard storage.failure == nil else { await reportStorageFailure(); return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await client.auth.signInWithOTP(email: email)
            if storage.failure != nil { await reportStorageFailure() }
        } catch {
            if storage.failure != nil { await reportStorageFailure(); return }
            errorMessage = safeMessage(for: error, isVerification: false)
        }
    }

    func verifyCode(_ code: String, for email: String) async -> Bool {
        guard let client else {
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
            signedInUserID = response.user.id
            signedInEmail = response.user.email ?? email
            await client.auth.startAutoRefresh()
            return true
        } catch {
            if storage.failure != nil { await reportStorageFailure(); return false }
            errorMessage = safeMessage(for: error, isVerification: true)
            return false
        }
    }

    func signOut(localOnly: Bool = false) async {
        guard let client else { return }
        guard !isWorking else { return }
        guard storage.failure == nil else { await reportStorageFailure(); return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await client.auth.signOut(scope: localOnly ? .local : .global)
            guard storage.failure == nil else { await reportStorageFailure(); return }
            await client.auth.stopAutoRefresh()
            signedInEmail = nil; signedInUserID = nil
        } catch {
            if storage.failure != nil { await reportStorageFailure(); return }
            errorMessage = "無法退出登入，請稍後再試。"
        }
    }

    func publicationCredentials(for bookID: UUID, expectedUserID: UUID) async throws -> PublicationCredentials {
        guard let client, let (url, key) = publicationConfiguration else { throw PublicationFailure.configuration }
        let session: Session
        do { session = try await client.auth.session }
        catch {
            signedInEmail = nil; signedInUserID = nil
            await reportStorageFailure()
            throw PublicationFailure.login
        }
        guard storage.failure == nil else { await reportStorageFailure(); throw PublicationFailure.login }
        guard session.user.id == expectedUserID else { throw WorkspaceError.identityMismatch }
        signedInUserID = session.user.id
            signedInEmail = session.user.email
        do {
            let _: UUID = try await client.rpc("publication_author_v1", params: ["p_book_id": bookID.uuidString]).execute().value
        } catch let error as PostgrestError {
            if error.message.contains("publication_author_unbound") { throw PublicationFailure.authorUnbound }
            if error.message.contains("publication_not_owner") { throw PublicationFailure.notOwner }
            if error.code == "42501" || error.code == "PGRST301" {
                signedInEmail = nil; signedInUserID = nil; throw PublicationFailure.login
            }
            throw PublicationFailure.connection
        } catch {
            throw PublicationFailure.connection
        }
        return PublicationCredentials(supabaseURL: url, publishableKey: key, token: session.accessToken, userID: session.user.id)
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

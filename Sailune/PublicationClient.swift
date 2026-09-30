import Foundation

nonisolated struct PublicationCredentials: Sendable {
    let supabaseURL: URL
    let publishableKey: String
    let token: String
    let userID: UUID
}
nonisolated struct PublicationResult: Decodable, Sendable {
    let bookId: String
    let createdChapters: Int
    let updatedChapters: Int
    let unchangedChapters: Int
    let hiddenChapters: Int
    let hiddenVolumes: Int
}
nonisolated enum PublicationFailure: LocalizedError {
    case configuration, login, authorUnbound, notOwner, invalidPackage(String), connection, upload, localSave
    var errorDescription: String? {
        switch self {
        case .configuration: "發布服務尚未設定。"
        case .login: "登入已失效，請重新登入後重試。"
        case .authorUnbound: "無法確認此帳號的作者資料，請稍後重試。"
        case .notOwner: "此帳號沒有這本作品的發布權限。"
        case .invalidPackage(let message): message
        case .connection: "無法確認發布結果，請使用相同傳送重試。"
        case .upload: "無法完成上傳，請重試。"
        case .localSave: "拾頁已發布，但本機狀態保存失敗，請重試保存。"
        }
    }
}
/// 一個 attempt 固定同一份 bytes，重試不重新擷取編輯中的書籍。
@MainActor
final class PublicationAttempt {
    let id = UUID()
    let bookID: UUID
    let tags: [String]
    let data: Data
    var userID: UUID?
    var uploadURL: URL?
    var uploadFinished = false
    var hasStartedCommit = false
    init(bookID: UUID, tags: [String], data: Data) { self.bookID = bookID; self.tags = tags; self.data = data }
}

/// Supabase Swift Session 提供憑證；TUS 以 URLSession 傳送，不建立第二個 Auth client。
@MainActor
struct PublicationClient {
    let endpoint: URL
    let session: URLSession
    init(bundle: Bundle = .main, session: URLSession = .shared) throws {
        let setting = bundle.object(forInfoDictionaryKey: "SailunePageletURL") as? String ?? ""
        guard let url = URL(string: setting), url.scheme == "https", url.host != nil else { throw PublicationFailure.configuration }
        endpoint = url.appendingPathComponent("api/publications/v1")
        self.session = session
    }
    init(endpoint: URL, session: URLSession) { self.endpoint = endpoint; self.session = session }

    func publish(_ attempt: PublicationAttempt, credentials: PublicationCredentials,
                 onProgress: @escaping @MainActor @Sendable (Double) -> Void,
                 onCommit: @escaping @MainActor () -> Void) async throws -> PublicationResult {
        if let owner = attempt.userID, owner != credentials.userID { throw PublicationFailure.notOwner }
        attempt.userID = credentials.userID
        if !attempt.uploadFinished {
            try await upload(attempt, credentials: credentials, onProgress: onProgress)
            try Task.checkCancellation()
        }
        attempt.hasStartedCommit = true
        onCommit()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["attemptUUID": attempt.id.uuidString.lowercased()])
        let (bytes, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw PublicationFailure.connection }
        if !(200..<300).contains(response.statusCode) {
            if response.statusCode == 409 { attempt.uploadFinished = false; attempt.uploadURL = nil; attempt.hasStartedCommit = false }
            throw failure(status: response.statusCode, bytes: bytes)
        }
        struct Envelope: Decodable { let result: PublicationResult }
        let result = try JSONDecoder().decode(Envelope.self, from: bytes).result
        guard result.bookId.uppercased() == attempt.bookID.uuidString,
              [result.createdChapters, result.updatedChapters, result.unchangedChapters, result.hiddenChapters, result.hiddenVolumes].allSatisfy({ $0 >= 0 }) else {
            throw PublicationFailure.connection
        }
        return result
    }
    private func storageEndpoint(_ credentials: PublicationCredentials) -> URL {
        var components = URLComponents(url: credentials.supabaseURL, resolvingAgainstBaseURL: false)!
        if let host = components.host, host.hasSuffix(".supabase.co") {
            components.host = String(host.dropLast(".supabase.co".count)) + ".storage.supabase.co"
        }
        return components.url!.appendingPathComponent("storage/v1/upload/resumable")
    }
    private func tusRequest(_ url: URL, method: String, credentials: PublicationCredentials) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 90
        request.setValue("1.0.0", forHTTPHeaderField: "Tus-Resumable")
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.publishableKey, forHTTPHeaderField: "apikey")
        return request
    }
    private func upload(_ attempt: PublicationAttempt, credentials: PublicationCredentials,
                        onProgress: @escaping @MainActor @Sendable (Double) -> Void) async throws {
        try Task.checkCancellation()
        let endpoint = storageEndpoint(credentials)
        if attempt.uploadURL == nil {
            var request = tusRequest(endpoint, method: "POST", credentials: credentials)
            request.setValue(String(attempt.data.count), forHTTPHeaderField: "Upload-Length")
            let values = [("bucketName", "publication-staging"), ("objectName", "\(credentials.userID.uuidString.lowercased())/\(attempt.id.uuidString.lowercased()).shiye"),
                          ("contentType", "application/octet-stream"), ("cacheControl", "3600")]
            request.setValue(values.map { "\($0.0) \(Data($0.1.utf8).base64EncodedString())" }.joined(separator: ","), forHTTPHeaderField: "Upload-Metadata")
            let (bytes, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw PublicationFailure.upload }
            guard response.statusCode == 201, let location = response.value(forHTTPHeaderField: "Location"),
                  let uploadURL = URL(string: location, relativeTo: endpoint)?.absoluteURL,
                  uploadURL.scheme == "https", uploadURL.host == endpoint.host,
                  uploadURL.path.hasPrefix(endpoint.path + "/") else { throw failure(status: response.statusCode, bytes: bytes) }
            attempt.uploadURL = uploadURL
        }
        guard let url = attempt.uploadURL else { throw PublicationFailure.upload }
        // 每次重試以伺服器的 offset 為準；PATCH 回應遺失也不會重複附加 bytes。
        let (bytes, head) = try await session.data(for: tusRequest(url, method: "HEAD", credentials: credentials))
        guard let response = head as? HTTPURLResponse else { throw PublicationFailure.upload }
        if response.statusCode == 404 || response.statusCode == 410 {
            // TUS URL 過期或完成後不可再讀：由發布 API 判斷 object／收據是否已存在。
            attempt.uploadURL = nil; attempt.uploadFinished = true
            return
        }
        guard response.statusCode == 200 || response.statusCode == 204,
              let rawOffset = response.value(forHTTPHeaderField: "Upload-Offset"), let serverOffset = Int(rawOffset),
              serverOffset >= 0, serverOffset <= attempt.data.count else { throw failure(status: response.statusCode, bytes: bytes) }
        var offset = serverOffset
        onProgress(Double(offset) / Double(attempt.data.count))
        while offset < attempt.data.count {
            try Task.checkCancellation()
            let end = min(offset + 6 * 1024 * 1024, attempt.data.count)
            var request = tusRequest(url, method: "PATCH", credentials: credentials)
            request.setValue(String(offset), forHTTPHeaderField: "Upload-Offset")
            request.setValue("application/offset+octet-stream", forHTTPHeaderField: "Content-Type")
            let chunkStart = offset, total = attempt.data.count
            let delegate = PublicationUploadProgress { progress in
                Task { @MainActor in onProgress((Double(chunkStart) + Double(end - chunkStart) * progress) / Double(total)) }
            }
            let (bytes, reply) = try await session.upload(for: request, from: attempt.data.subdata(in: offset..<end), delegate: delegate)
            if let reply = reply as? HTTPURLResponse, [404, 409, 410].contains(reply.statusCode) {
                attempt.uploadURL = nil; attempt.uploadFinished = true
                return
            }
            guard let reply = reply as? HTTPURLResponse, reply.statusCode == 204,
                  reply.value(forHTTPHeaderField: "Upload-Offset") == String(end) else {
                throw failure(status: (reply as? HTTPURLResponse)?.statusCode ?? 0, bytes: bytes)
            }
            offset = end; onProgress(Double(offset) / Double(total))
        }
        attempt.uploadFinished = true
    }
    private func failure(status: Int, bytes: Data) -> PublicationFailure {
        if status == 401 { return .login }
        struct Envelope: Decodable { struct Detail: Decodable { let code: String; let message: String }; let error: Detail }
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: bytes) {
            switch envelope.error.code {
            case "author_unbound": return .authorUnbound
            case "not_owner": return .notOwner
            case "invalid_package": return .invalidPackage(envelope.error.message)
            default: break
            }
        }
        if status == 403 { return .notOwner }
        return .connection
    }
}
nonisolated final class PublicationUploadProgress: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let report: @Sendable (Double) -> Void
    init(report: @escaping @Sendable (Double) -> Void) { self.report = report }
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if totalBytesExpectedToSend > 0 { report(min(1, Double(totalBytesSent) / Double(totalBytesExpectedToSend))) }
    }
}

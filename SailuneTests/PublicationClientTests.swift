import Foundation
import XCTest
@testable import Sailune

nonisolated private final class PublicationProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, headers, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
@MainActor
final class PublicationClientTests: XCTestCase {
    private func makeClient() -> PublicationClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicationProtocol.self]
        return PublicationClient(endpoint: URL(string: "https://pagelet.test/api/publications/v1")!, session: URLSession(configuration: configuration))
    }
    private var credentials: PublicationCredentials {
        PublicationCredentials(supabaseURL: URL(string: "https://project.supabase.co")!, publishableKey: "test-publishable",
            token: "test-author-jwt", userID: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!)
    }
    private func response(for attempt: PublicationAttempt) -> Data {
        Data("{\"result\":{\"bookId\":\"\(attempt.bookID.uuidString)\",\"createdChapters\":1,\"updatedChapters\":0,\"unchangedChapters\":0,\"hiddenChapters\":0,\"hiddenVolumes\":0}}".utf8)
    }
    func testResumeUsesServerOffsetAndDirectStorageThenSmallProtectedAPIRequest() async throws {
        let attempt = PublicationAttempt(bookID: UUID(), tags: [], data: Data([0, 1, 2, 3, 4]))
        let expectedResponse = response(for: attempt)
        let expectedBody = try JSONSerialization.data(withJSONObject: ["attemptUUID": attempt.id.uuidString.lowercased()])
        let uploadURL = "https://project.storage.supabase.co/storage/v1/upload/resumable/opaque"
        var methods: [String] = []
        PublicationProtocol.handler = { request in
            let method = request.httpMethod!; methods.append(method)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-author-jwt")
            if request.url!.host == "pagelet.test" {
                XCTAssertEqual(method, "POST")
                var body = request.httpBody
                if body == nil, let stream = request.httpBodyStream {
                    stream.open(); defer { stream.close() }
                    var bytes: [UInt8] = Array(repeating: 0, count: 1024)
                    let count = stream.read(&bytes, maxLength: bytes.count)
                    if count >= 0 { body = Data(bytes.prefix(count)) }
                }
                let actual = try XCTUnwrap(body)
                XCTAssertLessThan(actual.count, 100)
                XCTAssertEqual(actual, expectedBody)
                return (200, [:], expectedResponse)
            }
            XCTAssertEqual(request.url!.host, "project.storage.supabase.co")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Tus-Resumable"), "1.0.0")
            switch method {
            case "POST": return (201, ["Location": uploadURL], Data())
            case "HEAD": return (200, ["Upload-Offset": "2"], Data())
            case "PATCH":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Upload-Offset"), "2")
                return (204, ["Upload-Offset": "5"], Data())
            default: throw URLError(.badServerResponse)
            }
        }
        defer { PublicationProtocol.handler = nil }
        let result = try await makeClient().publish(attempt, credentials: credentials, onProgress: { _ in }, onCommit: {})
        XCTAssertEqual(result.createdChapters, 1)
        XCTAssertEqual(methods, ["POST", "HEAD", "PATCH", "POST"])
    }
    func testLostCommitResponseRetriesOnlyAPIWithSameAttempt() async throws {
        let attempt = PublicationAttempt(bookID: UUID(), tags: [], data: Data([1]))
        attempt.uploadFinished = true
        let expectedResponse = response(for: attempt)
        var calls = 0
        PublicationProtocol.handler = { request in
            calls += 1
            XCTAssertEqual(request.url!.host, "pagelet.test")
            if calls == 1 { throw URLError(.networkConnectionLost) }
            return (200, [:], expectedResponse)
        }
        defer { PublicationProtocol.handler = nil }
        let client = makeClient()
        do { _ = try await client.publish(attempt, credentials: credentials, onProgress: { _ in }, onCommit: {}); XCTFail("應回報回應遺失") }
        catch { XCTAssertTrue(attempt.hasStartedCommit) }
        let result = try await client.publish(attempt, credentials: credentials, onProgress: { _ in }, onCommit: {})
        XCTAssertEqual(result.bookId, attempt.bookID.uuidString)
        XCTAssertEqual(calls, 2)
    }
    func testUntrustedTusLocationAndDifferentRetryAccountAreRejected() async throws {
        let attempt = PublicationAttempt(bookID: UUID(), tags: [], data: Data([1]))
        PublicationProtocol.handler = { _ in (201, ["Location": "https://untrusted.test/upload"], Data()) }
        defer { PublicationProtocol.handler = nil }
        do { _ = try await makeClient().publish(attempt, credentials: credentials, onProgress: { _ in }, onCommit: {}); XCTFail("不應接受其他主機") }
        catch { XCTAssertNil(attempt.uploadURL) }
        attempt.userID = UUID()
        do { _ = try await makeClient().publish(attempt, credentials: credentials, onProgress: { _ in }, onCommit: {}); XCTFail("不應用其他帳號重試") }
        catch PublicationFailure.notOwner {} catch { XCTFail("錯誤類型不符") }
    }

    func testPublishedNameConflictIsNotReportedAsNetworkRetry() async throws {
        let attempt = PublicationAttempt(bookID: UUID(), tags: [], data: Data([1]))
        attempt.uploadFinished = true
        PublicationProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/publications/v1")
            return (409, [:], Data(#"{"error":{"code":"identity_locked","message":"fixed","retryable":false}}"#.utf8))
        }
        defer { PublicationProtocol.handler = nil }
        do {
            _ = try await makeClient().publish(attempt, credentials: credentials,
                onProgress: { _ in }, onCommit: {})
            XCTFail("已固定書名與筆名應被拒絕")
        } catch PublicationFailure.identityLocked {
            XCTAssertFalse(attempt.uploadFinished)
            XCTAssertFalse(attempt.hasStartedCommit)
        } catch { XCTFail("錯誤類型不符：\(error)") }
    }
}

import Foundation
import XCTest
@testable import Sailune

@MainActor
final class SailuneAITests: XCTestCase {
    func testConversationsPersistPerBookAndDeletionSurvivesReload() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SailuneAIConversations-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SailuneAIConversationStore(directory: root)
        let bookID = UUID()
        let otherBookID = UUID()
        let client = SailuneAIClient(appleOnDevice: ())
        let model = SailuneAIChatViewModel(client: client, bookID: bookID, store: store)
        let firstID = model.selectedConversationID
        let attachment = SailuneAISectionAttachment(id: UUID(), title: "第一節", content: "測試快照")
        XCTAssertTrue(model.send(prompt: "第一個問題", attachment: attachment))
        model.cancel()
        model.newConversation()
        let secondID = model.selectedConversationID
        XCTAssertNotEqual(firstID, secondID)
        XCTAssertTrue(model.messages.isEmpty)
        XCTAssertTrue(model.send(prompt: "第二個問題"))
        model.cancel()
        model.selectConversation(firstID)
        XCTAssertEqual(model.messages.first?.text, "第一個問題")
        XCTAssertEqual(model.messages.first?.attachment?.content, "測試快照")

        let reloaded = SailuneAIChatViewModel(client: client, bookID: bookID, store: store)
        XCTAssertEqual(reloaded.selectedConversationID, firstID)
        XCTAssertEqual(reloaded.conversations.count, 2)
        XCTAssertEqual(reloaded.messages.first?.text, "第一個問題")
        XCTAssertEqual(SailuneAIChatViewModel(client: client, bookID: otherBookID, store: store).conversations.count, 1)

        reloaded.deleteConversation(firstID)
        XCTAssertEqual(reloaded.selectedConversationID, secondID)
        XCTAssertEqual(reloaded.messages.first?.text, "第二個問題")
        reloaded.deleteConversation(secondID)
        XCTAssertEqual(reloaded.conversations.count, 1)
        XCTAssertTrue(reloaded.messages.isEmpty)
        let afterDeletion = SailuneAIChatViewModel(client: client, bookID: bookID, store: store)
        XCTAssertEqual(afterDeletion.conversations.count, 1)
        XCTAssertTrue(afterDeletion.messages.isEmpty)
        try store.removeBook(bookID: bookID)
        XCTAssertNil(try store.load(bookID: bookID))
    }

    func testConversationStoreReportsCorruptDataWithoutOverwritingIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SailuneAIInvalid-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let bookID = UUID()
        let file = root.appendingPathComponent("\(bookID.uuidString).json")
        let invalid = Data("invalid".utf8)
        try invalid.write(to: file)
        let model = SailuneAIChatViewModel(
            client: SailuneAIClient(appleOnDevice: ()),
            bookID: bookID,
            store: SailuneAIConversationStore(directory: root)
        )
        XCTAssertTrue(model.errorMessage?.contains("無法讀取") == true)
        XCTAssertFalse(model.send(prompt: "不應覆蓋"))
        XCTAssertEqual(try Data(contentsOf: file), invalid)
    }

    func testSwitchingConversationCancelsPendingReply() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PendingAIURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let model = SailuneAIChatViewModel(
            client: SailuneAIClient(baseURL: URL(string: "http://127.0.0.1:8787")!, session: session)
        )
        let firstID = model.selectedConversationID
        XCTAssertTrue(model.send(prompt: "第一段", sectionContent: "測試正文"))
        XCTAssertTrue(model.isLoading)
        model.newConversation()
        XCTAssertFalse(model.isLoading)
        XCTAssertTrue(model.messages.isEmpty)
        model.selectConversation(firstID)
        XCTAssertEqual(model.messages.map(\.text), ["第一段"])
        XCTAssertFalse(model.isLoading)
    }

    func testRequestContainsOnlyCurrentSectionContentAndConversation() throws {
        let request = SailuneAIChatRequest(
            sectionContent: "這是目前節次的內文。",
            messages: [.init(role: .user, text: "人物動機清楚嗎？")]
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["sectionContent", "messages"])
        XCTAssertEqual(object["sectionContent"] as? String, "這是目前節次的內文。")
        let messages = try XCTUnwrap(object["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(Set(messages[0].keys), ["role", "text"])
        XCTAssertEqual(messages[0]["text"] as? String, "人物動機清楚嗎？")
    }

    func testEvidenceRequiresExactNonemptyQuoteFromSection() {
        let evidence = SailuneAIResponseValidation.evidence(
            from: ["她握緊鑰匙", "她握著鑰匙", "  "],
            in: "她握緊鑰匙，沒有回頭。"
        )
        XCTAssertEqual(evidence.map(\.isVerified), [true, false, false])
    }

    func testAppleChatUsesOnlyConversationAndNeedsNoSection() throws {
        let client = SailuneAIClient(appleOnDevice: ())
        XCTAssertFalse(client.usesSectionContext)
        let request = SailuneAIChatRequest(
            sectionContent: "不應提供給 Apple 模型的正文",
            messages: [.init(role: .user, text: "你好")]
        )
        XCTAssertEqual(SailuneAIClient.localPrompt(for: request), "使用者：你好")

        let chatOnly = SailuneAIChatRequest(
            sectionContent: nil,
            messages: [.init(role: .user, text: "你好")]
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(chatOnly)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["messages"])
    }

    func testSelectedSectionAppearsOnlyWhenExplicitlyAttached() throws {
        let attachment = SailuneAISectionAttachment(
            id: UUID(), title: "第一卷／相遇", content: "她握緊鑰匙。"
        )
        let request = SailuneAIChatRequest(
            sectionContent: nil,
            messages: [
                .init(role: .user, text: "你好"),
                .init(role: .assistant, text: "你好！"),
                .init(role: .user, text: "她手裡拿著什麼？", attachment: attachment)
            ]
        )
        let prompt = SailuneAIClient.localPrompt(for: request)
        XCTAssertTrue(prompt.contains("第一卷／相遇"))
        XCTAssertTrue(prompt.contains("她握緊鑰匙。"))
        XCTAssertTrue(prompt.contains("她手裡拿著什麼？"))
        XCTAssertEqual(prompt.components(separatedBy: "她握緊鑰匙。").count - 1, 1)
        XCTAssertFalse(prompt.contains("sectionContent"))
    }

    func testEmptySelectedSectionIsRejectedBeforeModelCall() {
        let model = SailuneAIChatViewModel(client: SailuneAIClient(appleOnDevice: ()))
        let attachment = SailuneAISectionAttachment(id: UUID(), title: "空白節次", content: "  ")
        XCTAssertFalse(model.send(prompt: "分析這一節", attachment: attachment))
        XCTAssertEqual(model.errorMessage, "所選節次沒有內文可供加入。")
        XCTAssertTrue(model.messages.isEmpty)
    }

    func testClientPostsRequestAndDecodesResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockAIURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = SailuneAIClient(baseURL: URL(string: "http://127.0.0.1:8787")!, session: session)
        let request = SailuneAIChatRequest(
            sectionContent: "她握緊鑰匙。",
            messages: [.init(role: .user, text: "這一段如何？")]
        )
        let reply = try await client.chat(request)
        XCTAssertEqual(reply.answer, "可以補強人物的猶豫。")
        XCTAssertEqual(reply.evidenceQuotes, ["她握緊鑰匙"])
    }

    func testResponseRequiresEvidenceArray() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                SailuneAIChatResponse.self,
                from: Data(#"{"answer":"缺少引文"}"#.utf8)
            )
        )
    }

    func testEmptySectionDoesNotSendAndCancellationClearsLoadingState() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PendingAIURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let model = SailuneAIChatViewModel(
            client: SailuneAIClient(baseURL: URL(string: "http://127.0.0.1:8787")!, session: session)
        )
        XCTAssertFalse(model.send(prompt: "分析", sectionContent: "  "))
        XCTAssertEqual(model.errorMessage, "目前節次沒有內文可供分析。")
        XCTAssertTrue(model.messages.isEmpty)

        XCTAssertTrue(model.send(prompt: "分析", sectionContent: "測試正文"))
        XCTAssertTrue(model.isLoading)
        model.cancel()
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.errorMessage, "已取消這次請求。")
    }

    func testClientReportsHTTPFailure() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UnavailableAIURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = SailuneAIClient(baseURL: URL(string: "http://127.0.0.1:8787")!, session: session)
        let request = SailuneAIChatRequest(
            sectionContent: "測試正文",
            messages: [.init(role: .user, text: "分析")]
        )
        do {
            _ = try await client.chat(request)
            XCTFail("HTTP 503 應被視為失敗")
        } catch SailuneAIClientError.serverError(let status) {
            XCTAssertEqual(status, 503)
        }
    }

    func testGeminiSettingsRejectNonGoogleEndpoint() throws {
        XCTAssertThrowsError(try SailuneAISettings(endpoint: "https://example.com/v1beta/interactions", model: "gemini-3.8-flash"))
        XCTAssertThrowsError(try SailuneAISettings(endpoint: "http://generativelanguage.googleapis.com/v1beta/interactions", model: "gemini-3.8-flash"))
        XCTAssertThrowsError(try SailuneAISettings(endpoint: SailuneAISettings.defaultEndpoint, model: "bad/model"))
    }

    func testGeminiClientUsesSavedRequestShapeAndDecodesReply() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockGeminiURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let settings = try SailuneAISettings(endpoint: SailuneAISettings.defaultEndpoint, model: "gemini-3.8-flash")
        let client = SailuneAIClient(gemini: settings, apiKey: "test-key", session: session)
        let reply = try await client.chat(.init(
            sectionContent: "她握緊鑰匙。",
            messages: [.init(role: .user, text: "分析")]
        ))
        XCTAssertEqual(reply.answer, "她顯得緊張。")
        XCTAssertEqual(reply.evidenceQuotes, ["她握緊鑰匙"])
    }
}

private final class MockGeminiURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        XCTAssertEqual(request.url?.absoluteString, SailuneAISettings.defaultEndpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-goog-api-key"), "test-key")
        XCTAssertEqual(request.httpMethod, "POST")
        if let body = requestBody(),
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(object["model"] as? String, "gemini-3.8-flash")
            XCTAssertEqual(object["store"] as? Bool, false)
            XCTAssertNil(object["apiKey"])
            XCTAssertTrue((object["input"] as? String)?.contains("她握緊鑰匙。") == true)
        } else {
            XCTFail("Gemini 請求缺少 JSON body")
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"steps":[{"type":"model_output","content":[{"type":"text","text":"{\"answer\":\"她顯得緊張。\",\"evidenceQuotes\":[\"她握緊鑰匙\"]}"}]}]}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    private func requestBody() -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var bytes = [UInt8](repeating: 0, count: 4096)
        var body = Data()
        while stream.hasBytesAvailable {
            let count = stream.read(&bytes, maxLength: bytes.count)
            if count <= 0 { break }
            body.append(contentsOf: bytes.prefix(count))
        }
        return body
    }
}

private final class MockAIURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/ai/chat")
        if let body = requestBody(),
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(Set(object.keys), ["sectionContent", "messages"])
            XCTAssertEqual(object["sectionContent"] as? String, "她握緊鑰匙。")
        } else {
            XCTFail("AI 請求缺少可解碼的 JSON body")
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"answer":"可以補強人物的猶豫。","evidenceQuotes":["她握緊鑰匙"]}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func requestBody() -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var bytes = [UInt8](repeating: 0, count: 4096)
        var body = Data()
        while stream.hasBytesAvailable {
            let count = stream.read(&bytes, maxLength: bytes.count)
            if count <= 0 { break }
            body.append(contentsOf: bytes.prefix(count))
        }
        return body
    }
}

private final class PendingAIURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {}
    override func stopLoading() {}
}

private final class UnavailableAIURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"error":"AI_UNAVAILABLE"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

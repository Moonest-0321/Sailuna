import Foundation
import Observation

@MainActor @Observable
final class SailuneAIChatViewModel {
    private let injectedClient: SailuneAIClient?
    private let bookID: UUID?
    private let store: SailuneAIConversationStore?
    private(set) var conversations: [SailuneAIConversation]
    private(set) var selectedConversationID: UUID
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var requestTask: Task<Void, Never>?
    private var preparationID: UUID?
    private var canSave = true

    var messages: [SailuneAIMessage] {
        conversations.first(where: { $0.id == selectedConversationID })?.messages ?? []
    }

    init(client: SailuneAIClient? = nil, bookID: UUID? = nil, store: SailuneAIConversationStore? = nil) {
        injectedClient = client
        self.bookID = bookID
        self.store = store
        let initial = SailuneAIConversation()
        conversations = [initial]
        selectedConversationID = initial.id
        if let bookID, let store {
            do {
                if let archive = try store.load(bookID: bookID), !archive.conversations.isEmpty {
                    conversations = archive.conversations
                    selectedConversationID = archive.conversations.contains(where: { $0.id == archive.selectedConversationID })
                        ? archive.selectedConversationID : archive.conversations[0].id
                }
            } catch {
                canSave = false
                errorMessage = "無法讀取 AI 對話：\(error.localizedDescription)"
            }
        }
    }

    func newConversation() {
        guard canSave else { return }
        if messages.isEmpty { return }
        stopRequest()
        let conversation = SailuneAIConversation()
        _ = commit([conversation] + conversations, selectedID: conversation.id)
    }

    func selectConversation(_ conversationID: UUID) {
        guard canSave, conversations.contains(where: { $0.id == conversationID }),
              conversationID != selectedConversationID else { return }
        stopRequest()
        _ = commit(conversations, selectedID: conversationID)
    }

    func deleteConversation(_ conversationID: UUID) {
        guard canSave, conversations.contains(where: { $0.id == conversationID }) else { return }
        if conversationID == selectedConversationID { stopRequest() }
        var remaining = conversations.filter { $0.id != conversationID }
        if remaining.isEmpty { remaining = [SailuneAIConversation()] }
        let nextID = conversationID == selectedConversationID ? remaining[0].id : selectedConversationID
        _ = commit(remaining, selectedID: nextID)
    }

    func send(prompt: String, attachment: SailuneAISectionAttachment? = nil) -> Bool {
        send(prompt: prompt, sectionContent: nil, attachment: attachment)
    }

    func send(prompt: String, sectionContent: String) -> Bool {
        send(prompt: prompt, sectionContent: sectionContent, attachment: nil)
    }

    func sendValidated(prompt: String, attachment: SailuneAISectionAttachment? = nil) async -> Bool {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !isLoading, canSave,
              let index = conversations.firstIndex(where: { $0.id == selectedConversationID }) else { return false }
        if let attachment,
           attachment.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "所選範圍沒有可閱讀的內容。"
            return false
        }

        let client: SailuneAIClient
        do {
            client = try injectedClient ?? SailuneAIClient.configured()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        let conversationID = selectedConversationID
        let preparationID = UUID()
        self.preparationID = preparationID
        isLoading = true
        errorMessage = nil

        var updated = conversations
        updated[index].messages.append(SailuneAIMessage(role: .user, text: trimmedPrompt, attachment: attachment))
        if updated[index].messages.count == 1 {
            let firstLine = trimmedPrompt.components(separatedBy: .newlines).first ?? trimmedPrompt
            updated[index].title = String(firstLine.prefix(32))
        }
        updated[index].updatedAt = .now
        updated.sort { $0.updatedAt > $1.updatedAt }
        guard let candidate = updated.first(where: { $0.id == conversationID }) else { return false }
        let request = SailuneAIChatRequest(
            sectionContent: nil,
            messages: candidate.messages.map {
                SailuneAIChatRequest.Turn(role: $0.role, text: $0.text, attachment: $0.attachment)
            }
        )

        do {
            try await client.validateContext(request)
        } catch {
            guard self.preparationID == preparationID else { return false }
            self.preparationID = nil
            isLoading = false
            errorMessage = error.localizedDescription
            return false
        }

        guard self.preparationID == preparationID,
              selectedConversationID == conversationID,
              updated.contains(where: { $0.id == conversationID }) else { return false }
        self.preparationID = nil
        guard commit(updated, selectedID: conversationID) else {
            isLoading = false
            return false
        }
        requestTask = Task { [weak self] in
            do {
                let reply = try await client.chat(request)
                guard let self, !Task.isCancelled, self.selectedConversationID == conversationID else { return }
                self.appendReply(SailuneAIMessage(role: .assistant, text: reply.answer), to: conversationID)
                self.isLoading = false
                self.requestTask = nil
            } catch {
                guard let self, !Task.isCancelled, self.selectedConversationID == conversationID else { return }
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.requestTask = nil
            }
        }
        return true
    }

    private func send(prompt: String, sectionContent: String?, attachment: SailuneAISectionAttachment?) -> Bool {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !isLoading, canSave,
              let index = conversations.firstIndex(where: { $0.id == selectedConversationID }) else { return false }

        if let attachment, attachment.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "所選節次沒有內文可供加入。"
            return false
        }

        let client: SailuneAIClient
        do {
            client = try injectedClient ?? SailuneAIClient.configured()
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        if client.usesSectionContext,
           sectionContent?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            errorMessage = "目前節次沒有內文可供分析。"
            return false
        }

        let conversationID = selectedConversationID
        var updated = conversations
        let userMessage = SailuneAIMessage(role: .user, text: trimmedPrompt, attachment: attachment)
        updated[index].messages.append(userMessage)
        if updated[index].messages.count == 1 {
            let firstLine = trimmedPrompt.components(separatedBy: .newlines).first ?? trimmedPrompt
            updated[index].title = String(firstLine.prefix(32))
        }
        updated[index].updatedAt = .now
        updated.sort { $0.updatedAt > $1.updatedAt }
        guard commit(updated, selectedID: conversationID) else { return false }
        let request = SailuneAIChatRequest(
            sectionContent: client.usesSectionContext ? sectionContent : nil,
            messages: messages.map { SailuneAIChatRequest.Turn(role: $0.role, text: $0.text, attachment: $0.attachment) }
        )
        isLoading = true
        requestTask = Task { [weak self] in
            do {
                let reply = try await client.chat(request)
                guard let self, !Task.isCancelled, self.selectedConversationID == conversationID else { return }
                let evidence = request.sectionContent.map {
                    SailuneAIResponseValidation.evidence(from: reply.evidenceQuotes, in: $0)
                } ?? []
                self.appendReply(SailuneAIMessage(role: .assistant, text: reply.answer, evidence: evidence), to: conversationID)
                self.isLoading = false
                self.requestTask = nil
            } catch {
                guard let self, !Task.isCancelled, self.selectedConversationID == conversationID else { return }
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.requestTask = nil
            }
        }
        return true
    }

    private func appendReply(_ message: SailuneAIMessage, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        var updated = conversations
        updated[index].messages.append(message)
        updated[index].updatedAt = .now
        updated.sort { $0.updatedAt > $1.updatedAt }
        _ = commit(updated, selectedID: selectedConversationID)
    }

    @discardableResult
    private func commit(_ updated: [SailuneAIConversation], selectedID: UUID) -> Bool {
        if let bookID, let store {
            do {
                try store.save(.init(selectedConversationID: selectedID, conversations: updated), bookID: bookID)
            } catch {
                errorMessage = "無法儲存 AI 對話：\(error.localizedDescription)"
                return false
            }
        }
        conversations = updated
        selectedConversationID = selectedID
        errorMessage = nil
        return true
    }

    func cancel() {
        stopRequest()
        errorMessage = "已取消這次請求。"
    }

    private func stopRequest() {
        requestTask?.cancel()
        requestTask = nil
        preparationID = nil
        isLoading = false
        errorMessage = nil
    }

    func rejectUnavailableSection() -> Bool {
        errorMessage = "所選節次已不存在，請重新選擇。"
        return false
    }

    func reject(_ message: String) -> Bool {
        errorMessage = message
        return false
    }

    func reset() {
        stopRequest()
    }
}

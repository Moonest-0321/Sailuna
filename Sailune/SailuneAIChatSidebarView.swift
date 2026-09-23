import SwiftUI

struct SailuneAIChatSidebarView: View {
    let book: Book
    let model: SailuneAIChatViewModel
    let onSend: (String, UUID?) -> Bool
    let onClose: () -> Void

    @State private var draft = ""
    @State private var selectedSectionID: UUID?
    @State private var showingSectionPicker = false
    @State private var showingConversations = false
    @State private var conversationToDeleteID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI 助手")
                    .font(.headline)
                Spacer()
                Button {
                    showingConversations = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.plain)
                .help("切換對話")
                .accessibilityLabel("切換對話")
                .popover(isPresented: $showingConversations) {
                    conversationPicker
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("關閉 AI 助手")
                .accessibilityLabel("關閉 AI 助手")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(model.messages) { message in
                            messageView(message)
                        }
                        if model.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在回覆…")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Color.clear.frame(height: 1).id("chat-bottom")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .onChange(of: model.messages.count) { _, _ in
                    proxy.scrollTo("chat-bottom", anchor: .bottom)
                }
            }

            Divider()

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }

            if let selectedSectionID {
                HStack(spacing: 6) {
                    Label(selectedSectionTitle(for: selectedSectionID), systemImage: "doc.text")
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button {
                        self.selectedSectionID = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .help("移除節次")
                    .accessibilityLabel("移除已選節次")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button {
                    showingSectionPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .frame(minWidth: 24, minHeight: 24)
                .help("加入節次")
                .accessibilityLabel("加入節次")
                .popover(isPresented: $showingSectionPicker) {
                    sectionPicker
                }

                TextField("輸入訊息…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                    .accessibilityLabel("輸入給 AI 助手的訊息")

                if model.isLoading {
                    Button { model.cancel() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .help("取消請求")
                    .accessibilityLabel("取消 AI 請求")
                } else {
                    Button(action: send) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("送出訊息")
                    .accessibilityLabel("送出訊息")
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: model.selectedConversationID) { _, _ in
            draft = ""
            selectedSectionID = nil
        }
        .alert("刪除對話？", isPresented: Binding(
            get: { conversationToDeleteID != nil },
            set: { if !$0 { conversationToDeleteID = nil } }
        )) {
            Button("刪除對話", role: .destructive) {
                if let conversationToDeleteID {
                    model.deleteConversation(conversationToDeleteID)
                }
                conversationToDeleteID = nil
            }
            Button("取消", role: .cancel) {
                conversationToDeleteID = nil
            }
        } message: {
            Text("這段對話及其中已加入的節次快照會永久刪除。")
        }
    }

    private var conversationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("對話")
                    .font(.headline)
                Spacer()
                Button {
                    model.newConversation()
                    showingConversations = false
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("新增對話")
                .accessibilityLabel("新增對話")
            }
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.conversations) { conversation in
                        HStack(spacing: 8) {
                            Button {
                                model.selectConversation(conversation.id)
                                showingConversations = false
                            } label: {
                                HStack(spacing: 6) {
                                    if conversation.id == model.selectedConversationID {
                                        Image(systemName: "checkmark")
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(conversation.title)
                                            .lineLimit(1)
                                        Text(conversation.updatedAt, format: .dateTime.month().day().hour().minute())
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Button {
                                showingConversations = false
                                conversationToDeleteID = conversation.id
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .help("刪除對話")
                            .accessibilityLabel("刪除對話：\(conversation.title)")
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(14)
        .frame(width: 290)
    }

    private func messageView(_ message: SailuneAIMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user ? "你" : "AI 助手")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let attachment = message.attachment {
                DisclosureGroup("已加入：\(attachment.title)") {
                    Text(attachment.content)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .font(.caption)
            }
            Text(message.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(message.evidence) { evidence in
                VStack(alignment: .leading, spacing: 3) {
                    Text(evidence.isVerified ? "本節原文" : "來源未驗證")
                        .font(.caption2)
                        .foregroundStyle(evidence.isVerified ? Color.secondary : Color.orange)
                    Text(evidence.quote)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            message.role == .user ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private func send() {
        if onSend(draft, selectedSectionID) {
            draft = ""
            selectedSectionID = nil
        }
    }

    private var sectionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("選擇節次")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(BookStructure.orderedVolumes(in: book), id: \.id) { volume in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(volume.title.isEmpty ? "未命名卷" : volume.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(BookStructure.orderedSections(in: volume), id: \.id) { section in
                                Button {
                                    selectedSectionID = section.id
                                    showingSectionPicker = false
                                } label: {
                                    Text(section.title.isEmpty ? "未命名節" : section.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if BookStructure.orderedSections(in: book).isEmpty {
                        Text("尚無節次")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(width: 280, height: 320)
    }

    private func selectedSectionTitle(for sectionID: UUID) -> String {
        guard let section = BookStructure.orderedSections(in: book).first(where: { $0.id == sectionID }) else {
            return "節次已不存在"
        }
        let volumeTitle = section.volume.map { $0.title.isEmpty ? "未命名卷" : $0.title } ?? "未命名卷"
        return "\(volumeTitle)／\(section.title.isEmpty ? "未命名節" : section.title)"
    }
}

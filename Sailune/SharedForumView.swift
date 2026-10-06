import SwiftUI
import SwiftData

struct SharedForumView: View {
    @Environment(WorkspaceCoordinator.self) private var workspace
    @Environment(SailuneAccountAuthService.self) private var auth
    @Query private var profiles: [AuthorProfile]
    @State private var board: ForumBoard = .announcements
    @State private var posts: [SharedForumPost] = []
    @State private var isAdmin = false
    @State private var isLoading = false
    @State private var loadID = UUID()
    @State private var errorMessage: String?
    @State private var selectedPost: SharedForumPost?
    @State private var editingPost: SharedForumPost?
    @State private var showingEditor = false
    @State private var pendingDelete: SharedForumPost?

    private var service: SailuneCommunityService { .init(workspace: workspace, auth: auth) }
    private var displayName: String {
        let name = profiles.first?.penName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "帆夢使用者" : name
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("論壇").font(.title2.weight(.semibold))
                Spacer(minLength: 12)
                ForEach(ForumBoard.allCases) { candidate in
                    Button(candidate.title) { board = candidate }
                        .buttonStyle(.bordered)
                        .tint(board == candidate ? .accentColor : .secondary)
                        .accessibilityValue(board == candidate ? "目前分類" : "")
                }
            }
            .padding(16)
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(board.title).font(.title2.weight(.semibold))
                    Text(board.summary).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if board != .announcements || isAdmin {
                    Button("新增文章", systemImage: SailuneSymbol.add.systemName) {
                        editingPost = nil
                        showingEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            if let errorMessage {
                HStack {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("重試") { Task { await reload() } }
                }
                .padding(.horizontal, 24)
            }
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if posts.isEmpty {
                ContentUnavailableView("尚無內容", systemImage: SailuneSymbol.forum.systemName,
                                       description: Text("目前沒有文章。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(posts) { post in
                            Button { selectedPost = post } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(post.title).font(.headline)
                                    Text("\(post.displayName)・\(post.createdAt.prefix(10))")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(post.body).lineLimit(2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .task(id: board) { await reload() }
        .sheet(item: $selectedPost, onDismiss: {
            // 關閉文章詳情後才呈現編輯器，避免同一層級的兩個 sheet 互相遮擋。
            if editingPost != nil { showingEditor = true }
        }) { post in
            VStack(alignment: .leading, spacing: 16) {
                Text(post.title).font(.title2.weight(.semibold))
                Text("\(post.board.title)・\(post.displayName)・\(post.createdAt.prefix(10))")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                ScrollView { Text(post.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack {
                    if canEdit(post) {
                        Button("編輯", systemImage: SailuneSymbol.edit.systemName) {
                            editingPost = post
                            selectedPost = nil
                        }
                    }
                    if canEdit(post) || isAdmin {
                        Button("刪除", systemImage: SailuneSymbol.delete.systemName, role: .destructive) {
                            pendingDelete = post
                        }
                    }
                    Spacer()
                    Button("關閉") { selectedPost = nil }
                }
            }
            .padding(24)
            .frame(minWidth: 620, minHeight: 430)
        }
        .sheet(isPresented: $showingEditor) {
            SharedForumEditor(board: board, post: editingPost, onSave: { id, title, body in
                if editingPost != nil {
                    try await service.updatePost(id: id, title: title, body: body)
                } else {
                    try await service.createPost(id: id, board: board, title: title, body: body, displayName: displayName)
                }
                await reload()
            })
        }
        .onChange(of: showingEditor) { _, isPresented in
            if !isPresented { editingPost = nil }
        }
        .confirmationDialog("要刪除此文章嗎？", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("刪除文章", role: .destructive) {
                guard let post = pendingDelete else { return }
                Task {
                    do {
                        try await service.hidePost(id: post.id)
                        selectedPost = nil
                        pendingDelete = nil
                        await reload()
                    } catch { errorMessage = CommunityFailure.message(for: error) }
                }
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        }
    }

    private func canEdit(_ post: SharedForumPost) -> Bool {
        if post.board == .announcements { return isAdmin }
        return post.authorId == workspace.currentAccount?.userID
    }

    private func reload() async {
        let requestedBoard = board
        let requestID = UUID()
        loadID = requestID
        isLoading = true
        do {
            async let loadedPosts = service.listPosts(board: requestedBoard)
            async let loadedAdmin = service.isAdmin()
            let results = try await loadedPosts
            let admin = try await loadedAdmin
            guard requestedBoard == board, loadID == requestID, !Task.isCancelled else { return }
            posts = results
            isAdmin = admin
            errorMessage = nil
        } catch {
            guard loadID == requestID else { return }
            posts = []
            errorMessage = "無法載入論壇：\(CommunityFailure.message(for: error))"
        }
        if loadID == requestID { isLoading = false }
    }
}

private struct SharedForumEditor: View {
    @Environment(\.dismiss) private var dismiss
    let board: ForumBoard
    let post: SharedForumPost?
    let onSave: (UUID, String, String) async throws -> Void
    @State private var operationID: UUID
    @State private var title: String
    @State private var bodyText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(board: ForumBoard, post: SharedForumPost?, onSave: @escaping (UUID, String, String) async throws -> Void) {
        self.board = board
        self.post = post
        self.onSave = onSave
        _operationID = State(initialValue: post?.id ?? UUID())
        _title = State(initialValue: post?.title ?? "")
        _bodyText = State(initialValue: post?.body ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(post == nil ? "新增文章" : "修改文章").font(.title2.weight(.semibold))
            LabeledContent("分類", value: board.title)
            SailuneFormTextField(title: "標題", text: $title)
            SailuneBorderedTextEditor(text: $bodyText, minHeight: 260)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button(SailuneActionCopy.cancel) { dismiss() }.disabled(isSaving)
                Button(post == nil ? "發表文章" : "儲存文章") {
                    Task {
                        isSaving = true
                        defer { isSaving = false }
                        do {
                            try await onSave(operationID, title.trimmingCharacters(in: .whitespacesAndNewlines),
                                             bodyText.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        } catch { errorMessage = CommunityFailure.message(for: error) }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 480)
    }
}

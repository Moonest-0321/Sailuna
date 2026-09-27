import SwiftUI

struct ForumView: View {
    @Environment(LocalForumPostsStore.self) private var postsStore
    @State private var selectedBoard: ForumBoard = .announcements
    @State private var presentedSheet: PresentedSheet?

    private enum PresentedSheet: Identifiable {
        case compose(ForumBoard)
        case detail(ForumPost)

        var id: String {
            switch self {
            case .compose(let board): "compose-\(board.rawValue)"
            case .detail(let post): "detail-\(post.id.uuidString)"
            }
        }
    }

    private var visiblePosts: [ForumPost] {
        postsStore.posts(in: selectedBoard)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("論壇")
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 12)
                ForEach(ForumBoard.allCases) { board in
                    boardButton(board)
                }
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedBoard.title)
                            .font(.title2.weight(.semibold))
                        Text(selectedBoard.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Button("新增文章", systemImage: SailuneSymbol.add.systemName) {
                        presentedSheet = .compose(selectedBoard)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(postsStore.isUnavailable)
                }
                .padding(.bottom, 16)

                Divider()

                if postsStore.isUnavailable {
                    ContentUnavailableView(
                        "論壇資料無法使用",
                        systemImage: "exclamationmark.triangle",
                        description: Text(postsStore.unavailableReason ?? "請先還原有效備份，再重新開啟論壇。")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if visiblePosts.isEmpty {
                    ContentUnavailableView {
                        Label("尚無內容", systemImage: SailuneSymbol.forum.systemName)
                    } description: {
                        Text("目前沒有文章。")
                    } actions: {
                        Button("新增文章", systemImage: SailuneSymbol.add.systemName) {
                            presentedSheet = .compose(selectedBoard)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(visiblePosts) { post in
                                Button {
                                    presentedSheet = .detail(post)
                                } label: {
                                    postRow(post)
                                }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .compose(let board):
                ForumPostEditorSheet(board: board, store: postsStore)
            case .detail(let post):
                ForumPostDetailSheet(post: post, store: postsStore)
            }
        }
    }

    private func boardButton(_ board: ForumBoard) -> some View {
        Button {
            selectedBoard = board
        } label: {
            Text(board.title)
                .fontWeight(selectedBoard == board ? .semibold : .regular)
        }
        .buttonStyle(.bordered)
        .tint(selectedBoard == board ? .accentColor : .secondary)
        .accessibilityValue(selectedBoard == board ? "目前分類" : "")
    }

    private func postRow(_ post: ForumPost) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(post.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(post.body)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
    }
}

private struct ForumPostDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: LocalForumPostsStore
    @State private var post: ForumPost
    @State private var showingEditor = false
    @State private var confirmingDelete = false
    @State private var errorMessage: String?

    init(post: ForumPost, store: LocalForumPostsStore) {
        self.store = store
        _post = State(initialValue: post)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.title)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)
                    Text("\(post.board.title)・\(post.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("編輯", systemImage: SailuneSymbol.edit.systemName) {
                    showingEditor = true
                }
                .disabled(store.isUnavailable)
                Button("刪除", systemImage: SailuneSymbol.delete.systemName, role: .destructive) {
                    confirmingDelete = true
                }
                .disabled(store.isUnavailable)
            }

            Divider()

            ScrollView {
                Text(post.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.bottom, 12)
            }

            HStack {
                Spacer()
                Button("關閉") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 430)
        .sheet(isPresented: $showingEditor) {
            ForumPostEditorSheet(board: post.board, store: store, post: post) { updated in
                post = updated
            }
        }
        .confirmationDialog("要刪除此文章嗎？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("刪除文章", role: .destructive) {
                do {
                    try store.delete(id: post.id)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("刪除後無法復原。")
        }
        .alert("無法刪除文章", isPresented: errorBinding) {
            Button(SailuneActionCopy.acknowledge) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

private struct ForumPostEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let board: ForumBoard
    let store: LocalForumPostsStore
    let existingPost: ForumPost?
    let onSave: ((ForumPost) -> Void)?

    @State private var title: String
    @State private var content: String
    @State private var errorMessage: String?

    init(board: ForumBoard, store: LocalForumPostsStore, post: ForumPost? = nil, onSave: ((ForumPost) -> Void)? = nil) {
        self.board = board
        self.store = store
        existingPost = post
        self.onSave = onSave
        _title = State(initialValue: post?.title ?? "")
        _content = State(initialValue: post?.body ?? "")
    }

    private var canSave: Bool {
        !store.isUnavailable &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                LabeledContent("分類", value: board.title)
                VStack(alignment: .leading, spacing: 8) {
                    Text("標題")
                        .font(.subheadline.weight(.medium))
                    TextField("輸入文章標題", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("內文")
                        .font(.subheadline.weight(.medium))
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 250)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle(existingPost == nil ? "新增文章" : "修改文章")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存文章", systemImage: SailuneSymbol.save.systemName, action: save)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 480)
        .alert("無法儲存文章", isPresented: errorBinding) {
            Button(SailuneActionCopy.acknowledge) {
                errorMessage = nil
                store.clearPersistenceError()
            }
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
    }

    private func save() {
        do {
            let saved: ForumPost
            if let existingPost {
                saved = try store.update(id: existingPost.id, title: title, body: content)
            } else {
                saved = try store.create(board: board, title: title, body: content)
            }
            onSave?(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }
}

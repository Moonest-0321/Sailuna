import SwiftUI
import SwiftData

struct StartAchievementsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("成就")
                    .font(.title2.weight(.semibold))

                GroupBox("最多閱讀") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("書名") { blankValue }
                        LabeledContent("閱讀量") { blankValue }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("訂閱最高") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("書名") { blankValue }
                        LabeledContent("訂閱量") { blankValue }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("獲得榮耀") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("書名") { blankValue }
                        LabeledContent("榮耀") { blankValue }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var blankValue: some View {
        Text(" ")
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .accessibilityHidden(true)
    }
}

struct StartPublishingView: View {
    private static let availableTags = ["奇幻", "愛情", "冒險"]

    let books: [Book]
    let canPublish: Bool
    let statusForBook: (UUID) -> BookStatus
    let onAdvance: (UUID) -> Void
    let onPublish: (UUID, [String]) -> Void
    let onSendUpdate: (UUID) -> Void
    let tagsForBook: (UUID) -> [String]
    let onResume: (UUID) -> Void
    let onDelist: (UUID) -> Void
    let onRestoreDraft: (UUID) -> Void
    let writingStats: BookWritingStatsStore
    @State private var selectedBookID: UUID?
    @State private var publishingBookID: UUID?
    @State private var selectedTags: Set<String> = []

    var body: some View {
        ZStack {
            Group {
                if let selectedBookID, let book = books.first(where: { $0.id == selectedBookID }) {
                    BookAnalyticsView(book: book, writingStats: writingStats) {
                        self.selectedBookID = nil
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("發布")
                                .font(.title2.weight(.semibold))

                            ForEach(books) { book in
                                let status = statusForBook(book.id)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 16) {
                                        Button {
                                            selectedBookID = book.id
                                        } label: {
                                            Text(book.title.isEmpty ? "未命名作品" : book.title)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityHint("開啟《\(book.title)》的數據")

                                        Text(status.publicationTitle)
                                            .foregroundStyle(.secondary)
                                        if status == .completed {
                                            HStack(spacing: SailuneLayout.spacingS) {
                                                Button("傳送至拾頁") { onSendUpdate(book.id) }
                                                    .accessibilityLabel("傳送《\(book.title)》至拾頁")
                                                    .disabled(!canPublish)
                                                Button("恢復連載") { onResume(book.id) }
                                                    .accessibilityLabel("恢復《\(book.title)》連載")
                                                Button("下架") { onDelist(book.id) }
                                                    .accessibilityLabel("下架《\(book.title)》")
                                            }
                                        } else if status == .draft {
                                            Button("傳送至拾頁") {
                                                selectedTags = Set(tagsForBook(book.id))
                                                publishingBookID = book.id
                                            }
                                            .accessibilityLabel("傳送《\(book.title)》至拾頁")
                                            .disabled(!canPublish)
                                        } else if status == .delisted {
                                            Button("轉為草稿") { onRestoreDraft(book.id) }
                                                .accessibilityLabel("將《\(book.title)》轉為草稿")
                                        } else {
                                            HStack(spacing: SailuneLayout.spacingS) {
                                                Button("傳送至拾頁") { onSendUpdate(book.id) }
                                                    .accessibilityLabel("傳送《\(book.title)》至拾頁")
                                                    .disabled(!canPublish)
                                                Button("完結") { onAdvance(book.id) }
                                                    .accessibilityLabel("完結《\(book.title)》")
                                                Button("下架") { onDelist(book.id) }
                                                    .accessibilityLabel("下架《\(book.title)》")
                                            }
                                        }
                                    }

                                    let tags = tagsForBook(book.id)
                                    if !tags.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(tags, id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color.primary.opacity(0.08), in: Capsule())
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                Divider()
                            }
                        }
                        .padding(20)
                    }
                }
            }

            if let publishingBookID, let book = books.first(where: { $0.id == publishingBookID }) {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { self.publishingBookID = nil }
                    .zIndex(1)

                PublicationTagPickerPopup(
                    bookTitle: book.title,
                    tags: Self.availableTags,
                    selection: $selectedTags,
                    onCancel: { self.publishingBookID = nil },
                    onPublish: {
                        let bookID = book.id
                        let tags = Self.availableTags.filter(selectedTags.contains)
                        self.publishingBookID = nil
                        DispatchQueue.main.async { onPublish(bookID, tags) }
                    }
                )
                .frame(width: 420)
                .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 2)
                .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PublicationTagPickerPopup: View {
    let bookTitle: String
    let tags: [String]
    @Binding var selection: Set<String>
    let onCancel: () -> Void
    let onPublish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("選擇發布標籤")
                .font(.headline)
            Text(bookTitle.isEmpty ? "未命名作品" : bookTitle)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        if selection.contains(tag) { selection.remove(tag) }
                        else { selection.insert(tag) }
                    } label: {
                        HStack(spacing: 5) {
                            if selection.contains(tag) { Image(systemName: "checkmark") }
                            Text(tag)
                        }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityAddTraits(selection.contains(tag) ? .isSelected : [])
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button(SailuneActionCopy.cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("下一步", action: onPublish)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

struct BookTemplatesView: View {
    let books: [Book]
    let onCreatedBook: (UUID) -> Void
    @Environment(WorkspaceCoordinator.self) private var workspace
    @Environment(SailuneAccountAuthService.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AuthorProfile]
    @Environment(StoryPlanningStore.self) private var planningStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @State private var selectedTab = 0
    @State private var templateQuery = ""
    @State private var templateStore: BookTemplateStore?
    @State private var showingSourcePicker = false
    @State private var selectedSourceBookID: UUID?
    @State private var templateName = ""
    @State private var templatePendingDeletion: BookTemplateDocument?
    @State private var templatePendingUpload: BookTemplateDocument?
    @State private var templatePendingUnpublish: BookTemplateDocument?
    @State private var publishedIDs: Set<UUID> = []
    @State private var publicationStatusLoaded = false
    @State private var publicTemplates: [SharedTemplateSummary] = []
    @State private var isRemoteWorking = false
    @State private var remoteLoadID = UUID()
    @State private var remoteError: String?
    @State private var operationError: String?

    private var community: SailuneCommunityService { .init(workspace: workspace, auth: auth) }
    private var displayName: String {
        let name = profiles.first?.penName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "帆夢使用者" : name
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                tabButton("我的模板", index: 0)
                tabButton("搜尋模板", index: 1)
                Spacer(minLength: 0)
            }
            .padding(20)

            if selectedTab == 0 {
                if let templates = templateStore?.templates, !templates.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                            ForEach(templates) { template in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(template.name.isEmpty ? "未命名模板" : template.name)
                                        .font(.headline)
                                    Text("設定集・地圖・時間軸 · \(template.timelines.count) 條時間軸 · \(template.settings.maps.count) 張地圖")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                    HStack {
                                        if publishedIDs.contains(template.id) {
                                            Button("取消公開") { templatePendingUnpublish = template }
                                                .buttonStyle(.bordered)
                                                .disabled(isRemoteWorking)
                                        } else {
                                            Button("上傳並公開") { templatePendingUpload = template }
                                                .buttonStyle(.bordered)
                                                .disabled(isRemoteWorking || !publicationStatusLoaded)
                                        }
                                        Button(role: .destructive) {
                                            templatePendingDeletion = template
                                        } label: {
                                            Label(SailuneActionCopy.delete, systemImage: SailuneSymbol.delete.systemName)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(isRemoteWorking || !publicationStatusLoaded || publishedIDs.contains(template.id))
                                        .help(publishedIDs.contains(template.id) ? "請先取消公開" : "刪除本機模板")
                                        .accessibilityLabel("刪除模板「\(template.name)」")

                                        Spacer()

                                        Button {
                                            apply(template)
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.body.weight(.semibold))
                                                .frame(width: 34, height: 34)
                                                .background(Color.primary.opacity(0.08), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("使用此模板建立草稿")
                                        .accessibilityLabel("使用「\(template.name)」建立草稿")
                                    }
                                }
                                .padding(16)
                                .frame(minHeight: 132, alignment: .leading)
                                .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 84)
                    }
                } else {
                    ContentUnavailableView("尚無模板", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    SailuneSearchField(placeholder: "搜尋模板", text: $templateQuery)
                        .padding(.horizontal, 8)
                    if isRemoteWorking {
                        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if publicTemplates.isEmpty {
                        ContentUnavailableView("找不到公開模板", systemImage: SailuneSymbol.template.systemName)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                                ForEach(publicTemplates) { template in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(template.name).font(.headline)
                                        Text("\(template.displayName)・格式 V\(template.formatVersion)")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Text(template.summary).font(.callout).foregroundStyle(.secondary)
                                        Spacer()
                                        Button("使用模板建立草稿") {
                                            Task { await applyPublicTemplate(template) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
                                    .padding(16)
                                    .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(20)
                        }
                    }
                }
            }
        }
        .onAppear(perform: loadTemplates)
        .task(id: "\(selectedTab)|\(templateQuery)|\(workspace.generation)") {
            if selectedTab == 1 {
                do { try await Task.sleep(for: .milliseconds(250)) }
                catch { return }
            }
            await loadRemoteTemplates()
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab == 0 {
                Button { showingSourcePicker = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .frame(width: 46, height: 46)
                        .background(SailuneTheme.windowSurface, in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("從書籍建立模板")
                .accessibilityLabel("從書籍建立模板")
                .padding(24)
            }
        }
        .sheet(isPresented: $showingSourcePicker) {
            sourcePicker
                .frame(minWidth: 360, minHeight: 280)
        }
        .confirmationDialog(
            "刪除模板？",
            isPresented: Binding(
                get: { templatePendingDeletion != nil },
                set: { if !$0 { templatePendingDeletion = nil } }
            ),
            presenting: templatePendingDeletion
        ) { template in
            Button(SailuneActionCopy.delete, role: .destructive) {
                deleteTemplate(template)
            }
            Button(SailuneActionCopy.cancel, role: .cancel) {
                templatePendingDeletion = nil
            }
        } message: { template in
            Text("確定刪除「\(template.name.isEmpty ? "未命名模板" : template.name)」？刪除後無法復原。")
        }
        .confirmationDialog("上傳並公開模板？", isPresented: Binding(
            get: { templatePendingUpload != nil }, set: { if !$0 { templatePendingUpload = nil } }
        ), presenting: templatePendingUpload) { template in
            Button("上傳並公開") {
                templatePendingUpload = nil
                Task { await publish(template) }
            }
            Button(SailuneActionCopy.cancel, role: .cancel) { templatePendingUpload = nil }
        } message: { template in
            Text("「\(template.name)」將公開 \(template.characters.count) 位角色、\(template.settings.maps.count) 張地圖、\(template.timelines.count) 條時間軸及設定資料，可能包含 PDF 地圖。正文不會上傳。")
        }
        .confirmationDialog("取消公開模板？", isPresented: Binding(
            get: { templatePendingUnpublish != nil }, set: { if !$0 { templatePendingUnpublish = nil } }
        ), presenting: templatePendingUnpublish) { template in
            Button("取消公開") {
                templatePendingUnpublish = nil
                Task { await unpublish(template) }
            }
            Button(SailuneActionCopy.cancel, role: .cancel) { templatePendingUnpublish = nil }
        } message: { template in
            Text("「\(template.name)」將從公開搜尋中移除，本機模板仍會保留。")
        }
        .overlay(alignment: .top) {
            if let remoteError {
                HStack {
                    Text(remoteError).foregroundStyle(.red)
                    Button("重試") { Task { await loadRemoteTemplates() } }
                }
                .padding(12)
                .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .alert("模板操作失敗", isPresented: Binding(
            get: { operationError != nil },
            set: { if !$0 { operationError = nil } }
        )) {
            Button(SailuneActionCopy.acknowledge) { operationError = nil }
        } message: {
            Text(operationError ?? "未知錯誤")
        }
    }

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("選擇要匯出設定集、地圖與時間軸的書籍")
                .font(.headline)
            TextField("模板名稱", text: $templateName)
                .textFieldStyle(.roundedBorder)
            if books.isEmpty {
                ContentUnavailableView("尚無書籍", systemImage: "books.vertical")
            } else {
                List(books) { book in
                    Button {
                        selectedSourceBookID = book.id
                        if templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            templateName = book.title.isEmpty ? "未命名模板" : book.title
                        }
                    } label: {
                        HStack {
                            Text(book.title.isEmpty ? "未命名作品" : book.title)
                            Spacer()
                            if selectedSourceBookID == book.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                Button(SailuneActionCopy.cancel) { showingSourcePicker = false }
                    .buttonStyle(.bordered)
                Button("建立模板") {
                    guard let id = selectedSourceBookID, let book = books.first(where: { $0.id == id }) else { return }
                    createTemplate(from: book)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSourceBookID == nil || templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }

    private func loadTemplates() {
        do {
            if let templateStore { try templateStore.reload() }
            else { templateStore = try BookTemplateStore(directory: SailuneDataLocations.current.bookTemplatesDirectory) }
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func createTemplate(from book: Book) {
        do {
            let enteredName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = enteredName.isEmpty ? (book.title.isEmpty ? "未命名模板" : book.title) : enteredName
            let template = try BookTemplateCoordinator.snapshot(book: book, planning: planningStore, settingsStore: settingsStore, name: name, context: modelContext, copyStore: copyStore, abilityStore: abilityStore)
            if templateStore == nil { templateStore = try BookTemplateStore(directory: SailuneDataLocations.current.bookTemplatesDirectory) }
            try templateStore?.save(template)
            showingSourcePicker = false
            selectedSourceBookID = nil
            templateName = ""
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func deleteTemplate(_ template: BookTemplateDocument) {
        guard let templateStore else {
            templatePendingDeletion = nil
            operationError = "模板尚未載入，請稍後再試。"
            return
        }
        do {
            try templateStore.remove(template)
            templatePendingDeletion = nil
        } catch {
            templatePendingDeletion = nil
            operationError = error.localizedDescription
        }
    }

    private func apply(_ template: BookTemplateDocument) {
        do {
            let book = try BookTemplateCoordinator.apply(
                template,
                title: template.name,
                author: template.author,
                context: modelContext,
                planning: planningStore,
                settingsStore: settingsStore,
                copyStore: copyStore,
                abilityStore: abilityStore
            )
            onCreatedBook(book.id)
        } catch {
            operationError = error.localizedDescription
        }
    }

    private func loadRemoteTemplates() async {
        guard workspace.canUseSignedInFeatures(auth: auth) else { return }
        let requestID = UUID()
        let requestedTab = selectedTab
        let requestedQuery = templateQuery
        remoteLoadID = requestID
        if requestedTab == 0 {
            publicationStatusLoaded = false
            publishedIDs = []
        }
        isRemoteWorking = true
        do {
            if requestedTab == 0 {
                let ids = try await community.publishedTemplateIDs()
                guard remoteLoadID == requestID, selectedTab == requestedTab else { return }
                publishedIDs = ids
                publicationStatusLoaded = true
            } else {
                let templates = try await community.listTemplates(query: requestedQuery)
                guard remoteLoadID == requestID, selectedTab == requestedTab,
                      templateQuery == requestedQuery else { return }
                publicTemplates = templates
            }
            remoteError = nil
        } catch {
            guard remoteLoadID == requestID else { return }
            remoteError = "無法載入公開模板：\(CommunityFailure.message(for: error))"
        }
        if remoteLoadID == requestID { isRemoteWorking = false }
    }

    private func publish(_ template: BookTemplateDocument) async {
        remoteLoadID = UUID()
        isRemoteWorking = true
        defer { isRemoteWorking = false }
        do {
            try await community.publishTemplate(template, displayName: displayName)
            publishedIDs.insert(template.id)
            remoteError = nil
        } catch { remoteError = "無法公開模板：\(CommunityFailure.message(for: error))" }
    }

    private func unpublish(_ template: BookTemplateDocument) async {
        remoteLoadID = UUID()
        isRemoteWorking = true
        defer { isRemoteWorking = false }
        do {
            try await community.hideTemplate(id: template.id)
            publishedIDs.remove(template.id)
            remoteError = nil
        } catch { remoteError = "無法取消公開：\(CommunityFailure.message(for: error))" }
    }

    private func applyPublicTemplate(_ summary: SharedTemplateSummary) async {
        remoteLoadID = UUID()
        isRemoteWorking = true
        defer { isRemoteWorking = false }
        do {
            let template = try await community.downloadTemplate(id: summary.id)
            apply(template)
        } catch { remoteError = "無法使用公開模板：\(CommunityFailure.message(for: error))" }
    }

    @ViewBuilder
    private func tabButton(_ title: String, index: Int) -> some View {
        if selectedTab == index {
            Button(title) { selectedTab = index }
                .buttonStyle(.borderedProminent)
        } else {
            Button(title) { selectedTab = index }
                .buttonStyle(.bordered)
        }
    }
}

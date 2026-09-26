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
    let statusForBook: (UUID) -> BookStatus
    let onAdvance: (UUID) -> Void
    let onPublish: (UUID, [String]) -> Void
    let tagsForBook: (UUID) -> [String]
    let onResume: (UUID) -> Void
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
                                            Button("恢復連載") { onResume(book.id) }
                                                .accessibilityLabel("恢復《\(book.title)》連載")
                                        } else if status == .draft {
                                            Button("發布") {
                                                selectedTags = Set(tagsForBook(book.id))
                                                publishingBookID = book.id
                                            }
                                            .accessibilityLabel("發布《\(book.title)》")
                                        } else {
                                            Button("完結") { onAdvance(book.id) }
                                                .accessibilityLabel("完結《\(book.title)》")
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
                        onPublish(book.id, Self.availableTags.filter(selectedTags.contains))
                        self.publishingBookID = nil
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
                Button("發布", action: onPublish)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

struct BookTemplatesView: View {
    let books: [Book]
    let onCreatedBook: (UUID) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(StoryPlanningStore.self) private var planningStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @State private var selectedTab = 0
    @State private var templateStore: BookTemplateStore?
    @State private var showingSourcePicker = false
    @State private var selectedSourceBookID: UUID?
    @State private var templateName = ""
    @State private var operationError: String?

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
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: loadTemplates)
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

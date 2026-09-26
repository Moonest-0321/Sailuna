import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - 主畫面：網格書櫃
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(StoryPlanningStore.self) private var planningStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(BookPublicationStore.self) private var publicationStore
    @Environment(BookWritingStatsStore.self) private var writingStatsStore
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @Query private var profiles: [AuthorProfile]
    @State private var navigationPath = NavigationPath()
    @State private var showingNewBookSheet = false
    @State private var showingBookTextImporter = false
    @State private var bookTextImportSource: BookTextImportSource?
    @State private var searchText = ""
    @State private var deletionRequest: BookDeletionRequest?
    @State private var bookDeletionError: String?
    @State private var selectedSidebarItem: StartSidebarItem = .home
    @State private var showingAboutMeSheet = false
    @State private var showingAccountPopover = false
    @State private var selectedPlan: AccountPlan = .light
    @State private var sectionUnitUpdateError: String?
    @AppStorage(SectionUnitPreference.storageKey) private var sectionUnitRawValue = BookTextSectionMarker.section.rawValue

    private var selectedSectionUnit: BookTextSectionMarker {
        SectionUnitPreference.resolve(sectionUnitRawValue)
    }

    private var sectionUnitBinding: Binding<BookTextSectionMarker> {
        Binding(
            get: { selectedSectionUnit },
            set: { applySectionUnit($0) }
        )
    }

    private func applySectionUnit(_ unit: BookTextSectionMarker) {
        guard unit != selectedSectionUnit else { return }
        do {
            try SectionUnitCoordinator.apply(unit, to: books, in: modelContext)
            sectionUnitRawValue = unit.rawValue
            sectionUnitUpdateError = nil
        } catch {
            sectionUnitUpdateError = "無法更新章節單位，請再試一次。"
        }
    }

    private var showsStartTopBar: Bool {
        [.home, .find].contains(selectedSidebarItem)
    }

    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        } else {
            return books.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    let columns = [
        GridItem(.adaptive(minimum: 180), spacing: 24)
    ]

    private var bookMetrics: [UUID: BookStructure.Metrics] {
        var byBookID: [UUID: BookStructure.Metrics] = [:]
        byBookID.reserveCapacity(books.count)
        for book in books {
            byBookID[book.id] = BookStructure.metrics(for: book)
        }
        return byBookID
    }

    var body: some View {
        let metrics = bookMetrics
        NavigationStack(path: $navigationPath) {
            ZStack {
                HStack(spacing: 0) {
                    StartSidebarView(
                        selection: $selectedSidebarItem,
                        profile: profiles.first,
                        onSelect: handleSidebarSelection,
                        onToggleAccountPopover: {
                            showingAccountPopover.toggle()
                        }
                    )
                        .frame(width: 220)
                    Divider()
                    VStack(spacing: 0) {
                        if showsStartTopBar {
                            StartTopBarView(
                                searchText: $searchText,
                                isSearchPresented: selectedSidebarItem == .find,
                                onCreateBook: { showingNewBookSheet = true },
                                onImportBook: { showingBookTextImporter = true }
                            )
                        }
                        libraryContent(metrics: metrics)
                    }
                }

                if showingAccountPopover {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingAccountPopover = false
                        }
                        .zIndex(8)

                    AccountPopoverView(
                        selectedPlan: $selectedPlan,
                        onOpenSettings: {
                            showingAccountPopover = false
                            selectedSidebarItem = .settings
                            searchText = ""
                            navigationPath = NavigationPath()
                        }
                    )
                    .frame(width: 220)
                    .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 8)
                    .padding(.bottom, 78)
                    .zIndex(9)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if showingNewBookSheet || showingAboutMeSheet || deletionRequest != nil || bookDeletionError != nil {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingNewBookSheet = false
                            showingAboutMeSheet = false
                            deletionRequest = nil
                            bookDeletionError = nil
                        }
                        .zIndex(10)
                }

                if showingNewBookSheet {
                    NewBookSheet(
                        onCreated: { book in
                            showingNewBookSheet = false
                            selectedSidebarItem = .home
                            searchText = ""
                            navigationPath = NavigationPath()
                            navigationPath.append(BookRoute(id: book.id, opensEditor: true))
                        },
                        onCancel: {
                            showingNewBookSheet = false
                        }
                    )
                    .frame(width: 420, height: 250)
                    .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 2)
                    .zIndex(11)
                }

                if let bookTextImportSource {
                    BookTextImportOverlay(
                        source: bookTextImportSource,
                        onCancel: { self.bookTextImportSource = nil },
                        onCreated: { bookID in
                            self.bookTextImportSource = nil
                            selectedSidebarItem = .home
                            searchText = ""
                            navigationPath = NavigationPath()
                            navigationPath.append(BookRoute(id: bookID, opensEditor: true))
                        }
                    )
                }

                if showingAboutMeSheet {
                    AboutMeView(onDismiss: {
                        showingAboutMeSheet = false
                    })
                    .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 2)
                    .zIndex(11)
                }

                if let request = deletionRequest {
                    HomeDeletionPopup(
                        title: "刪除《\(request.title)》？",
                        message: "這會刪除本書的正文、角色與設定、敘事大綱、世界時間資料及封面，而且無法復原。",
                        onCancel: { deletionRequest = nil },
                        onConfirm: { deleteBook(request) }
                    )
                    .zIndex(11)
                }

                if let bookDeletionError {
                    HomeMessagePopup(
                        title: "書籍操作結果",
                        message: bookDeletionError,
                        onDismiss: { self.bookDeletionError = nil }
                    )
                    .zIndex(11)
                }
            }
            .navigationDestination(for: BookRoute.self) { route in
                BookRouteDestination(route: route)
            }
            .navigationDestination(for: Section.self) { section in
                if let book = section.volume?.book {
                    EditorWorkspaceView(book: book, initialSection: section)
                }
            }
            .environment(\.sectionUnit, selectedSectionUnit)
            .fileImporter(
                isPresented: $showingBookTextImporter,
                allowedContentTypes: [UTType(filenameExtension: "txt") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                guard url.pathExtension.lowercased() == "txt" else {
                    bookTextImportSource = BookTextImportSource(
                        fileName: url.lastPathComponent,
                        data: nil,
                        readError: "請選擇 TXT 檔案。"
                    )
                    return
                }
                let hasSecurityScope = url.startAccessingSecurityScopedResource()
                defer {
                    if hasSecurityScope { url.stopAccessingSecurityScopedResource() }
                }
                do {
                    bookTextImportSource = BookTextImportSource(
                        fileName: url.lastPathComponent,
                        data: try Data(contentsOf: url),
                        readError: nil
                    )
                } catch {
                    bookTextImportSource = BookTextImportSource(
                        fileName: url.lastPathComponent,
                        data: nil,
                        readError: "無法讀取檔案：\(error.localizedDescription)"
                    )
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showingAccountPopover)
        }
    }

    private func handleSidebarSelection(_ item: StartSidebarItem) {
        var transaction = Transaction()
        transaction.animation = .easeInOut(duration: 0.24)
        withTransaction(transaction) {
            if item == .about {
                showingAboutMeSheet = true
                return
            }

            selectedSidebarItem = item
            navigationPath = NavigationPath()
            if item != .find {
                searchText = ""
            }
        }
    }

    @ViewBuilder
    private func libraryContent(metrics: [UUID: BookStructure.Metrics]) -> some View {
        switch selectedSidebarItem {
        case .home, .find:
            libraryBookContent(metrics: metrics)
        case .settings:
            StartSettingsView(sectionUnit: sectionUnitBinding, updateError: sectionUnitUpdateError)
        case .publish:
            StartPublishingView(
                books: books,
                statusForBook: { publicationStore.status(for: $0) },
                onAdvance: advancePublication,
                writingStats: writingStatsStore
            )
        case .achievements:
            StartAchievementsView()
        case .templates, .forum, .about:
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func libraryBookContent(metrics: [UUID: BookStructure.Metrics]) -> some View {
        if searchText.isEmpty {
            ScrollView {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("書櫃還沒有小說", systemImage: "books.vertical")
                    } description: {
                        Text("建立第一本小說，立即開始寫作。")
                    } actions: {
                        Button("建立第一本小說", systemImage: SailuneSymbol.add.systemName) { showingNewBookSheet = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    bookStatusSections(books: books, metrics: metrics)
                }
            }
            .padding(24)
        } else if filteredBooks.isEmpty {
            ContentUnavailableView("找不到書籍", systemImage: SailuneSymbol.search.systemName)
        } else {
            ScrollView {
                bookStatusSections(books: filteredBooks, metrics: metrics)
                .padding(24)
            }
        }
    }

    private var shelfStatuses: [BookStatus] {
        [.ongoing, .draft, .completed]
    }

    private func bookStatusSections(
        books displayedBooks: [Book],
        metrics: [UUID: BookStructure.Metrics]
    ) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(shelfStatuses) { status in
                let statusBooks = displayedBooks.filter { publicationStore.status(for: $0.id) == status }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text(status.publicationTitle)
                            .font(.headline)
                        Rectangle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(height: 1)
                    }

                    if statusBooks.isEmpty {
                        Text("尚無\(status.publicationTitle)作品")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                            .padding(.vertical, 10)
                    } else {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(statusBooks) { book in
                                bookLink(book, wordCount: metrics[book.id]?.wordCount ?? 0)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bookLink(_ book: Book, wordCount: Int) -> some View {
        NavigationLink(value: BookRoute(id: book.id, opensEditor: false)) {
            BookCardView(book: book, wordCount: wordCount, status: publicationStore.status(for: book.id))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deletionRequest = BookDeletionRequest(id: book.id, title: book.title)
            } label: {
                Label(SailuneActionCopy.delete, systemImage: SailuneSymbol.delete.systemName)
            }
        }
    }

    @MainActor
    private func deleteBook(_ request: BookDeletionRequest) {
        defer { deletionRequest = nil }
        guard let book = books.first(where: { $0.id == request.id }) else { return }

        do {
            let outcome = try CrossStoreDeletionCoordinator.deleteBook(
                book,
                in: modelContext,
                copyStore: copyStore,
                planningStore: planningStore,
                settingsStore: settingsStore,
                abilityStore: abilityStore
            )
            if outcome.requiresRepair {
                bookDeletionError = "書籍已刪除，但部分附屬資料將在下次啟動時繼續修復。\n\n\(outcome.deferredCleanupErrors.joined(separator: "\n"))"
            }
            do {
                try publicationStore.remove(request.id)
            } catch {
                bookDeletionError = "書籍已刪除，但發布狀態清理失敗：\(error.localizedDescription)"
            }
            do {
                try writingStatsStore.removeBook(request.id)
            } catch {
                let detail = "書籍已刪除，但每日編輯統計清理失敗：\(error.localizedDescription)"
                bookDeletionError = [bookDeletionError, detail].compactMap { $0 }.joined(separator: "\n\n")
            }
        } catch {
            bookDeletionError = "無法刪除《\(request.title)》，內容仍完整保留。\n\n\(error.localizedDescription)"
        }
    }

    private func advancePublication(_ bookID: UUID) {
        do {
            try publicationStore.advance(bookID)
        } catch {
            bookDeletionError = "無法更新書籍發布狀態：\(error.localizedDescription)"
        }
    }

}

private enum StartSidebarItem: String, CaseIterable, Identifiable {
    case home = "首頁"
    case find = "尋找"
    case publish = "發布"
    case templates = "模板"
    case forum = "論壇"
    case achievements = "成就"
    case about = "關於我"
    case settings = "設定"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .find: return SailuneSymbol.search.systemName
        case .publish: return "square.and.arrow.up"
        case .templates: return SailuneSymbol.template.systemName
        case .forum: return SailuneSymbol.forum.systemName
        case .achievements: return "trophy"
        case .about: return "person"
        case .settings: return SailuneSymbol.settings.systemName
        }
    }
}

private struct StartSidebarView: View {
    @Binding var selection: StartSidebarItem
    let profile: AuthorProfile?
    let onSelect: (StartSidebarItem) -> Void
    let onToggleAccountPopover: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
            Text("帆夢 Sailune")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 22)

            Text("作品")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            Divider()

            sidebarButton(.home)
            sidebarButton(.find)
            sidebarButton(.publish)

            Text("社群")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 24)
                .padding(.bottom, 8)

            Divider()

            sidebarButton(.templates)
            sidebarButton(.forum)

            Text("作者")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 24)
                .padding(.bottom, 8)

            Divider()

            sidebarButton(.achievements)
            sidebarButton(.about)

            Spacer(minLength: 0)

            Button {
                onToggleAccountPopover()
            } label: {
                HStack(spacing: 9) {
                    SidebarAvatarView(profile: profile)
                    Text("登入")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
            .padding(.horizontal, 2)
            .padding(.bottom, 14)
            }

        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SailuneTheme.controlSurface)
    }

    private func sidebarButton(_ item: StartSidebarItem) -> some View {
        Button {
            onSelect(item)
        } label: {
            Label(item.rawValue, systemImage: item.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .foregroundStyle(selection == item ? .primary : .secondary)
        .background {
            if selection == item {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
            }
        }
        .contentShape(Rectangle())
        .help(item.rawValue)
    }
}

private enum AccountPlan: String, CaseIterable, Identifiable {
    case light
    case creator
    case business

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light 輕量"
        case .creator: return "Creator 創作者"
        case .business: return "Business 商業"
        }
    }
}

private struct AccountPopoverView: View {
    @Binding var selectedPlan: AccountPlan
    let onOpenSettings: () -> Void
    @State private var accountStatusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            accountAction("帳號", systemImage: "person.crop.circle") {
                accountStatusMessage = "Apple ID 登入需要付費 Apple Developer Program；目前個人開發團隊不支援。"
            }

            if let accountStatusMessage {
                Text(accountStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            }

            Picker(selection: $selectedPlan) {
                ForEach(AccountPlan.allCases) { plan in
                    Text(plan.title).tag(plan)
                }
            } label: {
                HStack {
                    Label("方案", systemImage: "sparkles")
                    Spacer(minLength: 12)
                    Text(selectedPlan.title)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .pickerStyle(.menu)

            Divider()

            accountAction("設定", systemImage: SailuneSymbol.settings.systemName, action: onOpenSettings)
            accountAction("切換帳號", systemImage: "person.2") { }

            Divider()

            Button(role: .destructive) { } label: {
                Label("退出登入", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 220)
    }

    private func accountAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 28)
    }

}

private struct StartSettingsView: View {
    @Binding var sectionUnit: BookTextSectionMarker
    let updateError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("AI 模型與 API") {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("使用模型", value: "Apple 裝置端模型")
                    LabeledContent("API", value: "不使用外部 API")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("版本") {
                LabeledContent("開發版本", value: "V10.1")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("章節單位") {
                Picker("預設單位", selection: $sectionUnit) {
                    ForEach(SectionUnitPreference.options) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                if let updateError {
                    Text(updateError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

}

private struct AboutMeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AuthorProfile]
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if let profile = profiles.first {
                AboutMeForm(profile: profile, onDismiss: onDismiss)
            } else {
                ProgressView()
            }
        }
        .padding(24)
        .frame(width: 420, height: 430)
        .onAppear {
            if profiles.isEmpty {
                modelContext.insert(AuthorProfile(penName: "我的筆名"))
            }
        }
    }
}

private struct AboutMeForm: View {
    @Bindable var profile: AuthorProfile
    @Environment(\.dismiss) private var dismiss
    let onDismiss: () -> Void

    private var defaultInitial: String {
        let trimmed = profile.penName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.first ?? "夢")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("關於我")
                .font(.title2.weight(.semibold))

            HStack(spacing: 16) {
                Group {
                    if let data = profile.avatarData, let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text(defaultInitial)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.secondary.opacity(0.12))
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))

                VStack(alignment: .leading, spacing: 5) {
                    Text("頭像")
                        .font(.headline)
                    Text("尚未設定圖片時，使用筆名第一個字。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("加入圖片", systemImage: SailuneSymbol.imageAsset.systemName) {
                        selectAvatar()
                    }
                    .buttonStyle(.borderless)
                }
            }

            SailuneFormTextField(title: "筆名", text: $profile.penName)

            VStack(alignment: .leading, spacing: 6) {
                Text("簡介")
                    .font(.headline)
                SailuneAuthorBioEditor(text: Binding(
                    get: { profile.bio ?? "" },
                    set: { profile.bio = $0 }
                ), height: 110, borderColor: Color.primary.opacity(0.12))
            }

            HStack {
                Spacer()
                Button(SailuneActionCopy.done) {
                    onDismiss()
                    dismiss()
                }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func selectAvatar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "選擇頭像"

        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        profile.avatarData = pngData
    }
}

private struct SidebarAvatarView: View {
    let profile: AuthorProfile?

    var body: some View {
        Group {
            if let data = profile?.avatarData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color.secondary.opacity(0.14), in: Circle())
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
        .accessibilityLabel("作者頭像")
    }
}

private struct StartTopBarView: View {
    @Binding var searchText: String
    let isSearchPresented: Bool
    let onCreateBook: () -> Void
    let onImportBook: () -> Void
    @FocusState private var searchFocused

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = proxy.size.width
            let reservedButtonWidth = min(250, availableWidth * 0.52)
            let maximumSearchWidth = max(0, availableWidth - reservedButtonWidth)
            let proportionalSearchWidth = availableWidth * 0.38
            let presentedSearchWidth = min(maximumSearchWidth, max(160, proportionalSearchWidth))

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: SailuneSymbol.search.systemName)
                        .foregroundStyle(.secondary)
                    TextField("搜尋書名或作者", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: SailuneSymbol.clearSearch.systemName)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .frame(width: isSearchPresented ? presentedSearchWidth : 0)
                .frame(height: 28)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .clipped()
                .opacity(isSearchPresented ? 1 : 0)
                .offset(x: isSearchPresented ? 0 : -18)

                HStack(spacing: 10) {
                    Button(action: onCreateBook) {
                        Label("新建書籍", systemImage: SailuneSymbol.add.systemName)
                    }
                    .buttonStyle(.borderless)

                    Button(action: onImportBook) {
                        Label(SailuneActionCopy.importBook, systemImage: SailuneSymbol.importBook.systemName)
                    }
                    .buttonStyle(.borderless)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: 44)
        .clipped()
        .animation(.easeInOut(duration: 0.24), value: isSearchPresented)
        .onChange(of: isSearchPresented) { _, presented in
            searchFocused = presented
        }
    }
}

private struct BookRoute: Hashable {
    let id: UUID
    let opensEditor: Bool
}

private struct BookDeletionRequest {
    let id: UUID
    let title: String
}

private struct BookRouteDestination: View {
    let route: BookRoute
    @Query private var books: [Book]

    init(route: BookRoute) {
        self.route = route
        let bookID = route.id
        _books = Query(filter: #Predicate<Book> { $0.id == bookID })
    }

    var body: some View {
        Group {
            if let book = books.first {
                destination(for: book)
            } else {
                ContentUnavailableView("找不到這本書", systemImage: "book.closed")
            }
        }
    }

    @ViewBuilder
    private func destination(for book: Book) -> some View {
        if route.opensEditor,
           let section = BookStructure.orderedSections(in: book).first {
            EditorWorkspaceView(book: book, initialSection: section)
        } else {
            BookOverviewView(book: book)
        }
    }
}

// MARK: - 書籍卡片視圖
struct BookCardView: View {
    let book: Book
    let wordCount: Int
    let status: BookStatus

    var body: some View {
        VStack(spacing: 0) {
            BookCoverArtwork(book: book)
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            VStack(alignment: .leading, spacing: 8) {
                Text(book.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("狀態")
                        .foregroundStyle(.secondary)
                    Text(status.publicationTitle)
                        .fontWeight(.medium)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                }
                .font(.caption)
                Spacer(minLength: 0)
                HStack {
                    Label("\(wordCount) 字", systemImage: "character.textbox")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("建立：\(book.createdAt, style: .date)")
                    Text("更新：\(book.updatedAt, style: .date)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SailuneTheme.controlSurface)
        }
        .frame(width: 180, height: 310)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

}

// MARK: - 書籍封面
struct BookCoverArtwork: View {
    let book: Book
    @State private var coverRevision = 0

    private var firstCharacter: String {
        let trimmed = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1))
    }

    var body: some View {
        let _ = coverRevision
        Group {
            if let image = BookCoverStore.image(for: book) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    defaultColor
                    Text(firstCharacter)
                        .font(.system(size: 64, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
            }
        }
        .clipped()
        .onReceive(NotificationCenter.default.publisher(for: BookCoverStore.didChange)) { notification in
            guard let changedID = notification.object as? NSUUID,
                  changedID.uuidString == book.id.uuidString else {
                return
            }
            coverRevision &+= 1
        }
    }

    private var defaultColor: Color {
        Color(nsColor: BookCoverStore.defaultColor(for: book))
    }
}

private struct HomeDeletionPopup: View {
    let title: String
    let message: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(SailuneActionCopy.cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("刪除書籍", role: .destructive) { onConfirm() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 390)
        .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 2)
    }
}

private struct HomeMessagePopup: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button(SailuneActionCopy.acknowledge) { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 390)
        .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 新建書籍視窗
struct NewBookSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sectionUnit) private var sectionUnit
    @Query private var profiles: [AuthorProfile]
    @State private var title = ""
    @State private var author = ""
    @State private var saveError: String?
    let onCreated: (Book) -> Void
    let onCancel: () -> Void

    init(
        onCreated: @escaping (Book) -> Void = { _ in },
        onCancel: @escaping () -> Void = { }
    ) {
        self.onCreated = onCreated
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("新建書籍")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 12) {
                    SailuneFormTextField(title: "書名", text: $title)
                        .onSubmit(saveBookIfValid)
                    SailuneFormTextField(title: "作者", text: $author)
                        .onSubmit(saveBookIfValid)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Spacer()
                    Button(SailuneActionCopy.cancel) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    Button(SailuneActionCopy.done) {
                        saveBook()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
            .onAppear {
                if author.isEmpty {
                    author = profiles.first?.penName ?? NSFullUserName()
                }
            }

            if let saveError {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.saveError = nil
                    }
                    .zIndex(1)

                HomeMessagePopup(
                    title: "無法建立書籍",
                    message: saveError,
                    onDismiss: { self.saveError = nil }
                )
                .zIndex(2)
            }
        }
    }

    @MainActor
    private func saveBookIfValid() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        saveBook()
    }

    @MainActor
    private func saveBook() {
        let newBook = Book(title: title, author: author)
        let defaultVolume = Volume(title: "第一卷", book: newBook)
        let firstSection = Section(title: sectionUnit.firstTitle, sortOrder: 0, volume: defaultVolume)
        defaultVolume.sections.append(firstSection)
        newBook.volumes.append(defaultVolume)
        modelContext.insert(newBook)

        do {
            try TimelineEngine.Bootstrap.ensure(for: newBook, in: modelContext)
            if modelContext.hasChanges { try modelContext.save() }
            #if DEBUG
            let eraStart = newBook.currentEra?.startOrdinal ?? -1
            let eraName  = newBook.currentEra?.name ?? "nil"
            let primary  = newBook.timelines.filter(\.isPrimary).count
            print("✅ [Bootstrap] 建書完成 → currentEra.startOrdinal=\(eraStart), name='\(eraName)', 主軸數=\(primary)")
            #endif
            onCreated(newBook)
        } catch {
            modelContext.rollback()
            let nsError = error as NSError
            saveError = "\(nsError.domain) \(nsError.code)：\(nsError.localizedDescription)"
        }
    }
}

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Combine

// MARK: - 主畫面：網格書櫃
struct ContentView: View {
    @Environment(SailuneAccountAuthService.self) private var accountAuthService
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
    @State private var delistingBookID: UUID?
    @State private var bookDeletionError: String?
    @State private var publicationCoordinator = PublicationCoordinator()
    @State private var selectedSidebarItem: StartSidebarItem = .home
    @State private var showingAccountPopover = false
    @State private var showingEmailLoginSheet = false
    @State private var selectedPlan: AccountPlan = .light
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

    private var accountPopover: some View {
        AccountPopoverView(
            signedInEmail: accountAuthService.signedInEmail,
            errorMessage: accountAuthService.errorMessage,
            onOpenAccount: {
                handleSidebarSelection(.account)
            },
            onEmailLogin: {
                showingAccountPopover = false
                showingEmailLoginSheet = true
            },
            onSignOut: {
                Task { await accountAuthService.signOut() }
            },
            isWorking: accountAuthService.isWorking,
            onSwitchAccount: {
                Task {
                    guard !accountAuthService.isWorking else { return }
                    await accountAuthService.signOut()
                    guard accountAuthService.signedInEmail == nil,
                          accountAuthService.errorMessage == nil else { return }
                    showingAccountPopover = false
                    showingEmailLoginSheet = true
                }
            },
            onOpenSettings: {
                showingAccountPopover = false
                selectedSidebarItem = .settings
                searchText = ""
                navigationPath = NavigationPath()
            }
        )
        .frame(maxWidth: .infinity)
        .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 5, x: 0, y: 1)
    }

    private func applySectionUnit(_ unit: BookTextSectionMarker) {
        guard unit != selectedSectionUnit else { return }
        sectionUnitRawValue = unit.rawValue
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
                        isSignedIn: accountAuthService.signedInEmail != nil,
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
                .disabled(publicationCoordinator.isPresented)
                .accessibilityHidden(publicationCoordinator.isPresented)

                if showingNewBookSheet || deletionRequest != nil || delistingBookID != nil || bookDeletionError != nil {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingNewBookSheet = false
                            deletionRequest = nil
                            delistingBookID = nil
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

                if let request = deletionRequest {
                    HomeConfirmationPopup(
                        title: "刪除《\(request.title)》？",
                        message: "這會刪除本書的正文、角色與設定、敘事大綱、世界時間資料及封面，而且無法復原。",
                        confirmTitle: "刪除書籍",
                        onCancel: { deletionRequest = nil },
                        onConfirm: { deleteBook(request) }
                    )
                    .zIndex(11)
                }

                if let delistingBookID, let book = books.first(where: { $0.id == delistingBookID }) {
                    HomeConfirmationPopup(
                        title: "下架《\(book.title)》？",
                        message: "下架只會更改帆夢本機狀態，不會通知網站。之後可轉為草稿，若要再次上架，需重新發布。",
                        confirmTitle: "下架",
                        onCancel: { self.delistingBookID = nil },
                        onConfirm: { delistPublication(delistingBookID) }
                    )
                    .zIndex(11)
                }

                if publicationCoordinator.isPresented {
                    PublicationPreviewView(
                        coordinator: publicationCoordinator,
                        isSignedIn: accountAuthService.signedInEmail != nil,
                        onLogin: { showingEmailLoginSheet = true },
                        onSend: { publicationCoordinator.send(auth: accountAuthService, store: publicationStore) }
                    )
                    .zIndex(12)
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
            .sheet(isPresented: $showingEmailLoginSheet) {
                EmailLoginView(authService: accountAuthService) {
                    showingEmailLoginSheet = false
                }
            }
            .task {
                await accountAuthService.restoreSession()
            }
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
            .overlayPreferenceValue(AccountButtonAnchorPreference.self) { anchor in
                GeometryReader { geometry in
                    if showingAccountPopover, let anchor {
                        let button = geometry[anchor]
                        let margin = SailuneLayout.spacingS
                        let panelBottom = max(margin, min(geometry.size.height - margin, button.minY - margin))
                        let availableHeight = max(0, panelBottom - margin)
                        let width = max(0, min(300, geometry.size.width - margin * 2))
                        let leading = max(margin, min(button.minX, geometry.size.width - width - margin))
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { showingAccountPopover = false }
                            ViewThatFits(in: .vertical) {
                                accountPopover
                                ScrollView { accountPopover }
                            }
                            .frame(width: width, height: availableHeight, alignment: .bottomLeading)
                            .position(x: leading + width / 2, y: margin + availableHeight / 2)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showingAccountPopover)
        }
    }

    private func handleSidebarSelection(_ item: StartSidebarItem) {
        var transaction = Transaction()
        transaction.animation = .easeInOut(duration: 0.24)
        withTransaction(transaction) {
            showingAccountPopover = false

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
            StartSettingsView(sectionUnit: sectionUnitBinding)
        case .publish:
            StartPublishingView(
                books: books,
                statusForBook: { publicationStore.status(for: $0) },
                onAdvance: advancePublication,
                onPublish: publishPublication,
                onSendUpdate: sendPublicationUpdate,
                tagsForBook: { publicationStore.tags(for: $0) },
                onResume: resumePublication,
                onDelist: { delistingBookID = $0 },
                onRestoreDraft: restoreDraftPublication,
                writingStats: writingStatsStore
            )
        case .achievements:
            StartAchievementsView()
        case .templates:
            BookTemplatesView(books: books) { bookID in
                selectedSidebarItem = .home
                searchText = ""
                navigationPath = NavigationPath()
                navigationPath.append(BookRoute(id: bookID, opensEditor: false))
            }
        case .forum:
            ForumView()
        case .account:
            AccountPageView(selectedPlan: $selectedPlan, signedInEmail: accountAuthService.signedInEmail)
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
        [.ongoing, .draft, .completed, .delisted]
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

    private func publishPublication(_ bookID: UUID, tags: [String]) {
        guard let book = books.first(where: { $0.id == bookID }) else { return }
        do {
            try publicationCoordinator.prepare(book: book, tags: tags,
                status: publicationStore.status(for: bookID), sectionUnit: selectedSectionUnit)
        } catch {
            bookDeletionError = "無法準備《\(book.title)》：\(error.localizedDescription)"
        }
    }

    private func sendPublicationUpdate(_ bookID: UUID) {
        publishPublication(bookID, tags: publicationStore.tags(for: bookID))
    }

    private func advancePublication(_ bookID: UUID) {
        do {
            try publicationStore.advance(bookID)
        } catch {
            bookDeletionError = "無法更新書籍發布狀態：\(error.localizedDescription)"
        }
    }

    private func resumePublication(_ bookID: UUID) {
        do {
            try publicationStore.resume(bookID)
        } catch {
            bookDeletionError = "無法恢復《\(books.first(where: { $0.id == bookID })?.title ?? "作品")》連載：\(error.localizedDescription)"
        }
    }

    private func delistPublication(_ bookID: UUID) {
        delistingBookID = nil
        do {
            try publicationStore.delist(bookID)
        } catch {
            bookDeletionError = "無法下架《\(books.first(where: { $0.id == bookID })?.title ?? "作品")》：\(error.localizedDescription)"
        }
    }

    private func restoreDraftPublication(_ bookID: UUID) {
        do {
            try publicationStore.restoreDraft(bookID)
        } catch {
            bookDeletionError = "無法將《\(books.first(where: { $0.id == bookID })?.title ?? "作品")》轉為草稿：\(error.localizedDescription)"
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
    case account = "帳號"
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
        case .account: return "person"
        case .settings: return SailuneSymbol.settings.systemName
        }
    }
}

private struct AccountButtonAnchorPreference: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        if let anchor = nextValue() { value = anchor }
    }
}

private struct StartSidebarView: View {
    @Binding var selection: StartSidebarItem
    let profile: AuthorProfile?
    let isSignedIn: Bool
    let onSelect: (StartSidebarItem) -> Void
    let onToggleAccountPopover: () -> Void

    private var accountCardTitle: String {
        guard isSignedIn else { return "帳號" }
        let penName = profile?.penName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return penName.isEmpty ? "帳號" : penName
    }

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

            Spacer(minLength: 0)

            Button(action: onToggleAccountPopover) {
                HStack(spacing: 9) {
                    SidebarAvatarView(profile: profile)
                    Text(accountCardTitle)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(SailuneTheme.navigationCardSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .anchorPreference(key: AccountButtonAnchorPreference.self, value: .bounds) { $0 }
            .accessibilityLabel("開啟帳號選單，\(accountCardTitle)")
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
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .frame(width: 20, alignment: .center)
                Text(item.rawValue)
            }
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
    let signedInEmail: String?
    let errorMessage: String?
    let onOpenAccount: () -> Void
    let onEmailLogin: () -> Void
    let onSignOut: () -> Void
    let isWorking: Bool
    let onSwitchAccount: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SailuneLayout.spacingXS) {
            accountAction("帳號", systemImage: StartSidebarItem.account.icon, action: onOpenAccount)
            Divider()
            accountAction("登入", systemImage: "envelope", action: onEmailLogin)
                .disabled(signedInEmail != nil || isWorking)
            accountAction("切換帳號", systemImage: "person.2", action: onSwitchAccount)
                .disabled(signedInEmail == nil || isWorking)
            accountAction("登出", systemImage: "rectangle.portrait.and.arrow.right", action: onSignOut)
                .disabled(signedInEmail == nil || isWorking)
            Divider()
            accountAction("設定", systemImage: SailuneSymbol.settings.systemName, action: onOpenSettings)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(SailuneLayout.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accountAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: SailuneLayout.regularControlHeight, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct StartSettingsView: View {
    @Binding var sectionUnit: BookTextSectionMarker

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
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

}

private struct AccountPageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AuthorProfile]
    @Binding var selectedPlan: AccountPlan
    let signedInEmail: String?
    @State private var persistenceError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if let profile = profiles.first {
                    AccountPageForm(profile: profile, selectedPlan: $selectedPlan, signedInEmail: signedInEmail)
                } else {
                    ProgressView()
                }
                if let persistenceError { Text(persistenceError).foregroundStyle(.red) }
            }
            .padding(SailuneLayout.spacingXL)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            guard profiles.isEmpty else { return }
            modelContext.insert(AuthorProfile(penName: "我的筆名"))
            do { try modelContext.save() }
            catch { persistenceError = "無法保存作者資料：\(error.localizedDescription)" }
        }
    }
}

private struct AccountPageForm: View {
    @Bindable var profile: AuthorProfile
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedPlan: AccountPlan
    let signedInEmail: String?
    @State private var persistenceError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SailuneLayout.spacingL) {
            Text("帳號").font(.title2.weight(.semibold))
            HStack(spacing: SailuneLayout.spacingL) {
                SidebarAvatarView(profile: profile)
                Button("加入圖片", systemImage: SailuneSymbol.imageAsset.systemName) { selectAvatar() }
                    .buttonStyle(.borderless)
            }
            VStack(alignment: .leading, spacing: SailuneLayout.spacingS) {
                Text("筆名").font(.headline)
                SailuneFormTextField(title: "筆名", text: $profile.penName)
            }
            VStack(alignment: .leading, spacing: SailuneLayout.spacingS) {
                Text("簡介").font(.headline)
                SailuneAuthorBioEditor(text: Binding(
                    get: { profile.bio ?? "" },
                    set: { profile.bio = $0 }
                ), height: 110, borderColor: Color.primary.opacity(0.12))
            }
            LabeledContent("帳號名稱", value: signedInEmail ?? "尚未登入")
                .textSelection(.enabled)
            Picker("使用方案", selection: $selectedPlan) {
                ForEach(AccountPlan.allCases) { plan in
                    Text(plan.title).tag(plan)
                }
            }
            .pickerStyle(.menu)
            if let persistenceError { Text(persistenceError).foregroundStyle(.red) }
        }
        .onChange(of: profile.penName) { _, _ in saveProfile() }
        .onChange(of: profile.bio) { _, _ in saveProfile() }
        .onChange(of: profile.avatarData) { _, _ in saveProfile() }
    }

    private func saveProfile() {
        profile.updatedAt = .now
        do { try modelContext.save(); persistenceError = nil }
        catch { persistenceError = "無法保存作者資料：\(error.localizedDescription)" }
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

private struct HomeConfirmationPopup: View {
    let title: String
    let message: String
    let confirmTitle: String
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
                Button(confirmTitle, role: .destructive) { onConfirm() }
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

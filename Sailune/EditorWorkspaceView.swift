import SwiftUI
import SwiftData
import AppKit
import OSLog

private let editorCharacterCreationLogger = Logger(subsystem: "com.MooNest.Sailune", category: "EditorCharacterCreation")

private final class EditorKeyboardMonitor {
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.contains(.option) else { return event }
            if event.keyCode == 123 {
                NotificationCenter.default.post(name: .sailunePreviousSection, object: nil)
                return nil
            }
            if event.keyCode == 124 {
                NotificationCenter.default.post(name: .sailuneNextSection, object: nil)
                return nil
            }
            return event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    deinit { stop() }
}

enum EditorWorkspaceMode: String, CaseIterable, Identifiable {
    case writing
    case planning
    case map

    var id: Self { self }

    var title: String {
        switch self {
        case .writing: "編輯"
        case .planning: "大綱"
        case .map: "地圖"
        }
    }

    var systemImage: String {
        switch self {
        case .writing: "text.book.closed"
        case .planning: "rectangle.3.group"
        case .map: "map"
        }
    }
}

// MARK: - 三欄式編輯工作區 (PRD 3.3)
struct EditorWorkspaceView: View {
    private enum Layout {
        static let minimumWorkspaceWidth: CGFloat = 960
        static let minimumWorkspaceHeight: CGFloat = 560
        static let minimumEditorWidth: CGFloat = 360
        static let minimumEditorHeight: CGFloat = 320
        static let inspectorWidth: CGFloat = 300
        static let minimumDirectoryWidth: CGFloat = 220
        static let minimumAISidebarWidth: CGFloat = 260
    }

    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(AbilityProgressStore.self) private var aiAbilityStore
    @Environment(V5SettingsStore.self) private var aiSettingsStore
    @State private var selectedSection: Section?
    @State private var showInspector = false
    @State private var showAIAssistant = false
    @State private var aiChatModel: SailuneAIChatViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var bridge = EditorBridge()
    @State private var showingCommandPalette = false
    @State private var showingShortcutHelp = false
    @State private var keyboardMonitor = EditorKeyboardMonitor()
    @State private var focusedCharacter: Character?
    @State private var characterFocusRequestID = UUID()
    @State private var settingsDestination: EditorSettingsDestination?
    @State private var settingsRequestID = UUID()
    @State private var matchedSettingTarget: EditorSettingsTarget?
    @State private var matchedSettingRequestID = UUID()
    @State private var planningRecordReference: PlanningRecordSourceReference?
    @State private var planningRecordRequestID = UUID()
    @State private var workspaceMode: EditorWorkspaceMode = .writing
    @State private var mapViewport = MapViewport()
    @State private var hasLoadedPlanningWorkspace = false
    @State private var writingColumnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var exportRequest: SailuneExportRequest?

    private var neighboringSections: (previous: Section?, next: Section?) {
        let sections = BookStructure.orderedSections(in: book)
        guard let selectedSection,
              let index = sections.firstIndex(where: { $0.id == selectedSection.id }) else {
            return (nil, nil)
        }
        return (
            index > 0 ? sections[index - 1] : nil,
            index + 1 < sections.count ? sections[index + 1] : nil
        )
    }

    init(book: Book, initialSection: Section) {
        self.book = book
        _selectedSection = State(initialValue: initialSection)
        _aiChatModel = State(initialValue: SailuneAIChatViewModel(
            bookID: book.id,
            store: SailuneAIConversationStore()
        ))
    }

    var body: some View {
        GeometryReader { geometry in
        HStack(spacing: 0) {
            ZStack {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    EditorSidebarView(book: book, selectedSection: $selectedSection, bridge: bridge)
                        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
                } detail: {
                    Group {
                        if workspaceMode == .map {
                            MapWorkspaceView(
                                book: book,
                                viewport: $mapViewport,
                                onOpenPlaceSettings: openPlaceSettings
                            )
                        } else {
                            EditorCenterView(
                                section: selectedSection,
                                bridge: bridge,
                                book: book,
                                onOpenCharacter: { character in
                                    focusedCharacter = character
                                    characterFocusRequestID = UUID()
                                    setInspectorPresented(true)
                                },
                                onOpenSettings: openSettings,
                                onOpenMatchedSetting: { target in
                                    focusedCharacter = nil
                                    settingsDestination = nil
                                    matchedSettingTarget = target
                                    matchedSettingRequestID = UUID()
                                    setInspectorPresented(true)
                                }
                            )
                        }
                    }
                    .frame(minWidth: Layout.minimumEditorWidth, minHeight: Layout.minimumEditorHeight)
                    .toolbar { workspaceToolbar }
                }
                .opacity(workspaceMode == .planning ? 0 : 1)
                .allowsHitTesting(workspaceMode != .planning)
                .accessibilityHidden(workspaceMode == .planning)

                if hasLoadedPlanningWorkspace {
                    BookPlanningWorkspaceView(
                        book: book,
                        onOpenOutlineItem: openOutlineItem,
                        onOpenTimelineSection: openTimelineSection,
                        onOpenPlanningRecord: openPlanningRecord
                    )
                        .opacity(workspaceMode == .planning ? 1 : 0)
                        .allowsHitTesting(workspaceMode == .planning)
                        .accessibilityHidden(workspaceMode != .planning)
                } else if workspaceMode == .planning {
                    ProgressView("整理大綱…")
                }
            }

            if showAIAssistant {
                HStack(spacing: 0) {
                    Divider()
                    SailuneAIChatSidebarView(
                        book: book,
                        model: aiChatModel,
                        onSubmit: submitAISubmission,
                        onClose: { setAIAssistantPresented(false) }
                    )
                    .workspaceFloatingPanel()
                    .frame(width: aiSidebarWidth(for: geometry.size.width))
                }
                .transition(.move(edge: .trailing))
            }

            if showInspector {
                HStack(spacing: 0) {
                    Divider()
                    WorkspaceInspectorView(
                        book: book,
                        currentSection: selectedSection,
                        focusedCharacter: focusedCharacter,
                        focusRequestID: characterFocusRequestID,
                        settingsDestination: settingsDestination,
                        settingsRequestID: settingsRequestID,
                        matchedSettingTarget: matchedSettingTarget,
                        matchedSettingRequestID: matchedSettingRequestID,
                        onMatchedSettingHandled: { requestID in
                            guard matchedSettingRequestID == requestID else { return }
                            matchedSettingTarget = nil
                        },
                        planningRecordReference: planningRecordReference,
                        planningRecordRequestID: planningRecordRequestID,
                        onSelectSection: { section in
                            bridge.flushPendingSave()
                            selectedSection = section
                        },
                        onOpenStoryTag: { tag in
                            guard let section = BookStructure.orderedSections(in: book).first(where: { $0.id == tag.sectionID }) else { return }
                            bridge.flushPendingSave()
                            let offset = tag.resolvedOffset(in: String(section.content.characters))
                            bridge.requestSelect(sectionID: section.id, range: NSRange(location: offset, length: 0))
                            selectedSection = section
                        },
                        onOpenOutlineItem: openOutlineItem
                    )
                    .workspaceFloatingPanel()
                    .frame(width: Layout.inspectorWidth)
                }
                .transition(.move(edge: .trailing))
            }
        }
        }
        .navigationTitle("")
        .frame(minWidth: minimumWorkspaceWidth, minHeight: Layout.minimumWorkspaceHeight)
        .sheet(isPresented: $showingCommandPalette) {
            CommandPaletteView { command in
                showingCommandPalette = false
                perform(command)
            }
        }
        .sheet(isPresented: $showingShortcutHelp) {
            ShortcutHelpView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sailunePreviousSection)) { _ in
            if workspaceMode == .writing { navigate(to: neighboringSections.previous) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sailuneNextSection)) { _ in
            if workspaceMode == .writing { navigate(to: neighboringSections.next) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sailunePlanningMarkersChanged)) { _ in
            bridge.reloadVisibleContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sailuneWillChangeCharacterReferences)) { _ in
            // 名稱同步會直接改寫 Section.content；先提交作者正在輸入的內容，
            // 避免背景同步以較舊的模型內容覆蓋編輯器。
            bridge.flushPendingSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sailuneCharacterReferencesChanged)) { notification in
            guard let sectionIDs = notification.object as? Set<UUID>,
                  let selectedSection,
                  sectionIDs.contains(selectedSection.id) else { return }
            bridge.reloadVisibleContent()
        }
        .onAppear { keyboardMonitor.start() }
        .onDisappear {
            keyboardMonitor.stop()
            aiChatModel.reset()
        }
        .sailuneFileExporter(request: $exportRequest)
    }

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button { showingCommandPalette = true } label: { Label("指令面板", systemImage: "command") }
                    .keyboardShortcut("k", modifiers: .command)
                Button {
                    if let section = selectedSection {
                        let content = ExportManager.exportSectionToTXT(section: section)
                        exportRequest = ExportManager.textExportRequest(defaultName: section.title, content: content)
                    } else {
                        let content = ExportManager.exportBookToTXT(book: book)
                        exportRequest = ExportManager.textExportRequest(defaultName: book.title, content: content)
                    }
                } label: { Label(SailuneActionCopy.exportText, systemImage: SailuneSymbol.exportText.systemName) }
                Button { exportRequest = EpubExporter.exportRequest(book: book) } label: { Label(SailuneActionCopy.exportEpub, systemImage: SailuneSymbol.exportEpub.systemName) }
            } label: { Label("更多", systemImage: SailuneSymbol.more.systemName) }
            ControlGroup {
                Button { switchWorkspace(to: .writing) } label: {
                    Label("編輯", systemImage: EditorWorkspaceMode.writing.systemImage)
                        .foregroundStyle(workspaceMode == .writing ? Color.accentColor : Color.primary)
                }
                .help(SailuneActionCopy.edit)
                Button { setAIAssistantPresented(!showAIAssistant) } label: {
                    Label("AI 助手", systemImage: "sparkles")
                        .foregroundStyle(showAIAssistant ? Color.accentColor : Color.primary)
                }
                .help("顯示／隱藏 AI 助手")
                Button { switchWorkspace(to: .planning) } label: {
                    Label("大綱", systemImage: EditorWorkspaceMode.planning.systemImage)
                        .foregroundStyle(workspaceMode == .planning ? Color.accentColor : Color.primary)
                }
                .help("大綱")
                Button { switchWorkspace(to: .map) } label: {
                    Label("地圖", systemImage: EditorWorkspaceMode.map.systemImage)
                        .foregroundStyle(workspaceMode == .map ? Color.accentColor : Color.primary)
                }
                .help("地圖")
            }
            .labelsHidden()
            Button { setInspectorPresented(!showInspector) } label: {
                Label("設定集", systemImage: SailuneSymbol.settingsSidebar.systemName)
            }
            .help("顯示/隱藏右欄設定集")
        }
    }

    private func toggleSidebar() {
        columnVisibility = (columnVisibility == .detailOnly) ? .automatic : .detailOnly
    }

    private func switchWorkspace(to mode: EditorWorkspaceMode) {
        guard mode != workspaceMode else { return }
        NSApp.keyWindow?.makeFirstResponder(nil)
        bridge.flushPendingSave()

        if mode == .planning {
            if workspaceMode != .planning {
                writingColumnVisibility = columnVisibility
            }
            columnVisibility = .detailOnly
            if !hasLoadedPlanningWorkspace {
                DispatchQueue.main.async { hasLoadedPlanningWorkspace = true }
            }
        } else if workspaceMode == .planning {
            columnVisibility = writingColumnVisibility
        }
        workspaceMode = mode
    }

    private func openOutlineItem(_ item: OutlineItem, _ anchor: OutlineItemAnchor) {
        guard let section = BookStructure.orderedSections(in: book).first(where: { $0.id == anchor.sectionID }) else { return }
        let offset = anchor.resolvedOffset(in: String(section.content.characters))
        switchWorkspace(to: .writing)
        selectedSection = section
        DispatchQueue.main.async {
            bridge.requestSelect(sectionID: section.id, range: NSRange(location: offset, length: 0))
        }
    }

    private func openTimelineSection(_ section: Section) {
        guard BookStructure.orderedSections(in: book).contains(where: { $0.id == section.id }) else { return }
        bridge.flushPendingSave()
        switchWorkspace(to: .writing)
        selectedSection = section
    }

    private func openPlanningRecord(_ reference: PlanningRecordSourceReference) {
        switchWorkspace(to: .writing)
        focusedCharacter = nil
        settingsDestination = nil
        planningRecordReference = reference
        planningRecordRequestID = UUID()
        setInspectorPresented(true)
    }

    private func perform(_ command: PaletteCommand) {
        switch command {
        case .toggleOutline:
            if workspaceMode != .planning { toggleSidebar() }
        case .toggleInspector: setInspectorPresented(!showInspector)
        case .previousSection:
            if workspaceMode == .writing { navigate(to: neighboringSections.previous) }
        case .nextSection:
            if workspaceMode == .writing { navigate(to: neighboringSections.next) }
        case .toggleSceneHeading: bridge.requestToggleHeading()
        case .showShortcuts: showingShortcutHelp = true
        }
    }

    private func navigate(to section: Section?) {
        guard let section else { return }
        bridge.flushPendingSave()
        selectedSection = section
    }

    private func setInspectorPresented(_ presented: Bool) {
        // 右欄切換會改變中央 NSTextView 的可用寬度，先結束文字輸入再滑入／滑出。
        NSApp.keyWindow?.makeFirstResponder(nil)
        if !presented {
            matchedSettingTarget = nil
        }
        withAnimation {
            showInspector = presented
        }
    }

    private func setAIAssistantPresented(_ presented: Bool) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        withAnimation {
            showAIAssistant = presented
        }
    }

    private func aiSidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        min(340, max(Layout.minimumAISidebarWidth, availableWidth * 0.28))
    }

    private var minimumWorkspaceWidth: CGFloat {
        guard showAIAssistant && showInspector else { return Layout.minimumWorkspaceWidth }
        return Layout.minimumDirectoryWidth + Layout.minimumEditorWidth
            + Layout.minimumAISidebarWidth + Layout.inspectorWidth
    }

    private func submitAISubmission(_ submission: SailuneAISubmission) async -> Bool {
        do {
            switch submission {
            case .chat(let prompt):
                let attachment = try SailuneAICharacterContextBuilder.queryAttachment(
                    for: prompt,
                    bookID: book.id,
                    context: modelContext,
                    abilityStore: aiAbilityStore,
                    settingsStore: aiSettingsStore
                )
                return await aiChatModel.sendValidated(prompt: prompt, attachment: attachment)
            case .readQuestion(let prompt, let scope):
                bridge.flushPendingSave()
                let attachment = try SailuneAIAnalysisContextBuilder.readingAttachment(scope: scope, book: book)
                return await aiChatModel.sendValidated(prompt: prompt, attachment: attachment)
            case .summary(let scope):
                bridge.flushPendingSave()
                let attachment = try SailuneAIAnalysisContextBuilder.readingAttachment(
                    scope: scope,
                    book: book,
                    kind: .readingSummary
                )
                return await aiChatModel.sendValidated(prompt: "請依附件正文順序生成摘要。", attachment: attachment)
            case .characterSectionTemplate(let prompt, let selection):
                bridge.flushPendingSave()
                guard let section = BookStructure.orderedSections(in: book).first(where: { $0.id == selection.sectionID }) else {
                    return aiChatModel.rejectUnavailableSection()
                }
                let attachment = try SailuneAICharacterContextBuilder.templateAttachment(
                    selection: selection,
                    section: section,
                    bookID: book.id,
                    context: modelContext
                )
                return await aiChatModel.sendValidated(prompt: prompt, attachment: attachment)
            case .settingAnalysis(let selection):
                bridge.flushPendingSave()
                let attachment = try SailuneAIAnalysisContextBuilder.settingAnalysisAttachment(
                    selection: selection,
                    book: book,
                    context: modelContext,
                    abilityStore: aiAbilityStore,
                    settingsStore: aiSettingsStore
                )
                return await aiChatModel.sendValidated(
                    prompt: "請依附件中所選既有設定維度與正文範圍分析目標。",
                    attachment: attachment
                )
            case .characterComparison(let selection):
                bridge.flushPendingSave()
                let attachment = try SailuneAIAnalysisContextBuilder.characterComparisonAttachment(
                    selection: selection,
                    book: book,
                    context: modelContext,
                    abilityStore: aiAbilityStore,
                    settingsStore: aiSettingsStore
                )
                return await aiChatModel.sendValidated(
                    prompt: "請比較附件中角色既有設定與所選正文範圍。",
                    attachment: attachment
                )
            }
        } catch {
            return aiChatModel.reject(error.localizedDescription)
        }
    }

    private func openSettings(_ destination: EditorSettingsDestination) {
        focusedCharacter = nil
        settingsDestination = destination
        settingsRequestID = UUID()
        setInspectorPresented(true)
    }

    private func openPlaceSettings(_ placeID: UUID) {
        focusedCharacter = nil
        settingsDestination = nil
        matchedSettingTarget = .place(placeID)
        matchedSettingRequestID = UUID()
        setInspectorPresented(true)
    }
}

private enum PaletteCommand: String, CaseIterable, Identifiable {
    case toggleOutline = "顯示／隱藏目錄"
    case toggleInspector = "顯示／隱藏設定集"
    case previousSection = "上一節"
    case nextSection = "下一節"
    case toggleSceneHeading = "切換幕標題"
    case showShortcuts = "開啟快捷鍵說明"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .toggleOutline: return "sidebar.left"
        case .toggleInspector: return "sidebar.right"
        case .previousSection: return "chevron.left"
        case .nextSection: return "chevron.right"
        case .toggleSceneHeading: return "textformat.size"
        case .showShortcuts: return "keyboard"
        }
    }
    var shortcut: String {
        switch self {
        case .toggleOutline: return ""
        case .toggleInspector: return ""
        case .previousSection: return "⌥←"
        case .nextSection: return "⌥→"
        case .toggleSceneHeading: return "⌘2"
        case .showShortcuts: return ""
        }
    }
}

private struct CommandPaletteView: View {
    let onPerform: (PaletteCommand) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var commands: [PaletteCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Array(PaletteCommand.allCases) }
        return PaletteCommand.allCases.filter { $0.rawValue.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: SailuneSymbol.search.systemName).foregroundStyle(.secondary)
                TextField("輸入指令…", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                Button(SailuneActionCopy.cancel) { dismiss() }
                    .buttonStyle(.borderless)
            }
            .padding(14)
            Divider()
            List(commands) { command in
                Button {
                    onPerform(command)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: command.icon).frame(width: 20)
                        Text(command.rawValue)
                        Spacer()
                        if !command.shortcut.isEmpty {
                            Text(command.shortcut).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 5)
            }
            .listStyle(.plain)
        }
        .frame(width: 420, height: 360)
        .onAppear { searchFocused = true }
    }
}

private struct ShortcutHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("快捷鍵").font(.title2.weight(.semibold))
                Spacer()
                Button(SailuneActionCopy.done) { dismiss() }
            }
            Divider()
            shortcut("⌘K", "開啟指令面板")
            shortcut("⌘2", "切換幕標題／內文")
            shortcut("⌘↩", "開啟反白角色資料")
            shortcut("⌥←", "上一節")
            shortcut("⌥→", "下一節")
            Spacer()
        }
        .padding(24)
        .frame(width: 360, height: 260)
    }

    private func shortcut(_ key: String, _ title: String) -> some View {
        HStack {
            Text(key).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
            Text(title)
        }
    }
}

// MARK: - 左欄：目錄
struct EditorSidebarView: View {
    let book: Book
    @Binding var selectedSection: Section?
    let bridge: EditorBridge
    private let dragCoordinateSpace = "editor-outline-drag"
    @Environment(\.modelContext) private var modelContext
    @Environment(StoryPlanningStore.self) private var planningStore

    @State private var collapsedVolumeIDs: Set<UUID> = []
    @State private var renamingID: UUID? = nil
    @State private var renameBuffer: String = ""
    @FocusState private var renameFocused: Bool
    @State private var deleteTarget: DeleteTarget? = nil
    @State private var undoTarget: DeleteTarget? = nil
    @State private var draggingKind: DragKind?
    @State private var outlineRowFrames: [OutlineRowID: CGRect] = [:]
    @State private var outlineDropTarget: OutlineDropTarget?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 頂部全域操作按鈕
            HStack(spacing: 12) {
                Button(action: addVolume) {
                    Label(SailuneActionCopy.addVolume, systemImage: SailuneSymbol.addVolume.systemName)
                }
                .buttonStyle(.borderless)
                .help(SailuneActionCopy.addVolume)
                Button(action: addSection) {
                    Label(SailuneActionCopy.addSection, systemImage: SailuneSymbol.addSection.systemName)
                }
                .buttonStyle(.borderless)
                .help(SailuneActionCopy.addSection)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.workspacePanelBackground)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(book.volumes.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { volume in
                        volumeRow(for: volume)
                        Divider()
                        if !collapsedVolumeIDs.contains(volume.id) {
                            if volume.sections.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("這一卷還沒有節").font(.caption).foregroundStyle(.secondary)
                                    Button(SailuneActionCopy.addFirstSection, systemImage: SailuneSymbol.add.systemName) { addSection(to: volume) }
                                        .buttonStyle(.borderedProminent)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 50).padding(.vertical, 8)
                                Divider()
                            } else {
                                ForEach(volume.sections.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { section in
                                    sectionRow(for: section, in: volume)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .background(Color.workspacePanelBackground)
            .coordinateSpace(name: dragCoordinateSpace)
        }
        .background(Color.workspacePanelBackground)
        .alert("確認刪除",
               isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
               presenting: deleteTarget) { target in
            Button(SailuneActionCopy.cancel, role: .cancel) { }
            Button(SailuneActionCopy.delete, role: .destructive) { performDelete(target) }
        } message: { target in
            switch target {
            case .volume(let v): Text("確定要刪除卷「\(v.title)」嗎？其下所有節將一併刪除，且無法復原。")
            case .section(let s): Text("確定要刪除節「\(s.title)」嗎？此操作無法復原。")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let undoTarget {
                HStack(spacing: 12) {
                    Text(deleteSummary(undoTarget))
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Button(SailuneActionCopy.restore) { restore(undoTarget) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func sectionIndex(for section: Section, in book: Book) -> Int {
        guard let volume = section.volume else { return 1 }
        let sortedSections = volume.sections.sorted { $0.sortOrder < $1.sortOrder }
        if let index = sortedSections.firstIndex(where: { $0.id == section.id }) {
            return index + 1
        }
        return 1
    }

    // MARK: 卷的列 (包含新增的 + 按鈕)
    @ViewBuilder
    private func volumeRow(for volume: Volume) -> some View {
        HStack(spacing: 6) {
            Image(systemName: collapsedVolumeIDs.contains(volume.id) ? "chevron.right" : "chevron.down")
                .font(.caption).foregroundStyle(.secondary).frame(width: 14)
                .contentShape(Rectangle())
                .onTapGesture {
                    commitCurrentRename()
                    toggleVolume(volume.id)
                }
            if renamingID == volume.id {
                renameEditor(commit: { newName in volume.title = newName.isEmpty ? volume.title : newName })
            } else {
                Text(volume.title).lineLimit(1).fontWeight(.semibold)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
                .onTapGesture {
                    commitCurrentRename()
                    toggleVolume(volume.id)
                }
            // 【新增】每個卷後面的 + 按鈕
            Button(action: {
                commitCurrentRename()
                addSection(to: volume)
            }) {
                Image(systemName: SailuneSymbol.add.systemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain) // 使用 plain 避免破壞 List 的選取背景色
                .help(SailuneAccessibilityCopy.addSectionInVolume)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button { startRenaming(id: volume.id, currentName: volume.title) } label: { Label(SailuneActionCopy.rename, systemImage: SailuneSymbol.edit.systemName) }
            Divider()
            Button { addSection(to: volume) } label: { Label(SailuneActionCopy.addSection, systemImage: SailuneSymbol.addSection.systemName) }
            Button(role: .destructive) { deleteTarget = .volume(volume) } label: { Label(SailuneActionCopy.deleteVolume, systemImage: SailuneSymbol.delete.systemName) }
        }
    }

    // MARK: 節的列
    @ViewBuilder
    private func sectionRow(for section: Section, in volume: Volume) -> some View {
        let index = sectionIndex(for: section, in: book)
        HStack(spacing: 6) {
            Image(systemName: SailuneSymbol.reorderHandle.systemName).font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                .frame(width: 24, height: 22).contentShape(Rectangle())
                .highPriorityGesture(outlineDragGesture(for: .section(section.id, volumeID: volume.id)))
            Image(systemName: SailuneSymbol.sectionDocument.systemName).foregroundStyle(.secondary).frame(width: 14)
            if renamingID == section.id {
                renameEditor(commit: { newName in section.title = newName.isEmpty ? section.title : newName })
            } else {
                HStack(spacing: 0) {
                    Text("\(index)｜")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.vertical, 6)
                    Text(section.title)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.vertical, 6)
                    if let annotation = planningStore.annotation(sectionID: section.id),
                       !annotation.plannedOutline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Circle().fill(.green.opacity(0.5)).frame(width: 5, height: 5)
                    }
                    if let annotation = planningStore.annotation(sectionID: section.id),
                       !annotation.revisionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Circle().fill(.orange.opacity(0.6)).frame(width: 5, height: 5)
                    }
                }
            }
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
        }
        .padding(.leading, 20).padding(.trailing, 12).padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .outlineGestureRow(
            id: .section(section.id, volumeID: volume.id),
            coordinateSpace: dragCoordinateSpace,
            dropTarget: outlineDropTarget,
            rowFrames: $outlineRowFrames
        )
        .background(selectedSection?.id == section.id ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            commitCurrentRename()
            selectedSection = section
        }
        .contextMenu {
            Button { startRenaming(id: section.id, currentName: section.title) } label: { Label(SailuneActionCopy.rename, systemImage: SailuneSymbol.edit.systemName) }
            Button {
                commitCurrentRename()
                addSection(to: volume)
            } label: { Label(SailuneActionCopy.addSection, systemImage: SailuneSymbol.addSection.systemName) }
            Divider()
            Button(role: .destructive) { deleteTarget = .section(section) } label: { Label(SailuneActionCopy.deleteSection, systemImage: SailuneSymbol.delete.systemName) }
        }
    }

    @ViewBuilder
    private func renameEditor(commit: @escaping (String) -> Void) -> some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                Text(renameBuffer.isEmpty ? "名稱" : renameBuffer)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.trailing, 12)
                    .opacity(0)
                TextField("", text: $renameBuffer)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                    .focused($renameFocused)
                    .submitLabel(.done)
                    .onAppear { renameFocused = true }
                    .onSubmit { commitAndClose(commit: commit) }
            }
            .frame(minWidth: 60, maxWidth: .infinity)
            Button { commitAndClose(commit: commit) } label: { Image(systemName: SailuneSymbol.confirm.systemName).foregroundStyle(.green) }
                .buttonStyle(.borderless).help(SailuneAccessibilityCopy.confirmEnter)
            Button { cancelRenaming() } label: { Image(systemName: SailuneSymbol.cancel.systemName).foregroundStyle(.secondary) }
                .buttonStyle(.borderless).help(SailuneActionCopy.cancel)
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
        .onChange(of: renameFocused) { _, focused in if !focused { commitAndClose(commit: commit) } }
    }

    private func startRenaming(id: UUID, currentName: String) {
        commitCurrentRename()
        renameBuffer = currentName
        renamingID = id
    }
    private func commitCurrentRename() {
        guard let id = renamingID else { return }
        if let volume = book.volumes.first(where: { $0.id == id }) {
            volume.title = renameBuffer.isEmpty ? volume.title : renameBuffer
        } else if let section = book.volumes.flatMap(\.sections).first(where: { $0.id == id }) {
            section.title = renameBuffer.isEmpty ? section.title : renameBuffer
        }
        renamingID = nil
        renameFocused = false
    }
    private func commitAndClose(commit: (String) -> Void) { commit(renameBuffer); renamingID = nil; renameFocused = false }
    private func cancelRenaming() { renamingID = nil; renameFocused = false }
    private func toggleVolume(_ id: UUID) {
        if collapsedVolumeIDs.contains(id) { collapsedVolumeIDs.remove(id) } else { collapsedVolumeIDs.insert(id) }
    }

    // MARK: 新增邏輯
    private func addVolume() {
        let next = (book.volumes.map(\.sortOrder).max() ?? -1) + 1
        // ⚠️ 若您的 Volume 初始化需要傳入 book，請改為: Volume(title: "新卷", sortOrder: next, book: book)
        let newVolume = Volume(title: "新卷", sortOrder: next)
        book.volumes.append(newVolume)
    }
    private func addSection() {
        let targetVolume: Volume
        if let currentVolume = selectedSection?.volume {
            targetVolume = currentVolume
        } else if let firstVolume = book.volumes.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            targetVolume = firstVolume
        } else {
            let newVolume = Volume(title: "第一卷", sortOrder: 0)
            book.volumes.append(newVolume)
            targetVolume = newVolume
        }
        addSection(to: targetVolume)
    }
    private func addSection(to volume: Volume) {
        let next = (volume.sections.map(\.sortOrder).max() ?? -1) + 1
        let newSection = Section(title: "新節", sortOrder: next, volume: volume)
        volume.sections.append(newSection)
        bridge.flushPendingSave()
        selectedSection = newSection // 自動選取並跳轉至中欄編輯
    }

    // MARK: 拖曳重排
    private func outlineDragGesture(for kind: DragKind) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(dragCoordinateSpace))
            .onChanged { value in
                if draggingKind != kind { draggingKind = kind }
                let nextTarget = dropTarget(for: kind, y: value.location.y)
                if outlineDropTarget != nextTarget { outlineDropTarget = nextTarget }
            }
            .onEnded { _ in
                finishOutlineDrag()
            }
    }

    private func dropTarget(for kind: DragKind, y: CGFloat) -> OutlineDropTarget? {
        guard case .section(let draggedID, let sourceVolumeID) = kind else { return nil }
        for (rowID, frame) in outlineRowFrames where y >= frame.minY && y <= frame.maxY {
            guard case .section(let targetID, let targetVolumeID) = rowID,
                  sourceVolumeID == targetVolumeID,
                  draggedID != targetID else { continue }
            return OutlineDropTarget(rowID: rowID, side: y < frame.midY ? .before : .after)
        }
        return nil
    }

    private func finishOutlineDrag() {
        let kind = draggingKind
        let target = outlineDropTarget
        draggingKind = nil
        outlineDropTarget = nil
        guard case .section(let draggedID, let volumeID) = kind,
              let target,
              case .section(let targetID, let targetVolumeID) = target.rowID,
              volumeID == targetVolumeID,
              let volume = book.volumes.first(where: { $0.id == volumeID }) else { return }

        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.animation = nil
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                moveSection(in: volume, draggedID: draggedID, relativeTo: targetID, side: target.side)
            }
        }
    }

    private func moveSection(in targetVolume: Volume, draggedID: UUID, relativeTo targetID: UUID, side: DropInsertionSide) {
        guard draggedID != targetID else { return }
        var sections = targetVolume.sections.sorted { $0.sortOrder < $1.sortOrder }
        let originalIDs = sections.map(\.id)
        guard let from = sections.firstIndex(where: { $0.id == draggedID }) else { return }
        let item = sections.remove(at: from)
        guard let to = sections.firstIndex(where: { $0.id == targetID }) else { return }
        sections.insert(item, at: side == .before ? to : to + 1)
        guard sections.map(\.id) != originalIDs else { return }
        for (index, section) in sections.enumerated() where section.sortOrder != index {
            section.sortOrder = index
        }
        book.updatedAt = Date()
    }

    // MARK: 刪除與 Fallback
    private func performDelete(_ target: DeleteTarget) {
        undoTarget = target
        switch target {
        case .volume(let v):
            if selectedSection?.volume?.id == v.id {
                selectedSection = findFallbackSectionForDeletedVolume(v, in: book)
            }
            CrossStoreDeletionCoordinator.stageDeleteVolume(v, in: modelContext)
        case .section(let s):
            if selectedSection?.id == s.id {
                selectedSection = findFallbackSection(for: s, in: book)
            }
            CrossStoreDeletionCoordinator.stageDeleteSection(s, in: modelContext)
        }
        deleteTarget = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if undoTarget?.id == target.id {
                do { try CrossStoreDeletionCoordinator.commitStagedDeletion(in: modelContext); undoTarget = nil }
                catch { presentPersistenceError(error) }
            }
        }
    }

    private func deleteSummary(_ target: DeleteTarget) -> String {
        switch target {
        case .volume(let volume): return "已刪除卷「\(volume.title)」"
        case .section(let section): return "已刪除節「\(section.title)」"
        }
    }

    private func restore(_ target: DeleteTarget) {
        switch target {
        case .volume(let volume):
            if !book.volumes.contains(where: { $0.id == volume.id }) {
                volume.book = book
                book.volumes.append(volume)
            }
            modelContext.insert(volume)
        case .section(let section):
            guard let volume = section.volume else { return }
            if !volume.sections.contains(where: { $0.id == section.id }) {
                volume.sections.append(section)
            }
            modelContext.insert(section)
            selectedSection = section
        }
        do { try modelContext.save(); undoTarget = nil }
        catch { modelContext.rollback(); presentPersistenceError(error) }
    }
    private func presentPersistenceError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "目錄資料無法儲存"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
    private func findFallbackSection(for deletedSection: Section, in book: Book) -> Section? {
        let sortedVolumes = book.volumes.sorted { $0.sortOrder < $1.sortOrder }
        guard let currentVolume = deletedSection.volume else { return nil }
        let sortedSections = currentVolume.sections.sorted { $0.sortOrder < $1.sortOrder }
        if let idx = sortedSections.firstIndex(where: { $0.id == deletedSection.id }) {
            if idx > 0 { return sortedSections[idx - 1] }
            if idx < sortedSections.count - 1 { return sortedSections[idx + 1] }
        }
        if let volIdx = sortedVolumes.firstIndex(where: { $0.id == currentVolume.id }) {
            for i in (0..<volIdx).reversed() {
                let prevSections = sortedVolumes[i].sections.sorted { $0.sortOrder < $1.sortOrder }
                if let last = prevSections.last { return last }
            }
            for i in (volIdx + 1)..<sortedVolumes.count {
                let nextSections = sortedVolumes[i].sections.sorted { $0.sortOrder < $1.sortOrder }
                if let first = nextSections.first { return first }
            }
        }
        return nil
    }
    private func findFallbackSectionForDeletedVolume(_ deletedVolume: Volume, in book: Book) -> Section? {
        let sortedVolumes = book.volumes.sorted { $0.sortOrder < $1.sortOrder }
        guard let volIdx = sortedVolumes.firstIndex(where: { $0.id == deletedVolume.id }) else { return nil }
        for i in (0..<volIdx).reversed() {
            let prevSections = sortedVolumes[i].sections.sorted { $0.sortOrder < $1.sortOrder }
            if let last = prevSections.last { return last }
        }
        for i in (volIdx + 1)..<sortedVolumes.count {
            let nextSections = sortedVolumes[i].sections.sorted { $0.sortOrder < $1.sortOrder }
            if let first = nextSections.first { return first }
        }
        return nil
    }
}

// MARK: - 中欄：真編輯器
struct EditorCenterView: View {
    let section: Section?
    let bridge: EditorBridge
    let book: Book
    let onOpenCharacter: (Character) -> Void
    let onOpenSettings: (EditorSettingsDestination) -> Void
    let onOpenMatchedSetting: (EditorSettingsTarget) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(StoryPlanningStore.self) private var planningStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @State private var liveWordCount: Int = 0
    @State private var cursorIsHeading: Bool = false
    @State private var saveState: EditorSaveState = .saved
    @State private var isContentLoading = false
    @State private var selectedText = ""
    @State private var isSelectionGestureInProgress = false
    @State private var lastRoutedSelection: String?
    @AppStorage("sailune.hasShownInlineAutosaveHint") private var hasShownInlineAutosaveHint = false
    @AppStorage("sailune.showCharacterSelectionInfo") private var showCharacterSelectionInfo = true
    @State private var showingInlineAutosaveHint = false
    @State private var activeAnnotation: ChapterAnnotation?
    @State private var planningUndoError: String?
    @FocusState private var titleFieldFocused: Bool
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @Query(sort: \CharacterAlias.createdAt) private var allAliases: [CharacterAlias]
    @Query(sort: \Item.updatedAt, order: .reverse) private var allItems: [Item]
    @Query(sort: \CharacterAbility.createdAt) private var allAbilities: [CharacterAbility]

    private func characterMatch(for text: String) -> Character? {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        var matchesByID: [UUID: Character] = [:]
        for character in allCharacters where
            character.book?.id == book.id &&
            character.realName.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            matchesByID[character.id] = character
        }
        for alias in allAliases where
            alias.character?.book?.id == book.id &&
            alias.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
            if let character = alias.character { matchesByID[character.id] = character }
        }
        guard matchesByID.count == 1 else { return nil }
        return matchesByID.values.first
    }

    private func settingTarget(for selection: String) -> EditorSettingsTarget? {
        let bookCharacters = allCharacters.filter { $0.book?.id == book.id }
        let bookCharacterIDs = Set(bookCharacters.map(\.id))
        var candidates = bookCharacters.map { character in
            let aliases = allAliases
                .filter { $0.character?.id == character.id }
                .map(\.name)
            return EditorSettingsNameCandidate(
                target: .character(character.id),
                names: [character.realName] + aliases
            )
        }

        candidates += allItems
            .filter { $0.book?.id == book.id }
            .map { EditorSettingsNameCandidate(target: .item($0.id), names: [$0.name]) }

        candidates += allAbilities.compactMap { ability in
            let belongsToBook = abilityStore.bookLinks.contains {
                $0.abilityID == ability.id && $0.bookID == book.id
            } || ability.character.map { bookCharacterIDs.contains($0.id) } == true
            guard belongsToBook else { return nil }
            return EditorSettingsNameCandidate(target: .ability(ability.id), names: [ability.name])
        }

        candidates += settingsStore.powers(for: book.id)
            .map { EditorSettingsNameCandidate(target: .power($0.id), names: [$0.name]) }
        candidates += settingsStore.places(for: book.id)
            .map { EditorSettingsNameCandidate(target: .place($0.id), names: [$0.name]) }
        candidates += settingsStore.worldTerms(for: book.id)
            .map { EditorSettingsNameCandidate(target: .worldTerm($0.id), names: [$0.name]) }

        return EditorSettingsMatcher.uniqueMatch(for: selection, candidates: candidates)
    }

    private func characterReference(from text: String) -> CharacterReference? {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("\n") else { return nil }
        let canonicalMatches = allCharacters.filter {
            $0.book?.id == book.id &&
            $0.realName.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        let aliasMatches = allAliases.filter {
            $0.character?.book?.id == book.id &&
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        let matchedCharacterIDs = Set(canonicalMatches.map(\.id) + aliasMatches.compactMap { $0.character?.id })
        guard matchedCharacterIDs.count == 1, let characterID = matchedCharacterIDs.first else { return nil }
        if canonicalMatches.contains(where: { $0.id == characterID }) {
            return CharacterReference(characterID: characterID, source: .canonical)
        }
        let matchingAliases = aliasMatches.filter { $0.character?.id == characterID }
        guard matchingAliases.count == 1 else { return nil }
        return CharacterReference(characterID: characterID, source: .alias(matchingAliases[0].id))
    }

    private func canCreateCharacter(from text: String) -> Bool {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 80, !name.contains("\n") else { return false }
        let hasCanonicalMatch = allCharacters.contains {
            $0.book?.id == book.id &&
            $0.realName.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        let hasAliasMatch = allAliases.contains {
            $0.character?.book?.id == book.id &&
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        return !hasCanonicalMatch && !hasAliasMatch
    }

    private func createCharacter(from text: String) -> CharacterReference? {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canCreateCharacter(from: name) else { return nil }
        let character = Character(realName: name, book: book)
        character.sortOrder = (allCharacters.filter { $0.book?.id == book.id }.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(character)
        do {
            try modelContext.save()
            onOpenCharacter(character)
            return CharacterReference(characterID: character.id, source: .canonical)
        } catch {
            editorCharacterCreationLogger.error("Creating character from editor selection failed: \(String(describing: error), privacy: .private)")
            modelContext.delete(character)
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let section {
                let index = sectionIndex(for: section, in: book)
                HStack(spacing: 4) {
                    Text("第 \(index) 節｜")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            titleFieldFocused = true
                        }
                    TextField("節次標題", text: Binding(
                        get: { section.title },
                        set: { section.title = $0 }
                    ))
                    .font(.system(size: 24, weight: .bold))
                    .textFieldStyle(.plain)
                    .focused($titleFieldFocused)
                    .onKeyPress(.tab) {
                        titleFieldFocused = false
                        bridge.focusEditor()
                        return .handled
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                Divider()
                HStack(alignment: .center, spacing: 8) {
                    Label(cursorIsHeading ? "幕標題" : "內文", systemImage: cursorIsHeading ? "textformat.size" : "text.alignleft")
                        .font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    GeometryReader { viewport in
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                Button { bridge.requestToggleHeading() } label: {
                                    Label("標題", systemImage: "textformat.size").labelStyle(.titleAndIcon)
                                }
                                .buttonStyle(.borderless)
                                .help("將游標所在段落設為幕標題 / 內文 (⌘2)")
                                .keyboardShortcut("2", modifiers: .command)
                                Button {
                                    activeAnnotation = planningStore.ensureAnnotation(sectionID: section.id, bookID: book.id)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "note.text")
                                        if let annotation = planningStore.annotation(sectionID: section.id),
                                           !annotation.plannedOutline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Circle().fill(.green.opacity(0.55)).frame(width: 5, height: 5)
                                        }
                                        if let annotation = planningStore.annotation(sectionID: section.id),
                                           !annotation.revisionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Circle().fill(.orange.opacity(0.65)).frame(width: 5, height: 5)
                                        }
                                    }
                                }
                                .buttonStyle(.borderless)
                                .help("預定大綱與修改註記")
                                .popover(item: $activeAnnotation) { annotation in
                                    SectionAnnotationsPopover(annotation: annotation)
                                }
                                StoryTagMarkerLegendView()
                            }
                            .frame(
                                minWidth: viewport.size.width,
                                minHeight: viewport.size.height,
                                alignment: .trailing
                            )
                        }
                        .scrollIndicators(.hidden)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .layoutPriority(1)
                    Toggle("反白顯示設定集", isOn: $showCharacterSelectionInfo)
                        .toggleStyle(.switch)
                        .font(.caption)
                        .fixedSize()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.appBackground)
                Divider()
                ZStack(alignment: .topLeading) {
                    RichEditorView(
                        section: section,
                        bridge: bridge,
                        onWordCountChange: { liveWordCount = $0 },
                        onHeadingStateChange: { cursorIsHeading = $0 },
                        onSaveStateChange: { saveState = $0 },
                        onEditorFocus: { showingInlineAutosaveHint = false },
                        onLoadingChange: { isContentLoading = $0 },
                        onSelectionTextChange: { selectedText = $0 },
                        onSelectionGestureChange: { isSelectionGestureInProgress = $0 },
                        onOpenSelectedText: { text in
                            guard let character = characterMatch(for: text) else { return false }
                            onOpenCharacter(character)
                            return true
                        },
                        onOpenCharacterReference: { characterID in
                            guard let character = allCharacters.first(where: {
                                $0.book?.id == book.id && $0.id == characterID
                            }) else { return false }
                            onOpenCharacter(character)
                            return true
                        },
                        canCreateCharacter: { canCreateCharacter(from: $0) },
                        onCreateCharacter: { createCharacter(from: $0) },
                        resolveCharacterReference: { characterReference(from: $0) },
                        characterSuggestions: {
                            let characters = allCharacters
                                .filter { $0.book?.id == book.id && !$0.realName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                                .sorted {
                                    if $0.isPinned != $1.isPinned { return $0.isPinned }
                                    return $0.sortOrder < $1.sortOrder
                                }
                            let trueNames = characters.map {
                                    CharacterMentionSuggestion(
                                        id: $0.id,
                                        characterName: $0.realName.trimmingCharacters(in: .whitespacesAndNewlines),
                                        insertionName: $0.realName.trimmingCharacters(in: .whitespacesAndNewlines),
                                        sortOrder: $0.sortOrder,
                                        source: .canonical
                                    )
                                }
                            let aliases = allAliases.compactMap { alias -> CharacterMentionSuggestion? in
                                guard let character = alias.character,
                                      character.book?.id == book.id else { return nil }
                                let aliasName = alias.name.trimmingCharacters(in: .whitespacesAndNewlines)
                                let characterName = character.realName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !aliasName.isEmpty, !characterName.isEmpty else { return nil }
                                return CharacterMentionSuggestion(
                                    id: character.id,
                                    characterName: characterName,
                                    insertionName: aliasName,
                                    sortOrder: character.sortOrder,
                                    source: .alias(alias.id)
                                )
                            }
                            return trueNames + aliases
                        },
                        onOpenSettings: onOpenSettings,
                        onCreateStoryTag: { kind, text, range in
                            // The marker refreshes the editor from the model;
                            // commit first so creating a tag never discards a
                            // just-typed paragraph that is still debouncing.
                            bridge.flushPendingSave()
                            let label = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                            do {
                                if kind.isStructuralOutlineKind {
                                    _ = try planningStore.createOutlineItemFromProse(
                                        kind: kind,
                                        title: label,
                                        anchorText: text,
                                        anchorOffset: range.location,
                                        bookID: book.id,
                                        sectionID: section.id,
                                        sections: BookStructure.orderedSections(in: book)
                                    )
                                } else {
                                    planningStore.createTag(title: label, kind: kind, anchorText: text, anchorOffset: range.location, bookID: book.id, sectionID: section.id)
                                }
                            } catch {
                                saveState = .failed
                            }
                            bridge.reloadVisibleContent()
                        },
                        onContentSaved: { sectionID, prose in
                            try planningStore.reconcileSavedProse(
                                sectionID: sectionID,
                                prose: prose
                            )
                        },
                        planningUndoDelta: { sectionID, prose in
                            planningStore.pendingPlanningUndoDelta(sectionID: sectionID, prose: prose)
                        },
                        applyPlanningUndoDelta: { delta, restoring in
                            try planningStore.applyPlanningUndoDelta(delta, restoring: restoring)
                        },
                        onPlanningUndoError: { restoring, error in
                            planningUndoError = "\(restoring ? "正文、大綱與標籤未能完整復原" : "正文、大綱與標籤未能完整重做")。\n\n\(error.localizedDescription)"
                        },
                        storyTags: { planningStore.tags(sectionID: section.id) },
                        outlineMarkers: { planningStore.outlineMarkers(sectionID: section.id) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isContentLoading && !section.content.characters.isEmpty {
                        ProgressView("載入內容…")
                            .controlSize(.small)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .allowsHitTesting(false)
                    }

                    if showingInlineAutosaveHint && section.content.characters.isEmpty {
                        Text("內容會自動儲存，開始輸入正文…")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary.opacity(0.48))
                            .padding(.leading, 24)
                            .padding(.top, 24)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                Divider()
                HStack {
                    Text(saveState.label)
                        .font(.caption)
                        .foregroundStyle(saveState == .failed ? .red : .secondary)
                    Spacer()
                    Text("\(liveWordCount) 字 · 第 \(index) 節 · \(section.volume?.title ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(Color.appBackground)
            } else {
                ContentUnavailableView("從目錄選擇節，或新增一節開始寫作", systemImage: SailuneSymbol.sectionDocument.systemName)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.appBackground)
        .alert("無法完成這次編輯", isPresented: Binding(
            get: { planningUndoError != nil },
            set: { if !$0 { planningUndoError = nil } }
        )) {
            Button(SailuneActionCopy.acknowledge) { planningUndoError = nil }
        } message: {
            Text(planningUndoError ?? "請再試一次。")
        }
        .onAppear {
            liveWordCount = section?.wordCount ?? 0
            if !hasShownInlineAutosaveHint {
                showingInlineAutosaveHint = true
                hasShownInlineAutosaveHint = true
            }
        }
        .onChange(of: section?.id) {
            liveWordCount = section?.wordCount ?? 0
            saveState = .saved
            selectedText = ""
        }
        .task(id: "\(showCharacterSelectionInfo)|\(isSelectionGestureInProgress)|\(selectedText)") {
            guard showCharacterSelectionInfo else {
                lastRoutedSelection = nil
                return
            }
            guard !isSelectionGestureInProgress else { return }
            let selection = selectedText
            guard !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                lastRoutedSelection = nil
                return
            }
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard !isSelectionGestureInProgress else { return }
            guard let target = settingTarget(for: selection) else {
                lastRoutedSelection = nil
                return
            }
            guard selection != lastRoutedSelection else { return }
            lastRoutedSelection = selection
            onOpenMatchedSetting(target)
        }
    }

    private func sectionIndex(for section: Section, in book: Book) -> Int {
        guard let volume = section.volume else { return 1 }
        let sortedSections = volume.sections.sorted { $0.sortOrder < $1.sortOrder }
        if let index = sortedSections.firstIndex(where: { $0.id == section.id }) {
            return index + 1
        }
        return 1
    }
}

private struct SectionAnnotationsPopover: View {
    @Bindable var annotation: ChapterAnnotation
    @Environment(StoryPlanningStore.self) private var planningStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("章節註記").font(.headline)
            annotationField("預定大綱", color: .green, text: $annotation.plannedOutline, prompt: "這一節預定要發生什麼…")
            annotationField("修改", color: .orange, text: $annotation.revisionNote, prompt: "此節還需要更新或補強什麼…")
        }
        .padding(16)
        .frame(width: 340)
        .onChange(of: annotation.plannedOutline) { _, _ in save() }
        .onChange(of: annotation.revisionNote) { _, _ in save() }
    }

    private func annotationField(_ title: String, color: Color, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: "circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(color.opacity(0.8))
            TextEditor(text: text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(height: 76)
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(prompt).font(.caption).foregroundStyle(.tertiary).padding(11).allowsHitTesting(false)
                    }
                }
        }
    }

    private func save() {
        annotation.updatedAt = Date()
        planningStore.save()
    }
}

private struct StoryTagMarkerLegendView: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(StoryTagMarkerDefinition.allCases) { definition in
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color(nsColor: definition.color))
                        .frame(width: 7, height: 7)
                    Text(definition.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
        }
    }
}

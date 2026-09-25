import SwiftUI
import SwiftData
import AppKit
import OSLog

private let inspectorNavigationLogger = Logger(subsystem: "com.MooNest.Sailune", category: "InspectorNavigation")

struct InspectorLinkedEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
}

struct InspectorLinkedItemsRow: View {
    let title: String
    let entries: [InspectorLinkedEntry]
    let onOpen: (UUID) -> Void

    var body: some View {
        if !entries.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Label(title, systemImage: SailuneSymbol.linkedReference.systemName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(entries) { entry in
                        Button(entry.name) { onOpen(entry.id) }
                            .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - 導航狀態枚舉
enum InspectorRoute: Hashable {
    case list
    case detail(Character)
    case graph(Character)
    case itemDetail(Item, Character?)
    case itemCopyDetail(Item, ItemCopy, Character?)
    case abilityDetail(CharacterAbility)
    case powerDetail(PowerUnit)
    case placeDetail(Place)
    case worldTermDetail(WorldTerm)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .list: hasher.combine(0)
        case .detail(let c): hasher.combine(1); hasher.combine(c.id)
        case .graph(let c): hasher.combine(2); hasher.combine(c.id)
        case .itemDetail(let item, let source): hasher.combine(3); hasher.combine(item.id); hasher.combine(source?.id)
        case .itemCopyDetail(let item, let copy, let source):
            hasher.combine(4); hasher.combine(item.id); hasher.combine(copy.id); hasher.combine(source?.id)
        case .abilityDetail(let ability):
            hasher.combine(5); hasher.combine(ability.id)
        case .powerDetail(let power):
            hasher.combine(6); hasher.combine(power.id)
        case .placeDetail(let place):
            hasher.combine(7); hasher.combine(place.id)
        case .worldTermDetail(let term):
            hasher.combine(8); hasher.combine(term.id)
        }
    }

    static func == (lhs: InspectorRoute, rhs: InspectorRoute) -> Bool {
        switch (lhs, rhs) {
        case (.list, .list): return true
        case (.detail(let a), .detail(let b)): return a.id == b.id
        case (.graph(let a), .graph(let b)): return a.id == b.id
        case (.itemDetail(let a, let sourceA), .itemDetail(let b, let sourceB)):
            return a.id == b.id && sourceA?.id == sourceB?.id
        case (.itemCopyDetail(let itemA, let copyA, let sourceA), .itemCopyDetail(let itemB, let copyB, let sourceB)):
            return itemA.id == itemB.id && copyA.id == copyB.id && sourceA?.id == sourceB?.id
        case (.abilityDetail(let a), .abilityDetail(let b)): return a.id == b.id
        case (.powerDetail(let a), .powerDetail(let b)): return a.id == b.id
        case (.placeDetail(let a), .placeDetail(let b)): return a.id == b.id
        case (.worldTermDetail(let a), .worldTermDetail(let b)): return a.id == b.id
        default: return false
        }
    }
}

// MARK: - 1. 設定集根視圖
private enum InspectorCategorySelection: Hashable, Identifiable {
    case setting(SidebarSettingKey)
    case simpleOutline

    var id: String {
        switch self {
        case .setting(let key): "setting-\(key.rawValue)"
        case .simpleOutline: "simple-outline"
        }
    }
}

struct InspectorRootView: View {
    let book: Book
    let currentSection: Section?
    let focusedCharacter: Character?
    let focusRequestID: UUID
    let settingsDestination: EditorSettingsDestination?
    let settingsRequestID: UUID
    let matchedSettingTarget: EditorSettingsTarget?
    let matchedSettingRequestID: UUID
    let onMatchedSettingHandled: ((UUID) -> Void)?
    let planningRecordReference: PlanningRecordSourceReference?
    let planningRecordRequestID: UUID
    let onSelectSection: ((Section) -> Void)?
    let onOpenStoryTag: ((StoryTag) -> Void)?
    let onOpenOutlineItem: ((OutlineItem, OutlineItemAnchor) -> Void)?
    @State private var selectedTab: InspectorCategorySelection = .setting(.character)
    @State private var outlineTab: SailuneOutlineTab = .narrative
    @State private var showingSidebarSettings = false
    @State private var route: InspectorRoute = .list
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @Query(sort: \Item.updatedAt, order: .reverse) private var allItems: [Item]
    @Query(sort: \CharacterAbility.createdAt) private var allAbilities: [CharacterAbility]

    init(book: Book, currentSection: Section? = nil, focusedCharacter: Character? = nil, focusRequestID: UUID = UUID(), settingsDestination: EditorSettingsDestination? = nil, settingsRequestID: UUID = UUID(), matchedSettingTarget: EditorSettingsTarget? = nil, matchedSettingRequestID: UUID = UUID(), onMatchedSettingHandled: ((UUID) -> Void)? = nil, planningRecordReference: PlanningRecordSourceReference? = nil, planningRecordRequestID: UUID = UUID(), onSelectSection: ((Section) -> Void)? = nil, onOpenStoryTag: ((StoryTag) -> Void)? = nil, onOpenOutlineItem: ((OutlineItem, OutlineItemAnchor) -> Void)? = nil) {
        self.book = book
        self.currentSection = currentSection
        self.focusedCharacter = focusedCharacter
        self.focusRequestID = focusRequestID
        self.settingsDestination = settingsDestination
        self.settingsRequestID = settingsRequestID
        self.matchedSettingTarget = matchedSettingTarget
        self.matchedSettingRequestID = matchedSettingRequestID
        self.onMatchedSettingHandled = onMatchedSettingHandled
        self.planningRecordReference = planningRecordReference
        self.planningRecordRequestID = planningRecordRequestID
        self.onSelectSection = onSelectSection
        self.onOpenStoryTag = onOpenStoryTag
        self.onOpenOutlineItem = onOpenOutlineItem
    }

    var body: some View {
        VStack(spacing: 0) {
            if route == .list {
                HStack(spacing: 8) {
                    ScrollView(.horizontal) {
                        Picker("", selection: $selectedTab) {
                            ForEach(visibleSidebarKeys) { key in
                                Text(key.title).tag(InspectorCategorySelection.setting(key))
                            }
                            Text("簡易版大綱").tag(InspectorCategorySelection.simpleOutline)
                        }
                        .pickerStyle(.segmented)
                    }
                    .scrollIndicators(.hidden)
                    Button { showingSidebarSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.borderless)
                    .help("管理設定集顯示")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()
            }

            switch route {
            case .list:
                if selectedTab == .simpleOutline {
                    SimpleOutlineInspectorView(
                        book: book,
                        onOpenOutlineItem: onOpenOutlineItem,
                        onSelectSection: onSelectSection,
                        outlineTab: $outlineTab
                    )
                } else if visibleSidebarKeys.isEmpty {
                    ContentUnavailableView("尚未顯示設定集", systemImage: SailuneSymbol.settingsSidebar.systemName, description: Text("使用上方的管理設定集重新加入項目。"))
                } else if activeSidebarKey == .character {
                    CharacterListContainerView(
                        book: book,
                        currentSection: currentSection,
                        onSelectSection: onSelectSection,
                        onSelect: { navigate(to: .detail($0)) },
                        onCreated: { navigate(to: .detail($0)) }
                    )
                } else if activeSidebarKey == .ability {
                    AbilityListContainerView(book: book, currentSection: currentSection, onOpen: { navigate(to: .abilityDetail($0)) })
                } else if activeSidebarKey == .power {
                    PowerListView(book: book, currentSection: currentSection, onOpen: { navigate(to: .powerDetail($0)) })
                } else if activeSidebarKey == .item {
                    ItemListContainerView(
                        book: book,
                        currentSection: currentSection,
                        onSelectSection: onSelectSection,
                        onOpen: { navigate(to: .itemDetail($0, nil)) }
                    )
                } else if activeSidebarKey == .storyTag {
                    StoryTagListView(book: book, currentSection: currentSection, onOpen: onOpenStoryTag)
                } else if activeSidebarKey == .place {
                    PlaceListView(book: book, currentSection: currentSection)
                } else if activeSidebarKey == .worldTerm {
                    WorldTermListView(book: book, currentSection: currentSection)
                } else {
                    ContentUnavailableView("設定集項目已隱藏", systemImage: "eye.slash")
                }
            case .detail(let character):
                CharacterDetailView(
                    character: character,
                    book: book,
                    onBack: { navigate(to: .list) },
                    onShowGraph: { navigate(to: .graph(character)) },
                    onOpenItem: { navigate(to: .itemDetail($0, character)) },
                    onOpenAbility: { navigate(to: .abilityDetail($0)) },
                    onSelectSection: onSelectSection
                )
            case .graph(let character):
                KinshipGraphView(
                    character: character,
                    book: book,
                    onBack: { navigate(to: .detail(character)) },
                    onSelectCharacter: { navigate(to: .graph($0)) }
                )
            case .itemDetail(let item, let sourceCharacter):
                ItemDetailView(
                    item: item,
                    book: book,
                    onBack: { navigate(to: sourceCharacter.map(InspectorRoute.detail) ?? .list) },
                    onOpenCopy: { navigate(to: .itemCopyDetail(item, $0, sourceCharacter)) },
                    onSelectSection: onSelectSection
                )
            case .itemCopyDetail(let item, let copy, let sourceCharacter):
                ItemCopyDetailView(
                    item: item,
                    copy: copy,
                    book: book,
                    onBack: { navigate(to: .itemDetail(item, sourceCharacter)) },
                    onOpenCharacter: { navigate(to: .detail($0)) }
                )
            case .abilityDetail(let ability):
                AbilityDetailView(ability: ability, book: book, onBack: { navigate(to: .list) }, onOpenCharacter: { navigate(to: .detail($0)) })
            case .powerDetail(let power):
                PowerDetailView(power: power, book: book, onBack: { navigate(to: .list) })
            case .placeDetail(let place):
                PlaceDetailView(place: place, book: book, onBack: { navigate(to: .list) })
            case .worldTermDetail(let term):
                WorldTermDetailView(term: term, book: book, shouldFocusName: false, onBack: { navigate(to: .list) })
            }
        }
        .sheet(isPresented: $showingSidebarSettings) {
            SidebarSettingsManagerView(book: book)
        }
        .task {
            settingsStore.ensureDefaults(for: book.id)
            selectedTab = .setting(activeSidebarKey)
        }
        .onChange(of: visibleSidebarKeys) { _, keys in
            guard case .setting(let key) = selectedTab else { return }
            selectedTab = .setting(SidebarSettingCatalog.resolvedSelection(key, visibleKeys: keys))
        }
        .onAppear { showFocusedCharacter() }
        .onChange(of: focusedCharacter?.id) { _, _ in showFocusedCharacter() }
        .onChange(of: focusRequestID) { _, _ in showFocusedCharacter() }
        .onAppear { showRequestedSettings() }
        .onChange(of: settingsRequestID) { _, _ in showRequestedSettings() }
        .onAppear { showMatchedSetting() }
        .onChange(of: matchedSettingRequestID) { _, _ in showMatchedSetting() }
        .onAppear { showRequestedPlanningRecord() }
        .onChange(of: planningRecordRequestID) { _, _ in showRequestedPlanningRecord() }
    }

    private var visibleSidebarKeys: [SidebarSettingKey] {
        let rows = settingsStore.sidebarRows(for: book.id)
        let keys = SidebarSettingCatalog.visibleKeys(rows: rows)
        return keys
    }

    private var activeSidebarKey: SidebarSettingKey {
        let key: SidebarSettingKey
        if case .setting(let selectedKey) = selectedTab {
            key = selectedKey
        } else {
            key = .character
        }
        return SidebarSettingCatalog.resolvedSelection(key, visibleKeys: visibleSidebarKeys)
    }

    private func showFocusedCharacter() {
        guard let focusedCharacter else { return }
        selectedTab = .setting(.character)
        navigate(to: .detail(focusedCharacter))
    }

    private func showRequestedSettings() {
        guard let settingsDestination else { return }
        route = .list
        switch settingsDestination {
        case .item:
            selectedTab = .setting(.item)
        case .ability:
            selectedTab = .setting(.ability)
        }
    }

    private func showMatchedSetting() {
        guard let matchedSettingTarget else { return }
        onMatchedSettingHandled?(matchedSettingRequestID)
        let targetKey: SidebarSettingKey
        switch matchedSettingTarget {
        case .character: targetKey = .character
        case .item: targetKey = .item
        case .ability: targetKey = .ability
        case .power: targetKey = .power
        case .place: targetKey = .place
        case .worldTerm: targetKey = .worldTerm
        }
        selectedTab = .setting(visibleSidebarKeys.contains(targetKey) ? targetKey : activeSidebarKey)

        switch matchedSettingTarget {
        case .character(let id):
            guard let character = allCharacters.first(where: { $0.id == id && $0.book?.id == book.id }) else { return }
            navigate(to: .detail(character))
        case .item(let id):
            guard let item = allItems.first(where: { $0.id == id && $0.book?.id == book.id }) else { return }
            navigate(to: .itemDetail(item, nil))
        case .ability(let id):
            guard let ability = allAbilities.first(where: { $0.id == id }) else { return }
            let characterIDs = Set(allCharacters.filter { $0.book?.id == book.id }.map(\.id))
            let belongsToBook = abilityStore.bookLinks.contains { $0.abilityID == id && $0.bookID == book.id }
                || ability.character.map { characterIDs.contains($0.id) } == true
            guard belongsToBook else { return }
            navigate(to: .abilityDetail(ability))
        case .power(let id):
            guard let power = settingsStore.powers(for: book.id).first(where: { $0.id == id }) else { return }
            navigate(to: .powerDetail(power))
        case .place(let id):
            guard let place = settingsStore.places(for: book.id).first(where: { $0.id == id }) else { return }
            navigate(to: .placeDetail(place))
        case .worldTerm(let id):
            guard let term = settingsStore.worldTerms(for: book.id).first(where: { $0.id == id }) else { return }
            navigate(to: .worldTermDetail(term))
        }
    }

    private func showRequestedPlanningRecord() {
        guard let reference = planningRecordReference else { return }
        do {
            switch reference.kind {
            case .organizationJoin, .organizationIdentity:
                break
            case .appearance:
                if let source = try modelContext.fetch(FetchDescriptor<CharacterAppearance>()).first(where: { $0.id == reference.id }),
                   let character = source.character {
                    selectedTab = .setting(.character)
                    navigate(to: .detail(character))
                }
            case .psychology:
                if let source = try modelContext.fetch(FetchDescriptor<CharacterPsychology>()).first(where: { $0.id == reference.id }),
                   let character = source.character {
                    selectedTab = .setting(.character)
                    navigate(to: .detail(character))
                }
            case .characterItemHistory:
                if let owner = try modelContext.fetch(FetchDescriptor<CharacterItem>()).first(where: {
                    $0.history.contains { $0.id == reference.id }
                }), let character = owner.character {
                    selectedTab = .setting(.character)
                    navigate(to: .detail(character))
                }
            case .itemHistory:
                if let item = try modelContext.fetch(FetchDescriptor<Item>()).first(where: {
                    $0.histories.contains { $0.id == reference.id }
                }) {
                    selectedTab = .setting(.item)
                    navigate(to: .itemDetail(item, nil))
                }
            case .itemCopyHistory:
                if let history = copyStore.histories.first(where: { $0.id == reference.id }),
                   let copy = copyStore.copies.first(where: { $0.id == history.copyID }),
                   let item = try modelContext.fetch(FetchDescriptor<Item>()).first(where: { $0.id == copy.itemID }) {
                    selectedTab = .setting(.item)
                    navigate(to: .itemCopyDetail(item, copy, nil))
                }
            case .relationshipHistory:
                if let relationship = try modelContext.fetch(FetchDescriptor<CharacterRelationship>()).first(where: {
                    $0.history.contains { $0.id == reference.id }
                }), let character = relationship.sourceCharacter {
                    selectedTab = .setting(.character)
                    navigate(to: .detail(character))
                }
            case .abilityHistory:
                if let history = abilityStore.histories.first(where: { $0.id == reference.id }),
                   let connection = abilityStore.connections.first(where: { $0.id == history.connectionID }),
                   let ability = try modelContext.fetch(FetchDescriptor<CharacterAbility>()).first(where: { $0.id == connection.abilityID }) {
                    selectedTab = .setting(.ability)
                    navigate(to: .abilityDetail(ability))
                } else if let ability = try modelContext.fetch(FetchDescriptor<CharacterAbility>()).first(where: {
                    $0.history.contains { $0.id == reference.id }
                }) {
                    selectedTab = .setting(.ability)
                    navigate(to: .abilityDetail(ability))
                }
            }
        } catch {
            inspectorNavigationLogger.error("Opening linked inspector entry failed: \(String(describing: error), privacy: .private)")
            route = .list
        }
    }

    /// The center editor and the inspector both host AppKit text views. Replacing
    /// the inspector hierarchy while either text view is first responder can make
    /// AppKit resize both text containers inside the same constraint-update pass.
    /// End editing first, then change routes on the next run-loop turn.
    private func navigate(to destination: InspectorRoute) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                route = destination
            }
        }
    }
}

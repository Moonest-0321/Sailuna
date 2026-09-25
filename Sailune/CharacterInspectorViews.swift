import SwiftUI
import SwiftData

// MARK: - 1b. 列表容器
struct CharacterListContainerView: View {
    let book: Book
    let currentSection: Section?
    let onSelectSection: ((Section) -> Void)?
    let onSelect: (Character) -> Void
    let onCreated: (Character) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @State private var deletionErrorMessage: String?

    private var characters: [Character] {
        allCharacters.filter { $0.book?.id == book.id }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    var body: some View {
            CharacterListView(
            characters: characters,
            currentSection: currentSection,
            onSelect: onSelect,
            onAdd: addCharacter,
            onDelete: { character in
                do {
                    let outcome = try CrossStoreDeletionCoordinator.deleteCharacter(
                        character,
                        in: modelContext,
                        copyStore: copyStore,
                        settingsStore: settingsStore,
                        abilityStore: abilityStore
                    )
                    if outcome.requiresRepair {
                        deletionErrorMessage = "角色已刪除，但勢力成員連結將於下次啟動修復。"
                    }
                } catch {
                    modelContext.rollback()
                    deletionErrorMessage = "角色刪除失敗，資料未變更。"
                }
            }
            )
            .alert(
                "無法刪除角色",
                isPresented: Binding(
                    get: { deletionErrorMessage != nil },
                    set: { if !$0 { deletionErrorMessage = nil } }
                )
            ) {
                Button(SailuneActionCopy.acknowledge, role: .cancel) { deletionErrorMessage = nil }
            } message: {
                Text(deletionErrorMessage ?? "請稍後再試。")
            }
    }

    private func addCharacter() {
        let maxOrder = characters.map(\.sortOrder).max() ?? -1
        let newChar = Character(realName: "新角色", book: book)
        newChar.sortOrder = maxOrder + 1
        modelContext.insert(newChar)
        onCreated(newChar)
    }
}

// MARK: - 2. 列表頁
struct CharacterListView: View {
    let characters: [Character]
    let currentSection: Section?
    let onSelect: (Character) -> Void
    let onAdd: () -> Void
    let onDelete: (Character) -> Void
    @State private var searchText = ""
    @State private var showCurrentSectionOnly = false
    @State private var deleteTarget: Character?
    @Query private var allAliases: [CharacterAlias]
    @Query private var allProfiles: [CharacterProfile]

    private var referencedCharacters: [Character] {
        guard let currentSection else { return [] }
        let linkedIDs = WritingReferenceScanner.linkedCharacterIDs(in: currentSection)
        return characters.filter { character in
            linkedIDs.contains(character.id) ||
                WritingReferenceScanner.contains(character, aliases: allAliases, in: currentSection)
        }
    }

    private func role(for character: Character) -> String {
        allProfiles.first { $0.character?.id == character.id }?.role
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var filteredCharacters: [Character] {
        let source: [Character]
        if showCurrentSectionOnly, let currentSection {
            let linkedIDs = WritingReferenceScanner.linkedCharacterIDs(in: currentSection)
            source = linkedIDs.isEmpty
                ? characters.filter { WritingReferenceScanner.contains($0, aliases: allAliases, in: currentSection) }
                : characters.filter { linkedIDs.contains($0.id) }
        } else {
            source = characters
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return source }
        return source.filter { character in
            character.realName.localizedCaseInsensitiveContains(query) ||
            character.notes?.localizedCaseInsensitiveContains(query) == true ||
            allAliases.contains {
                $0.character?.id == character.id &&
                $0.name.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !referencedCharacters.isEmpty {
                InspectorLinkedItemsRow(
                    title: "本節連結角色",
                    entries: referencedCharacters.map { InspectorLinkedEntry(id: $0.id, name: $0.realName.isEmpty ? "未命名角色" : $0.realName) },
                    onOpen: { id in if let character = characters.first(where: { $0.id == id }) { onSelect(character) } }
                )
            }

            SailuneSearchField(placeholder: "搜尋角色", text: $searchText)

            if currentSection != nil {
                Toggle("只顯示本節相關角色", isOn: $showCurrentSectionOnly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            List {
                if filteredCharacters.isEmpty {
                    EmptyView()
                } else {
                    ForEach(filteredCharacters) { character in
                    CharacterRow(
                        character: character,
                        role: role(for: character),
                        onDelete: { deleteTarget = character }
                    )
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(character) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deleteTarget = character } label: {
                                Label(SailuneActionCopy.delete, systemImage: SailuneSymbol.delete.systemName)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.workspacePanelBackground)

            Divider()
            Button(action: onAdd) {
                Label("新增角色", systemImage: SailuneSymbol.addCircleFilled.systemName)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.accentColor.opacity(0.1))
        }
        .alert(
            "刪除角色？",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            presenting: deleteTarget
        ) { character in
            Button(SailuneActionCopy.cancel, role: .cancel) { deleteTarget = nil }
            Button(SailuneActionCopy.delete, role: .destructive) {
                deleteTarget = nil
                onDelete(character)
            }
        } message: { character in
            Text("將刪除「\(character.realName.isEmpty ? "未命名角色" : character.realName)」的設定、關係與事件關聯；正文文字會保留，但角色連結會解除。此操作無法復原。")
        }
    }
}

struct CharacterRow: View {
    let character: Character
    let role: String
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button { character.isPinned.toggle() } label: {
                Image(systemName: character.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(character.isPinned ? .orange : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(character.realName.isEmpty ? "未命名角色" : character.realName)
                    .font(.body).fontWeight(.medium)
            }
            Spacer()
            if !role.isEmpty {
                Text(role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button(SailuneActionCopy.delete, role: .destructive, action: onDelete)
                .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 3. 詳情頁
struct CharacterDetailView: View {
    @Bindable var character: Character
    let book: Book
    let onBack: () -> Void
    let onShowGraph: () -> Void
    let onOpenItem: (Item) -> Void
    let onOpenAbility: (CharacterAbility) -> Void
    let onSelectSection: ((Section) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Query private var allProfiles: [CharacterProfile]
    @Query private var allAliases: [CharacterAlias]
    @Query private var allAbilities: [CharacterAbility]
    @Query private var allNodes: [Node]
    @Query private var allAppearances: [CharacterAppearance]
    @Query private var allPsychologies: [CharacterPsychology]
    @Query private var allCharacterItems: [CharacterItem]
    @Query private var allItems: [Item]
    @Query private var allRelationships: [CharacterRelationship]
    @Query private var allEvents: [Event]
    @State private var realNameBeforeEditing = ""
    @State private var unlinkedCandidates: [UnlinkedReferenceCandidate] = []
    @State private var unlinkedScanTask: Task<Void, Never>?
    @State private var referenceErrorMessage: String?

    private var profile: CharacterProfile? {
        allProfiles.first { $0.character?.id == character.id }
    }

    private var aliases: [CharacterAlias] { allAliases.filter { $0.character?.id == character.id } }
    private var appearances: [CharacterAppearance] { allAppearances.filter { $0.character?.id == character.id } }
    private var psychologies: [CharacterPsychology] { allPsychologies.filter { $0.character?.id == character.id } }
    private var relationships: [CharacterRelationship] { allRelationships.filter { $0.sourceCharacter?.id == character.id } }
    private var abilityConnections: [CharacterAbilityConnection] {
        abilityStore.connections.filter { $0.characterID == character.id }
    }
    private var itemHoldings: [ItemCopyHolding] {
        copyStore.holdings.filter { $0.characterID == character.id }
    }
    private var timelineEntries: [CharacterTimelineProjection] {
        CharacterTimelineProjectionBuilder.build(
            characterID: character.id,
            abilities: allAbilities,
            abilityConnections: abilityStore.connections,
            abilityHistories: abilityStore.histories,
            abilityLevels: abilityStore.levels,
            nodes: allNodes,
            appearances: allAppearances,
            psychologies: allPsychologies,
            characterItems: allCharacterItems,
            itemCopies: copyStore.copies,
            copyHoldings: copyStore.holdings,
            copyHistories: copyStore.histories,
            items: allItems,
            relationships: allRelationships,
            events: allEvents
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Label("返回列表", systemImage: SailuneSymbol.back.systemName)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(SailuneTheme.controlSurface)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    characterHeader

                    if let referenceErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: SailuneSymbol.warning.systemName)
                                .foregroundStyle(.orange)
                            Text(referenceErrorMessage)
                                .font(.caption)
                                .lineLimit(2)
                            Spacer()
                            Button { self.referenceErrorMessage = nil } label: {
                                Image(systemName: SailuneSymbol.close.systemName)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(9)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }

                    if !unlinkedCandidates.isEmpty {
                        UnlinkedReferenceReviewView(
                            candidates: $unlinkedCandidates,
                            onApply: applySelectedUnlinkedChanges,
                            onDismiss: { unlinkedCandidates = [] }
                        )
                    }

                    CharacterReferenceSectionsView(character: character, book: book, onSelectSection: onSelectSection)

                    staticDetailSection("摘要", systemImage: "text.quote") {
                        CharacterSummarySectionView(character: character)
                    }

                    detailSection("基本資訊", systemImage: "person.text.rectangle", preview: basicInfoSummary) {
                        labeledField("UID") {
                            Text(String(format: "%06d", character.sortOrder + 1))
                                .foregroundStyle(.secondary)
                        }
                        labeledField("性別") {
                            Picker("性別", selection: Binding(
                                get: { character.gender ?? "未設定" },
                                set: { character.gender = ($0 == "未設定") ? nil : $0 }
                            )) {
                                Text("未設定").tag("未設定")
                                Text("男").tag("男")
                                Text("女").tag("女")
                            }
                            .pickerStyle(.segmented)
                        }
                        Divider()
                        BirthDatePickerSection(
                            birthYear: character.birthYear,
                            birthMonth: character.birthMonth,
                            birthDay: character.birthDay,
                            birthSeason: character.birthSeason,
                            setYear: { character.birthYear = $0 },
                            setMonth: { character.birthMonth = $0 },
                            setDay: { character.birthDay = $0 },
                            setSeason: { character.birthSeason = $0 }
                        )
                        .equatable()

                        SailuneFormTextField(title: "出身 (家族/地位)", text: Binding(
                            get: { character.originBackground ?? "" },
                            set: { character.originBackground = $0 }
                        ))

                        Text("來歷").font(.caption).foregroundStyle(.secondary)
                        InsetTextEditor(text: Binding(
                            get: { character.originStory ?? "" },
                            set: { character.originStory = $0 }
                        ), minHeight: 90)
                        textEditorField("私人備註 / 非血緣關係", text: $character.notes)
                    }

                    detailSection("所屬勢力", systemImage: "building.2", preview: latestPowerMembershipPreview) {
                        CharacterPowerMembershipSection(character: character, book: book)
                    }

                    detailSection("別名", systemImage: "person.badge.key", preview: latestAliasPreview) {
                        CharacterAliasSectionView(character: character) { alias, oldName, newName in
                            commitAliasNameChange(alias, from: oldName, to: newName)
                        }
                    }

                    detailSection("能力", systemImage: SailuneSymbol.ability.systemName, preview: latestAbilityPreview) {
                        CharacterAbilitySectionView(character: character, book: book, onOpenAbility: onOpenAbility)
                    }

                    detailSection("外觀", systemImage: "person.crop.rectangle", preview: latestAppearancePreview) {
                        CharacterAppearanceSectionView(character: character, book: book)
                    }

                    detailSection("心理", systemImage: "brain.head.profile", preview: latestPsychologyPreview) {
                        CharacterPsychologySectionView(character: character, book: book)
                    }

                    detailSection("物品", systemImage: SailuneSymbol.item.systemName, preview: latestItemPreview) {
                        CharacterItemSectionView(character: character, book: book, onOpenItem: onOpenItem)
                    }

                    detailSection("關係", systemImage: SailuneSymbol.relationship.systemName, preview: latestRelationshipPreview) {
                        Button(action: onShowGraph) {
                            Label("開啟關係網", systemImage: SailuneSymbol.relationship.systemName)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    detailSection("事件", systemImage: "calendar.badge.clock", preview: latestEventPreview) {
                        CharacterEventSectionView(character: character, book: book)
                    }
                }
                .padding(12)
            }
        }
        .onDisappear { unlinkedScanTask?.cancel() }
    }

    @ViewBuilder
    private var characterHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .leading) {
                if character.realName.isEmpty {
                    Text("角色真名")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .allowsHitTesting(false)
                }
                CompositionAwareTextField(
                    text: $character.realName,
                    placeholder: "角色真名",
                    font: .systemFont(ofSize: 22, weight: .semibold),
                    onEditingChanged: { isEditing in
                        if isEditing {
                            realNameBeforeEditing = character.realName
                        } else {
                            commitNameChange(from: realNameBeforeEditing, to: character.realName, sourceLabel: "真名", updatesLinkedReferences: true)
                        }
                    }
                )
            }
                .frame(minHeight: 32, alignment: .center)
                .padding(.vertical, 2)
                .onAppear {
                    realNameBeforeEditing = character.realName
                }
            TextField("角色定位，例如：男主角", text: roleBinding)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var roleBinding: Binding<String> {
        Binding(
            get: { profile?.role ?? "" },
            set: { newValue in
                if let profile {
                    profile.role = newValue
                } else if !newValue.isEmpty {
                    let created = CharacterProfile(role: newValue, character: character)
                    modelContext.insert(created)
                }
            }
        )
    }

    private func commitNameChange(
        from oldName: String,
        to newName: String,
        sourceLabel: String,
        updatesLinkedReferences: Bool
    ) {
        let old = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard old != new, !old.isEmpty, !new.isEmpty else { return }
        NotificationCenter.default.post(name: .sailuneWillChangeCharacterReferences, object: nil)
        if updatesLinkedReferences {
            do {
                try CharacterReferenceSynchronizer.updateLinkedNames(
                    for: character,
                    from: old,
                    to: new,
                    in: book,
                    context: modelContext
                )
            } catch {
                modelContext.rollback()
                referenceErrorMessage = "角色名稱同步失敗，變更已復原。"
                return
            }
        }
        scheduleUnlinkedScan(from: old, to: new, sourceLabel: sourceLabel)
    }

    private func commitAliasNameChange(_ alias: CharacterAlias, from oldName: String, to newName: String) {
        let old = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let new = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard old != new, !old.isEmpty, !new.isEmpty else { return }
        NotificationCenter.default.post(name: .sailuneWillChangeCharacterReferences, object: nil)
        do {
            try CharacterReferenceSynchronizer.updateLinkedAlias(
                alias,
                from: old,
                to: new,
                in: book,
                context: modelContext
            )
        } catch {
            modelContext.rollback()
            referenceErrorMessage = "別名同步失敗，變更已復原。"
            return
        }
        scheduleUnlinkedScan(from: old, to: new, sourceLabel: "別名")
    }

    private func scheduleUnlinkedScan(from oldName: String, to newName: String, sourceLabel: String) {
        unlinkedScanTask?.cancel()
        unlinkedCandidates.removeAll()
        unlinkedScanTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            let candidates = await CharacterReferenceSynchronizer.unlinkedCandidates(
                from: oldName,
                to: newName,
                sourceLabel: sourceLabel,
                in: book
            )
            guard !Task.isCancelled else { return }
            unlinkedCandidates = candidates
            unlinkedScanTask = nil
        }
    }

    private func applySelectedUnlinkedChanges() {
        do {
            _ = try CharacterReferenceSynchronizer.apply(unlinkedCandidates, in: book, context: modelContext)
            unlinkedCandidates.removeAll()
        } catch {
            modelContext.rollback()
            referenceErrorMessage = "正文名稱替換失敗，內容已復原。"
        }
    }

    @ViewBuilder
    private func detailSection<Content: View>(_ title: String, systemImage: String, preview: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        CollapsibleDetailSection(title: title, systemImage: systemImage, preview: preview, characterID: character.id, content: content)
    }

    private func staticDetailSection<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        StaticCharacterDetailSection(title: title, systemImage: systemImage, content: content)
    }

    private var basicInfoSummary: String {
        let values = [character.gender, character.originBackground]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? "尚未填寫" : values.prefix(2).joined(separator: "・")
    }

    private var latestAliasPreview: String {
        guard let alias = CharacterDetailPreviewOrdering.latest(
            in: aliases,
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        ) else { return "尚無" }
        return nonempty(alias.name, fallback: "未命名別名")
    }

    private var latestPowerMembershipPreview: String {
        guard let membership = settingsStore.members(for: book.id)
            .filter({ $0.characterID == character.id })
            .max(by: { $0.updatedAt < $1.updatedAt }) else { return "尚無" }
        let powerName = settingsStore.powers(for: book.id)
            .first(where: { $0.id == membership.powerID })?.name
        let name = nonempty(powerName, fallback: "未命名勢力")
        let title = membership.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? name : "\(name)・\(title)"
    }

    private var latestAbilityPreview: String {
        guard let connection = CharacterDetailPreviewOrdering.latest(
            in: abilityConnections,
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        ) else { return "尚無" }
        let ability = allAbilities.first { $0.id == connection.abilityID }
        let abilityName = nonempty(ability?.name, fallback: "未命名能力")
        let levelName = connection.currentLevelID.flatMap { levelID in
            abilityStore.levels.first { $0.id == levelID }?.name
        }
        return "\(abilityName)・\(nonempty(levelName, fallback: "未設定"))"
    }

    private var latestAppearancePreview: String {
        guard let appearance = CharacterDetailPreviewOrdering.latest(
            in: appearances,
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        ) else { return "尚無" }
        let kind = appearance.kind == .outfit ? "服裝" : "身體特徵"
        return "\(kind)・\(nonempty(appearance.descriptionText, fallback: "未填寫"))"
    }

    private var latestPsychologyPreview: String {
        guard let psychology = CharacterDetailPreviewOrdering.latest(
            in: psychologies,
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        ) else { return "尚無" }
        let kind: String
        switch psychology.kind {
        case .personality: kind = "性格"
        case .value: kind = "價值觀"
        case .motivation: kind = "動機"
        }
        return "\(kind)・\(nonempty(psychology.content, fallback: "未填寫"))"
    }

    private var latestItemPreview: String {
        guard let holding = CharacterDetailPreviewOrdering.latest(
            in: itemHoldings,
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        ),
        let copy = copyStore.copies.first(where: { $0.id == holding.copyID }),
        let item = allItems.first(where: { $0.id == copy.itemID && $0.book?.id == book.id }) else { return "尚無" }
        return copy.displayName(for: item)
    }

    private var latestRelationshipPreview: String {
        guard let relationship = CharacterDetailPreviewOrdering.latest(
            in: relationships,
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        ) else { return "尚無" }
        let target = nonempty(relationship.targetCharacter?.realName, fallback: "未知角色")
        return "\(target)・\(nonempty(relationship.type, fallback: "未設定"))"
    }

    private var latestEventPreview: String {
        guard let entry = timelineEntries.last else { return "尚無" }
        return "\(entry.source)・\(entry.title)"
    }

    private func nonempty(_ value: String?, fallback: String) -> String {
        guard let value else { return fallback }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(detail).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title).frame(width: 60, alignment: .leading).font(.subheadline)
            content()
        }
    }

    @ViewBuilder
    private func textEditorField(_ title: String, text: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            InsetTextEditor(text: Binding(
                get: { text.wrappedValue ?? "" },
                set: { text.wrappedValue = $0 }
            ), minHeight: 90)
        }
    }

    private func removeKinship(_ kinship: KinshipRelation) {
        if let target = kinship.targetCharacter {
            target.kinships.removeAll { $0.targetCharacter?.id == character.id }
        }
        character.kinships.removeAll { $0.id == kinship.id }
        modelContext.delete(kinship)
    }
}

private struct CharacterPowerMembershipSection: View {
    let character: Character
    let book: Book
    @Environment(V5SettingsStore.self) private var settingsStore
    @State private var errorMessage: String?

    private var powers: [PowerUnit] {
        settingsStore.powers(for: book.id).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
    private var memberships: [PowerMember] {
        settingsStore.members(for: book.id).filter { $0.characterID == character.id }
    }
    private var availablePowers: [PowerUnit] {
        let joinedIDs = Set(memberships.map(\.powerID))
        return powers.filter { !joinedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(memberships) { member in
                HStack(spacing: 7) {
                    Picker("名稱", selection: powerBinding(member)) {
                        ForEach(powers) { power in
                            Text(power.name.isEmpty ? "未命名勢力" : power.name).tag(power.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    SailuneFormTextField(title: "職稱", text: titleBinding(member))
                    Button(SailuneActionCopy.delete, role: .destructive) {
                        settingsStore.removeMember(member, bookID: book.id)
                    }
                    .buttonStyle(.plain)
                }
            }
            Menu {
                ForEach(availablePowers) { power in
                    Button(power.name.isEmpty ? "未命名勢力" : power.name) {
                        addMembership(to: power)
                    }
                }
            } label: {
                Label("新增所屬勢力", systemImage: SailuneSymbol.add.systemName)
            }
            .menuStyle(.borderlessButton)
            .disabled(availablePowers.isEmpty)
        }
        .alert("無法更新所屬勢力", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(SailuneActionCopy.acknowledge, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "請稍後再試。")
        }
    }

    private func powerBinding(_ member: PowerMember) -> Binding<UUID> {
        Binding(
            get: { member.powerID },
            set: { powerID in
                guard let power = powers.first(where: { $0.id == powerID }) else { return }
                do { try settingsStore.moveMember(member, to: power, bookID: book.id) }
                catch { errorMessage = error.localizedDescription }
            }
        )
    }

    private func titleBinding(_ member: PowerMember) -> Binding<String> {
        Binding(
            get: { member.title },
            set: { title in
                do { try settingsStore.updateMember(member, title: title, bookID: book.id) }
                catch { errorMessage = error.localizedDescription }
            }
        )
    }

    private func addMembership(to power: PowerUnit) {
        do {
            try settingsStore.addMember(
                characterID: character.id,
                characterBookID: book.id,
                title: "",
                to: power,
                bookID: book.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CharacterReferenceSectionsView: View {
    let character: Character
    let book: Book
    let onSelectSection: ((Section) -> Void)?
    @Query private var allAliases: [CharacterAlias]
    @AppStorage private var isCollapsed: Bool
    @State private var linkedSections: [Section] = []
    @State private var possibleSections: [Section] = []
    @State private var hasLoadedReferences = false

    init(character: Character, book: Book, onSelectSection: ((Section) -> Void)?) {
        self.character = character
        self.book = book
        self.onSelectSection = onSelectSection
        _isCollapsed = AppStorage(wrappedValue: false, "sailune.characterDetail.\(character.id.uuidString).正文引用.collapsed")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("正文引用", systemImage: SailuneSymbol.linkedReference.systemName)
                    .font(.headline)
                Spacer()
                Button { isCollapsed.toggle() } label: {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isCollapsed ? "展開正文引用" : "收合正文引用")
            }
            if !isCollapsed && hasLoadedReferences && linkedSections.isEmpty && possibleSections.isEmpty {
                Text("尚未在正文中找到此角色")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !isCollapsed {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(linkedSections) { section in
                            sectionButton(section)
                        }
                        if !possibleSections.isEmpty {
                            Text("可能提及")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.top, linkedSections.isEmpty ? 0 : 3)
                            ForEach(possibleSections) { section in
                                sectionButton(section)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
        .task(id: referenceScanID) {
            guard !isCollapsed else { return }
            hasLoadedReferences = false
            let result = await WritingReferenceScanner.categorizedSections(
                for: character,
                aliases: allAliases,
                in: book
            )
            guard !Task.isCancelled else { return }
            linkedSections = result.linked
            possibleSections = result.possible
            hasLoadedReferences = true
        }
    }

    private var referenceScanID: String {
        let latestSectionUpdate = WritingReferenceScanner.allSections(in: book)
            .map(\.updatedAt.timeIntervalSinceReferenceDate)
            .max() ?? 0
        let latestAliasUpdate = allAliases
            .filter { $0.character?.id == character.id }
            .map(\.updatedAt.timeIntervalSinceReferenceDate)
            .max() ?? 0
        return "\(character.id.uuidString)|\(latestSectionUpdate)|\(latestAliasUpdate)|\(character.realName)|\(isCollapsed)"
    }

    private func sectionButton(_ section: Section) -> some View {
        Button("第 \(sectionNumber(section, in: book)) 節｜\(section.title)") {
            onSelectSection?(section)
        }
        .buttonStyle(.link)
        .font(.caption)
        .lineLimit(1)
    }

    private func sectionNumber(_ section: Section, in book: Book) -> Int {
        guard let volume = section.volume else { return 1 }
        return volume.sections.sorted { $0.sortOrder < $1.sortOrder }
            .firstIndex(where: { $0.id == section.id }).map { $0 + 1 } ?? 1
    }
}

private struct StaticCharacterDetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SailuneTheme.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SailuneTheme.characterSectionBorder))
    }
}

private struct CollapsibleDetailSection<Content: View>: View {
    let title: String
    let systemImage: String
    let preview: String
    @ViewBuilder let content: () -> Content
    @AppStorage private var isCollapsed: Bool

    init(title: String, systemImage: String, preview: String, characterID: UUID, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.preview = preview
        self.content = content
        _isCollapsed = AppStorage(
            wrappedValue: true,
            "sailune.characterDetail.\(characterID.uuidString).\(title).collapsed"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button { isCollapsed.toggle() } label: {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 30)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isCollapsed ? "展開\(title)" : "收合\(title)")
            if !isCollapsed {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(SailuneTheme.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SailuneTheme.characterSectionBorder))
    }
}

// MARK: - 3b. 出生年月日 Picker
struct BirthDatePickerSection: View, Equatable {
    let birthYear: String?
    let birthMonth: String?
    let birthDay: String?
    let birthSeason: String?
    let setYear: (String?) -> Void
    let setMonth: (String?) -> Void
    let setDay: (String?) -> Void
    let setSeason: (String?) -> Void

    private static let months = Array(1...12).map { String($0) }
    private static let days = Array(1...31).map { String($0) }

    static func == (lhs: BirthDatePickerSection, rhs: BirthDatePickerSection) -> Bool {
        lhs.birthYear == rhs.birthYear && lhs.birthMonth == rhs.birthMonth &&
        lhs.birthDay == rhs.birthDay && lhs.birthSeason == rhs.birthSeason
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日期").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("年", text: Binding(
                    get: { birthYear ?? "" },
                    set: { newValue in
                        let filtered = newValue.filter(\.isNumber)
                        setYear(filtered.isEmpty ? nil : filtered)
                    }
                ))
                .textFieldStyle(.roundedBorder).frame(width: 80)

                Picker("月", selection: Binding(
                    get: { birthMonth ?? "" },
                    set: { setMonth($0.isEmpty ? nil : $0) }
                )) {
                    Text("月").tag("")
                    ForEach(Self.months, id: \.self) { Text($0).tag($0) }
                }

                Picker("日", selection: Binding(
                    get: { birthDay ?? "" },
                    set: { setDay($0.isEmpty ? nil : $0) }
                )) {
                    Text("日").tag("")
                    ForEach(Self.days, id: \.self) { Text($0).tag($0) }
                }
            }
            SailuneFormTextField(title: "季節 (例: 梅雨季)", text: Binding(
                get: { birthSeason ?? "" },
                set: { setSeason($0) }
            ))
        }
    }
}

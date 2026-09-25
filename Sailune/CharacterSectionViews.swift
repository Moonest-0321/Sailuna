import SwiftUI
import SwiftData
import AppKit

struct CharacterSummarySectionView: View {
    let character: Character
    @Environment(\.modelContext) private var modelContext
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Query private var allSummaries: [CharacterSummary]
    @Query(sort: \CharacterAlias.createdAt) private var allAliases: [CharacterAlias]
    @Query(sort: \CharacterAbility.createdAt) private var allAbilities: [CharacterAbility]
    @Query(sort: \CharacterPsychology.createdAt) private var allPsychologies: [CharacterPsychology]
    @Query(sort: \CharacterRelationship.createdAt) private var allRelationships: [CharacterRelationship]

    private var summary: CharacterSummary? { allSummaries.first { $0.character?.id == character.id } }
    private var aliases: [CharacterAlias] { allAliases.filter { $0.character?.id == character.id } }
    private var abilities: [CharacterAbility] {
        let connectedAbilityIDs = Set(
            abilityStore.connections
                .filter { $0.characterID == character.id }
                .map(\.abilityID)
        )
        return allAbilities.filter {
            $0.character?.id == character.id || connectedAbilityIDs.contains($0.id)
        }
    }
    private var psychologies: [CharacterPsychology] { allPsychologies.filter { $0.character?.id == character.id } }
    private var relationships: [CharacterRelationship] {
        allRelationships.filter {
            $0.sourceCharacter?.id == character.id || $0.targetCharacter?.id == character.id
        }
    }
    private var latestAlias: CharacterAlias? { aliases.max { $0.updatedAt < $1.updatedAt } }
    private var latestAbility: CharacterAbility? { abilities.max { $0.updatedAt < $1.updatedAt } }
    private var latestPsychology: CharacterPsychology? { psychologies.max { $0.updatedAt < $1.updatedAt } }
    private var latestRelationship: CharacterRelationship? { relationships.max { $0.updatedAt < $1.updatedAt } }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            summaryPicker("別名", automaticTitle: automaticTitle(latestAlias?.name), selection: aliasBinding) {
                ForEach(aliases) { Text($0.name).tag(Optional($0.id)) }
            }
            summaryPicker("能力", automaticTitle: automaticTitle(latestAbility?.name), selection: abilityBinding) {
                ForEach(abilities) { Text($0.name).tag(Optional($0.id)) }
            }
            summaryPicker("心理", automaticTitle: automaticTitle(latestPsychology.map(psychologyLabel)), selection: psychologyBinding) {
                ForEach(psychologies) { Text(psychologyLabel($0)).tag(Optional($0.id)) }
            }
            summaryPicker("關係", automaticTitle: automaticTitle(latestRelationship.map(relationshipLabel)), selection: relationshipBinding) {
                ForEach(relationships) { relationship in
                    Text(relationshipLabel(relationship)).tag(Optional(relationship.id))
                }
            }
        }
    }

    private func summaryPicker<Content: View>(_ title: String, automaticTitle: String, selection: Binding<UUID?>, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title).frame(width: 72, alignment: .leading).font(.subheadline)
            Picker(title, selection: selection) {
                Text(automaticTitle).tag(Optional<UUID>.none)
                content()
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func automaticTitle(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "自動" }
        return value
    }

    private func relationshipLabel(_ relationship: CharacterRelationship) -> String {
        let other = relationship.sourceCharacter?.id == character.id
            ? relationship.targetCharacter
            : relationship.sourceCharacter
        return "\(other?.realName ?? "未知角色")・\(relationship.type)"
    }

    private func currentSummary() -> CharacterSummary {
        if let summary { return summary }
        let created = CharacterSummary(character: character)
        modelContext.insert(created)
        return created
    }

    private var aliasBinding: Binding<UUID?> { Binding(get: { summary?.alias?.id }, set: { id in
        updateSummary(createIfNeeded: id != nil) { $0.alias = id.flatMap { selected in aliases.first { $0.id == selected } } }
    }) }
    private var abilityBinding: Binding<UUID?> { Binding(get: { summary?.ability?.id }, set: { id in
        updateSummary(createIfNeeded: id != nil) { $0.ability = id.flatMap { selected in abilities.first { $0.id == selected } } }
    }) }
    private var psychologyBinding: Binding<UUID?> { Binding(get: { summary?.psychology?.id }, set: { id in
        updateSummary(createIfNeeded: id != nil) { $0.psychology = id.flatMap { selected in psychologies.first { $0.id == selected } } }
    }) }
    private var relationshipBinding: Binding<UUID?> { Binding(get: { summary?.relationship?.id }, set: { id in
        updateSummary(createIfNeeded: id != nil) { $0.relationship = id.flatMap { selected in relationships.first { $0.id == selected } } }
    }) }

    private func updateSummary(createIfNeeded: Bool, _ update: (CharacterSummary) -> Void) {
        if let summary {
            update(summary)
            deleteIfEmpty(summary)
        } else if createIfNeeded {
            update(currentSummary())
        }
    }

    private func deleteIfEmpty(_ summary: CharacterSummary) {
        if summary.alias == nil,
           summary.ability == nil,
           summary.psychology == nil,
           summary.relationship == nil {
            modelContext.delete(summary)
        }
    }

    private func psychologyLabel(_ psychology: CharacterPsychology) -> String {
        let type: String
        switch psychology.kind {
        case .personality: type = "性格"
        case .value: type = "價值觀"
        case .motivation: type = "動機"
        }
        return "\(type)・\(psychology.content.isEmpty ? "未填寫" : psychology.content)"
    }
}

struct CharacterSectionEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(detail).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct CharacterAliasSectionView: View {
    let character: Character
    var onRename: (CharacterAlias, String, String) -> Void = { _, _, _ in }
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CharacterAlias.createdAt) private var allAliases: [CharacterAlias]
    @State private var deletionErrorMessage: String?

    private var aliases: [CharacterAlias] { allAliases.filter { $0.character?.id == character.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if aliases.isEmpty {
                CharacterSectionEmptyState(title: "尚無別名", detail: "可加入化名、稱號或其他常用名稱。")
            } else {
                ForEach(aliases) { alias in
                    AliasRow(alias: alias, onRename: onRename, onDelete: { deleteAlias(alias) })
                }
            }
            Button { modelContext.insert(CharacterAlias(name: "新別名", character: character)) } label: {
                Label("新增別名", systemImage: SailuneSymbol.add.systemName)
            }
            .buttonStyle(.borderless)
        }
        .alert(
            "無法刪除別名",
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

    private func deleteAlias(_ alias: CharacterAlias) {
        NotificationCenter.default.post(name: .sailuneWillChangeCharacterReferences, object: nil)
        var changedSectionIDs = Set<UUID>()
        if let book = character.book {
            for section in book.volumes.flatMap(\.sections) {
                let attributed = NSMutableAttributedString(attributedString: NSAttributedString(section.content))
                var ranges: [NSRange] = []
                attributed.enumerateAttribute(.link, in: NSRange(location: 0, length: attributed.length)) { value, range, _ in
                    guard let value,
                          let reference = CharacterReferenceLink.reference(from: value),
                          reference.characterID == character.id,
                          reference.source == .alias(alias.id) else { return }
                    ranges.append(range)
                }
                guard !ranges.isEmpty else { continue }
                let legacyLink = CharacterReferenceLink.url(
                    for: CharacterReference(characterID: character.id, source: .legacy)
                )
                for range in ranges {
                    attributed.addAttribute(.link, value: legacyLink, range: range)
                }
                section.content = AttributedString(attributed)
                section.updatedAt = Date()
                changedSectionIDs.insert(section.id)
            }
            if !changedSectionIDs.isEmpty { book.updatedAt = Date() }
        }
        modelContext.delete(alias)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deletionErrorMessage = "別名刪除失敗，正文與角色資料均未變更。"
            return
        }
        if !changedSectionIDs.isEmpty {
            NotificationCenter.default.post(name: .sailuneCharacterReferencesChanged, object: changedSectionIDs)
        }
    }
}

private struct AliasRow: View {
    @Bindable var alias: CharacterAlias
    let onRename: (CharacterAlias, String, String) -> Void
    let onDelete: () -> Void
    @FocusState private var nameFieldFocused: Bool
    @State private var nameBeforeEditing = ""
    var body: some View {
        HStack {
            TextField("別名", text: $alias.name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFieldFocused)
            SailuneFormTextField(title: "備註", text: $alias.note)
            Button(role: .destructive, action: onDelete) { Image(systemName: SailuneSymbol.delete.systemName) }.buttonStyle(.plain)
        }
        .onAppear { nameBeforeEditing = alias.name }
        .onChange(of: nameFieldFocused) { _, isFocused in
            if isFocused {
                nameBeforeEditing = alias.name
            } else if nameBeforeEditing != alias.name {
                onRename(alias, nameBeforeEditing, alias.name)
            }
        }
        .onChange(of: alias.name) { alias.updatedAt = Date() }
        .onChange(of: alias.note) { alias.updatedAt = Date() }
    }
}

struct CharacterAbilitySectionView: View {
    let character: Character
    let book: Book
    let onOpenAbility: (CharacterAbility) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CharacterAbility.createdAt) private var allAbilities: [CharacterAbility]
    @Environment(AbilityProgressStore.self) private var abilityStore

    private var abilities: [CharacterAbility] { allAbilities.filter { ability in
        abilityStore.bookLinks.contains { $0.abilityID == ability.id && $0.bookID == book.id }
            || ability.character?.book?.id == book.id
    } }
    private var connections: [CharacterAbilityConnection] { abilityStore.connections.filter { $0.characterID == character.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if connections.isEmpty {
                CharacterSectionEmptyState(title: "尚無能力資料", detail: "從下方連接已建立的能力；等級與時間序會只屬於此角色。")
            } else {
                ForEach(connections) { connection in
                    CharacterAbilityConnectionRow(connection: connection, book: book, onOpenAbility: onOpenAbility, onDelete: { abilityStore.deleteConnection(connection) })
                }
            }
            Menu {
                let connectedIDs = Set(connections.map(\.abilityID))
                ForEach(abilities.filter { !connectedIDs.contains($0.id) }) { ability in
                    Button(ability.name.isEmpty ? "未命名能力" : ability.name) {
                        abilityStore.connect(characterID: character.id, abilityID: ability.id)
                    }
                }
            } label: {
                Label("連接能力", systemImage: "link.badge.plus")
            }
            .buttonStyle(.borderless)
            .disabled(abilities.isEmpty)
        }
    }
}

private struct CharacterAbilityConnectionRow: View {
    @Bindable var connection: CharacterAbilityConnection
    let book: Book
    let onOpenAbility: (CharacterAbility) -> Void
    let onDelete: () -> Void
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Query private var allAbilities: [CharacterAbility]
    private var levels: [AbilityLevel] { abilityStore.levels.filter { $0.abilityID == connection.abilityID }.sorted { $0.sortOrder < $1.sortOrder } }
    private var history: [CharacterAbilityHistory] { abilityStore.histories.filter { $0.connectionID == connection.id }.sorted { $0.sortOrder < $1.sortOrder } }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                if let ability = allAbilities.first(where: { $0.id == connection.abilityID }) {
                    Button(ability.name.isEmpty ? "未命名能力" : ability.name) { onOpenAbility(ability) }
                        .buttonStyle(.link)
                } else { Text("未命名能力").fontWeight(.medium) }
                Spacer()
                Button(role: .destructive, action: onDelete) { Image(systemName: SailuneSymbol.delete.systemName) }.buttonStyle(.plain)
            }
            Picker("目前等級", selection: Binding(get: { connection.currentLevelID }, set: { connection.currentLevelID = $0; abilityStore.save() })) {
                Text("未設定").tag(Optional<UUID>.none)
                ForEach(levels) { Text($0.name.isEmpty ? "未命名等級" : $0.name).tag(Optional($0.id)) }
            }
            CharacterAbilityTimelineEditor(connection: connection, book: book, levels: levels, history: history)
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CharacterAbilityTimelineEditor: View {
    let connection: CharacterAbilityConnection
    let book: Book
    let levels: [AbilityLevel]
    let history: [CharacterAbilityHistory]
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Query private var allNodes: [Node]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("時間序").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                @Bindable var entry = entry
                HStack {
                    Picker("變更為", selection: levelBinding(for: entry)) {
                        Text("選擇等級").tag(Optional<UUID>.none)
                        ForEach(levels) { level in
                            Text(level.name.isEmpty ? "未命名等級" : level.name).tag(Optional(level.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 180)
                    if let change = changeLabel(at: index) {
                        Text(change)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(change == "上升" ? .green : change == "下降" ? .orange : .secondary)
                            .frame(width: 34, alignment: .leading)
                    }
                    CharacterTimelinePlacementEditor(
                        book: book,
                        node: Binding(
                            get: { entry.nodeID.flatMap { id in allNodes.first { $0.id == id } } },
                            set: { entry.nodeID = $0?.id; entry.updatedAt = Date(); abilityStore.save() }
                        ),
                        onChange: { entry.updatedAt = Date(); abilityStore.save() }
                    )
                    Button(role: .destructive) { abilityStore.deleteHistory(entry) } label: { Image(systemName: SailuneSymbol.delete.systemName) }.buttonStyle(.plain)
                }
            }
            Button("新增時間序", systemImage: SailuneSymbol.add.systemName) {
                abilityStore.addHistory(connectionID: connection.id)
            }
            .buttonStyle(.borderless)
        }
    }

    private func levelBinding(for entry: CharacterAbilityHistory) -> Binding<UUID?> {
        Binding(
            get: { UUID(uuidString: entry.content) },
            set: { entry.content = $0?.uuidString ?? ""; entry.updatedAt = Date(); abilityStore.save() }
        )
    }

    private func changeLabel(at index: Int) -> String? {
        guard let currentID = UUID(uuidString: history[index].content),
              let current = levels.firstIndex(where: { $0.id == currentID }) else { return nil }
        guard index > 0,
              let previousID = UUID(uuidString: history[index - 1].content),
              let previous = levels.firstIndex(where: { $0.id == previousID }) else { return nil }
        if current > previous { return "上升" }
        if current < previous { return "下降" }
        return "維持"
    }
}

struct CharacterPsychologySectionView: View {
    let character: Character
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CharacterPsychology.createdAt) private var allPsychologies: [CharacterPsychology]
    private var psychologies: [CharacterPsychology] { allPsychologies.filter { $0.character?.id == character.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if psychologies.isEmpty {
                CharacterSectionEmptyState(title: "尚無心理資料", detail: "可新增性格、價值觀與動機。")
            } else {
                ForEach(psychologies) { psychology in PsychologyRow(psychology: psychology, book: book, onDelete: { modelContext.delete(psychology) }) }
            }
            Menu("新增心理資料") {
                Button("性格") { add(.personality) }
                Button("價值觀") { add(.value) }
                Button("動機") { add(.motivation) }
            }.menuStyle(.borderlessButton)
        }
    }

    private func add(_ kind: CharacterPsychologyKind) {
        modelContext.insert(CharacterPsychology(kind: kind, content: "", character: character))
    }
}

private struct PsychologyRow: View {
    @Bindable var psychology: CharacterPsychology
    let book: Book
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Picker("類型", selection: $psychology.kindRawValue) {
                    Text("性格").tag(CharacterPsychologyKind.personality.rawValue)
                    Text("價值觀").tag(CharacterPsychologyKind.value.rawValue)
                    Text("動機").tag(CharacterPsychologyKind.motivation.rawValue)
                }
                .frame(width: 150)

                Spacer(minLength: 0)

                Button(role: .destructive, action: onDelete) {
                    Label("刪除心理資料", systemImage: SailuneSymbol.delete.systemName)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .help("刪除心理資料")
            }

            SailuneFormTextField(title: "內容", text: $psychology.content)

            HStack(spacing: 10) {
                Text("時間定位")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                CharacterTimelinePlacementEditor(book: book, node: $psychology.node) {
                    psychology.updatedAt = Date()
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onChange(of: psychology.kindRawValue) { psychology.updatedAt = Date() }
        .onChange(of: psychology.content) { psychology.updatedAt = Date() }
    }
}

struct CharacterItemSectionView: View {
    let character: Character
    let book: Book
    var onOpenItem: ((Item) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(ItemCopyStore.self) private var copyStore
    @Query(sort: \Item.name) private var allItems: [Item]
    @State private var selectedItemID: UUID?
    private var holdings: [ItemCopyHolding] {
        copyStore.holdings.filter { $0.characterID == character.id }
    }
    private var heldCopies: [ItemCopy] {
        let copyIDs = Set(holdings.map(\.copyID))
        return copyStore.copies.filter { copyIDs.contains($0.id) }.sorted { $0.sortOrder < $1.sortOrder }
    }
    private var bookItems: [Item] {
        allItems.filter { $0.book?.id == book.id }
    }
    private var selectedItem: Item? { selectedItemID.flatMap { id in bookItems.first { $0.id == id } } }
    private var availableCopies: [ItemCopy] {
        guard let selectedItem else { return [] }
        let heldCopyIDs = Set(copyStore.holdings.map(\.copyID))
        return copyStore.copies.filter { $0.itemID == selectedItem.id && !heldCopyIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if heldCopies.isEmpty {
                CharacterSectionEmptyState(title: "尚無持有物品", detail: "每個副本固定計為一件，並擁有獨立名稱與歷史。")
            } else {
                ForEach(heldCopies) { copy in
                    if let item = allItems.first(where: { $0.id == copy.itemID }) {
                        ItemCopyCharacterRow(
                            copy: copy,
                            item: item,
                            onOpenItem: onOpenItem,
                            onRemoveHolder: { removeHolder(from: copy) }
                        )
                    }
                }
            }
            GroupBox("連接既有物品") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("物品名稱", selection: $selectedItemID) {
                        Text("選擇物品").tag(Optional<UUID>.none)
                        ForEach(bookItems) { item in Text(item.name.isEmpty ? "未命名物品" : item.name).tag(Optional(item.id)) }
                    }
                    if selectedItem != nil {
                        Picker("副本", selection: Binding(get: { Optional<UUID>.none }, set: { id in
                            guard let id, let copy = availableCopies.first(where: { $0.id == id }) else { return }
                            copyStore.setHolder(copyID: copy.id, characterID: character.id)
                            selectedItemID = nil
                        })) {
                            Text(availableCopies.isEmpty ? "沒有可連接的副本" : "選擇副本").tag(Optional<UUID>.none)
                            ForEach(availableCopies) { copy in Text(copy.displayName(for: selectedItem!)).tag(Optional(copy.id)) }
                        }
                    }
                    Text("只能連接既有物品與既有副本；建立、命名與改名請到物品設定。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func removeHolder(from copy: ItemCopy) {
        copyStore.setHolder(copyID: copy.id, characterID: nil)
    }
}

private struct ItemCopyCharacterRow: View {
    let copy: ItemCopy
    let item: Item
    let onOpenItem: ((Item) -> Void)?
    let onRemoveHolder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(copy.displayName(for: item)).fontWeight(.medium)
                Spacer()
                if let onOpenItem {
                    Button { onOpenItem(item) } label: {
                        Image(systemName: SailuneSymbol.disclosure.systemName)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("前往物品設定")
                }
                Button(role: .destructive, action: onRemoveHolder) {
                    Image(systemName: SailuneSymbol.removeHolder.systemName)
                }
                .buttonStyle(.plain)
                .help(SailuneActionCopy.removeHolder)
            }
            Text("物品設定：\(item.name.isEmpty ? "未命名物品" : item.name) · 數量 1")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !item.itemDescription.isEmpty {
                Text(item.itemDescription).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }
}

struct CharacterRelationshipSectionView: View {
    let character: Character
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Query private var allRelationships: [CharacterRelationship]
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @State private var selectedTargetID: UUID?

    private var relationships: [CharacterRelationship] { allRelationships.filter { $0.sourceCharacter?.id == character.id } }
    private var targets: [Character] { allCharacters.filter { $0.book?.id == book.id && $0.id != character.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if relationships.isEmpty {
                CharacterSectionEmptyState(title: "尚無一般關係", detail: "關係為單向，同兩人可建立多種關係。")
            } else {
                ForEach(relationships) { relationship in RelationshipRow(relationship: relationship, book: book, onDelete: { modelContext.delete(relationship) }) }
            }
            HStack {
                Picker("目標角色", selection: $selectedTargetID) {
                    Text("選擇角色").tag(Optional<UUID>.none)
                    ForEach(targets) { Text($0.realName.isEmpty ? "未命名" : $0.realName).tag(Optional($0.id)) }
                }
                Button(SailuneActionCopy.addRelationship, action: addRelationship).disabled(selectedTargetID == nil)
            }
        }
    }

    private func addRelationship() {
        guard let selectedTargetID, let target = targets.first(where: { $0.id == selectedTargetID }) else { return }
        guard !allRelationships.contains(where: {
            $0.sourceCharacter?.id == character.id && $0.targetCharacter?.id == target.id
        }) else { return }
        let relationship = CharacterRelationship(type: "朋友", sourceCharacter: character, targetCharacter: target)
        let history = RelationshipHistory(type: "朋友", relationship: relationship)
        relationship.history.append(history)
        modelContext.insert(relationship)
        modelContext.insert(history)
        self.selectedTargetID = nil
    }
}

private struct RelationshipRow: View {
    @Bindable var relationship: CharacterRelationship
    let book: Book
    let onDelete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(relationship.targetCharacter?.realName ?? "未知角色").frame(minWidth: 80, alignment: .leading)
                SailuneFormTextField(title: "關係類型", text: $relationship.type)
                SailuneFormTextField(title: "備註", text: $relationship.note)
                Button(role: .destructive, action: onDelete) { Image(systemName: SailuneSymbol.delete.systemName) }.buttonStyle(.plain)
            }
            RelationshipHistoryEditor(relationship: relationship, book: book)
        }
        .onChange(of: relationship.type) { relationship.updatedAt = Date() }
        .onChange(of: relationship.note) { relationship.updatedAt = Date() }
    }
}

struct CharacterTimelineProjection: Identifiable {
    let id: String
    let source: String
    let title: String
    let node: Node?
    let sortOrder: Int

    var locationLabel: String {
        var parts: [String] = []
        if let node {
            var date = ""
            if node.year > 0 { date += "\(node.year)年" }
            if let month = node.month { date += "\(month)月" }
            if let day = node.day { date += "\(day)日" }
            if !date.isEmpty { parts.append(date) }
            if let volume = node.section?.volume {
                parts.append(volume.title.isEmpty ? "未命名卷" : volume.title)
            }
            if let section = node.section {
                parts.append(section.title.isEmpty ? "未命名節" : section.title)
            }
        }
        return parts.isEmpty ? "未定位" : parts.joined(separator: "・")
    }
}

enum CharacterTimelineProjectionBuilder {
    static func build(
        characterID: UUID,
        abilities: [CharacterAbility],
        abilityConnections: [CharacterAbilityConnection],
        abilityHistories: [CharacterAbilityHistory],
        abilityLevels: [AbilityLevel],
        nodes: [Node],
        appearances: [CharacterAppearance],
        psychologies: [CharacterPsychology],
        characterItems: [CharacterItem],
        itemCopies: [ItemCopy],
        copyHoldings: [ItemCopyHolding],
        copyHistories: [ItemCopyHistory],
        items: [Item],
        relationships: [CharacterRelationship],
        events: [Event]
    ) -> [CharacterTimelineProjection] {
        let abilityByID = Dictionary(uniqueKeysWithValues: abilities.map { ($0.id, $0) })
        let levelByID = Dictionary(uniqueKeysWithValues: abilityLevels.map { ($0.id, $0) })
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let copyByID = Dictionary(uniqueKeysWithValues: itemCopies.map { ($0.id, $0) })
        var result: [CharacterTimelineProjection] = []

        for connection in abilityConnections where connection.characterID == characterID {
            let abilityName = normalized(abilityByID[connection.abilityID]?.name, fallback: "未命名能力")
            for history in abilityHistories where history.connectionID == connection.id {
                let levelName = UUID(uuidString: history.content).flatMap { levelByID[$0]?.name }
                    ?? normalized(history.content, fallback: "未設定")
                result.append(.init(id: "ability-\(history.id)", source: "能力", title: "\(abilityName)・\(levelName)", node: history.nodeID.flatMap { nodeByID[$0] }, sortOrder: history.sortOrder))
            }
        }
        for appearance in appearances where appearance.character?.id == characterID {
            let type = appearance.kind == .outfit ? "服裝" : "身體特徵"
            result.append(.init(id: "appearance-\(appearance.id)", source: "外觀", title: "\(type)・\(normalized(appearance.descriptionText, fallback: "未填寫"))", node: appearance.node, sortOrder: 0))
        }
        for psychology in psychologies where psychology.character?.id == characterID {
            let type: String
            switch psychology.kind { case .personality: type = "性格"; case .value: type = "價值觀"; case .motivation: type = "動機" }
            result.append(.init(id: "psychology-\(psychology.id)", source: "心理", title: "\(type)・\(normalized(psychology.content, fallback: "未填寫"))", node: psychology.node, sortOrder: 0))
        }
        for characterItem in characterItems where characterItem.character?.id == characterID {
            let itemName = normalized(characterItem.item?.name, fallback: "未命名物品")
            for history in characterItem.history {
                result.append(.init(id: "character-item-\(history.id)", source: "物品", title: "\(itemName)・\(normalized(history.content, fallback: "未填寫"))", node: history.node, sortOrder: history.sortOrder))
            }
        }
        let heldCopyIDs = Set(copyHoldings.filter { $0.characterID == characterID }.map(\.copyID))
        for history in copyHistories where heldCopyIDs.contains(history.copyID) || history.relatedCharacterIDs.contains(characterID) {
            guard let copy = copyByID[history.copyID], let item = itemByID[copy.itemID] else { continue }
            result.append(.init(id: "copy-\(history.id)", source: "物品", title: "\(copy.displayName(for: item))・\(normalized(history.content, fallback: "未填寫"))", node: history.nodeID.flatMap { nodeByID[$0] }, sortOrder: history.sortOrder))
        }
        for relationship in relationships where relationship.sourceCharacter?.id == characterID || relationship.targetCharacter?.id == characterID {
            let other = relationship.sourceCharacter?.id == characterID ? relationship.targetCharacter : relationship.sourceCharacter
            for history in relationship.history {
                result.append(.init(id: "relationship-\(history.id)", source: "關係", title: "\(normalized(other?.realName, fallback: "未知角色"))・\(normalized(history.type, fallback: "未設定"))", node: history.node, sortOrder: history.sortOrder))
            }
        }
        for event in events where event.characters.contains(where: { $0.id == characterID }) {
            result.append(.init(id: "event-\(event.id)", source: "事件", title: normalized(event.title, fallback: "未命名事件"), node: event.node, sortOrder: Int(event.sortOrder)))
        }
        return result.filter { $0.node != nil }.sorted { lhs, rhs in
            let lhsDate = lhs.node.map { ($0.year, $0.month ?? 0, $0.day ?? 0) } ?? (Int.max, Int.max, Int.max)
            let rhsDate = rhs.node.map { ($0.year, $0.month ?? 0, $0.day ?? 0) } ?? (Int.max, Int.max, Int.max)
            if lhsDate.0 != rhsDate.0 { return lhsDate.0 < rhsDate.0 }
            if lhsDate.1 != rhsDate.1 { return lhsDate.1 < rhsDate.1 }
            if lhsDate.2 != rhsDate.2 { return lhsDate.2 < rhsDate.2 }
            if lhs.node?.section?.volume?.sortOrder != rhs.node?.section?.volume?.sortOrder {
                return (lhs.node?.section?.volume?.sortOrder ?? Int.max) < (rhs.node?.section?.volume?.sortOrder ?? Int.max)
            }
            if lhs.node?.section?.sortOrder != rhs.node?.section?.sortOrder {
                return (lhs.node?.section?.sortOrder ?? Int.max) < (rhs.node?.section?.sortOrder ?? Int.max)
            }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.id < rhs.id
        }
    }

    private static func normalized(_ value: String?, fallback: String) -> String {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? fallback : text
    }
}

struct CharacterEventSectionView: View {
    let character: Character
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(StoryPlanningStore.self) private var planningStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(ItemCopyStore.self) private var copyStore
    @Query(sort: \Event.sortOrder) private var allEvents: [Event]
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @Query private var allAbilities: [CharacterAbility]
    @Query private var allNodes: [Node]
    @Query private var allAppearances: [CharacterAppearance]
    @Query private var allPsychologies: [CharacterPsychology]
    @Query private var allCharacterItems: [CharacterItem]
    @Query private var allItems: [Item]
    @Query private var allRelationships: [CharacterRelationship]
    @State private var deletionErrorMessage: String?

    private var events: [Event] {
        allEvents.filter { event in
            event.node != nil && event.characters.contains { $0.id == character.id }
        }
    }
    private var bookCharacters: [Character] {
        allCharacters.filter { $0.book?.id == book.id }
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
        VStack(alignment: .leading, spacing: 10) {
            if timelineEntries.isEmpty {
                CharacterSectionEmptyState(title: "尚無事件", detail: "")
            } else {
                ForEach(timelineEntries) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.source)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).lineLimit(2)
                            Text(entry.locationLabel).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            if !events.isEmpty {
                Divider()
                ForEach(events) { event in
                    CharacterEventRow(event: event, character: character, book: book, allCharacters: bookCharacters) { deleteEvent(event) }
                }
            }
            Button(action: addEvent) {
                Label(SailuneActionCopy.addEvent, systemImage: SailuneSymbol.add.systemName)
            }
            .buttonStyle(.borderless)
        }
        .alert("無法刪除事件", isPresented: Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )) { Button(SailuneActionCopy.acknowledge) { deletionErrorMessage = nil } } message: {
            Text(deletionErrorMessage ?? "請稍後再試。")
        }
    }

    private func addEvent() {
        let event = Event(title: "新事件")
        let node = Node(year: 0)
        node.timeline = book.timelines.first(where: \.isPrimary) ?? book.timelines.first
        node.era = book.currentEra
        node.sortOrder = (node.timeline?.nodes.map(\.sortOrder).max() ?? -1) + 1
        event.characters = [character]
        event.node = node
        event.sortOrder = (allEvents.map(\.sortOrder).max() ?? -1) + 1
        modelContext.insert(node)
        modelContext.insert(event)
    }

    private func deleteEvent(_ event: Event) {
        do {
            let outcome = try CrossStoreDeletionCoordinator.deleteEvent(
                event, in: modelContext, planningStore: planningStore
            )
            if outcome.requiresRepair {
                deletionErrorMessage = "事件已刪除，但附屬規劃資料將在下次啟動修復。"
            }
        } catch {
            modelContext.rollback()
            deletionErrorMessage = "事件未刪除。\n\n\(error.localizedDescription)"
        }
    }
}

private struct CharacterEventRow: View {
    @Bindable var event: Event
    let character: Character
    let book: Book
    let allCharacters: [Character]
    let onDelete: () -> Void

    private var relatedCharacters: [Character] {
        event.characters.filter { $0.book?.id == book.id }
    }
    private var availableCharacters: [Character] {
        let relatedIDs = Set(relatedCharacters.map(\.id))
        return allCharacters.filter { !relatedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SailuneFormTextField(title: "事件標題", text: $event.title)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: SailuneSymbol.delete.systemName)
                }
                .buttonStyle(.plain)
            }
            TextField("摘要", text: $event.detail, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                CharacterTimelinePlacementEditor(book: book, node: $event.node)
                Menu {
                    ForEach(availableCharacters) { candidate in
                        Button(candidate.realName.isEmpty ? "未命名角色" : candidate.realName) {
                            event.characters.append(candidate)
                        }
                    }
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .menuStyle(.borderlessButton)
            }
            if relatedCharacters.count > 1 {
                HStack(spacing: 6) {
                    ForEach(relatedCharacters) { related in
                        if related.id == character.id {
                            Text(related.realName.isEmpty ? "未命名角色" : related.realName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button {
                                event.characters.removeAll { $0.id == related.id }
                            } label: {
                                Label(related.realName.isEmpty ? "未命名角色" : related.realName, systemImage: SailuneSymbol.removeRelatedCharacter.systemName)
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }
}

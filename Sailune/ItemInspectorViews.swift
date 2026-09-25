import SwiftUI
import SwiftData
import AppKit

struct ItemListContainerView: View {
    let book: Book
    let currentSection: Section?
    let onSelectSection: ((Section) -> Void)?
    let onOpen: (Item) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Query(sort: \Item.updatedAt, order: .reverse) private var allItems: [Item]
    @Query(sort: \ItemLevel.sortOrder) private var allLevels: [ItemLevel]
    @State private var searchText = ""
    @State private var showCurrentSectionOnly = false
    @State private var showNewItemSheet = false
    @State private var newItemName = ""
    @State private var deleteTarget: Item?
    @State private var deletionErrorMessage: String?

    private var bookItems: [Item] {
        allItems.filter { $0.book?.id == book.id }
    }

    private var referencedItems: [Item] {
        bookItems.filter { InspectorSectionNameMatcher.matches(name: $0.name, in: currentSection) }
    }

    private var items: [Item] {
        let related = showCurrentSectionOnly && currentSection != nil
            ? referencedItems
            : bookItems
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return related }
        return related.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.itemDescription.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorLinkedItemsRow(
                title: "本節連結物品",
                entries: referencedItems.map { InspectorLinkedEntry(id: $0.id, name: $0.name.isEmpty ? "未命名物品" : $0.name) },
                onOpen: { id in if let item = bookItems.first(where: { $0.id == id }) { onOpen(item) } }
            )

            SailuneSearchField(placeholder: "搜尋物品", text: $searchText)

            if currentSection != nil {
                Toggle("只顯示本節相關物品", isOn: $showCurrentSectionOnly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            } else {
                Spacer().frame(height: 10)
            }

            List {
                if !items.isEmpty {
                    ForEach(items) { item in
                        ItemReferenceRow(item: item, onOpen: onOpen, onDelete: { deleteTarget = item })
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.workspacePanelBackground)

            Button("新增物品", systemImage: SailuneSymbol.add.systemName) { showNewItemSheet = true }
            .buttonStyle(.borderedProminent)
            .padding(12)
        }
        .sheet(isPresented: $showNewItemSheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text("新增物品").font(.headline)
                SailuneFormTextField(title: "物品名稱", text: $newItemName)
                HStack {
                    Button(SailuneActionCopy.cancel) { showNewItemSheet = false }
                    Spacer()
                    Button(SailuneActionCopy.create) {
                        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        let item = Item(name: name, book: book)
                        modelContext.insert(item)
                        copyStore.createCopy(itemID: item.id)
                        newItemName = ""
                        showNewItemSheet = false
                        onOpen(item)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(width: 320)
        }
        .confirmationDialog("刪除物品？", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { item in
            Button(SailuneActionCopy.delete, role: .destructive) { delete(item) }
            Button(SailuneActionCopy.cancel, role: .cancel) { deleteTarget = nil }
        }
        .alert("物品刪除未完成", isPresented: Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )) { Button(SailuneActionCopy.acknowledge) { deletionErrorMessage = nil } } message: {
            Text(deletionErrorMessage ?? "")
        }
    }

    private func delete(_ item: Item) {
        do {
            let levels = allLevels.filter { $0.itemID == item.id }
            _ = try CrossStoreDeletionCoordinator.deleteItem(
                item, levels: levels, in: modelContext,
                copyStore: copyStore, settingsStore: settingsStore
            )
            deleteTarget = nil
        } catch {
            modelContext.rollback()
            deletionErrorMessage = error.localizedDescription
        }
    }
}

private struct ItemReferenceRow: View {
    @Bindable var item: Item
    let onOpen: (Item) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { onOpen(item) }) {
                Text(item.name.isEmpty ? "未命名物品" : item.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(SailuneActionCopy.delete, role: .destructive, action: onDelete)
                .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
        .onChange(of: item.name) { item.updatedAt = Date() }
        .onChange(of: item.itemDescription) { item.updatedAt = Date() }
    }

}

struct ItemDetailView: View {
    @Bindable var item: Item
    let book: Book
    let onBack: () -> Void
    let onOpenCopy: (ItemCopy) -> Void
    let onSelectSection: ((Section) -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Query(sort: \ItemLevel.sortOrder) private var allLevels: [ItemLevel]
    @State private var showDeleteConfirmation = false
    @State private var deletionErrorMessage: String?

    private var referencedSections: [Section] {
        WritingReferenceScanner.sections(for: item, in: book)
    }
    private var levels: [ItemLevel] {
        allLevels.filter { $0.itemID == item.id }.sorted { $0.sortOrder < $1.sortOrder }
    }
    private var copies: [ItemCopy] {
        copyStore.copies.filter { $0.itemID == item.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Label(SailuneActionCopy.back, systemImage: SailuneSymbol.back.systemName)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SailuneTheme.controlSurface)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("物品設定", systemImage: SailuneSymbol.item.systemName).font(.headline)
                    GroupBox("物品名稱") {
                        VStack(alignment: .leading, spacing: 8) {
                            SailuneFormTextField(title: "名稱", text: $item.name)
                            if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Label("物品名稱不可空白", systemImage: SailuneSymbol.requirementNotice.systemName)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            SailuneFormTextField(title: "分類（可自由填寫）", text: $item.category)
                        }
                    }
                    itemCopiesSection
                    GroupBox("概要") {
                        itemEditor("物品的整體概念", text: $item.itemDescription, minHeight: 80)
                    }
                    ItemLevelEditor(item: item, levels: levels)
                    GroupBox("外觀與材質") { itemEditor("自由描述外型、材質與辨識特徵", text: $item.appearanceAndMaterial, minHeight: 100) }
                    GroupBox("用途") { itemEditor("物品的使用方式與故事用途", text: $item.usage, minHeight: 90) }
                    GroupBox("正文引用") {
                        if referencedSections.isEmpty { Text("尚未在正文中出現").foregroundStyle(.secondary) }
                        else { ForEach(referencedSections) { section in
                            Button("第 \(sectionNumber(section)) 節｜\(section.title.isEmpty ? "未命名節" : section.title)") { onSelectSection?(section) }.buttonStyle(.link)
                        } }
                    }
                    HStack {
                        Button(SailuneActionCopy.addCopy, systemImage: SailuneSymbol.addCopy.systemName, action: addCopy)
                        Spacer()
                        Button(SailuneActionCopy.deleteItem, systemImage: SailuneSymbol.delete.systemName, role: .destructive) { showDeleteConfirmation = true }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
        }
        .onChange(of: item.name) { item.updatedAt = Date() }
        .onChange(of: item.itemDescription) { item.updatedAt = Date() }
        .onChange(of: item.category) { item.updatedAt = Date() }
        .onChange(of: item.appearanceAndMaterial) { item.updatedAt = Date() }
        .onChange(of: item.usage) { item.updatedAt = Date() }
        .onDisappear {
            if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                item.name = "未命名物品"
            }
        }
        .confirmationDialog("確定刪除「\(item.name)」？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(SailuneActionCopy.deleteItem, role: .destructive, action: deleteItem)
            Button(SailuneActionCopy.cancel, role: .cancel) { }
        } message: {
            Text("所有副本、副本持有人、副本當下等級與副本歷史將一併刪除；正文內容本身會保留。")
        }
        .alert("物品刪除未完成", isPresented: Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )) { Button(SailuneActionCopy.acknowledge) { deletionErrorMessage = nil } } message: {
            Text(deletionErrorMessage ?? "請稍後再試。")
        }
    }

    private var itemCopiesSection: some View {
        GroupBox("副本") {
            VStack(alignment: .leading, spacing: 10) {
                if copies.isEmpty {
                    Text("尚未建立副本").foregroundStyle(.secondary)
                }
                ForEach(Array(copies.enumerated()), id: \.element.id) { index, copy in
                    copyListRow(
                        copy,
                        number: index + 1,
                        canMoveUp: index > 0,
                        canMoveDown: index < copies.count - 1
                    )
                }
                Button(SailuneActionCopy.addCopy, systemImage: SailuneSymbol.addCopy.systemName, action: addCopy)
                    .buttonStyle(.borderless)
            }
        }
    }

    private func copyListRow(
        _ copy: ItemCopy,
        number: Int,
        canMoveUp: Bool,
        canMoveDown: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Button { onOpenCopy(copy) } label: {
                HStack(spacing: 10) {
                    Text("\(number)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    Text(copy.displayName(for: item)).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: SailuneSymbol.disclosure.systemName).foregroundStyle(.tertiary).font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { copyStore.moveCopy(copy, by: -1) } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.plain)
            .disabled(!canMoveUp)
            .help("上移副本")

            Button { copyStore.moveCopy(copy, by: 1) } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.plain)
            .disabled(!canMoveDown)
            .help("下移副本")
        }
    }

    private func itemEditor(_ label: String, text: Binding<String>, minHeight: CGFloat) -> some View { VStack(alignment: .leading, spacing: 4) { Text(label).font(.caption).foregroundStyle(.secondary); InsetTextEditor(text: text, minHeight: minHeight) } }
    private func addCopy() { copyStore.createCopy(itemID: item.id) }
    private func deleteItem() {
        do {
            let outcome = try CrossStoreDeletionCoordinator.deleteItem(
                item, levels: levels, in: modelContext,
                copyStore: copyStore, settingsStore: settingsStore
            )
            if outcome.requiresRepair {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "物品已刪除"
                alert.informativeText = "部分附屬連結將在下次啟動修復。\n\n\(outcome.deferredCleanupErrors.joined(separator: "\n"))"
                alert.addButton(withTitle: "好")
                alert.runModal()
            }
            onBack()
        } catch {
            modelContext.rollback()
            deletionErrorMessage = "物品未刪除。\n\n\(error.localizedDescription)"
        }
    }
    private func sectionNumber(_ section: Section) -> Int { guard let volume = section.volume else { return 1 }; return volume.sections.sorted { $0.sortOrder < $1.sortOrder }.firstIndex(where: { $0.id == section.id }).map { $0 + 1 } ?? 1 }
}

struct ItemCopyDetailView: View {
    let item: Item
    @Bindable var copy: ItemCopy
    let book: Book
    let onBack: () -> Void
    let onOpenCharacter: (Character) -> Void
    @Environment(ItemCopyStore.self) private var copyStore
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @Query(sort: \ItemLevel.sortOrder) private var allLevels: [ItemLevel]
    @Query private var allNodes: [Node]
    @State private var showDeleteConfirmation = false

    private var copyNumber: Int {
        copyStore.copies.filter { $0.itemID == item.id }.sorted { $0.sortOrder < $1.sortOrder }
            .firstIndex(where: { $0.id == copy.id }).map { $0 + 1 } ?? 1
    }
    private var levels: [ItemLevel] { allLevels.filter { $0.itemID == item.id }.sorted { $0.sortOrder < $1.sortOrder } }
    private var histories: [ItemCopyHistory] {
        let nodesByID = Dictionary(uniqueKeysWithValues: allNodes.map { ($0.id, $0) })
        return copyStore.histories
            .filter { $0.copyID == copy.id }
            .sorted { lhs, rhs in
                let lhsNode = lhs.nodeID.flatMap { nodesByID[$0] }
                let rhsNode = rhs.nodeID.flatMap { nodesByID[$0] }
                switch (lhsNode, rhsNode) {
                case let (left?, right?):
                    if TimelineEngine.Query.nodeComesBefore(left, right) { return true }
                    if TimelineEngine.Query.nodeComesBefore(right, left) { return false }
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): break
                }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) { Label("返回物品", systemImage: SailuneSymbol.back.systemName) }.buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(SailuneTheme.controlSurface)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("副本 \(copyNumber)", systemImage: "square.stack.3d.up") .font(.headline)
                    Text("固定使用「\(item.name.isEmpty ? "未命名物品" : item.name)」的共用設定。")
                        .font(.caption).foregroundStyle(.secondary)
                    GroupBox("副本名稱") {
                        SailuneFormTextField(title: "名稱（留空沿用物品名稱）", text: $copy.name)
                            .onChange(of: copy.name) { copy.updatedAt = Date(); copyStore.save() }
                    }
                    GroupBox("所屬者") {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("目前所屬者", selection: holderBinding) {
                                Text("無人持有").tag(Optional<UUID>.none)
                                ForEach(allCharacters.filter { $0.book?.id == book.id }) { character in
                                    Text(character.realName.isEmpty ? "未命名角色" : character.realName).tag(Optional(character.id))
                                }
                            }
                            if let holder = holderBinding.wrappedValue.flatMap({ id in allCharacters.first { $0.id == id } }) {
                                Button(holder.realName.isEmpty ? "未命名角色" : holder.realName) { onOpenCharacter(holder) }
                                    .buttonStyle(.link)
                            }
                        }
                    }
                    GroupBox("當下等級") {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("手動選擇", selection: currentLevelBinding) {
                                Text("未設定").tag(Optional<UUID>.none)
                                ForEach(levels) { level in Text(level.name.isEmpty ? "未命名等級" : level.name).tag(Optional(level.id)) }
                            }
                            Text("僅記錄此副本目前使用的等級，不會自動改變物品名稱、能力、代價或時間序。")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    GroupBox("時間序") { historyEditor }
                    Button(SailuneActionCopy.deleteCopy, systemImage: SailuneSymbol.delete.systemName, role: .destructive) { showDeleteConfirmation = true }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
        }
        .confirmationDialog("確定刪除副本 \(copyNumber)？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(SailuneActionCopy.deleteCopy, role: .destructive) { copyStore.deleteCopy(copy); onBack() }
            Button(SailuneActionCopy.cancel, role: .cancel) { }
        }
    }

    private var holderBinding: Binding<UUID?> { Binding(get: { copyStore.holdings.first(where: { $0.copyID == copy.id })?.characterID }, set: { copyStore.setHolder(copyID: copy.id, characterID: $0) }) }
    private var currentLevelBinding: Binding<UUID?> { Binding(get: { copyStore.currentLevelID(for: copy.id) }, set: { copyStore.setCurrentLevel(copyID: copy.id, levelID: $0) }) }
    private var historyEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            if histories.isEmpty { Text("尚無歷史").font(.caption).foregroundStyle(.secondary) }
            ForEach(histories) { history in
                @Bindable var history = history
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        SailuneFormTextField(title: "發生的事情", text: $history.content)
                        Button(role: .destructive) { copyStore.deleteHistory(history) } label: { Image(systemName: SailuneSymbol.delete.systemName) }.buttonStyle(.plain)
                    }
                    HStack(spacing: 8) {
                        Text("時間定位").font(.caption).foregroundStyle(.secondary)
                        CharacterNodePicker(book: book, node: Binding(get: { history.nodeID.flatMap { id in allNodes.first { $0.id == id } } }, set: { history.nodeID = $0?.id; history.updatedAt = Date(); copyStore.save() }), sourceReference: .init(kind: .itemCopyHistory, id: history.id))
                    }
                    Menu {
                        ForEach(allCharacters.filter { $0.book?.id == book.id }) { character in
                            Button { toggle(character.id, in: history) } label: {
                                history.relatedCharacterIDs.contains(character.id)
                                    ? Label(character.realName.isEmpty ? "未命名角色" : character.realName, systemImage: SailuneSymbol.selected.systemName)
                                    : Label(character.realName.isEmpty ? "未命名角色" : character.realName, systemImage: "")
                            }
                        }
                    } label: { Label(relatedNames(for: history).isEmpty ? "關聯角色" : relatedNames(for: history).joined(separator: "、"), systemImage: SailuneSymbol.relatedCharacters.systemName) }
                }
                .padding(8).background(SailuneTheme.insetRowSurface, in: RoundedRectangle(cornerRadius: 7))
                .onChange(of: history.content) { history.updatedAt = Date(); copyStore.save() }
            }
            Button(SailuneActionCopy.addHistory, systemImage: SailuneSymbol.add.systemName) { copyStore.addHistory(copyID: copy.id) }.buttonStyle(.borderless)
        }
    }
    private func toggle(_ id: UUID, in history: ItemCopyHistory) { var ids = history.relatedCharacterIDs; if let index = ids.firstIndex(of: id) { ids.remove(at: index) } else { ids.append(id) }; history.relatedCharacterIDs = ids; history.updatedAt = Date(); copyStore.save() }
    private func relatedNames(for history: ItemCopyHistory) -> [String] { let ids = Set(history.relatedCharacterIDs); return allCharacters.filter { ids.contains($0.id) }.map { $0.realName.isEmpty ? "未命名角色" : $0.realName } }
}

/// This editor only defines possible stages. It intentionally does not expose
/// a selected/current stage, character-specific stages, or automatic effects.
private struct ItemLevelEditor: View {
    let item: Item
    let levels: [ItemLevel]
    @Environment(\.modelContext) private var modelContext
    @Environment(ItemCopyStore.self) private var copyStore
    @State private var editingLevelIDs: Set<UUID> = []

    var body: some View {
        GroupBox("物品等級") {
            VStack(alignment: .leading, spacing: 10) {
                if levels.isEmpty {
                    Text("尚未建立等級；等級僅作為設定資料，不會套用到持有角色。")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                if !levels.isEmpty {
                    HStack(spacing: 10) {
                        Text("序號").frame(width: 42, alignment: .leading)
                        Text("等級").frame(width: 110, alignment: .leading)
                        Text("概述")
                        Spacer(minLength: 20)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                }
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    ItemLevelRow(
                        level: level,
                        sequenceNumber: index + 1,
                        isEditing: editingBinding(for: level),
                        canMoveUp: index > 0,
                        canMoveDown: index < levels.count - 1,
                        onMoveUp: { move(level, by: -1) },
                        onMoveDown: { move(level, by: 1) },
                        onDelete: { delete(level) }
                    )
                }
                Button(SailuneActionCopy.addLevel, systemImage: SailuneSymbol.add.systemName, action: addLevel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func editingBinding(for level: ItemLevel) -> Binding<Bool> {
        Binding(
            get: { editingLevelIDs.contains(level.id) },
            set: { isEditing in
                if isEditing { editingLevelIDs.insert(level.id) }
                else { editingLevelIDs.remove(level.id) }
            }
        )
    }

    private func addLevel() {
        let level = ItemLevel(
            itemID: item.id,
            sortOrder: (levels.map(\.sortOrder).max() ?? -1) + 1,
            name: "新等級"
        )
        modelContext.insert(level)
        editingLevelIDs.insert(level.id)
    }

    private func delete(_ level: ItemLevel) {
        editingLevelIDs.remove(level.id)
        copyStore.clearCurrentLevelSelections(levelID: level.id)
        modelContext.delete(level)
    }

    private func move(_ level: ItemLevel, by offset: Int) {
        guard let source = levels.firstIndex(where: { $0.id == level.id }) else { return }
        let destination = source + offset
        guard levels.indices.contains(destination) else { return }
        let other = levels[destination]
        let order = level.sortOrder
        level.sortOrder = other.sortOrder
        other.sortOrder = order
        level.updatedAt = Date()
        other.updatedAt = Date()
    }
}

private struct ItemLevelRow: View {
    @Bindable var level: ItemLevel
    let sequenceNumber: Int
    @Binding var isEditing: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            if isEditing {
                editor
            } else {
                summary
            }
        }
        .onChange(of: level.name) { level.updatedAt = Date() }
        .onChange(of: level.itemName) { level.updatedAt = Date() }
        .onChange(of: level.ability) { level.updatedAt = Date() }
        .onChange(of: level.cost) { level.updatedAt = Date() }
        .onChange(of: level.note) { level.updatedAt = Date() }
        .onDisappear {
            if level.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                level.name = "未命名等級"
            }
        }
    }

    private var summary: some View {
        Button {
            isEditing = true
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(String(format: "%02d", sequenceNumber))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .leading)
                Text(displayName)
                    .fontWeight(.medium)
                    .frame(width: 110, alignment: .leading)
                Text(level.compactOverview)
                    .foregroundStyle(level.compactOverview == "尚未填寫概述" ? .tertiary : .secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: SailuneSymbol.disclosure.systemName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("序號 \(sequenceNumber)，等級 \(displayName)，概述 \(level.compactOverview)")
        .accessibilityHint("點擊進入編輯畫面")
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("序號 \(String(format: "%02d", sequenceNumber))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(SailuneActionCopy.done, action: finishEditing)
                    .buttonStyle(.borderedProminent)
            }
            HStack {
                SailuneFormTextField(title: "等級名稱（必填）", text: $level.name)
                Button(action: onMoveUp) { Image(systemName: "arrow.up") }.buttonStyle(.plain).disabled(!canMoveUp)
                Button(action: onMoveDown) { Image(systemName: "arrow.down") }.buttonStyle(.plain).disabled(!canMoveDown)
                Button(role: .destructive, action: onDelete) { Image(systemName: SailuneSymbol.delete.systemName) }.buttonStyle(.plain)
            }
            if level.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("等級名稱不可空白", systemImage: SailuneSymbol.requirementNotice.systemName)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            SailuneFormTextField(title: "物品名稱（選填）", text: $level.itemName)
            levelEditor("能力", text: $level.ability)
            levelEditor("代價", text: $level.cost)
            levelEditor("其他", text: $level.note)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func finishEditing() {
        if level.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            level.name = "未命名等級"
        }
        isEditing = false
    }

    private var displayName: String {
        let trimmed = level.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名等級" : trimmed
    }

    private func levelEditor(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            InsetTextEditor(text: text, minHeight: 56)
        }
    }
}

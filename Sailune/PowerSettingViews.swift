import SwiftUI
import SwiftData

struct PowerListView: View {
    let book: Book
    let currentSection: Section?
    let onOpen: (PowerUnit) -> Void
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @State private var searchText = ""
    @State private var showCurrentSectionOnly = false
    @State private var showingLevels = false
    @State private var deleteTarget: PowerUnit?

    private var levels: [PowerLevel] { settingsStore.levels(for: book.id) }
    private var allPowers: [PowerUnit] {
        settingsStore.powers(for: book.id)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var referencedPowers: [PowerUnit] {
        allPowers.filter { InspectorSectionNameMatcher.matches(name: $0.name, in: currentSection) }
    }
    private var powers: [PowerUnit] {
        let source = showCurrentSectionOnly && currentSection != nil ? referencedPowers : allPowers
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return source.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorLinkedItemsRow(
                title: "本節連結勢力",
                entries: referencedPowers.map { InspectorLinkedEntry(id: $0.id, name: $0.name.isEmpty ? "未命名勢力" : $0.name) },
                onOpen: { id in if let power = allPowers.first(where: { $0.id == id }) { onOpen(power) } }
            )
            SailuneSearchField(placeholder: "搜尋勢力", text: $searchText)
            if currentSection != nil {
                Toggle("只顯示本節相關勢力", isOn: $showCurrentSectionOnly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            HStack {
                Button { showingLevels = true } label: { Label(SailuneActionCopy.manageLevels, systemImage: SailuneSymbol.powerLevel.systemName) }
                    .buttonStyle(.borderless)
                    .disabled(bookIsReadOnly)
            }
            .padding(10)
            List {
                ForEach(powers) { power in
                    HStack(spacing: 8) {
                        Button { onOpen(power) } label: {
                            HStack {
                                Text(power.name.isEmpty ? "未命名勢力" : power.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if let level = PowerHierarchyStore.level(for: power, levels: levels)?.name,
                                   !level.isEmpty {
                                    Text(level)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        if !bookIsReadOnly { Button(SailuneActionCopy.delete, role: .destructive) { deleteTarget = power }.buttonStyle(.plain) }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.workspacePanelBackground)
            if !bookIsReadOnly { Button { addPower() } label: { Label(SailuneActionCopy.add, systemImage: SailuneSymbol.add.systemName) }.buttonStyle(.borderless).padding(10) }
        }
        .confirmationDialog("刪除勢力？", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { power in
            Button(SailuneActionCopy.delete, role: .destructive) {
                settingsStore.deletePower(power, bookID: book.id)
                deleteTarget = nil
            }
            Button(SailuneActionCopy.cancel, role: .cancel) { deleteTarget = nil }
        }
        .sheet(isPresented: $showingLevels) {
            PowerLevelManagementView(book: book)
        }
    }

    private func addPower() {
        guard !bookIsReadOnly else { return }
        let power = PowerUnit(bookID: book.id, name: "新勢力")
        settingsStore.context.insert(power)
        settingsStore.save()
        onOpen(power)
    }
}

struct PowerLevelManagementView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @State private var draftNames: [UUID: String] = [:]
    @State private var errorMessage: String?

    private var levels: [PowerLevel] { settingsStore.levels(for: book.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("管理勢力層級").font(.headline)
                    Text("由高至低排列；勢力可跨級直屬。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !bookIsReadOnly { Button("新增層級", systemImage: SailuneSymbol.add.systemName, action: addLevel) }
                Button(SailuneActionCopy.done) { dismiss() }
            }

            if levels.isEmpty {
                ContentUnavailableView(
                    "尚未建立層級",
                    systemImage: SailuneSymbol.powerLevel.systemName,
                    description: Text("先新增一個具名層級，再為勢力指定層級。")
                )
            } else {
                List {
                    ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 22)
                            TextField("層級名稱", text: nameBinding(for: level))
                                .onSubmit { rename(level) }
                            Button(SailuneActionCopy.save) { rename(level) }
                                .disabled((draftNames[level.id] ?? level.name) == level.name)
                            Button { move(level, offset: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(.borderless)
                                .disabled(index == 0)
                            Button { move(level, offset: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.borderless)
                                .disabled(index == levels.count - 1)
                            Button(role: .destructive) { delete(level) } label: { Image(systemName: SailuneSymbol.delete.systemName) }
                                .buttonStyle(.borderless)
                        }
                    }
                    .onMove(perform: reorder)
                }
                .disabledWhenBookIsCompleted()
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 380)
        .onAppear { synchronizeDraftNames() }
        .onChange(of: settingsStore.revision) { synchronizeDraftNames() }
        .alert("無法變更層級", isPresented: errorBinding) {
            Button(SailuneActionCopy.acknowledge, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func nameBinding(for level: PowerLevel) -> Binding<String> {
        Binding(
            get: { draftNames[level.id] ?? level.name },
            set: { draftNames[level.id] = $0 }
        )
    }

    private func synchronizeDraftNames() {
        for level in levels where draftNames[level.id] == nil {
            draftNames[level.id] = level.name
        }
        draftNames = draftNames.filter { id, _ in levels.contains(where: { $0.id == id }) }
    }

    private func addLevel() {
        guard !bookIsReadOnly else { return }
        do {
            let level = try settingsStore.createLevel(bookID: book.id)
            draftNames[level.id] = level.name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rename(_ level: PowerLevel) {
        guard !bookIsReadOnly else { return }
        do {
            try settingsStore.renameLevel(level, to: draftNames[level.id] ?? level.name, bookID: book.id)
            draftNames[level.id] = level.name
        } catch {
            draftNames[level.id] = level.name
            errorMessage = error.localizedDescription
        }
    }

    private func move(_ level: PowerLevel, offset: Int) {
        guard !bookIsReadOnly else { return }
        guard let index = levels.firstIndex(where: { $0.id == level.id }) else { return }
        let destination = index + offset
        guard levels.indices.contains(destination) else { return }
        var orderedIDs = levels.map(\.id)
        orderedIDs.swapAt(index, destination)
        applyOrder(orderedIDs)
    }

    private func reorder(from source: IndexSet, to destination: Int) {
        guard !bookIsReadOnly else { return }
        var reordered = levels
        reordered.move(fromOffsets: source, toOffset: destination)
        applyOrder(reordered.map(\.id))
    }

    private func applyOrder(_ orderedIDs: [UUID]) {
        guard !bookIsReadOnly else { return }
        do {
            try settingsStore.reorderLevels(bookID: book.id, orderedIDs: orderedIDs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ level: PowerLevel) {
        guard !bookIsReadOnly else { return }
        do {
            try settingsStore.deleteLevel(level, bookID: book.id)
            draftNames[level.id] = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct PowerDetailView: View {
    @Bindable var power: PowerUnit
    let book: Book
    let onBack: () -> Void
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @Query(sort: \Item.name) private var allItems: [Item]
    @Query(sort: \CharacterAbility.name) private var allAbilities: [CharacterAbility]
    @Query(sort: \Node.sortOrder) private var allNodes: [Node]
    @State private var showingLevels = false
    @State private var showingRelationEditor = false
    @State private var errorMessage: String?
    @State private var selectedCharacterID: UUID?
    @State private var memberTitle = ""
    @State private var transitionKind: PowerTransitionKind = .succeeded

    private var levels: [PowerLevel] { settingsStore.levels(for: book.id) }
    private var powers: [PowerUnit] { settingsStore.powers(for: book.id) }
    private var edges: [PowerSubordination] { settingsStore.edges(for: book.id) }
    private var currentLevel: PowerLevel? { PowerHierarchyStore.level(for: power, levels: levels) }
    private var upper: [PowerUnit] { PowerGraphStore.directUpperPowers(of: power, edges: edges, powers: powers) }
    private var lower: [PowerUnit] { PowerGraphStore.directLowerPowers(of: power, edges: edges, powers: powers) }
    private var worldTerms: [WorldTerm] { settingsStore.worldTerms(for: book.id).sorted { $0.name < $1.name } }
    private var members: [PowerMember] { settingsStore.members(for: power, bookID: book.id) }
    private var assets: [PowerAssetLink] { settingsStore.assets(for: power, bookID: book.id) }
    private var advantages: [PowerAdvantage] { settingsStore.advantages(for: power, bookID: book.id) }
    private var lifecycleEvents: [PowerLifecycleEvent] { settingsStore.lifecycleEvents(for: power, bookID: book.id) }
    private var successionLinks: [PowerSuccessionLink] { settingsStore.successionLinks(for: power, bookID: book.id) }
    private var powerRelations: [PowerRelation] { settingsStore.powerRelations(for: power, bookID: book.id) }
    private var nodes: [Node] { allNodes.filter { $0.timeline?.book?.id == book.id } }
    private var characters: [Character] { allCharacters.filter { $0.book?.id == book.id } }
    private var items: [Item] { allItems.filter { $0.book?.id == book.id } }
    private var abilities: [CharacterAbility] { allAbilities.filter { $0.character?.book?.id == book.id } }
    private var availableCharacters: [Character] {
        let memberIDs = Set(members.map(\.characterID))
        return characters.filter { !memberIDs.contains($0.id) }
    }
    private var upperCandidates: [PowerUnit] {
        PowerHierarchyStore.upperCandidates(for: power, powers: powers, levels: levels)
            .filter { candidate in !upper.contains(where: { $0.id == candidate.id }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button(action: onBack) { Label("返回勢力", systemImage: SailuneSymbol.back.systemName) }.buttonStyle(.plain)
                    Spacer()
                    Button(SailuneActionCopy.manageLevels, systemImage: SailuneSymbol.powerLevel.systemName) { showingLevels = true }
                        .buttonStyle(.borderless)
                        .disabled(bookIsReadOnly)
                    if !bookIsReadOnly { Button(role: .destructive, action: deletePower) { Label(SailuneActionCopy.delete, systemImage: SailuneSymbol.delete.systemName) }.buttonStyle(.borderless) }
                }
                SailuneFormTextField(title: "勢力名稱", text: $power.name)
                Text("簡介").font(.caption).foregroundStyle(.secondary)
                SailuneBorderedTextEditor(text: $power.powerDescription, minHeight: 90)

                identificationSection.disabled(bookIsReadOnly)
                lifecycleSection.disabled(bookIsReadOnly)

                VStack(alignment: .leading, spacing: 8) {
                    Text("勢力設定").font(.subheadline.weight(.semibold))
                    ForEach(PowerWorldTermField.allCases) { field in
                        worldTermPicker(field)
                    }
                    territoryLinkPlaceholder(title: "核心區域")
                    territoryLinkPlaceholder(title: "範圍")
                    Text("目的").font(.caption).foregroundStyle(.secondary)
                    SailuneBorderedTextEditor(text: $power.purpose, minHeight: 72)
                }
                .padding(10)
                .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
                .disabled(bookIsReadOnly)

                memberSection.disabled(bookIsReadOnly)
                assetSection.disabled(bookIsReadOnly)
                advantageSection.disabled(bookIsReadOnly)

                powerNotebookField(
                    title: "高層管理員",
                    detail: "記錄職稱與人名；第一版不連結角色資料。",
                    text: $power.seniorManagers
                )
                powerNotebookField(
                    title: "其他名單",
                    detail: "可自由記錄其他職稱、人名或群組。",
                    text: $power.otherRoster
                )
                powerRelationSection.disabled(bookIsReadOnly)
                powerNotebookField(title: "政治", detail: "記錄政治立場、制度或運作方式。", text: $power.politics)
                powerNotebookField(title: "宗教", detail: "記錄信仰、宗教制度或相關影響。", text: $power.religion)

                VStack(alignment: .leading, spacing: 7) {
                    Text("層級").font(.subheadline.weight(.semibold))
                    if levels.isEmpty {
                        Text("尚未建立層級。請先使用「管理層級」新增。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Menu {
                            ForEach(levels) { level in
                                Button(level.name) { changeLevel(to: level) }
                            }
                        } label: {
                            Label(currentLevel?.name ?? "選擇層級", systemImage: SailuneSymbol.powerLevel.systemName)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(10)
                .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))

                if currentLevel == nil {
                    ContentUnavailableView(
                        "請先指定層級",
                        systemImage: "arrow.up.arrow.down",
                        description: Text("指定具體層級後，才能選擇此勢力的直屬上級。")
                    )
                } else {
                    upperRelationSection.disabled(bookIsReadOnly)
                    relationQuerySection(title: "直屬下級", detail: "僅顯示直接隸屬於此勢力的勢力。", values: lower)
                }
            }
            .padding(14)
        }
        .sheet(isPresented: $showingLevels) {
            PowerLevelManagementView(book: book)
        }
        .sheet(isPresented: $showingRelationEditor) {
            PowerRelationEditorView(currentPower: power, candidates: powers.filter { $0.id != power.id }) {
                source, target, kind, detail in
                do {
                    try settingsStore.addPowerRelation(from: source, to: target, kind: kind, detail: detail, bookID: book.id)
                    return true
                } catch {
                    errorMessage = error.localizedDescription
                    return false
                }
            }
        }
        .alert("無法完成勢力變更", isPresented: errorBinding) {
            Button(SailuneActionCopy.acknowledge, role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
        .onChange(of: power.name) { power.updatedAt = Date() }
        .onChange(of: power.powerDescription) { power.updatedAt = Date() }
        .onChange(of: power.formerNames) { power.updatedAt = Date() }
        .onChange(of: power.foreignNames) { power.updatedAt = Date() }
        .onChange(of: power.shortName) { power.updatedAt = Date() }
        .onChange(of: power.seniorManagers) { power.updatedAt = Date() }
        .onChange(of: power.otherRoster) { power.updatedAt = Date() }
        .onChange(of: power.relationshipNotes) { power.updatedAt = Date() }
        .onChange(of: power.politics) { power.updatedAt = Date() }
        .onChange(of: power.religion) { power.updatedAt = Date() }
        .onChange(of: power.purpose) { power.updatedAt = Date() }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    @ViewBuilder
    private func powerNotebookField(title: String, detail: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            SailuneBorderedTextEditor(text: text, minHeight: 72)
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var upperRelationSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("直屬上級").font(.subheadline.weight(.semibold))
            Text("此列表供查詢；移除入口位於各筆上級旁。").font(.caption).foregroundStyle(.secondary)
            if upper.isEmpty { Text("尚未設定").font(.caption).foregroundStyle(.tertiary) }
            ForEach(upper) { value in
                HStack {
                    powerCandidateLabel(value)
                    Spacer()
                    Button(role: .destructive) { settingsStore.removeSubordination(lower: power, upper: value, bookID: book.id) } label: { Image(systemName: SailuneSymbol.removeAssociation.systemName) }
                        .buttonStyle(.plain)
                }
            }
            Menu {
                if upperCandidates.isEmpty {
                    Text("沒有符合層級的候選勢力")
                } else {
                    ForEach(upperCandidates) { candidate in
                        Button { add(lower: power, upper: candidate) } label: { powerCandidateLabel(candidate) }
                    }
                }
            } label: {
                Label("選擇直屬上級", systemImage: "arrow.up.circle")
            }
            .buttonStyle(.borderless)
            .disabled(upperCandidates.isEmpty)
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var powerRelationSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("非隸屬關係").font(.subheadline.weight(.semibold))
            Text("記錄同盟、敵對、競爭、貿易、臨時合作或宗主／附庸；不會改變上下隸屬。")
                .font(.caption)
                .foregroundStyle(.secondary)
            if powerRelations.isEmpty {
                Text("尚未設定").font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(powerRelations) { relation in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(powerRelationTargetName(relation))
                        Text(powerRelationTitle(relation)).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            settingsStore.removePowerRelation(relation, bookID: book.id)
                        } label: {
                            Image(systemName: SailuneSymbol.removeAssociation.systemName)
                        }
                        .buttonStyle(.plain)
                    }
                    SailuneFormTextField(title: "關係說明（可留空）", text: powerRelationDetailBinding(relation))
                }
            }
            Button(SailuneActionCopy.addRelationship, systemImage: SailuneSymbol.add.systemName) { showingRelationEditor = true }
                .buttonStyle(.borderless)
                .disabled(powers.count < 2)
            Divider()
            Text("關係補充筆記").font(.caption).foregroundStyle(.secondary)
            Text("保留既有自由文字，不會自動轉換為上方關係。")
                .font(.caption)
                .foregroundStyle(.secondary)
            SailuneBorderedTextEditor(text: $power.relationshipNotes, minHeight: 72)
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func powerRelationTargetName(_ relation: PowerRelation) -> String {
        let targetID = relation.sourcePowerID == power.id ? relation.targetPowerID : relation.sourcePowerID
        return powers.first(where: { $0.id == targetID }).map { $0.name.isEmpty ? "未命名勢力" : $0.name } ?? "已刪除勢力"
    }

    private func powerRelationTitle(_ relation: PowerRelation) -> String {
        guard let kind = relation.kind else { return "未知關係" }
        guard kind == .suzerainty else { return kind.title }
        return relation.sourcePowerID == power.id ? "附庸" : "宗主"
    }

    private func powerRelationDetailBinding(_ relation: PowerRelation) -> Binding<String> {
        Binding(get: { relation.detail }, set: {
            relation.detail = $0
            relation.updatedAt = Date()
            settingsStore.save()
        })
    }

    private func relationQuerySection(title: String, detail: String, values: [PowerUnit]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            if values.isEmpty { Text("尚未設定").font(.caption).foregroundStyle(.tertiary) }
            ForEach(values) { powerCandidateLabel($0) }
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func powerCandidateLabel(_ candidate: PowerUnit) -> some View {
        let levelName = PowerHierarchyStore.level(for: candidate, levels: levels)?.name ?? "未指定層級"
        return HStack {
            Text(candidate.name.isEmpty ? "未命名勢力" : candidate.name)
            Text(levelName).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func worldTermPicker(_ field: PowerWorldTermField) -> some View {
        let selectedID = settingsStore.worldTermID(for: field, on: power)
        let selectedName = worldTerms.first(where: { $0.id == selectedID })?.name
        let candidates = worldTerms.filter {
            $0.id == selectedID || $0.termCategory == field.matchingCategory.rawValue
        }
        return HStack {
            Text(field.title).frame(width: 48, alignment: .leading)
            Menu(selectedName?.isEmpty == false ? selectedName! : "選擇世界條目") {
                Button("不連結") { setWorldTerm(nil, field: field) }
                Divider()
                ForEach(candidates) { term in
                    Button(term.name.isEmpty ? "未命名條目" : term.name) { setWorldTerm(term, field: field) }
                }
            }
            .disabled(candidates.isEmpty && selectedID == nil)
        }
    }

    private func territoryLinkPlaceholder(title: String) -> some View {
        HStack {
            Text(title).frame(width: 48, alignment: .leading)
            Text("之後連接地點／地圖")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var identificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("識別與別名").font(.subheadline.weight(.semibold))
            SailuneFormTextField(title: "舊名（可用頓號或換行分隔）", text: $power.formerNames)
            SailuneFormTextField(title: "外文名（可用頓號或換行分隔）", text: $power.foreignNames)
            SailuneFormTextField(title: "簡稱", text: $power.shortName)
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var lifecycleSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("勢力生命週期").font(.subheadline.weight(.semibold))
            Picker("目前狀態", selection: Binding(get: { power.existenceStatus }, set: { power.existenceStatus = $0; power.updatedAt = Date(); settingsStore.save() })) {
                ForEach(PowerExistenceStatus.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            ForEach(lifecycleEvents) { event in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Picker("事件", selection: Binding(get: { event.kind ?? .established }, set: { event.kindRawValue = $0.rawValue; event.updatedAt = Date(); settingsStore.save() })) {
                            ForEach(PowerLifecycleKind.allCases) { Text($0.title).tag($0) }
                        }
                        SailuneFormTextField(title: "事件標題", text: modelTextBinding(event, keyPath: \.title))
                        Button(role: .destructive) { settingsStore.removeLifecycleEvent(event, bookID: book.id) } label: { Image(systemName: SailuneSymbol.removeEntry.systemName) }.buttonStyle(.plain)
                    }
                    SailuneFormTextField(title: "說明", text: modelTextBinding(event, keyPath: \.detail))
                    nodePicker(nodeID: Binding(get: { event.nodeID }, set: { event.nodeID = $0; event.updatedAt = Date(); settingsStore.save() }))
                }
            }
            Menu("新增生命週期事件") {
                ForEach(PowerLifecycleKind.allCases) { kind in Button(kind.title) { addLifecycleEvent(kind) } }
            }.buttonStyle(.borderless)
            Divider()
            Picker("承接類型", selection: $transitionKind) { ForEach(PowerTransitionKind.allCases) { Text($0.title).tag($0) } }
            HStack {
                Menu("加入前身") { ForEach(powers.filter { $0.id != power.id }) { candidate in Button(candidate.name) { addSuccession(predecessor: candidate, successor: power) } } }
                Menu("加入後繼") { ForEach(powers.filter { $0.id != power.id }) { candidate in Button(candidate.name) { addSuccession(predecessor: power, successor: candidate) } } }
            }.buttonStyle(.borderless)
            ForEach(successionLinks) { link in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(successionLabel(link))
                        Spacer()
                        Button(role: .destructive) { settingsStore.removeSuccession(link, bookID: book.id) } label: { Image(systemName: SailuneSymbol.removeAssociation.systemName) }.buttonStyle(.plain)
                    }
                    SailuneFormTextField(title: "承接說明", text: modelTextBinding(link, keyPath: \.detail))
                    nodePicker(nodeID: Binding(get: { link.nodeID }, set: { link.nodeID = $0; link.updatedAt = Date(); settingsStore.save() }))
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private var assetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("掌握的資源與能力").font(.subheadline.weight(.semibold))
            Text("連接既有資料；來源改名會同步顯示，不複製名稱或內容。").font(.caption).foregroundStyle(.secondary)
            ForEach(PowerAssetKind.allCases) { kind in
                assetRows(kind: kind)
            }
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func assetRows(kind: PowerAssetKind) -> some View {
        let linked = assets.filter { $0.kind == kind }
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(kind.title).frame(width: 46, alignment: .leading)
                Menu("連接\(kind.title)") {
                    let candidates = assetCandidates(kind: kind).filter { source in
                        !linked.contains(where: { $0.sourceID == source.id })
                    }
                    if candidates.isEmpty {
                        Text("沒有可連接的\(kind.title)")
                    } else {
                        ForEach(candidates) { source in
                            Button(source.name) { addAsset(kind: kind, sourceID: source.id) }
                        }
                    }
                }
                .buttonStyle(.borderless)
            }
            ForEach(linked) { asset in
                HStack {
                    Text(assetName(asset) ?? "來源已刪除")
                        .foregroundStyle(assetName(asset) == nil ? .secondary : .primary)
                    Spacer()
                    Button(role: .destructive) { settingsStore.removeAsset(asset, bookID: book.id) } label: { Image(systemName: SailuneSymbol.removeAssociation.systemName) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var advantageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("軍事與經濟優勢").font(.subheadline.weight(.semibold))
            Text("軍事與經濟沒有獨立來源模型，因此逐筆記錄名稱與說明，不虛構跨模組連接。 ").font(.caption).foregroundStyle(.secondary)
            ForEach(PowerAdvantageKind.allCases) { kind in
                HStack {
                    Text(kind.title).frame(width: 74, alignment: .leading)
                    Button(SailuneActionCopy.add) { addAdvantage(kind: kind) }.buttonStyle(.borderless)
                }
                ForEach(advantages.filter { $0.kind == kind }) { advantage in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            SailuneFormTextField(title: "優勢名稱", text: advantageBinding(advantage, keyPath: \.name))
                            Button(role: .destructive) { settingsStore.removeAdvantage(advantage, bookID: book.id) } label: { Image(systemName: SailuneSymbol.removeEntry.systemName) }
                                .buttonStyle(.plain)
                        }
                        SailuneFormTextField(title: "說明", text: advantageBinding(advantage, keyPath: \.detail))
                    }
                }
            }
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private struct AssetCandidate: Identifiable {
        let id: UUID
        let name: String
    }

    private func assetCandidates(kind: PowerAssetKind) -> [AssetCandidate] {
        switch kind {
        case .resource:
            worldTerms.filter { $0.termCategory == WorldTermCategory.resource.rawValue }.map { AssetCandidate(id: $0.id, name: $0.name.isEmpty ? "未命名資源" : $0.name) }
        case .technology:
            worldTerms.filter { $0.termCategory == WorldTermCategory.technology.rawValue }.map { AssetCandidate(id: $0.id, name: $0.name.isEmpty ? "未命名技術" : $0.name) }
        case .item:
            items.map { AssetCandidate(id: $0.id, name: $0.name.isEmpty ? "未命名物品" : $0.name) }
        case .ability:
            abilities.map { AssetCandidate(id: $0.id, name: $0.name.isEmpty ? "未命名能力" : $0.name) }
        }
    }

    private func assetName(_ asset: PowerAssetLink) -> String? {
        assetCandidates(kind: asset.kind ?? .resource).first(where: { $0.id == asset.sourceID })?.name
    }

    private func addAsset(kind: PowerAssetKind, sourceID: UUID) {
        guard !bookIsReadOnly else { return }
        do { try settingsStore.addAsset(kind: kind, sourceID: sourceID, sourceBookID: book.id, to: power, bookID: book.id) }
        catch { errorMessage = error.localizedDescription }
    }

    private func addAdvantage(kind: PowerAdvantageKind) {
        guard !bookIsReadOnly else { return }
        do { try settingsStore.addAdvantage(kind: kind, name: "新\(kind.title)", detail: "", to: power, bookID: book.id) }
        catch { errorMessage = error.localizedDescription }
    }

    private func advantageBinding(_ advantage: PowerAdvantage, keyPath: ReferenceWritableKeyPath<PowerAdvantage, String>) -> Binding<String> {
        Binding(get: { advantage[keyPath: keyPath] }, set: { value in
            advantage[keyPath: keyPath] = value
            advantage.updatedAt = Date()
            settingsStore.save()
        })
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("成員").font(.subheadline.weight(.semibold))
            ForEach(members) { member in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(characters.first(where: { $0.id == member.characterID })?.realName ?? "已刪除角色").font(.headline)
                        Picker("狀態", selection: Binding(get: { member.status }, set: { member.status = $0; member.updatedAt = Date(); settingsStore.save() })) {
                            ForEach(PowerMembershipStatus.allCases) { Text($0.title).tag($0) }
                        }.frame(width: 150)
                        Spacer()
                        Button(role: .destructive) { settingsStore.removeMember(member, bookID: book.id) } label: { Image(systemName: SailuneSymbol.removeAssociation.systemName) }.buttonStyle(.plain)
                    }
                    HStack { Text("加入").frame(width: 34, alignment: .leading); nodePicker(nodeID: memberNodeBinding(member, keyPath: \.joinedNodeID)) }
                    HStack { Text("離開").frame(width: 34, alignment: .leading); nodePicker(nodeID: memberNodeBinding(member, keyPath: \.leftNodeID)) }
                    ForEach(settingsStore.roles(for: member, bookID: book.id)) { role in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                TextField("職務", text: modelTextBinding(role, keyPath: \.title))
                                Toggle("領導職位", isOn: Binding(get: { role.isLeadership }, set: { role.isLeadership = $0; role.updatedAt = Date(); settingsStore.save() }))
                                Picker("職務狀態", selection: Binding(get: { role.status }, set: { role.status = $0; role.updatedAt = Date(); settingsStore.save() })) {
                                    ForEach(PowerRoleStatus.allCases) { Text($0.title).tag($0) }
                                }.frame(width: 145)
                                Button(role: .destructive) { settingsStore.removeRole(role, bookID: book.id) } label: { Image(systemName: SailuneSymbol.removeEntry.systemName) }.buttonStyle(.plain)
                            }
                            HStack { Text("任職").frame(width: 34, alignment: .leading); nodePicker(nodeID: roleNodeBinding(role, keyPath: \.startNodeID)) }
                            HStack { Text("卸任").frame(width: 34, alignment: .leading); nodePicker(nodeID: roleNodeBinding(role, keyPath: \.endNodeID)) }
                        }.padding(7).background(SailuneTheme.insetRowSurface, in: RoundedRectangle(cornerRadius: 6))
                    }
                    Button("新增職務", systemImage: SailuneSymbol.add.systemName) { addRole(member) }.buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
            HStack {
                Menu(characterName(selectedCharacterID) ?? "選擇角色") {
                    ForEach(availableCharacters) { character in
                        Button(character.realName.isEmpty ? "未命名角色" : character.realName) { selectedCharacterID = character.id }
                    }
                }
                TextField("職稱（手寫）", text: $memberTitle)
                Button("加入") { addMember() }.disabled(selectedCharacterID == nil)
            }
        }
        .padding(10)
        .background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 8))
    }

    private func characterName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return characters.first(where: { $0.id == id }).map { $0.realName.isEmpty ? "未命名角色" : $0.realName }
    }

    private func setWorldTerm(_ term: WorldTerm?, field: PowerWorldTermField) {
        do { try settingsStore.setWorldTerm(term, for: field, on: power, bookID: book.id) }
        catch { errorMessage = error.localizedDescription }
    }

    private func addMember() {
        guard !bookIsReadOnly else { return }
        guard let character = characters.first(where: { $0.id == selectedCharacterID }) else { return }
        do {
            try settingsStore.addMember(characterID: character.id, characterBookID: book.id, title: memberTitle, to: power, bookID: book.id)
            selectedCharacterID = nil
            memberTitle = ""
        } catch { errorMessage = error.localizedDescription }
    }

    private func addRole(_ member: PowerMember) {
        guard !bookIsReadOnly else { return }
        do { try settingsStore.addRole(to: member, bookID: book.id) } catch { errorMessage = error.localizedDescription }
    }

    private func addLifecycleEvent(_ kind: PowerLifecycleKind) {
        guard !bookIsReadOnly else { return }
        do { try settingsStore.addLifecycleEvent(to: power, kind: kind, bookID: book.id) } catch { errorMessage = error.localizedDescription }
    }

    private func addSuccession(predecessor: PowerUnit, successor: PowerUnit) {
        guard !bookIsReadOnly else { return }
        do { try settingsStore.addSuccession(predecessor: predecessor, successor: successor, kind: transitionKind, bookID: book.id) } catch { errorMessage = error.localizedDescription }
    }

    private func successionLabel(_ link: PowerSuccessionLink) -> String {
        let predecessor = powers.first(where: { $0.id == link.predecessorPowerID })?.name ?? "失效前身"
        let successor = powers.first(where: { $0.id == link.successorPowerID })?.name ?? "失效後繼"
        return "\(predecessor) → \(successor)（\(link.kind?.title ?? "承接"))"
    }

    private func nodePicker(nodeID: Binding<UUID?>) -> some View {
        CharacterNodePicker(book: book, node: Binding(get: { nodeID.wrappedValue.flatMap { id in nodes.first { $0.id == id } } }, set: { nodeID.wrappedValue = $0?.id }))
    }

    private func memberNodeBinding(_ member: PowerMember, keyPath: ReferenceWritableKeyPath<PowerMember, UUID?>) -> Binding<UUID?> {
        Binding(get: { member[keyPath: keyPath] }, set: { member[keyPath: keyPath] = $0; member.updatedAt = Date(); settingsStore.save() })
    }

    private func roleNodeBinding(_ role: PowerMemberRole, keyPath: ReferenceWritableKeyPath<PowerMemberRole, UUID?>) -> Binding<UUID?> {
        Binding(get: { role[keyPath: keyPath] }, set: { role[keyPath: keyPath] = $0; role.updatedAt = Date(); settingsStore.save() })
    }

    private func modelTextBinding<Root: AnyObject>(_ root: Root, keyPath: ReferenceWritableKeyPath<Root, String>) -> Binding<String> {
        Binding(get: { root[keyPath: keyPath] }, set: { root[keyPath: keyPath] = $0; settingsStore.save() })
    }

    private func changeLevel(to level: PowerLevel) {
        guard !bookIsReadOnly else { return }
        do {
            try settingsStore.changeLevel(of: power, to: level, bookID: book.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func add(lower: PowerUnit, upper: PowerUnit) {
        guard !bookIsReadOnly else { return }
        do {
            try settingsStore.addSubordination(lower: lower, upper: upper, bookID: book.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePower() {
        guard !bookIsReadOnly else { return }
        settingsStore.deletePower(power, bookID: book.id)
        onBack()
    }
}

private struct PowerRelationEditorView: View {
    let currentPower: PowerUnit
    let candidates: [PowerUnit]
    let onSave: (PowerUnit, PowerUnit, PowerRelationKind, String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPowerID: UUID?
    @State private var kind: PowerRelationKind = .alliance
    @State private var currentPowerIsOverlord = true
    @State private var detail = ""

    init(
        currentPower: PowerUnit,
        candidates: [PowerUnit],
        onSave: @escaping (PowerUnit, PowerUnit, PowerRelationKind, String) -> Bool
    ) {
        self.currentPower = currentPower
        self.candidates = candidates
        self.onSave = onSave
        _selectedPowerID = State(initialValue: candidates.first?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("對象勢力", selection: $selectedPowerID) {
                    ForEach(candidates) { candidate in
                        Text(candidate.name.isEmpty ? "未命名勢力" : candidate.name).tag(Optional(candidate.id))
                    }
                }
                Picker("關係類型", selection: $kind) {
                    ForEach(PowerRelationKind.allCases) { Text($0.title).tag($0) }
                }
                if kind.isDirected {
                    Picker("本勢力身分", selection: $currentPowerIsOverlord) {
                        Text("宗主").tag(true)
                        Text("附庸").tag(false)
                    }
                    Text(relationDirectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("關係說明（可留空）", text: $detail)
            }
            .formStyle(.grouped)
            .navigationTitle("新增非隸屬關係")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(SailuneActionCopy.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(SailuneActionCopy.add, action: save).disabled(selectedPowerID == nil)
                }
            }
        }
        .frame(minWidth: 430, minHeight: kind.isDirected ? 310 : 250)
    }

    private var selectedPower: PowerUnit? {
        candidates.first(where: { $0.id == selectedPowerID })
    }

    private var relationDirectionDescription: String {
        let currentName = currentPower.name.isEmpty ? "目前勢力" : currentPower.name
        let otherName = selectedPower.map { $0.name.isEmpty ? "對象勢力" : $0.name } ?? "對象勢力"
        return currentPowerIsOverlord
            ? "\(currentName)為宗主，\(otherName)為附庸。"
            : "\(otherName)為宗主，\(currentName)為附庸。"
    }

    private func save() {
        guard let selectedPower else { return }
        let source = kind.isDirected && !currentPowerIsOverlord ? selectedPower : currentPower
        let target = kind.isDirected && !currentPowerIsOverlord ? currentPower : selectedPower
        if onSave(source, target, kind, detail) { dismiss() }
    }
}

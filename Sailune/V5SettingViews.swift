import SwiftUI
import SwiftData

struct SidebarSettingsManagerView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(V5SettingsStore.self) private var settingsStore

    private var rows: [BookSidebarSetting] {
        settingsStore.sidebarRows(for: book.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("管理設定集").font(.headline)
                Spacer()
                Button("完成") { dismiss() }
            }
            Text("預設項目也可以隱藏；隱藏只影響側邊欄，不會刪除資料。")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                SwiftUI.Section("側邊欄順序") {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Toggle(isOn: binding(for: row)) {
                                Label(row.key?.title ?? "未知設定", systemImage: row.key?.systemImage ?? "questionmark")
                            }
                            Spacer()
                            Button { move(row, offset: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(.borderless)
                                .disabled(row.sortOrder == rows.first?.sortOrder)
                            Button { move(row, offset: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.borderless)
                                .disabled(row.sortOrder == rows.last?.sortOrder)
                        }
                    }
                }
            }
            HStack {
                Button("重設預設顯示", action: reset)
                Spacer()
                Text("可選項目：地點")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 420, minHeight: 360)
        .task { settingsStore.ensureDefaults(for: book.id) }
    }

    private func binding(for row: BookSidebarSetting) -> Binding<Bool> {
        Binding(get: { row.isVisible }, set: { row.isVisible = $0; settingsStore.save() })
    }

    private func move(_ row: BookSidebarSetting, offset: Int) {
        guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
        let target = index + offset
        guard rows.indices.contains(target) else { return }
        let other = rows[target]
        let order = row.sortOrder
        row.sortOrder = other.sortOrder
        other.sortOrder = order
        settingsStore.save()
    }

    private func reset() {
        for row in rows {
            if let key = row.key,
               let index = SidebarSettingKey.defaultOrder.firstIndex(of: key) {
                row.sortOrder = index
            }
            row.isVisible = row.key?.isDefaultVisible ?? false
        }
        settingsStore.save()
    }
}

struct PowerListView: View {
    let book: Book
    let onOpen: (PowerUnit) -> Void
    @Environment(V5SettingsStore.self) private var settingsStore
    @State private var searchText = ""
    @State private var showingLevels = false

    private var levels: [PowerLevel] { settingsStore.levels(for: book.id) }
    private var powers: [PowerUnit] {
        settingsStore.powers(for: book.id).filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("搜尋勢力", text: $searchText).textFieldStyle(.roundedBorder)
                Button { showingLevels = true } label: { Label("管理層級", systemImage: "list.number") }
                    .buttonStyle(.borderless)
                Button { addPower() } label: { Label("新增", systemImage: "plus") }
                    .buttonStyle(.borderless)
            }
            .padding(10)
            List {
                ForEach(powers) { power in
                    Button { onOpen(power) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(power.name.isEmpty ? "未命名勢力" : power.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(PowerHierarchyStore.level(for: power, levels: levels)?.name ?? "尚未指定層級")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !power.powerDescription.isEmpty {
                                Text(power.powerDescription).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for power in offsets.map({ powers[$0] }) {
                        settingsStore.deletePower(power, bookID: book.id)
                    }
                }
            }
        }
        .sheet(isPresented: $showingLevels) {
            PowerLevelManagementView(book: book)
        }
    }

    private func addPower() {
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
                Button("新增層級", systemImage: "plus", action: addLevel)
                Button("完成") { dismiss() }
            }

            if levels.isEmpty {
                ContentUnavailableView(
                    "尚未建立層級",
                    systemImage: "list.number",
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
                            Button("儲存") { rename(level) }
                                .disabled((draftNames[level.id] ?? level.name) == level.name)
                            Button { move(level, offset: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(.borderless)
                                .disabled(index == 0)
                            Button { move(level, offset: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.borderless)
                                .disabled(index == levels.count - 1)
                            Button(role: .destructive) { delete(level) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                    }
                    .onMove(perform: reorder)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 380)
        .onAppear { synchronizeDraftNames() }
        .onChange(of: settingsStore.revision) { synchronizeDraftNames() }
        .alert("無法變更層級", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
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
        do {
            let level = try settingsStore.createLevel(bookID: book.id)
            draftNames[level.id] = level.name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rename(_ level: PowerLevel) {
        do {
            try settingsStore.renameLevel(level, to: draftNames[level.id] ?? level.name, bookID: book.id)
            draftNames[level.id] = level.name
        } catch {
            draftNames[level.id] = level.name
            errorMessage = error.localizedDescription
        }
    }

    private func move(_ level: PowerLevel, offset: Int) {
        guard let index = levels.firstIndex(where: { $0.id == level.id }) else { return }
        let destination = index + offset
        guard levels.indices.contains(destination) else { return }
        var orderedIDs = levels.map(\.id)
        orderedIDs.swapAt(index, destination)
        applyOrder(orderedIDs)
    }

    private func reorder(from source: IndexSet, to destination: Int) {
        var reordered = levels
        reordered.move(fromOffsets: source, toOffset: destination)
        applyOrder(reordered.map(\.id))
    }

    private func applyOrder(_ orderedIDs: [UUID]) {
        do {
            try settingsStore.reorderLevels(bookID: book.id, orderedIDs: orderedIDs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ level: PowerLevel) {
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
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @State private var showingLevels = false
    @State private var errorMessage: String?
    @State private var selectedCharacterID: UUID?
    @State private var memberTitle = ""

    private var levels: [PowerLevel] { settingsStore.levels(for: book.id) }
    private var powers: [PowerUnit] { settingsStore.powers(for: book.id) }
    private var edges: [PowerSubordination] { settingsStore.edges(for: book.id) }
    private var currentLevel: PowerLevel? { PowerHierarchyStore.level(for: power, levels: levels) }
    private var upper: [PowerUnit] { PowerGraphStore.directUpperPowers(of: power, edges: edges, powers: powers) }
    private var lower: [PowerUnit] { PowerGraphStore.directLowerPowers(of: power, edges: edges, powers: powers) }
    private var worldTerms: [WorldTerm] { settingsStore.worldTerms(for: book.id).sorted { $0.name < $1.name } }
    private var members: [PowerMember] { settingsStore.members(for: power, bookID: book.id) }
    private var characters: [Character] { allCharacters.filter { $0.book?.id == book.id } }
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
                    Button(action: onBack) { Label("返回勢力", systemImage: "chevron.left") }.buttonStyle(.plain)
                    Spacer()
                    Button("管理層級", systemImage: "list.number") { showingLevels = true }
                        .buttonStyle(.borderless)
                    Button(role: .destructive, action: deletePower) { Label("刪除", systemImage: "trash") }.buttonStyle(.borderless)
                }
                TextField("勢力名稱", text: $power.name).textFieldStyle(.roundedBorder)
                Text("簡介").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $power.powerDescription)
                    .frame(minHeight: 90)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))

                VStack(alignment: .leading, spacing: 8) {
                    Text("勢力設定").font(.subheadline.weight(.semibold))
                    ForEach(PowerWorldTermField.allCases) { field in
                        worldTermPicker(field)
                    }
                    Text("目的").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $power.purpose)
                        .frame(minHeight: 72)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                memberSection

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
                powerNotebookField(
                    title: "勢力關係",
                    detail: "補充隸屬以外的合作、敵對或其他關係。",
                    text: $power.relationshipNotes
                )
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
                            Label(currentLevel?.name ?? "選擇層級", systemImage: "list.number")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                if currentLevel == nil {
                    ContentUnavailableView(
                        "請先指定層級",
                        systemImage: "arrow.up.arrow.down",
                        description: Text("指定具體層級後，才能選擇此勢力的直屬上級。")
                    )
                } else {
                    upperRelationSection
                    relationQuerySection(title: "直屬下級", detail: "僅顯示直接隸屬於此勢力的勢力。", values: lower)
                }
            }
            .padding(14)
        }
        .sheet(isPresented: $showingLevels) {
            PowerLevelManagementView(book: book)
        }
        .alert("無法完成勢力變更", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
        .onChange(of: power.name) { power.updatedAt = Date() }
        .onChange(of: power.powerDescription) { power.updatedAt = Date() }
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
            TextEditor(text: text)
                .frame(minHeight: 72)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
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
                    Button(role: .destructive) { settingsStore.removeSubordination(lower: power, upper: value, bookID: book.id) } label: { Image(systemName: "minus.circle") }
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
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func relationQuerySection(title: String, detail: String, values: [PowerUnit]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            if values.isEmpty { Text("尚未設定").font(.caption).foregroundStyle(.tertiary) }
            ForEach(values) { powerCandidateLabel($0) }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
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
        return HStack {
            Text(field.title).frame(width: 48, alignment: .leading)
            Menu(selectedName?.isEmpty == false ? selectedName! : "選擇世界條目") {
                Button("不連結") { setWorldTerm(nil, field: field) }
                Divider()
                ForEach(worldTerms) { term in
                    Button(term.name.isEmpty ? "未命名條目" : term.name) { setWorldTerm(term, field: field) }
                }
            }
            .disabled(worldTerms.isEmpty && selectedID == nil)
        }
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("成員").font(.subheadline.weight(.semibold))
            ForEach(members) { member in
                HStack {
                    Text(characters.first(where: { $0.id == member.characterID })?.realName ?? "已刪除角色")
                    TextField("職稱", text: Binding(
                        get: { member.title },
                        set: { member.title = $0; member.updatedAt = Date(); settingsStore.save() }
                    ))
                    Button(role: .destructive) { settingsStore.removeMember(member, bookID: book.id) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain)
                }
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
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
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
        guard let character = characters.first(where: { $0.id == selectedCharacterID }) else { return }
        do {
            try settingsStore.addMember(characterID: character.id, characterBookID: book.id, title: memberTitle, to: power, bookID: book.id)
            selectedCharacterID = nil
            memberTitle = ""
        } catch { errorMessage = error.localizedDescription }
    }

    private func changeLevel(to level: PowerLevel) {
        do {
            try settingsStore.changeLevel(of: power, to: level, bookID: book.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func add(lower: PowerUnit, upper: PowerUnit) {
        do {
            try settingsStore.addSubordination(lower: lower, upper: upper, bookID: book.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePower() {
        settingsStore.deletePower(power, bookID: book.id)
        onBack()
    }
}

struct PlaceListView: View {
    let book: Book
    @Environment(V5SettingsStore.self) private var settingsStore
    @State private var searchText = ""
    @State private var editingPlace: Place?

    private var places: [Place] { settingsStore.places(for: book.id).sorted { $0.sortOrder < $1.sortOrder } }
    private var filteredPlaces: [Place] {
        V5SettingsSearch.places(places, matching: searchText)
    }

    var body: some View {
        List {
            ForEach(filteredPlaces) { place in
                Button { editingPlace = place } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(place.name.isEmpty ? "未命名地點" : place.name)
                                .font(.headline)
                            if let placeType = place.placeType, !placeType.isEmpty {
                                Text(placeType)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(place.placeDescription.isEmpty ? "尚無簡介" : place.placeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { filteredPlaces[$0] }.forEach { settingsStore.deletePlace($0, bookID: book.id) }
            }
        }
        .overlay {
            if places.isEmpty {
                ContentUnavailableView("尚無地點", systemImage: "mappin.and.ellipse", description: Text("使用右上角新增第一個地點。"))
            } else if filteredPlaces.isEmpty {
                ContentUnavailableView("找不到地點", systemImage: "magnifyingglass", description: Text("請嘗試其他搜尋關鍵字。"))
            }
        }
        .searchable(text: $searchText, prompt: "搜尋地點、別名、類型或簡介")
        .toolbar {
            Button("新增地點", systemImage: "plus") {
                editingPlace = settingsStore.createPlace(bookID: book.id)
            }
        }
        .sheet(item: $editingPlace) { place in
            PlaceDetailView(place: place, book: book)
        }
    }
}

struct WorldTermListView: View {
    let book: Book
    @Environment(V5SettingsStore.self) private var settingsStore
    @State private var searchText = ""
    @State private var categoryFilter: String?
    @State private var editingTerm: WorldTerm?
    @State private var newlyCreatedTermID: UUID?

    private var terms: [WorldTerm] { settingsStore.worldTerms(for: book.id).sorted { $0.sortOrder < $1.sortOrder } }
    private var filteredTerms: [WorldTerm] {
        let categoryFilteredTerms = categoryFilter.map { category in
            terms.filter { $0.termCategory == category }
        } ?? terms
        return V5SettingsSearch.worldTerms(categoryFilteredTerms, matching: searchText)
    }

    var body: some View {
        List {
            ForEach(filteredTerms) { term in
                Button {
                    newlyCreatedTermID = nil
                    editingTerm = term
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(term.name.isEmpty ? "未命名條目" : term.name)
                                .font(.headline)
                            if let termCategory = term.termCategory, !termCategory.isEmpty {
                                Text(termCategory)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(term.termDescription.isEmpty ? "尚無簡介" : term.termDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                offsets.map { filteredTerms[$0] }.forEach { settingsStore.deleteWorldTerm($0, bookID: book.id) }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                Picker("分類篩選", selection: $categoryFilter) {
                    Text("全部分類").tag(String?.none)
                    ForEach(WorldTermCategory.allCases) { category in
                        Text(category.rawValue).tag(String?.some(category.rawValue))
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button {
                    let term = settingsStore.createWorldTerm(bookID: book.id)
                    newlyCreatedTermID = term.id
                    editingTerm = term
                } label: {
                    Label("新增條目", systemImage: "plus")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .overlay {
            if terms.isEmpty {
                ContentUnavailableView("尚無世界條目", systemImage: "book.closed", description: Text("使用上方的「新增條目」建立第一筆世界設定。"))
            } else if filteredTerms.isEmpty {
                ContentUnavailableView("找不到世界條目", systemImage: "magnifyingglass", description: Text("請嘗試其他搜尋關鍵字或分類。"))
            }
        }
        .searchable(text: $searchText, prompt: "搜尋條目、別名、分類或簡介")
        .sheet(item: $editingTerm, onDismiss: { newlyCreatedTermID = nil }) { term in
            WorldTermDetailView(
                term: term,
                book: book,
                shouldFocusName: term.id == newlyCreatedTermID
            )
        }
    }
}

struct PlaceDetailView: View {
    @Bindable var place: Place
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(V5SettingsStore.self) private var settingsStore
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("編輯地點").font(.headline)
                Spacer()
                Button("刪除", role: .destructive) { showingDeleteConfirmation = true }
                Button("完成") {
                    settingsStore.save()
                    dismiss()
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("地點名稱", text: $place.name)
                        .textFieldStyle(.roundedBorder)
                    TextField("其他名稱（舊名、俗稱或不同語言名稱）", text: textBinding(\.alternateNames))
                        .textFieldStyle(.roundedBorder)
                    TextField("地點類型（例如城市、建築、自然地景）", text: textBinding(\.placeType))
                        .textFieldStyle(.roundedBorder)
                    settingTextArea(title: "簡介", detail: "列表與快速查找使用的短摘要。", text: $place.placeDescription)
                    settingTextArea(title: "詳細描述", detail: "可記錄外觀、氣候、文化、資源、危險與氛圍。", text: textBinding(\.detailedDescription), minHeight: 130)
                    settingTextArea(title: "備註", detail: "作者寫作時需要記得的內部資訊。", text: textBinding(\.notes))
                }
            }
        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 560)
        .onDisappear { settingsStore.save() }
        .confirmationDialog("確定要刪除這個地點嗎？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("刪除地點", role: .destructive) {
                settingsStore.deletePlace(place, bookID: book.id)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func settingTextArea(title: String, detail: String, text: Binding<String>, minHeight: CGFloat = 90) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
        }
    }

    private func textBinding(_ keyPath: ReferenceWritableKeyPath<Place, String?>) -> Binding<String> {
        Binding(
            get: { place[keyPath: keyPath] ?? "" },
            set: { place[keyPath: keyPath] = $0 }
        )
    }
}

struct WorldTermDetailView: View {
    @Bindable var term: WorldTerm
    let book: Book
    let shouldFocusName: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(V5SettingsStore.self) private var settingsStore
    @State private var showingDeleteConfirmation = false
    @State private var saveErrorMessage: String?
    @State private var showingGovernmentPresets = false
    @State private var showingBeliefPresets = false
    @State private var showingTechnologyPresets = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        let appliedPreset = GovernmentPreset.matching(term)
        let appliedBeliefPreset = BeliefPreset.matching(term)
        let appliedTechnologyPreset = TechnologyPreset.matching(term)
        let guidance = WorldTermContentGuidance.forCategory(term.termCategory)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("編輯世界條目").font(.headline)
                Spacer()
                Button("刪除", role: .destructive) { showingDeleteConfirmation = true }
                Button("完成") {
                    if settingsStore.saveAndReport() {
                        dismiss()
                    } else {
                        saveErrorMessage = settingsStore.persistenceErrorMessage ?? "請稍後再試。"
                    }
                }
            }

            if let appliedPreset {
                GovernmentPresetDetailView(preset: appliedPreset)
            } else if let appliedBeliefPreset {
                BeliefPresetDetailView(preset: appliedBeliefPreset)
            } else if let appliedTechnologyPreset {
                TechnologyPresetDetailView(preset: appliedTechnologyPreset)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                    TextField("條目名稱", text: $term.name)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFocused)
                    TextField("其他名稱（別稱、舊稱、縮寫或翻譯）", text: textBinding(\.alternateNames))
                        .textFieldStyle(.roundedBorder)
                    Picker("分類", selection: categoryBinding) {
                        Text("未分類").tag(String?.none)
                        ForEach(WorldTermCategory.allCases) { category in
                            Text(category.rawValue).tag(String?.some(category.rawValue))
                        }
                        if let legacyCategory = term.termCategory,
                           !legacyCategory.isEmpty,
                           WorldTermCategory(rawValue: legacyCategory) == nil {
                            Text("既有分類：\(legacyCategory)")
                                .tag(String?.some(legacyCategory))
                        }
                    }
                    if term.termCategory == WorldTermCategory.institution.rawValue {
                        Button("選擇並套用政體", systemImage: "building.columns") {
                            showingGovernmentPresets = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if term.termCategory == WorldTermCategory.belief.rawValue {
                        Button("選擇並套用信仰", systemImage: "hands.sparkles") {
                            showingBeliefPresets = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if term.termCategory == WorldTermCategory.technology.rawValue {
                        Button("選擇並套用技術階段", systemImage: "gearshape.2") {
                            showingTechnologyPresets = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if let legacyCategory = term.termCategory,
                       !legacyCategory.isEmpty,
                       WorldTermCategory(rawValue: legacyCategory) == nil {
                        Text("這是舊版自由文字分類；選擇上方分類後即可改用有限分類。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    settingTextArea(title: "簡介", detail: "列表與快速查找使用的短定義。", text: $term.termDescription)
                    settingTextArea(title: "核心定義", detail: guidance.coreDefinition, text: textBinding(\.detailedDescription), minHeight: 130)
                    settingTextArea(title: "運作與表現", detail: guidance.operationAndExpression, text: textBinding(\.operationAndExpression), minHeight: 110)
                    settingTextArea(title: "限制、差異與例外", detail: guidance.limitationsAndExceptions, text: textBinding(\.limitationsAndExceptions), minHeight: 110)
                    settingTextArea(title: "世界影響", detail: guidance.worldImpact, text: textBinding(\.worldImpact), minHeight: 110)
                    settingTextArea(title: "使用範例", detail: "可記錄對話、敘述或世界中的實際用法。", text: textBinding(\.usageExamples))
                    settingTextArea(title: "備註", detail: "作者內部提醒或尚未定案的內容。", text: textBinding(\.notes))
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 480, minHeight: 620)
        .task {
            if shouldFocusName {
                isNameFocused = true
            }
        }
        .onDisappear { settingsStore.save() }
        .alert(
            "無法保存世界條目",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("好") { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "請稍後再試。")
        }
        .popover(isPresented: $showingGovernmentPresets, arrowEdge: .trailing) {
            GovernmentPresetCatalogView(allowsSelection: true) { preset in
                guard let preset else { return }
                preset.apply(to: term)
                if !settingsStore.saveAndReport() {
                    saveErrorMessage = settingsStore.persistenceErrorMessage ?? "請稍後再試。"
                }
            }
        }
        .popover(isPresented: $showingBeliefPresets, arrowEdge: .trailing) {
            BeliefPresetCatalogView(allowsSelection: true) { preset in
                guard let preset else { return }
                preset.apply(to: term)
                if !settingsStore.saveAndReport() {
                    saveErrorMessage = settingsStore.persistenceErrorMessage ?? "請稍後再試。"
                }
            }
        }
        .popover(isPresented: $showingTechnologyPresets, arrowEdge: .trailing) {
            TechnologyPresetCatalogView(allowsSelection: true) { preset in
                guard let preset else { return }
                preset.apply(to: term)
                if !settingsStore.saveAndReport() {
                    saveErrorMessage = settingsStore.persistenceErrorMessage ?? "請稍後再試。"
                }
            }
        }
        .confirmationDialog("確定要刪除這個世界條目嗎？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("刪除世界條目", role: .destructive) {
                settingsStore.deleteWorldTerm(term, bookID: book.id)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func settingTextArea(title: String, detail: String, text: Binding<String>, minHeight: CGFloat = 90) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: text)
                .frame(minHeight: minHeight)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
        }
    }

    private func textBinding(_ keyPath: ReferenceWritableKeyPath<WorldTerm, String?>) -> Binding<String> {
        Binding(
            get: { term[keyPath: keyPath] ?? "" },
            set: { term[keyPath: keyPath] = $0 }
        )
    }

    private var categoryBinding: Binding<String?> {
        Binding(
            get: { term.termCategory },
            set: { term.termCategory = $0 }
        )
    }
}

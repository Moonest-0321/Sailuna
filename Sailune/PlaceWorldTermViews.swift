import SwiftUI
import SwiftData

struct PlaceListView: View {
    let book: Book
    let currentSection: Section?
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @State private var searchText = ""
    @State private var showCurrentSectionOnly = false
    @State private var editingPlace: Place?
    @State private var deleteTarget: Place?

    private var places: [Place] { settingsStore.places(for: book.id).sorted { $0.sortOrder < $1.sortOrder } }
    private var referencedPlaces: [Place] {
        places.filter { InspectorSectionNameMatcher.matches(name: $0.name, in: currentSection) }
    }
    private var filteredPlaces: [Place] {
        V5SettingsSearch.places(
            showCurrentSectionOnly && currentSection != nil ? referencedPlaces : places,
            matching: searchText
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorLinkedItemsRow(
                title: "本節連結地點",
                entries: referencedPlaces.map { InspectorLinkedEntry(id: $0.id, name: $0.name.isEmpty ? "未命名地點" : $0.name) },
                onOpen: { id in editingPlace = places.first(where: { $0.id == id }) }
            )
            SailuneSearchField(placeholder: "搜尋地點", text: $searchText)
            if currentSection != nil {
                Toggle("只顯示本節相關地點", isOn: $showCurrentSectionOnly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            List {
                ForEach(filteredPlaces) { place in
                    HStack(spacing: 8) {
                        Button { editingPlace = place } label: {
                            Text(place.name.isEmpty ? "未命名地點" : place.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        if let placeType = place.placeType, !placeType.isEmpty {
                            Text(placeType)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !bookIsReadOnly { Button(SailuneActionCopy.delete, role: .destructive) { deleteTarget = place }.buttonStyle(.plain) }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.workspacePanelBackground)
            if !bookIsReadOnly {
                Button("新增地點", systemImage: SailuneSymbol.add.systemName) {
                    editingPlace = settingsStore.createPlace(bookID: book.id)
                }.padding(10)
            }
        }
        .sheet(item: $editingPlace) { place in
            PlaceDetailView(place: place, book: book)
        }
        .confirmationDialog("刪除地點？", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { place in
            Button(SailuneActionCopy.delete, role: .destructive) {
                settingsStore.deletePlace(place, bookID: book.id)
                deleteTarget = nil
            }
            Button(SailuneActionCopy.cancel, role: .cancel) { deleteTarget = nil }
        }
    }
}

struct WorldTermListView: View {
    let book: Book
    let currentSection: Section?
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @State private var searchText = ""
    @State private var showCurrentSectionOnly = false
    @State private var categoryFilter: String?
    @State private var editingTerm: WorldTerm?
    @State private var newlyCreatedTermID: UUID?
    @State private var deleteTarget: WorldTerm?

    private var terms: [WorldTerm] { settingsStore.worldTerms(for: book.id).sorted { $0.sortOrder < $1.sortOrder } }
    private var referencedTerms: [WorldTerm] {
        terms.filter { InspectorSectionNameMatcher.matches(name: $0.name, in: currentSection) }
    }
    private var filteredTerms: [WorldTerm] {
        let sectionFilteredTerms = showCurrentSectionOnly && currentSection != nil ? referencedTerms : terms
        let categoryFilteredTerms = categoryFilter.map { category in
            sectionFilteredTerms.filter { $0.termCategory == category }
        } ?? sectionFilteredTerms
        return V5SettingsSearch.worldTerms(categoryFilteredTerms, matching: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorLinkedItemsRow(
                title: "本節連結世界條目",
                entries: referencedTerms.map { InspectorLinkedEntry(id: $0.id, name: $0.name.isEmpty ? "未命名條目" : $0.name) },
                onOpen: { id in
                    newlyCreatedTermID = nil
                    editingTerm = terms.first(where: { $0.id == id })
                }
            )
            SailuneSearchField(placeholder: "搜尋世界條目", text: $searchText)
            if currentSection != nil {
                Toggle("只顯示本節相關世界條目", isOn: $showCurrentSectionOnly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            HStack(spacing: 10) {
                Picker("分類篩選", selection: $categoryFilter) {
                    Text("全部分類").tag(String?.none)
                    ForEach(WorldTermCategory.allCases) { category in
                        Text(category.rawValue).tag(String?.some(category.rawValue))
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            List {
                ForEach(filteredTerms) { term in
                    HStack(spacing: 8) {
                        Button {
                            newlyCreatedTermID = nil
                            editingTerm = term
                        } label: {
                            Text(term.name.isEmpty ? "未命名條目" : term.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        if let termCategory = term.termCategory, !termCategory.isEmpty {
                            Text(termCategory)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !bookIsReadOnly { Button(SailuneActionCopy.delete, role: .destructive) { deleteTarget = term }.buttonStyle(.plain) }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.workspacePanelBackground)
            if !bookIsReadOnly { Button {
                let term = settingsStore.createWorldTerm(bookID: book.id)
                newlyCreatedTermID = term.id
                editingTerm = term
            } label: { Label("新增條目", systemImage: SailuneSymbol.add.systemName) }.padding(10) }
        }
        .sheet(item: $editingTerm, onDismiss: { newlyCreatedTermID = nil }) { term in
            WorldTermDetailView(
                term: term,
                book: book,
                shouldFocusName: term.id == newlyCreatedTermID
            )
        }
        .confirmationDialog("刪除世界條目？", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { term in
            Button(SailuneActionCopy.delete, role: .destructive) {
                settingsStore.deleteWorldTerm(term, bookID: book.id)
                deleteTarget = nil
            }
            Button(SailuneActionCopy.cancel, role: .cancel) { deleteTarget = nil }
        }
    }
}

struct PlaceDetailView: View {
    @Bindable var place: Place
    let book: Book
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let onBack {
                    Button(action: onBack) { Label("返回地點", systemImage: SailuneSymbol.back.systemName) }
                        .buttonStyle(.plain)
                } else {
                    Text("編輯地點").font(.headline)
                }
                Spacer()
                if !bookIsReadOnly { Button(SailuneActionCopy.delete, role: .destructive) { showingDeleteConfirmation = true } }
                Button(SailuneActionCopy.done, action: finish)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SailuneFormTextField(title: "地點名稱", text: $place.name)
                    SailuneFormTextField(title: "其他名稱（舊名、俗稱或不同語言名稱）", text: textBinding(\.alternateNames))
                    SailuneFormTextField(title: "地點類型（例如城市、建築、自然地景）", text: textBinding(\.placeType))
                    settingTextArea(title: "簡介", detail: "列表與快速查找使用的短摘要。", text: $place.placeDescription)
                    settingTextArea(title: "詳細描述", detail: "可記錄外觀、氣候、文化、資源、危險與氛圍。", text: textBinding(\.detailedDescription), minHeight: 130)
                    settingTextArea(title: "備註", detail: "作者寫作時需要記得的內部資訊。", text: textBinding(\.notes))
                }
            }
        }
        .padding(16)
        .frame(minWidth: onBack == nil ? 480 : 0, minHeight: onBack == nil ? 560 : 320)
        .onDisappear { if !bookIsReadOnly { settingsStore.save() } }
        .confirmationDialog("確定要刪除這個地點嗎？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button(SailuneActionCopy.deletePlace, role: .destructive) {
                settingsStore.deletePlace(place, bookID: book.id)
                finish()
            }
            Button(SailuneActionCopy.cancel, role: .cancel) {}
        }
    }

    @ViewBuilder
    private func settingTextArea(title: String, detail: String, text: Binding<String>, minHeight: CGFloat = 90) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            SailuneBorderedTextEditor(text: text, minHeight: minHeight)
        }
    }

    private func textBinding(_ keyPath: ReferenceWritableKeyPath<Place, String?>) -> Binding<String> {
        Binding(
            get: { place[keyPath: keyPath] ?? "" },
            set: { place[keyPath: keyPath] = $0 }
        )
    }

    private func finish() {
        if !bookIsReadOnly { settingsStore.save() }
        if let onBack { onBack() } else { dismiss() }
    }
}

struct WorldTermDetailView: View {
    @Bindable var term: WorldTerm
    let book: Book
    let shouldFocusName: Bool
    var onBack: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @State private var showingDeleteConfirmation = false
    @State private var saveErrorMessage: String?
    @State private var showingGovernmentPresets = false
    @State private var showingBeliefPresets = false
    @State private var showingTechnologyPresets = false
    @State private var showingResourcePresets = false
    @State private var showingPeoplePresets = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        let appliedPreset = GovernmentPreset.matching(term)
        let appliedBeliefPreset = BeliefPreset.matching(term)
        let appliedTechnologyPreset = TechnologyPreset.matching(term)
        let appliedResourcePreset = ResourcePreset.matching(term)
        let appliedPeoplePreset = PeoplePreset.matching(term)
        let guidance = WorldTermContentGuidance.forCategory(term.termCategory)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let onBack {
                    Button(action: onBack) { Label("返回條目", systemImage: SailuneSymbol.back.systemName) }
                        .buttonStyle(.plain)
                } else {
                    Text("編輯世界條目").font(.headline)
                }
                Spacer()
                Button(SailuneActionCopy.delete, role: .destructive) { showingDeleteConfirmation = true }
                Button(SailuneActionCopy.done) {
                    if settingsStore.saveAndReport() {
                        finish()
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
            } else if let appliedResourcePreset {
                ResourcePresetDetailView(preset: appliedResourcePreset)
            } else if let appliedPeoplePreset {
                PeoplePresetDetailView(preset: appliedPeoplePreset)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                    TextField("條目名稱", text: $term.name)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFocused)
                    SailuneFormTextField(title: "其他名稱（別稱、舊稱、縮寫或翻譯）", text: textBinding(\.alternateNames))
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
                        Button("選擇並套用政體", systemImage: SailuneSymbol.government.systemName) {
                            showingGovernmentPresets = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if term.termCategory == WorldTermCategory.belief.rawValue {
                        Button("選擇並套用信仰", systemImage: SailuneSymbol.belief.systemName) {
                            showingBeliefPresets = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if term.termCategory == WorldTermCategory.technology.rawValue {
                        Button("選擇並套用技術階段", systemImage: SailuneSymbol.technology.systemName) {
                            showingTechnologyPresets = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if term.termCategory == WorldTermCategory.resource.rawValue {
                        Button("選擇並套用資源", systemImage: SailuneSymbol.resource.systemName) {
                            showingResourcePresets = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if term.termCategory == WorldTermCategory.people.rawValue {
                        Button("選擇並套用族群／種族", systemImage: SailuneSymbol.people.systemName) {
                            showingPeoplePresets = true
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
        .frame(minWidth: onBack == nil ? 480 : 0, minHeight: onBack == nil ? 620 : 320)
        .task {
            if shouldFocusName {
                isNameFocused = true
            }
        }
        .onDisappear { if !bookIsReadOnly { settingsStore.save() } }
        .alert(
            "無法保存世界條目",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button(SailuneActionCopy.acknowledge) { saveErrorMessage = nil }
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
        .popover(isPresented: $showingResourcePresets, arrowEdge: .trailing) {
            ResourcePresetCatalogView(allowsSelection: true) { preset in
                guard let preset else { return }
                preset.apply(to: term)
                if !settingsStore.saveAndReport() {
                    saveErrorMessage = settingsStore.persistenceErrorMessage ?? "請稍後再試。"
                }
            }
        }
        .popover(isPresented: $showingPeoplePresets, arrowEdge: .trailing) {
            PeoplePresetCatalogView(allowsSelection: true) { preset in
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
                finish()
            }
            Button(SailuneActionCopy.cancel, role: .cancel) {}
        }
    }

    @ViewBuilder
    private func settingTextArea(title: String, detail: String, text: Binding<String>, minHeight: CGFloat = 90) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
            SailuneBorderedTextEditor(text: text, minHeight: minHeight)
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

    private func finish() {
        if let onBack { onBack() } else { dismiss() }
    }
}

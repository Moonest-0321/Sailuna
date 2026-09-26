import SwiftUI
import SwiftData

struct SailuneAIChatSidebarView: View {
    let book: Book
    let model: SailuneAIChatViewModel
    let onSubmit: (SailuneAISubmission) async -> Bool
    let onClose: () -> Void

    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]
    @Query(sort: \Item.name) private var allItems: [Item]
    @Query(sort: \CharacterAbility.name) private var allAbilities: [CharacterAbility]
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.sectionUnit) private var sectionUnit
    @State private var draft = ""
    @State private var selectedScope: SailuneAIReadingScope?
    @State private var characterTemplate: SailuneAICharacterTemplateSelection?
    @State private var showingCharacterTemplate = false
    @State private var showingReadingRange = false
    @State private var showingSettingAnalysis = false
    @State private var showingCharacterComparison = false
    @State private var showingConversations = false
    @State private var conversationToDeleteID: UUID?
    @State private var templateSectionID: UUID?
    @State private var templateCharacterID: UUID?
    @State private var templateCategories = Set(SailuneAICharacterCategory.allCases)
    @State private var scopeLevel: ScopeLevel = .section
    @State private var scopeSectionID: UUID?
    @State private var scopeVolumeID: UUID?
    @State private var settingKind: SailuneAISettingKind = .character
    @State private var settingTargetID: UUID?
    @State private var settingDimensions = Set(SailuneAISettingDimension.all(for: .character))
    @State private var comparisonCharacterID: UUID?
    @State private var comparisonCategories = Set(SailuneAICharacterCategory.allCases)
    @State private var isSubmitting = false

    private enum ScopeLevel: String, CaseIterable, Identifiable {
        case section = "單節"
        case volume = "單卷"
        case wholeBook = "全書"
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AI 助手")
                    .font(.headline)
                Spacer()
                Button {
                    showingConversations = true
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.plain)
                .help(SailuneAccessibilityCopy.switchConversation)
                .accessibilityLabel(SailuneAccessibilityCopy.switchConversation)
                .popover(isPresented: $showingConversations) {
                    conversationPicker
                }
                Button(action: onClose) {
                    Image(systemName: SailuneSymbol.close.systemName)
                }
                .buttonStyle(.plain)
                .help(SailuneAccessibilityCopy.closeAIAssistant)
                .accessibilityLabel(SailuneAccessibilityCopy.closeAIAssistant)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(model.messages) { message in
                            messageView(message)
                        }
                        if model.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在回覆…")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Color.clear.frame(height: 1).id("chat-bottom")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .onChange(of: model.messages.count) { _, _ in
                    proxy.scrollTo("chat-bottom", anchor: .bottom)
                }
            }

            Divider()

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
            }

            if let characterTemplate {
                HStack(alignment: .top, spacing: 6) {
                    Label(templateSummary(characterTemplate), systemImage: SailuneSymbol.aiCharacterTemplate.systemName)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Button {
                        self.characterTemplate = nil
                    } label: {
                        Image(systemName: SailuneSymbol.removeSelection.systemName)
                    }
                    .buttonStyle(.plain)
                    .help(SailuneAccessibilityCopy.removeCharacterTemplate)
                    .accessibilityLabel(SailuneAccessibilityCopy.removeCharacterTemplate)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            } else if let selectedScope {
                HStack(spacing: 6) {
                    Label(selectedScopeTitle(selectedScope), systemImage: SailuneSymbol.aiReadingScope.systemName)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("生成摘要") {
                        submit(.summary(selectedScope))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting || model.isLoading)
                    Button {
                        self.selectedScope = nil
                    } label: {
                        Image(systemName: SailuneSymbol.removeSelection.systemName)
                    }
                    .buttonStyle(.plain)
                    .help(SailuneAccessibilityCopy.removeReadingScope)
                    .accessibilityLabel(SailuneAccessibilityCopy.removeReadingScope)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Menu {
                    Button("加入閱讀範圍…", systemImage: SailuneSymbol.aiReadingScope.systemName) {
                        prepareScopeSelection()
                        showingReadingRange = true
                    }
                    Button("設定分析…", systemImage: "list.clipboard") {
                        prepareScopeSelection()
                        settingKind = .character
                        settingTargetID = bookCharacters.first?.id
                        settingDimensions = Set(SailuneAISettingDimension.all(for: .character))
                        showingSettingAnalysis = true
                    }
                    Button("角色比較…", systemImage: "person.crop.rectangle.stack") {
                        prepareScopeSelection()
                        comparisonCharacterID = bookCharacters.first?.id
                        comparisonCategories = Set(SailuneAICharacterCategory.allCases)
                        showingCharacterComparison = true
                    }
                    Button("角色資訊整理…", systemImage: SailuneSymbol.aiCharacterTemplate.systemName) {
                        let sections = BookStructure.orderedSections(in: book)
                        let characters = bookCharacters
                        templateSectionID = sections.first?.id
                        templateCharacterID = characters.first?.id
                        templateCategories = Set(SailuneAICharacterCategory.allCases)
                        showingCharacterTemplate = true
                    }
                } label: {
                    Image(systemName: SailuneSymbol.add.systemName)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 24, minHeight: 24)
                .help("加入\(sectionUnit.unitLabel)或角色整理模板")
                .accessibilityLabel("加入內容")
                .sheet(isPresented: $showingReadingRange) {
                    readingRangeSheet
                }
                .sheet(isPresented: $showingSettingAnalysis) {
                    settingAnalysisSheet
                }
                .sheet(isPresented: $showingCharacterComparison) {
                    characterComparisonSheet
                }
                .sheet(isPresented: $showingCharacterTemplate) {
                    characterTemplateSheet
                }

                TextField("輸入訊息…", text: $draft, axis: .vertical)
                    .disabled(bookIsReadOnly)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                    .accessibilityLabel("輸入給 AI 助手的訊息")

                if model.isLoading || isSubmitting {
                    Button { model.cancel() } label: {
                        Image(systemName: "stop.fill")
                    }
                    .help("取消請求")
                    .accessibilityLabel("取消 AI 請求")
                } else if !bookIsReadOnly {
                    Button(action: send) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help(SailuneAccessibilityCopy.sendMessage)
                    .accessibilityLabel(SailuneAccessibilityCopy.sendMessage)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: model.selectedConversationID) { _, _ in
            draft = ""
            selectedScope = nil
            characterTemplate = nil
            showingReadingRange = false
            showingSettingAnalysis = false
            showingCharacterComparison = false
            isSubmitting = false
        }
        .alert("刪除對話？", isPresented: Binding(
            get: { conversationToDeleteID != nil },
            set: { if !$0 { conversationToDeleteID = nil } }
        )) {
            if !bookIsReadOnly { Button("刪除對話", role: .destructive) {
                if let conversationToDeleteID {
                    model.deleteConversation(conversationToDeleteID)
                }
                conversationToDeleteID = nil
            } }
            Button(SailuneActionCopy.cancel, role: .cancel) {
                conversationToDeleteID = nil
            }
        } message: {
            Text("這段對話及其中已加入的正文與設定快照會永久刪除。")
        }
    }

    private var conversationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("對話")
                    .font(.headline)
                Spacer()
                if !bookIsReadOnly { Button {
                    model.newConversation()
                    showingConversations = false
                } label: {
                    Image(systemName: SailuneSymbol.add.systemName)
                }
                .buttonStyle(.plain)
                .help(SailuneAccessibilityCopy.addConversation)
                .accessibilityLabel(SailuneAccessibilityCopy.addConversation) }
            }
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(model.conversations) { conversation in
                        HStack(spacing: 8) {
                            Button {
                                model.selectConversation(conversation.id)
                                showingConversations = false
                            } label: {
                                HStack(spacing: 6) {
                                    if conversation.id == model.selectedConversationID {
                                        Image(systemName: SailuneSymbol.selected.systemName)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(conversation.title)
                                            .lineLimit(1)
                                        Text(conversation.updatedAt, format: .dateTime.month().day().hour().minute())
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Button {
                                showingConversations = false
                                conversationToDeleteID = conversation.id
                            } label: {
                                Image(systemName: SailuneSymbol.delete.systemName)
                            }
                            .buttonStyle(.plain)
                            .help("刪除對話")
                            .accessibilityLabel("刪除對話：\(conversation.title)")
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
        .padding(14)
        .frame(width: 290)
    }

    private func messageView(_ message: SailuneAIMessage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user ? "你" : "AI 助手")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let attachment = message.attachment {
                DisclosureGroup(attachmentDisclosureTitle(attachment)) {
                    Text(attachment.content)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .font(.caption)
            }
            Text(message.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(message.evidence) { evidence in
                VStack(alignment: .leading, spacing: 3) {
                    Text(evidence.isVerified ? "本節原文" : "來源未驗證")
                        .font(.caption2)
                        .foregroundStyle(evidence.isVerified ? Color.secondary : Color.orange)
                    Text(evidence.quote)
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            message.role == .user ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private func send() {
        if let characterTemplate {
            submit(.characterSectionTemplate(draft, characterTemplate))
        } else if let selectedScope {
            submit(.readQuestion(draft, selectedScope))
        } else {
            submit(.chat(draft))
        }
    }

    private func submit(_ submission: SailuneAISubmission, onSuccess: @escaping () -> Void = {}) {
        guard !isSubmitting, !model.isLoading else { return }
        isSubmitting = true
        Task { @MainActor in
            let succeeded = await onSubmit(submission)
            if succeeded {
                draft = ""
                selectedScope = nil
                characterTemplate = nil
                onSuccess()
            }
            isSubmitting = false
        }
    }

    private func prepareScopeSelection() {
        let sections = BookStructure.orderedSections(in: book)
        let volumes = BookStructure.orderedVolumes(in: book)
        scopeLevel = .section
        scopeSectionID = sections.first?.id
        scopeVolumeID = volumes.first?.id
    }

    private var selectedScopeForForm: SailuneAIReadingScope? {
        switch scopeLevel {
        case .section:
            guard let id = scopeSectionID,
                  BookStructure.orderedSections(in: book).contains(where: { $0.id == id }) else { return nil }
            return .section(id)
        case .volume:
            guard let id = scopeVolumeID,
                  BookStructure.orderedVolumes(in: book).contains(where: { $0.id == id }) else { return nil }
            return .volume(id)
        case .wholeBook:
            return .wholeBook
        }
    }

    private var scopeFields: some View {
        Group {
            Picker("閱讀範圍", selection: $scopeLevel) {
                ForEach(ScopeLevel.allCases) { level in
                    Text(level == .section ? "單\(sectionUnit.unitLabel)" : level.rawValue).tag(level)
                }
            }
            if scopeLevel == .section {
                Picker(sectionUnit.unitLabel, selection: $scopeSectionID) {
                    Text("選擇\(sectionUnit.unitLabel)").tag(Optional<UUID>.none)
                    ForEach(BookStructure.orderedSections(in: book), id: \.id) { section in
                        Text(selectedSectionTitle(for: section.id)).tag(Optional(section.id))
                    }
                }
            } else if scopeLevel == .volume {
                Picker("卷次", selection: $scopeVolumeID) {
                    Text("選擇卷次").tag(Optional<UUID>.none)
                    ForEach(BookStructure.orderedVolumes(in: book), id: \.id) { volume in
                        Text(volume.title.isEmpty ? "未命名卷" : volume.title).tag(Optional(volume.id))
                    }
                }
            } else {
                LabeledContent("作品", value: book.title.isEmpty ? "未命名作品" : book.title)
            }
        }
    }

    private var readingRangeSheet: some View {
        NavigationStack {
            Form {
                scopeFields
                if let selectedScopeForForm {
                    Text("範圍：\(selectedScopeTitle(selectedScopeForForm))")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("加入閱讀範圍")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SailuneActionCopy.cancel) { showingReadingRange = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入範圍") {
                        guard let selectedScopeForForm else { return }
                        selectedScope = selectedScopeForForm
                        characterTemplate = nil
                        showingReadingRange = false
                    }
                    .disabled(selectedScopeForForm == nil)
                }
            }
        }
        .frame(minWidth: 390, minHeight: 300)
    }

    private var settingAnalysisSheet: some View {
        NavigationStack {
            Form {
                scopeFields
                Picker("設定類型", selection: $settingKind) {
                    ForEach(SailuneAISettingKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .onChange(of: settingKind) { _, kind in
                    settingTargetID = analysisTargets(for: kind).first?.id
                    settingDimensions = Set(SailuneAISettingDimension.all(for: kind))
                }
                if analysisTargets(for: settingKind).isEmpty {
                    Text("目前作品沒有已建立的\(settingKind.rawValue)資料。")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("目標", selection: $settingTargetID) {
                        Text("選擇既有\(settingKind.rawValue)").tag(Optional<UUID>.none)
                        ForEach(analysisTargets(for: settingKind)) { target in
                            Text(target.title).tag(Optional(target.id))
                        }
                    }
                    SwiftUI.Section("分析維度") {
                        ForEach(SailuneAISettingDimension.all(for: settingKind), id: \.self) { dimension in
                            Toggle(dimension.title, isOn: Binding(
                                get: { settingDimensions.contains(dimension) },
                                set: { isSelected in
                                    if isSelected { settingDimensions.insert(dimension) }
                                    else { settingDimensions.remove(dimension) }
                                }
                            ))
                        }
                    }
                }
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("設定分析")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SailuneActionCopy.cancel) { showingSettingAnalysis = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("開始分析") { runSettingAnalysis() }
                        .disabled(selectedScopeForForm == nil || settingTargetID == nil || settingDimensions.isEmpty || isSubmitting || model.isLoading)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 480)
    }

    private var characterComparisonSheet: some View {
        NavigationStack {
            Form {
                scopeFields
                if bookCharacters.isEmpty {
                    Text("目前作品沒有已建立的角色資料。")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("角色", selection: $comparisonCharacterID) {
                        Text("選擇既有角色").tag(Optional<UUID>.none)
                        ForEach(bookCharacters, id: \.id) { character in
                            Text(character.realName.isEmpty ? "未命名角色" : character.realName).tag(Optional(character.id))
                        }
                    }
                    SwiftUI.Section("比較分類") {
                        ForEach(SailuneAICharacterCategory.allCases) { category in
                            Toggle(category.rawValue, isOn: Binding(
                                get: { comparisonCategories.contains(category) },
                                set: { isSelected in
                                    if isSelected { comparisonCategories.insert(category) }
                                    else { comparisonCategories.remove(category) }
                                }
                            ))
                        }
                    }
                }
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("角色比較")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SailuneActionCopy.cancel) { showingCharacterComparison = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("開始比較") { runCharacterComparison() }
                        .disabled(selectedScopeForForm == nil || comparisonCharacterID == nil || comparisonCategories.isEmpty || isSubmitting || model.isLoading)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 480)
    }

    private struct AnalysisTarget: Identifiable {
        let id: UUID
        let title: String
    }

    private func analysisTargets(for kind: SailuneAISettingKind) -> [AnalysisTarget] {
        switch kind {
        case .character:
            return bookCharacters.map { AnalysisTarget(id: $0.id, title: $0.realName.isEmpty ? "未命名角色" : $0.realName) }
        case .item:
            return allItems.filter { $0.book?.id == book.id }.map { AnalysisTarget(id: $0.id, title: $0.name.isEmpty ? "未命名物品" : $0.name) }
        case .ability:
            let bookIDs = abilityStore.resolvedBookIDs(for: allAbilities)
            return allAbilities.filter { bookIDs[$0.id] == book.id }
                .map { AnalysisTarget(id: $0.id, title: $0.name.isEmpty ? "未命名能力" : $0.name) }
        case .power:
            return settingsStore.powers(for: book.id).map { AnalysisTarget(id: $0.id, title: $0.name.isEmpty ? "未命名勢力" : $0.name) }
        }
    }

    private func runSettingAnalysis() {
        guard let scope = selectedScopeForForm, let settingTargetID else { return }
        let selection = SailuneAISettingAnalysisSelection(
            scope: scope,
            kind: settingKind,
            targetID: settingTargetID,
            dimensions: settingDimensions
        )
        submit(.settingAnalysis(selection)) { showingSettingAnalysis = false }
    }

    private func runCharacterComparison() {
        guard let scope = selectedScopeForForm, let comparisonCharacterID else { return }
        let selection = SailuneAICharacterComparisonSelection(
            scope: scope,
            characterID: comparisonCharacterID,
            categories: comparisonCategories
        )
        submit(.characterComparison(selection)) { showingCharacterComparison = false }
    }

    private func selectedScopeTitle(_ scope: SailuneAIReadingScope) -> String {
        switch scope {
        case .section(let id): selectedSectionTitle(for: id)
        case .volume(let id):
            BookStructure.orderedVolumes(in: book).first(where: { $0.id == id }).map {
                $0.title.isEmpty ? "未命名卷" : $0.title
            } ?? "卷次已不存在"
        case .wholeBook: book.title.isEmpty ? "全書" : book.title
        }
    }

    private var bookCharacters: [Character] {
        allCharacters.filter { $0.book?.id == book.id }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var characterTemplateSheet: some View {
        NavigationStack {
            Form {
                Picker(sectionUnit.unitLabel, selection: $templateSectionID) {
                    ForEach(BookStructure.orderedSections(in: book), id: \.id) { section in
                        Text(selectedSectionTitle(for: section.id)).tag(Optional(section.id))
                    }
                }
                Picker("角色", selection: $templateCharacterID) {
                    ForEach(bookCharacters, id: \.id) { character in
                        Text(character.realName.isEmpty ? "未命名角色" : character.realName).tag(Optional(character.id))
                    }
                }
                SwiftUI.Section("整理分類") {
                    ForEach(SailuneAICharacterCategory.allCases) { category in
                        Toggle(category.rawValue, isOn: Binding(
                            get: { templateCategories.contains(category) },
                            set: { selected in
                                if selected { templateCategories.insert(category) }
                                else { templateCategories.remove(category) }
                            }
                        ))
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("角色資訊整理")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SailuneActionCopy.cancel) { showingCharacterTemplate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("套用") {
                        guard let templateSectionID, let templateCharacterID, !templateCategories.isEmpty else { return }
                        characterTemplate = SailuneAICharacterTemplateSelection(
                            sectionID: templateSectionID,
                            characterID: templateCharacterID,
                            categories: templateCategories
                        )
                        showingCharacterTemplate = false
                    }
                    .disabled(templateSectionID == nil || templateCharacterID == nil || templateCategories.isEmpty)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 470)
    }

    private func templateSummary(_ template: SailuneAICharacterTemplateSelection) -> String {
        let characterName = bookCharacters.first(where: { $0.id == template.characterID })?.realName ?? "角色已不存在"
        let categories = template.categories.map(\.rawValue).sorted().joined(separator: "、")
        return "整理：\(selectedSectionTitle(for: template.sectionID))／\(characterName)・\(categories)"
    }

    private func attachmentDisclosureTitle(_ attachment: SailuneAISectionAttachment) -> String {
        switch attachment.kind {
        case .characterProfile: "已參照角色設定：\(attachment.title)"
        case .characterSectionTemplate: "角色整理依據：\(attachment.title)"
        case .readingSummary: "摘要依據：\(attachment.title)"
        case .settingAnalysis: "設定分析依據：\(attachment.title)"
        case .characterComparison: "角色比較依據：\(attachment.title)"
        case .section, .none: "已加入：\(attachment.title)"
        }
    }

    private func selectedSectionTitle(for sectionID: UUID) -> String {
        guard let section = BookStructure.orderedSections(in: book).first(where: { $0.id == sectionID }) else {
            return "\(sectionUnit.unitLabel)已不存在"
        }
        let volumeTitle = section.volume.map { $0.title.isEmpty ? "未命名卷" : $0.title } ?? "未命名卷"
        return "\(volumeTitle)／\(section.title.isEmpty ? sectionUnit.unnamedTitle : sectionUnit.displayTitle(section.title))"
    }
}

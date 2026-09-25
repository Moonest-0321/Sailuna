import SwiftUI
import SwiftData
import AppKit
import OSLog

private let abilityCreationLogger = Logger(subsystem: "com.MooNest.Sailune", category: "AbilityCreation")

struct AbilityDetailView: View {
    @Bindable var ability: CharacterAbility
    let book: Book
    let onBack: () -> Void
    let onOpenCharacter: (Character) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Query(sort: \Character.sortOrder) private var allCharacters: [Character]

    private var levels: [AbilityLevel] { abilityStore.levels.filter { $0.abilityID == ability.id }.sorted { $0.sortOrder < $1.sortOrder } }
    private var connections: [CharacterAbilityConnection] { abilityStore.connections.filter { $0.abilityID == ability.id } }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Button(action: onBack) { Label(SailuneActionCopy.back, systemImage: SailuneSymbol.back.systemName) }.buttonStyle(.plain); Spacer() }
                .padding(.horizontal, 12).padding(.vertical, 8).background(SailuneTheme.controlSurface)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label("能力設定", systemImage: SailuneSymbol.ability.systemName).font(.headline)
                    GroupBox("能力名稱") { SailuneFormTextField(title: "名稱", text: $ability.name) }
                    abilityLevels
                    GroupBox("連接角色") {
                        VStack(alignment: .leading, spacing: 7) {
                            if connections.isEmpty { Text("尚未連接角色；請到角色詳細資料連接能力。").font(.caption).foregroundStyle(.secondary) }
                            ForEach(connections) { connection in
                                let name = characterDisplayName(id: connection.characterID)
                                let level = levels.first { $0.id == connection.currentLevelID }?.name ?? "未設定等級"
                                HStack {
                                    if let character = allCharacters.first(where: { $0.id == connection.characterID }) {
                                        Button(name.isEmpty ? "未命名角色" : name) { onOpenCharacter(character) }
                                            .buttonStyle(.link)
                                    } else { Text(name.isEmpty ? "未命名角色" : name) }
                                    Spacer(); Text(level).foregroundStyle(.secondary)
                                }
                            }
                            Menu("連接角色") {
                                let connectedIDs = Set(connections.map(\.characterID))
                                ForEach(allCharacters.filter { $0.book?.id == book.id && !connectedIDs.contains($0.id) }) { character in
                                    Button(character.realName.isEmpty ? "未命名角色" : character.realName) {
                                        abilityStore.connect(characterID: character.id, abilityID: ability.id)
                                    }
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Button("刪除能力", systemImage: SailuneSymbol.delete.systemName, role: .destructive) { deleteAbility() }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
        }
        .onChange(of: ability.name) { ability.updatedAt = Date() }
        .onDisappear { if ability.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { ability.name = "未命名能力" } }
    }

    private var abilityLevels: some View {
        GroupBox("能力等級") {
            VStack(alignment: .leading, spacing: 8) {
                if levels.isEmpty { Text("尚未建立等級").font(.caption).foregroundStyle(.secondary) }
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    @Bindable var level = level
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(String(format: "%02d", index + 1))").monospacedDigit().foregroundStyle(.secondary)
                            SailuneFormTextField(title: "等級名稱", text: $level.name)
                            Button(role: .destructive) { abilityStore.deleteAbilityLevel(level) } label: { Image(systemName: SailuneSymbol.delete.systemName) }.buttonStyle(.plain)
                        }
                        SailuneFormTextField(title: "能力描述", text: $level.descriptionText)
                        SailuneFormTextField(title: "代價", text: $level.cost)
                        SailuneFormTextField(title: "其他", text: $level.note)
                    }
                    .padding(8).background(SailuneTheme.subtleSurface, in: RoundedRectangle(cornerRadius: 7))
                    .onChange(of: level.name) { level.updatedAt = Date() }
                    .onChange(of: level.descriptionText) { level.updatedAt = Date() }
                    .onChange(of: level.cost) { level.updatedAt = Date() }
                    .onChange(of: level.note) { level.updatedAt = Date() }
                }
                Button(SailuneActionCopy.addLevel, systemImage: SailuneSymbol.add.systemName) {
                    abilityStore.addLevel(abilityID: ability.id)
                }.buttonStyle(.borderless)
            }
        }
    }

    private func characterDisplayName(id: UUID) -> String {
        guard let character = allCharacters.first(where: { $0.id == id }) else { return "" }
        return character.realName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deleteAbility() {
        do {
            let outcome = try CrossStoreDeletionCoordinator.deleteAbility(
                ability, in: modelContext,
                abilityStore: abilityStore, settingsStore: settingsStore
            )
            if outcome.requiresRepair {
                presentDeletionMessage("能力已刪除，但部分附屬連結將在下次啟動修復。\n\n\(outcome.deferredCleanupErrors.joined(separator: "\n"))")
            }
            onBack()
        } catch {
            modelContext.rollback()
            presentDeletionMessage("能力未刪除。\n\n\(error.localizedDescription)")
        }
    }

    private func presentDeletionMessage(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "能力刪除未完成"
        alert.informativeText = message
        alert.runModal()
    }
}

struct AbilityListContainerView: View {
    let book: Book
    let currentSection: Section?
    let onOpen: (CharacterAbility) -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Query(sort: \CharacterAbility.createdAt) private var allAbilities: [CharacterAbility]
    @Query(sort: \Character.createdAt) private var allCharacters: [Character]
    @State private var searchText = ""
    @State private var showCurrentSectionOnly = false
    @State private var deleteTarget: CharacterAbility?
    @State private var deletionErrorMessage: String?
    @State private var creationErrorMessage: String?

    private var characters: [Character] { allCharacters.filter { $0.book?.id == book.id } }
    private var bookAbilities: [CharacterAbility] {
        let ids = Set(characters.map(\.id))
        return allAbilities.filter { ability in
            abilityStore.bookLinks.contains { $0.abilityID == ability.id && $0.bookID == book.id }
                || (ability.character.map { ids.contains($0.id) } ?? false)
        }
    }
    private var referencedAbilities: [CharacterAbility] {
        bookAbilities.filter { InspectorSectionNameMatcher.matches(name: $0.name, in: currentSection) }
    }
    private var abilities: [CharacterAbility] {
        let source = showCurrentSectionOnly && currentSection != nil ? referencedAbilities : bookAbilities
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return source }
        return source.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorLinkedItemsRow(
                title: "本節連結能力",
                entries: referencedAbilities.map { InspectorLinkedEntry(id: $0.id, name: $0.name.isEmpty ? "未命名能力" : $0.name) },
                onOpen: { id in if let ability = bookAbilities.first(where: { $0.id == id }) { onOpen(ability) } }
            )
            SailuneSearchField(placeholder: "搜尋能力", text: $searchText)
            if currentSection != nil {
                Toggle("只顯示本節相關能力", isOn: $showCurrentSectionOnly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            List(abilities) { ability in
                HStack(spacing: 8) {
                    Button(ability.name.isEmpty ? "未命名能力" : ability.name) { onOpen(ability) }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(SailuneActionCopy.delete, role: .destructive) { deleteTarget = ability }
                        .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.workspacePanelBackground)
            Button("新增能力", systemImage: SailuneSymbol.add.systemName, action: addAbility)
            .padding(10)
        }
        .confirmationDialog("刪除能力？", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { ability in
            Button(SailuneActionCopy.delete, role: .destructive) { delete(ability) }
            Button(SailuneActionCopy.cancel, role: .cancel) { deleteTarget = nil }
        }
        .alert("能力刪除未完成", isPresented: Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )) { Button(SailuneActionCopy.acknowledge) { deletionErrorMessage = nil } } message: {
            Text(deletionErrorMessage ?? "")
        }
        .alert("能力建立未完成", isPresented: Binding(
            get: { creationErrorMessage != nil },
            set: { if !$0 { creationErrorMessage = nil } }
        )) { Button(SailuneActionCopy.acknowledge) { creationErrorMessage = nil } } message: {
            Text(creationErrorMessage ?? "")
        }
    }

    private func addAbility() {
        let ability = CharacterAbility(name: "新能力")
        modelContext.insert(ability)
        do {
            // 能力本體與書籍歸屬分屬兩個 store；先確定本體落盤，再建立跨 store 連結。
            try modelContext.save()
            do {
                try abilityStore.register(abilityID: ability.id, bookID: book.id)
            } catch {
                modelContext.delete(ability)
                do { try modelContext.save() }
                catch {
                    abilityCreationLogger.error("Compensating ability save failed; registration error remains primary: \(String(describing: error), privacy: .private)")
                }
                throw error
            }
        } catch {
            modelContext.rollback()
            creationErrorMessage = error.localizedDescription
        }
    }

    private func delete(_ ability: CharacterAbility) {
        do {
            _ = try CrossStoreDeletionCoordinator.deleteAbility(
                ability, in: modelContext,
                abilityStore: abilityStore, settingsStore: settingsStore
            )
            deleteTarget = nil
        } catch {
            modelContext.rollback()
            deletionErrorMessage = error.localizedDescription
        }
    }
}

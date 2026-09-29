import SwiftUI
import SwiftData

@main
struct SailuneApp: App {
    @State private var accountAuthService = SailuneAccountAuthService()
    @State private var workspaceCoordinator = WorkspaceCoordinator()

    var body: some Scene {
        WindowGroup {
            Group {
                if let bundle = workspaceCoordinator.bundle {
                    SailuneRootView(container: bundle.container, settingsStore: bundle.settingsStore,
                        copyStore: bundle.copyStore, abilityStore: bundle.abilityStore,
                        planningStore: bundle.planningStore, publicationStore: bundle.publicationStore,
                        writingStatsStore: bundle.writingStatsStore, forumPostsStore: bundle.forumPostsStore)
                        .id(workspaceCoordinator.generation)
                        .defaultAppStorage(workspaceCoordinator.preferences)
                        .disabled(workspaceCoordinator.isWorking)
                        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                            guard workspaceCoordinator.bundle === bundle else { return }
                            do { try WorkspacePreferences.save(workspaceCoordinator.preferences, at: bundle.locations.preferencesURL) }
                            catch { workspaceCoordinator.errorMessage = "無法保存資料空間設定：\(error.localizedDescription)" }
                        }
                } else if workspaceCoordinator.isTransferring {
                    ProgressView("移入中…").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if workspaceCoordinator.hasPendingTransfer {
                    VStack(spacing: SailuneLayout.spacingL) {
                        Text(workspaceCoordinator.errorMessage ?? "移入復原未完成")
                        Button("重試") { workspaceCoordinator.retryPendingTransfer() }
                    }.padding(SailuneLayout.spacingXL)
                } else {
                    DatabaseStartupFailureView(message: workspaceCoordinator.errorMessage ?? "正在開啟資料空間")
                }
            }
            .alert("資料空間", isPresented: Binding(
                get: { workspaceCoordinator.transferCompletionMessage != nil },
                set: { if !$0 { workspaceCoordinator.dismissTransferCompletion() } })) {
                Button(SailuneActionCopy.acknowledge) { workspaceCoordinator.dismissTransferCompletion() }
            } message: { Text(workspaceCoordinator.transferCompletionMessage ?? "") }
            .environment(accountAuthService)
            .environment(workspaceCoordinator)
        }
        .defaultSize(width: 1_280, height: 820)
    }
}

private struct SailuneRootView: View {
    let container: ModelContainer
    @Bindable var settingsStore: V5SettingsStore
    @Bindable var copyStore: ItemCopyStore
    @Bindable var abilityStore: AbilityProgressStore
    @Bindable var planningStore: StoryPlanningStore
    @Bindable var publicationStore: BookPublicationStore
    @Bindable var writingStatsStore: BookWritingStatsStore
    @Bindable var forumPostsStore: LocalForumPostsStore

    var body: some View {
        ContentView()
            .modelContainer(container)
            .environment(settingsStore)
            .environment(copyStore)
            .environment(abilityStore)
            .environment(planningStore)
            .environment(publicationStore)
            .environment(writingStatsStore)
            .environment(forumPostsStore)
            .alert("物品副本無法儲存", isPresented: persistenceErrorBinding) {
                Button(SailuneActionCopy.acknowledge) { copyStore.clearPersistenceError() }
            } message: {
                Text(copyStore.persistenceErrorMessage ?? "未知錯誤")
            }
            .alert("設定集無法儲存", isPresented: settingsPersistenceErrorBinding) {
                Button(SailuneActionCopy.acknowledge) { settingsStore.clearPersistenceError() }
            } message: {
                Text(settingsStore.persistenceErrorMessage ?? "未知錯誤")
            }
            .alert("能力資料無法儲存", isPresented: abilityPersistenceErrorBinding) {
                Button(SailuneActionCopy.acknowledge) { abilityStore.clearPersistenceError() }
            } message: {
                Text(abilityStore.persistenceErrorMessage ?? "未知錯誤")
            }
            .alert("故事規劃無法儲存", isPresented: planningPersistenceErrorBinding) {
                Button(SailuneActionCopy.acknowledge) { planningStore.clearPersistenceError() }
            } message: {
                Text(planningStore.persistenceErrorMessage ?? "未知錯誤")
            }
            .alert("每日編輯統計無法保存", isPresented: writingStatsPersistenceErrorBinding) {
                Button(SailuneActionCopy.acknowledge) { writingStatsStore.clearPersistenceError() }
            } message: {
                Text(writingStatsStore.persistenceErrorMessage ?? "未知錯誤")
            }
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { copyStore.persistenceErrorMessage != nil },
            set: { if !$0 { copyStore.clearPersistenceError() } }
        )
    }


    private var settingsPersistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.persistenceErrorMessage != nil },
            set: { if !$0 { settingsStore.clearPersistenceError() } }
        )
    }

    private var abilityPersistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { abilityStore.persistenceErrorMessage != nil },
            set: { if !$0 { abilityStore.clearPersistenceError() } }
        )
    }

    private var planningPersistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { planningStore.persistenceErrorMessage != nil },
            set: { if !$0 { planningStore.clearPersistenceError() } }
        )
    }

    private var writingStatsPersistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { writingStatsStore.persistenceErrorMessage != nil },
            set: { if !$0 { writingStatsStore.clearPersistenceError() } }
        )
    }
}

private struct DatabaseStartupFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text("資料庫無法開啟").font(.title2.bold())
            Text("原始資料庫不會被刪除或覆寫。請保留此畫面中的錯誤資訊，以便進行修復。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(message)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 180)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(28)
        .frame(minWidth: 520, minHeight: 330)
    }
}

@MainActor
enum V5DataBackfill {
    /// ItemLevel has no database relationship by design, so remove only rows
    /// whose parent Item no longer exists. This is idempotent and preserves all
    /// valid level data through future launches.
    static func removeOrphanedItemLevels(in context: ModelContext) throws {
        let itemIDs = Set(try context.fetch(FetchDescriptor<Item>()).map(\.id))
        let levels = try context.fetch(FetchDescriptor<ItemLevel>())
        let orphans = levels.filter { !itemIDs.contains($0.itemID) }
        for level in orphans { context.delete(level) }
        let invalidHoldings = try context.fetch(FetchDescriptor<CharacterItem>()).filter { $0.quantity < 1 }
        for holding in invalidHoldings { holding.quantity = 1 }
        let unnamedItems = try context.fetch(FetchDescriptor<Item>()).filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for item in unnamedItems { item.name = "未命名物品" }
        let orphanIDs = Set(orphans.map(\.id))
        let unnamedLevels = levels.filter {
            !orphanIDs.contains($0.id) && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for level in unnamedLevels { level.name = "未命名等級" }
        let emptyHistories = try context.fetch(FetchDescriptor<ItemHistory>()).filter {
            $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        for history in emptyHistories { history.content = "未填寫描述" }
        if !orphans.isEmpty || !invalidHoldings.isEmpty || !unnamedItems.isEmpty || !unnamedLevels.isEmpty || !emptyHistories.isEmpty {
            try context.save()
        }
    }
}

@MainActor
enum V4DataBackfill {
    /// 舊版歷史附著在每一個持有關係。首次開啟新版時把它們收攏至物品，
    /// 同時保留原始紀錄，避免任何既有資料遺失。
    static func migrateLegacyItemHistories(in context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<Item>())
        var didChange = false
        for item in items where item.histories.isEmpty {
            let legacy = item.characterItems
                .flatMap { relation in relation.history.map { (relation, $0) } }
                .sorted { $0.1.sortOrder < $1.1.sortOrder }
            for (index, entry) in legacy.enumerated() {
                let history = ItemHistory(
                    content: entry.1.content,
                    sortOrder: index,
                    node: entry.1.node,
                    item: item,
                    relatedCharacters: entry.0.character.map { [$0] } ?? []
                )
                item.histories.append(history)
                context.insert(history)
                didChange = true
            }
        }
        if didChange { try context.save() }
    }

    static func ensureInitialWritingStructure(in context: ModelContext) throws {
        let books = try context.fetch(FetchDescriptor<Book>())
        var didChange = false
        for book in books {
            if book.volumes.isEmpty {
                let volume = Volume(title: "第一卷", sortOrder: 0, book: book)
                let section = Section(title: SectionUnitPreference.current.firstTitle, sortOrder: 0, volume: volume)
                volume.sections.append(section)
                book.volumes.append(volume)
                didChange = true
            } else if book.volumes.allSatisfy({ $0.sections.isEmpty }) {
                let firstVolume = book.volumes.min { $0.sortOrder < $1.sortOrder }!
                let section = Section(title: SectionUnitPreference.current.firstTitle, sortOrder: 0, volume: firstVolume)
                firstVolume.sections.append(section)
                didChange = true
            }
        }
        if didChange { try context.save() }
    }

    static func migrateLegacyPsychology(in context: ModelContext) throws {
        let characters = try context.fetch(FetchDescriptor<Character>())
        var didChange = false

        for character in characters {
            if let personality = character.personality?.trimmingCharacters(in: .whitespacesAndNewlines), !personality.isEmpty {
                context.insert(CharacterPsychology(kind: .personality, content: personality, character: character))
                character.personality = nil
                didChange = true
            }
            if let principles = character.principles?.trimmingCharacters(in: .whitespacesAndNewlines), !principles.isEmpty {
                context.insert(CharacterPsychology(kind: .value, content: principles, character: character))
                character.principles = nil
                didChange = true
            }
        }

        if didChange { try context.save() }
    }
}

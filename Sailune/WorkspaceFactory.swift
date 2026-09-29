import SwiftUI
import SwiftData

/// 每個工作區沿用既有 schema 與啟動修復次序。
@MainActor
enum WorkspaceFactory {
    private struct StartupStageError: LocalizedError {
        let stage: String
        let underlying: Error
        var errorDescription: String? { "\(stage)：\(underlying.localizedDescription)" }
    }
    private enum LegacyStoreSource { case v3(ModelContainer), v2(ModelContainer) }
    static func makeModelContainer(locations: SailuneDataLocations) throws -> (ModelContainer, V5SettingsStore, ItemCopyStore, AbilityProgressStore, StoryPlanningStore) {
        let storeURL = locations.mainStore
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw StartupStageError(stage: "資料目錄建立失敗", underlying: error)
        }
        do {
            try SailuneBackupService.applyPendingRestoreIfNeeded(locations: locations)
        } catch {
            throw StartupStageError(stage: "備份還原失敗，原資料回復狀態未確認", underlying: error)
        }
        // Open the released schema before V5. SwiftData caches model metadata
        // for shared top-level model types, so reversing this order makes it
        // attempt to open the V3 store with V5's expanded model graph.
        let legacySource: LegacyStoreSource?
        do {
            legacySource = try openLegacyStoreIfPresent(storeURL: storeURL)
        } catch {
            throw StartupStageError(stage: "舊資料庫載入失敗", underlying: error)
        }

        let mainSchema = Schema(versionedSchema: NovelWriterSchemaV5.self)
        let mainConfig = ModelConfiguration(schema: mainSchema, url: storeURL)
        
        let container: ModelContainer
        do {
            container = try ModelContainer(for: mainSchema, configurations: [mainConfig])
        } catch {
            throw StartupStageError(stage: "V5 主資料庫載入失敗（Sailune-v5.store）", underlying: error)
        }
        do {
            try importLegacyStore(legacySource, into: container)
        } catch {
            throw StartupStageError(stage: "舊資料匯入 V5 失敗", underlying: error)
        }
        do {
            try PersistentStoreRepair.run(in: container.mainContext)
        } catch {
            throw StartupStageError(stage: "書籍懸空資料修復失敗", underlying: error)
        }
        do {
            try V5DataCleanup.removeLegacyOrganizations(in: container.mainContext)
        } catch {
            throw StartupStageError(stage: "V5 舊組織資料清理失敗", underlying: error)
        }
        let settingsStore: V5SettingsStore
        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
            let settingsContainer = try ModelContainer(
                for: schema,
                migrationPlan: V5SettingsMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: SailuneDataLocations(mainStore: storeURL).settingsStore)]
            )
            settingsStore = V5SettingsStore(container: settingsContainer)
        } catch {
            throw StartupStageError(stage: "V5 設定集與勢力資料庫載入失敗", underlying: error)
        }
        do {
            try V4DataBackfill.migrateLegacyPsychology(in: container.mainContext)
        } catch {
            throw StartupStageError(stage: "心理資料轉換失敗", underlying: error)
        }
        do {
            try V4DataBackfill.migrateLegacyItemHistories(in: container.mainContext)
        } catch {
            throw StartupStageError(stage: "物品舊歷史轉換失敗", underlying: error)
        }
        do {
            try V5DataBackfill.removeOrphanedItemLevels(in: container.mainContext)
        } catch {
            throw StartupStageError(stage: "物品等級資料修復失敗", underlying: error)
        }
        let copyStore: ItemCopyStore
        do {
            let copySchema = Schema(versionedSchema: ItemCopySchemaV1.self)
            let copyConfig = ModelConfiguration(schema: copySchema, url: SailuneDataLocations(mainStore: storeURL).itemCopyStore)
            let copyContainer = try ModelContainer(for: copySchema, configurations: [copyConfig])
            let selectionSchema = Schema(versionedSchema: ItemCopyLevelSelectionSchemaV1.self)
            let selectionConfig = ModelConfiguration(
                schema: selectionSchema,
                url: SailuneDataLocations(mainStore: storeURL).itemCopyLevelStore
            )
            let selectionContainer = try ModelContainer(
                for: selectionSchema,
                configurations: [selectionConfig]
            )
            try V6ItemCopyBackfill.run(
                source: container.mainContext,
                destination: copyContainer.mainContext
            )
            try ItemCopyLevelSelectionRepair.run(
                source: container.mainContext,
                copyContext: copyContainer.mainContext,
                selectionContext: selectionContainer.mainContext
            )
            copyStore = try ItemCopyStore(
                container: copyContainer,
                levelSelectionContainer: selectionContainer
            )
        } catch {
            throw StartupStageError(stage: "獨立物品副本或當下等級資料庫載入失敗", underlying: error)
        }
        do {
            try V4DataBackfill.ensureInitialWritingStructure(in: container.mainContext)
        } catch {
            throw StartupStageError(stage: "初始寫作結構補齊失敗", underlying: error)
        }
        let abilityStore: AbilityProgressStore
        do {
            let schema = Schema(versionedSchema: AbilityProgressSchemaV1.self)
            let abilityContainer = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: SailuneDataLocations(mainStore: storeURL).abilityProgressStore)])
            abilityStore = try AbilityProgressStore(container: abilityContainer)
            try abilityStore.migrateLegacy(try container.mainContext.fetch(FetchDescriptor<CharacterAbility>()))
        } catch { throw StartupStageError(stage: "能力進度資料庫載入失敗", underlying: error) }
        let planningStore: StoryPlanningStore
        do {
            let schema = Schema(versionedSchema: StoryPlanningSchemaV7.self)
            let planningContainer = try ModelContainer(
                for: schema,
                migrationPlan: StoryPlanningMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: SailuneDataLocations(mainStore: storeURL).storyPlanningStore)]
            )
            planningStore = try StoryPlanningStore(container: planningContainer)
        } catch { throw StartupStageError(stage: "故事規劃資料庫載入失敗", underlying: error) }
        do {
            try planningStore.removeLegacyOrganizationMetadata()
        } catch {
            throw StartupStageError(stage: "V5 舊組織規劃資料清理失敗", underlying: error)
        }
        CrossStoreDeletionCoordinator.reconcileBestEffort(
            in: container.mainContext,
            planningStore: planningStore
        )
        do {
            let validBookIDs = Set(try container.mainContext.fetch(FetchDescriptor<Book>()).map(\.id))
            let items = try container.mainContext.fetch(FetchDescriptor<Item>())
            let abilities = try container.mainContext.fetch(FetchDescriptor<CharacterAbility>())
            let characters = try container.mainContext.fetch(FetchDescriptor<Character>())
            let itemLevels = try container.mainContext.fetch(FetchDescriptor<ItemLevel>())
            let validCharacterIDs = Set(characters.map(\.id))
            let validItemIDs = Set(items.map(\.id))
            let validAbilityIDs = Set(abilities.map(\.id))
            let validNodeIDs = Set(try container.mainContext.fetch(FetchDescriptor<Node>()).map(\.id))
            let characterBookIDs = Dictionary(uniqueKeysWithValues: characters.compactMap { character in
                character.book.map { (character.id, $0.id) }
            })
            let itemBookIDs = Dictionary(uniqueKeysWithValues: items.compactMap { item in
                item.book.map { (item.id, $0.id) }
            })
            let abilityBookIDs = abilityStore.resolvedBookIDs(for: abilities)
            try settingsStore.reconcile(
                validBookIDs: validBookIDs,
                validCharacterIDs: validCharacterIDs,
                validItemIDs: validItemIDs,
                validAbilityIDs: validAbilityIDs,
                validNodeIDs: validNodeIDs,
                characterBookIDs: characterBookIDs,
                itemBookIDs: itemBookIDs,
                abilityBookIDs: abilityBookIDs
            )
            try copyStore.reconcile(
                itemBookIDs: itemBookIDs,
                characterBookIDs: characterBookIDs,
                validNodeIDs: validNodeIDs,
                itemLevelItemIDs: Dictionary(uniqueKeysWithValues: itemLevels.map { ($0.id, $0.itemID) })
            )
            try abilityStore.reconcile(
                validBookIDs: validBookIDs,
                characterBookIDs: characterBookIDs,
                abilityBookIDs: abilityBookIDs,
                validNodeIDs: validNodeIDs
            )
        } catch {
            throw StartupStageError(stage: "V5 勢力跨資料庫連結修復失敗", underlying: error)
        }
        return (container, settingsStore, copyStore, abilityStore, planningStore)
    }

    private static func errorDetails(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription); userInfo=\(nsError.userInfo)"
    }

    private static func openLegacyStoreIfPresent(storeURL: URL) throws -> LegacyStoreSource? {
        let fileManager = FileManager.default
        let legacyV3StoreURL = storeURL.deletingLastPathComponent().appendingPathComponent("Sailune-v3.store")
        let legacyV2StoreURL = storeURL.deletingLastPathComponent().appendingPathComponent("Sailune.store")
        if fileManager.fileExists(atPath: legacyV3StoreURL.path) {
            let schema = Schema(versionedSchema: NovelWriterSchemaV3.self)
            let config = ModelConfiguration(schema: schema, url: legacyV3StoreURL)
            return .v3(try ModelContainer(for: schema, configurations: [config]))
        }
        guard fileManager.fileExists(atPath: legacyV2StoreURL.path) else { return nil }

        let legacySchema = Schema(versionedSchema: NovelWriterSchemaV2.self)
        let legacyConfig = ModelConfiguration(schema: legacySchema, url: legacyV2StoreURL)
        return .v2(try ModelContainer(for: legacySchema, configurations: [legacyConfig]))
    }

    private static func importLegacyStore(_ source: LegacyStoreSource?, into destination: ModelContainer) throws {
        guard source != nil else { return }

        let importContext = ModelContext(destination)
        importContext.autosaveEnabled = false

        switch source {
        case .v3(let container):
            try LegacyV3StoreImporter.importIfNeeded(from: container.mainContext, to: importContext)
        case .v2(let container):
            try LegacyV2StoreImporter.importIfNeeded(from: container.mainContext, to: importContext)
        case nil:
            break
        }
    }
    
}

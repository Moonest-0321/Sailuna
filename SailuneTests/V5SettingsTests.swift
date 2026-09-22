import XCTest
import SwiftData
@testable import Sailune

@MainActor
final class V5SettingsTests: XCTestCase {
    func testTechnologyPresetCatalogHasFourteenFixedCompleteCases() throws {
        XCTAssertEqual(
            TechnologyPreset.realWorld.map(\.title),
            ["狩獵採集時代", "農業新石器時代", "青銅時代", "鐵器時代", "前工業時代", "工業時代", "電氣化與大量生產時代", "資訊與網路時代", "智慧科技時代"]
        )
        XCTAssertEqual(
            TechnologyPreset.fictional.map(\.title),
            ["蒸汽朋克", "鋼鐵朋克", "廢土", "太空時代", "修仙"]
        )
        XCTAssertEqual(TechnologyPreset.all.count, 14)
        XCTAssertEqual(Set(TechnologyPreset.all.map(\.id)).count, 14)

        for preset in TechnologyPreset.all {
            XCTAssertFalse(preset.referenceCase.isEmpty)
            XCTAssertFalse(preset.referencePeriod.isEmpty)
            XCTAssertFalse(preset.summary.isEmpty)
            XCTAssertEqual(preset.sections.count, 12)
            XCTAssertEqual(Set(preset.sections.map(\.title)).count, 12)
            XCTAssertTrue(preset.sections.allSatisfy { !$0.content.isEmpty })
            XCTAssertEqual(TechnologyPreset.preset(id: preset.id), preset)
        }
    }

    func testRealWorldTechnologyPresetAppliesAndIsRecognizedAsTechnology() throws {
        let term = WorldTerm(bookID: UUID(), name: "新條目")
        TechnologyPreset.intelligentTechnology.apply(to: term)

        XCTAssertEqual(TechnologyPreset.matching(term), .intelligentTechnology)
        XCTAssertEqual(term.termCategory, WorldTermCategory.technology.rawValue)
        XCTAssertEqual(term.alternateNames, "21 世紀人工智慧與生物科技社會")
        XCTAssertTrue(try XCTUnwrap(term.detailedDescription).contains("【世界前提與技術階段】"))
        XCTAssertTrue(try XCTUnwrap(term.worldImpact).contains("【故事衝突與世界影響】"))
    }

    func testTechnologyPresetAppliesToWorldTermAndKeepsOrdinaryTechnologyEditable() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let presetTerm = WorldTerm(bookID: bookID, name: "新條目")
        let ordinaryTerm = WorldTerm(bookID: bookID, name: "自訂技術")
        ordinaryTerm.termCategory = WorldTermCategory.technology.rawValue
        ordinaryTerm.termDescription = "作者自己的技術"
        container.mainContext.insert(presetTerm)
        container.mainContext.insert(ordinaryTerm)
        try container.mainContext.save()

        TechnologyPreset.spaceAge.apply(to: presetTerm)
        try container.mainContext.save()
        XCTAssertEqual(TechnologyPreset.matching(presetTerm), .spaceAge)
        XCTAssertNil(GovernmentPreset.matching(presetTerm))
        XCTAssertNil(BeliefPreset.matching(presetTerm))
        XCTAssertEqual(presetTerm.termCategory, WorldTermCategory.technology.rawValue)
        XCTAssertTrue(try XCTUnwrap(presetTerm.detailedDescription).contains("【世界前提與技術階段】"))

        XCTAssertNil(TechnologyPreset.matching(ordinaryTerm))
        ordinaryTerm.termDescription = "更新後的自訂技術"
        try store.saveAndReport()
        XCTAssertEqual(ordinaryTerm.termDescription, "更新後的自訂技術")
    }

    func testResourcePresetCatalogHasThirtyNineFixedCompleteCases() throws {
        XCTAssertEqual(ResourcePreset.all.count, 39)
        XCTAssertEqual(ResourcePreset.metal.count, 8)
        XCTAssertEqual(ResourcePreset.nonMetal.count, 8)
        XCTAssertEqual(ResourcePreset.agriculture.count, 10)
        XCTAssertEqual(ResourcePreset.population.count, 4)
        XCTAssertEqual(ResourcePreset.synthetic.count, 9)
        XCTAssertEqual(Set(ResourcePreset.all.map(\.id)).count, 39)

        for preset in ResourcePreset.all {
            XCTAssertFalse(preset.title.isEmpty)
            XCTAssertFalse(preset.referenceCase.isEmpty)
            XCTAssertFalse(preset.referencePeriod.isEmpty)
            XCTAssertFalse(preset.summary.isEmpty)
            XCTAssertEqual(preset.sections.count, 12)
            XCTAssertEqual(Set(preset.sections.map(\.title)).count, 12)
            XCTAssertTrue(preset.sections.allSatisfy { !$0.content.isEmpty })
            XCTAssertEqual(ResourcePreset.preset(id: preset.id), preset)
        }
    }

    func testResourcePresetAppliesAndKeepsOrdinaryResourceEditable() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let presetTerm = WorldTerm(bookID: bookID, name: "新資源")
        let ordinaryTerm = WorldTerm(bookID: bookID, name: "自訂資源")
        ordinaryTerm.termCategory = WorldTermCategory.resource.rawValue
        ordinaryTerm.termDescription = "作者自己的資源"
        container.mainContext.insert(presetTerm)
        container.mainContext.insert(ordinaryTerm)
        try container.mainContext.save()

        let copper = try XCTUnwrap(ResourcePreset.metal.first { $0.title == "銅礦" })
        copper.apply(to: presetTerm)
        try container.mainContext.save()
        XCTAssertEqual(ResourcePreset.matching(presetTerm), copper)
        XCTAssertEqual(presetTerm.termCategory, WorldTermCategory.resource.rawValue)
        XCTAssertEqual(presetTerm.alternateNames, "現代全球礦業與冶金供應鏈")
        XCTAssertTrue(try XCTUnwrap(presetTerm.detailedDescription).contains("【資源定義與分類】"))

        XCTAssertNil(ResourcePreset.matching(ordinaryTerm))
        ordinaryTerm.termDescription = "更新後的自訂資源"
        try store.saveAndReport()
        XCTAssertEqual(ordinaryTerm.termDescription, "更新後的自訂資源")
    }

    func testPeoplePresetCatalogHasEighteenFixedCompleteCases() throws {
        XCTAssertEqual(PeoplePreset.realWorld.count, 12)
        XCTAssertEqual(PeoplePreset.fictional.count, 6)
        XCTAssertEqual(PeoplePreset.all.count, 18)
        XCTAssertEqual(Set(PeoplePreset.all.map(\.id)).count, 18)

        for preset in PeoplePreset.all {
            XCTAssertFalse(preset.title.isEmpty)
            XCTAssertFalse(preset.referenceCase.isEmpty)
            XCTAssertFalse(preset.referencePeriod.isEmpty)
            XCTAssertFalse(preset.summary.isEmpty)
            XCTAssertEqual(preset.sections.count, 12)
            XCTAssertEqual(Set(preset.sections.map(\.title)).count, 12)
            XCTAssertTrue(preset.sections.allSatisfy { !$0.content.isEmpty })
            XCTAssertEqual(PeoplePreset.preset(id: preset.id), preset)
        }

        XCTAssertEqual(PeoplePreset.all.filter { $0.group == .realWorld }.count, 12)
        XCTAssertEqual(PeoplePreset.all.filter { $0.group == .fictional }.count, 6)
    }

    func testPeoplePresetAppliesAndKeepsOrdinaryPeopleEditable() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let presetTerm = WorldTerm(bookID: bookID, name: "新條目")
        let ordinaryTerm = WorldTerm(bookID: bookID, name: "自訂族群")
        ordinaryTerm.termCategory = WorldTermCategory.people.rawValue
        ordinaryTerm.termDescription = "作者自己的族群設定"
        container.mainContext.insert(presetTerm)
        container.mainContext.insert(ordinaryTerm)
        try container.mainContext.save()

        let han = PeoplePreset.han
        han.apply(to: presetTerm)
        try container.mainContext.save()
        XCTAssertEqual(PeoplePreset.matching(presetTerm), han)
        XCTAssertEqual(presetTerm.termCategory, WorldTermCategory.people.rawValue)
        XCTAssertEqual(presetTerm.alternateNames, "東亞漢文化圈的歷史社會")
        XCTAssertTrue(try XCTUnwrap(presetTerm.detailedDescription).contains("【族群／種族定位與起源】"))
        XCTAssertTrue(try XCTUnwrap(presetTerm.worldImpact).contains("【與其他族群的關係面向】"))

        XCTAssertNil(PeoplePreset.matching(ordinaryTerm))
        ordinaryTerm.termDescription = "更新後的自訂族群"
        try store.saveAndReport()
        XCTAssertEqual(ordinaryTerm.termDescription, "更新後的自訂族群")
    }

    func testBeliefPresetCatalogHasNineFixedCompleteCases() throws {
        XCTAssertEqual(
            BeliefPreset.all.map(\.title),
            ["基督教", "猶太教", "伊斯蘭教", "道教", "佛教", "祆教", "科學", "高控制團體", "末世型新興宗教運動"]
        )
        XCTAssertEqual(Set(BeliefPreset.all.map(\.id)).count, 9)

        for preset in BeliefPreset.all {
            XCTAssertFalse(preset.referenceCase.isEmpty)
            XCTAssertFalse(preset.referencePeriod.isEmpty)
            XCTAssertFalse(preset.summary.isEmpty)
            XCTAssertEqual(preset.sections.count, 12)
            XCTAssertEqual(Set(preset.sections.map(\.title)).count, 12)
            XCTAssertTrue(preset.sections.allSatisfy { !$0.content.isEmpty })
            XCTAssertEqual(BeliefPreset.preset(id: preset.id), preset)
        }

        let science = try XCTUnwrap(BeliefPreset.all.first { $0 == .science })
        XCTAssertTrue(science.sections.contains { $0.title == "神聖對象或終極實在" && $0.content.contains("不適用") })
        XCTAssertTrue(science.sections.contains { $0.title == "儀式與實踐" && $0.content.contains("不適用") })
        XCTAssertTrue(science.sections.contains { $0.title == "節期與空間" && $0.content.contains("不適用") })
    }

    func testBeliefPresetAppliesToWorldTermAndCanBeLinkedFromPower() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let power = PowerUnit(bookID: bookID, name: "教團")
        let term = WorldTerm(bookID: bookID, name: "新條目")
        container.mainContext.insert(power)
        container.mainContext.insert(term)
        try container.mainContext.save()

        BeliefPreset.taoism.apply(to: term)
        try container.mainContext.save()
        XCTAssertEqual(BeliefPreset.matching(term), .taoism)
        XCTAssertEqual(GovernmentPreset.matching(term), nil)
        XCTAssertEqual(term.termCategory, WorldTermCategory.belief.rawValue)
        XCTAssertTrue(try XCTUnwrap(term.detailedDescription).contains("【起源／核心信念】"))

        try store.setWorldTerm(term, for: .religion, on: power, bookID: bookID)
        XCTAssertEqual(power.religionWorldTermID, term.id)
        try store.reconcile(validBookIDs: [bookID], validCharacterIDs: [])
        XCTAssertEqual(power.religionWorldTermID, term.id)

        store.deleteWorldTerm(term, bookID: bookID)
        XCTAssertNil(power.religionWorldTermID)
    }

    func testGovernmentPresetCatalogHasEightFixedCompleteCases() throws {
        XCTAssertEqual(
            GovernmentPreset.all.map(\.title),
            ["民主", "共產", "威權", "法西斯", "帝制", "聯邦制", "共和制", "殖民統治"]
        )
        XCTAssertEqual(Set(GovernmentPreset.all.map(\.id)).count, 8)

        for preset in GovernmentPreset.all {
            XCTAssertFalse(preset.referenceCase.isEmpty)
            XCTAssertFalse(preset.referencePeriod.isEmpty)
            XCTAssertFalse(preset.summary.isEmpty)
            XCTAssertEqual(preset.sections.count, 16)
            XCTAssertEqual(Set(preset.sections.map(\.title)).count, 16)
            XCTAssertTrue(preset.sections.allSatisfy { !$0.content.isEmpty })
            XCTAssertFalse(preset.sections.contains { $0.content.contains("請選擇") })
            XCTAssertEqual(GovernmentPreset.preset(id: preset.id), preset)
        }
    }

    func testGovernmentPresetAppliesToWorldTermAndCanBeLinkedFromPower() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let power = PowerUnit(bookID: bookID, name: "聯邦")
        let term = WorldTerm(bookID: bookID, name: "新條目")
        container.mainContext.insert(power)
        container.mainContext.insert(term)
        try container.mainContext.save()

        GovernmentPreset.federalism.apply(to: term)
        try container.mainContext.save()
        XCTAssertEqual(GovernmentPreset.matching(term), .federalism)
        XCTAssertEqual(term.termCategory, WorldTermCategory.institution.rawValue)
        XCTAssertTrue(try XCTUnwrap(term.detailedDescription).contains("【主權歸屬與統治正當性】"))

        try store.setWorldTerm(term, for: .government, on: power, bookID: bookID)
        XCTAssertEqual(power.governmentWorldTermID, term.id)
        try store.reconcile(validBookIDs: [bookID], validCharacterIDs: [])
        XCTAssertEqual(power.governmentWorldTermID, term.id)

        try store.setWorldTerm(nil, for: .government, on: power, bookID: bookID)
        XCTAssertNil(power.governmentWorldTermID)
    }

    func testWorldTermCategoryProvidesFiniteChoices() {
        XCTAssertEqual(
            WorldTermCategory.allCases.map(\.rawValue),
            ["制度", "信仰", "技術", "資源", "族群／種族", "文化習俗", "專有名詞"]
        )
    }

    func testLegacyWorldTermCategoryIsNotGuessed() {
        XCTAssertNil(WorldTermCategory(rawValue: "曆法"))
        XCTAssertNil(WorldTermCategory(rawValue: "語言"))
    }

    func testWorldTermGuidanceTreatsInstitutionAsAWorldSystem() {
        let guidance = WorldTermContentGuidance.forCategory(WorldTermCategory.institution.rawValue)

        XCTAssertTrue(guidance.coreDefinition.contains("制度"))
        XCTAssertTrue(guidance.operationAndExpression.contains("權力"))
        XCTAssertTrue(guidance.limitationsAndExceptions.contains("地區"))
        XCTAssertTrue(guidance.worldImpact.contains("政治"))
    }

    func testReconcileEnforcesSameBookEndpointsAndDeduplicatesWithoutRemovingSuccessionCycles() throws {
        let container = try makeMainContainer()
        let context = container.mainContext
        let store = V5SettingsStore(container: container)
        let bookA = UUID(), bookB = UUID(), characterA = UUID(), characterB = UUID(), itemA = UUID()
        let upperLevel = PowerLevel(bookID: bookA, name: "上層", sortOrder: 0)
        let lowerLevel = PowerLevel(bookID: bookA, name: "下層", sortOrder: 1)
        let first = PowerUnit(bookID: bookA, name: "前身", levelID: upperLevel.id)
        let second = PowerUnit(bookID: bookA, name: "後繼", levelID: lowerLevel.id)
        let validMember = PowerMember(bookID: bookA, powerID: first.id, characterID: characterA)
        let crossBookMember = PowerMember(bookID: bookA, powerID: first.id, characterID: characterB)
        let validAsset = PowerAssetLink(bookID: bookA, powerID: first.id, kind: .item, sourceID: itemA)
        let duplicateAsset = PowerAssetLink(bookID: bookA, powerID: first.id, kind: .item, sourceID: itemA)
        let forward = PowerSuccessionLink(bookID: bookA, predecessorPowerID: first.id, successorPowerID: second.id, kind: .succeeded)
        let duplicateForward = PowerSuccessionLink(bookID: bookA, predecessorPowerID: first.id, successorPowerID: second.id, kind: .succeeded)
        let cycleBack = PowerSuccessionLink(bookID: bookA, predecessorPowerID: second.id, successorPowerID: first.id, kind: .succeeded)
        let validEdge = PowerSubordination(bookID: bookA, lowerPowerID: second.id, upperPowerID: first.id)
        let reversedEdge = PowerSubordination(bookID: bookA, lowerPowerID: first.id, upperPowerID: second.id)
        [upperLevel, lowerLevel].forEach(context.insert)
        [first, second].forEach(context.insert)
        [validMember, crossBookMember].forEach(context.insert)
        [validAsset, duplicateAsset].forEach(context.insert)
        [forward, duplicateForward, cycleBack].forEach(context.insert)
        [validEdge, reversedEdge].forEach(context.insert)
        try context.save()

        try store.reconcile(
            validBookIDs: [bookA, bookB], validCharacterIDs: [characterA, characterB],
            validItemIDs: [itemA], characterBookIDs: [characterA: bookA, characterB: bookB],
            itemBookIDs: [itemA: bookA]
        )

        XCTAssertEqual(store.members(for: bookA).map(\.id), [validMember.id])
        XCTAssertEqual(store.assets(for: first, bookID: bookA).count, 1)
        XCTAssertEqual(store.successionLinks(for: first, bookID: bookA).count, 2)
        XCTAssertEqual(store.edges(for: bookA).map(\.id), [validEdge.id])
    }

    func testWorldTermGuidanceTreatsPeopleAsAContextualWorldSystem() {
        let guidance = WorldTermContentGuidance.forCategory(WorldTermCategory.people.rawValue)

        XCTAssertTrue(guidance.coreDefinition.contains("族群／種族"))
        XCTAssertTrue(guidance.limitationsAndExceptions.contains("生物本質"))
    }

    func testWorldTermGuidanceFallsBackForLegacyOrUnclassifiedCategory() {
        let unclassified = WorldTermContentGuidance.forCategory(nil)

        XCTAssertEqual(WorldTermContentGuidance.forCategory("曆法"), unclassified)
        XCTAssertEqual(WorldTermContentGuidance.forCategory("語言"), unclassified)
        XCTAssertFalse(unclassified.coreDefinition.isEmpty)
        XCTAssertFalse(unclassified.operationAndExpression.isEmpty)
        XCTAssertFalse(unclassified.limitationsAndExceptions.isEmpty)
        XCTAssertFalse(unclassified.worldImpact.isEmpty)
    }

    func testSidebarDefaultsShowWorldTermBetweenPowerAndItem() throws {
        let container = try makeMainContainer()
        let context = container.mainContext
        let store = V5SettingsStore(container: container)
        let bookID = UUID()

        let rows = store.ensureDefaults(for: bookID)

        XCTAssertEqual(rows.count, SidebarSettingKey.defaultOrder.count)
        XCTAssertEqual(
            SidebarSettingCatalog.visibleKeys(rows: rows),
            [.character, .power, .worldTerm, .item, .ability, .storyTag]
        )
        XCTAssertEqual(rows.filter { !$0.isVisible }.compactMap(\.key), [.place])
        XCTAssertTrue(rows.allSatisfy { $0.catalogRevision == SidebarSettingCatalog.currentRevision })

        rows.first(where: { $0.key == .character })?.isVisible = false
        try context.save()
        let reloaded = try SidebarSettingCatalog.rows(for: bookID, in: context)
        XCTAssertFalse(SidebarSettingCatalog.visibleKeys(rows: reloaded).contains(.character))
        XCTAssertEqual(try context.fetch(FetchDescriptor<BookSidebarSetting>()).count, rows.count)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerLevel>()).sorted { $0.sortOrder < $1.sortOrder }.map(\.name), ["層級 1", "層級 2"])
    }

    func testV5SidebarConfigurationRevealsWorldTermOnlyOnce() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-settings-v6-sidebar-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID()
        let termID = UUID()

        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV5.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            for (index, key) in [
                SidebarSettingKey.character, .power, .item, .ability, .storyTag, .place, .worldTerm
            ].enumerated() {
                container.mainContext.insert(
                    V5SettingsSchemaV5.BookSidebarSetting(
                        bookID: bookID,
                        key: key,
                        sortOrder: index,
                        isVisible: ![.place, .worldTerm].contains(key)
                    )
                )
            }
            container.mainContext.insert(V5SettingsSchemaV5.WorldTerm(id: termID, bookID: bookID, name: "月曆"))
            try container.mainContext.save()
        }

        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let store = V5SettingsStore(container: migrated)
        var rows = store.ensureDefaults(for: bookID)

        XCTAssertEqual(
            rows.sorted { $0.sortOrder < $1.sortOrder }.compactMap(\.key),
            SidebarSettingKey.defaultOrder
        )
        XCTAssertTrue(try XCTUnwrap(rows.first { $0.key == .worldTerm }).isVisible)
        XCTAssertTrue(rows.allSatisfy { $0.catalogRevision == SidebarSettingCatalog.currentRevision })
        XCTAssertEqual(try migrated.mainContext.fetch(FetchDescriptor<WorldTerm>()).map(\.id), [termID])

        let worldTermRow = try XCTUnwrap(rows.first { $0.key == .worldTerm })
        worldTermRow.isVisible = false
        try migrated.mainContext.save()
        rows = store.ensureDefaults(for: bookID)

        XCTAssertFalse(try XCTUnwrap(rows.first { $0.key == .worldTerm }).isVisible)
        XCTAssertEqual(try migrated.mainContext.fetch(FetchDescriptor<WorldTerm>()).map(\.id), [termID])
    }

    func testV6WorldTermMigratesToV7WithoutRewritingExistingContent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-settings-v7-world-term-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID()
        let termID = UUID()

        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV6.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            container.mainContext.insert(
                V5SettingsSchemaV6.BookSidebarSetting(
                    bookID: bookID,
                    key: .worldTerm,
                    sortOrder: 2,
                    isVisible: true,
                    catalogRevision: 1
                )
            )
            container.mainContext.insert(
                V5SettingsSchemaV6.WorldTerm(
                    id: termID,
                    bookID: bookID,
                    name: "月曆",
                    alternateNames: "月之曆法",
                    termCategory: WorldTermCategory.institution.rawValue,
                    termDescription: "一年十三月",
                    detailedDescription: "由議會統一頒布的紀年制度",
                    usageExamples: "新月月初",
                    notes: "待確認閏月",
                    sortOrder: 4
                )
            )
            try container.mainContext.save()
        }

        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let term = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<WorldTerm>()).first)
        let row = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<BookSidebarSetting>()).first)

        XCTAssertEqual(row.catalogRevision, 1)
        XCTAssertEqual(term.id, termID)
        XCTAssertEqual(term.name, "月曆")
        XCTAssertEqual(term.alternateNames, "月之曆法")
        XCTAssertEqual(term.termCategory, WorldTermCategory.institution.rawValue)
        XCTAssertEqual(term.termDescription, "一年十三月")
        XCTAssertEqual(term.detailedDescription, "由議會統一頒布的紀年制度")
        XCTAssertEqual(term.usageExamples, "新月月初")
        XCTAssertEqual(term.notes, "待確認閏月")
        XCTAssertEqual(term.sortOrder, 4)
        XCTAssertNil(term.operationAndExpression)
        XCTAssertNil(term.limitationsAndExceptions)
        XCTAssertNil(term.worldImpact)
    }

    func testPowerGraphStoresCrossLevelEdgesAndRejectsWrongDirection() throws {
        let container = try makeMainContainer()
        let context = container.mainContext
        let bookID = UUID()
        let allianceLevel = PowerLevel(bookID: bookID, name: "聯盟", sortOrder: 0)
        let countryLevel = PowerLevel(bookID: bookID, name: "國家", sortOrder: 1)
        let localLevel = PowerLevel(bookID: bookID, name: "地方", sortOrder: 2)
        let alliance = PowerUnit(bookID: bookID, name: "聯盟", levelID: allianceLevel.id)
        let countryA = PowerUnit(bookID: bookID, name: "國家 A", levelID: countryLevel.id)
        let countryB = PowerUnit(bookID: bookID, name: "國家 B", levelID: countryLevel.id)
        let province = PowerUnit(bookID: bookID, name: "直屬下層", levelID: localLevel.id)
        [allianceLevel, countryLevel, localLevel].forEach(context.insert)
        [alliance, countryA, countryB, province].forEach(context.insert)
        try context.save()

        var edges: [PowerSubordination] = []
        let levels = [allianceLevel, countryLevel, localLevel]
        try PowerGraphStore.addDirectSubordination(lower: countryA, upper: alliance, bookID: bookID, levels: levels, edges: &edges, context: context)
        try PowerGraphStore.addDirectSubordination(lower: countryB, upper: alliance, bookID: bookID, levels: levels, edges: &edges, context: context)
        try PowerGraphStore.addDirectSubordination(lower: province, upper: alliance, bookID: bookID, levels: levels, edges: &edges, context: context)
        XCTAssertEqual(edges.count, 3)
        XCTAssertEqual(PowerGraphStore.directLowerPowers(of: alliance, edges: edges, powers: [alliance, countryA, countryB, province]).count, 3)
        XCTAssertEqual(PowerGraphStore.directUpperPowers(of: province, edges: edges, powers: [alliance, countryA, countryB, province]).map(\.name), ["聯盟"])

        XCTAssertThrowsError(
            try PowerGraphStore.addDirectSubordination(lower: alliance, upper: province, bookID: bookID, levels: levels, edges: &edges, context: context)
        )
        XCTAssertEqual(edges.count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerSubordination>()).count, 3)
    }

    func testDeletingPowerRemovesOnlyItsDirectEdges() throws {
        let container = try makeMainContainer()
        let context = container.mainContext
        let bookID = UUID()
        let otherBookID = UUID()
        let upper = PowerUnit(bookID: bookID, name: "上層")
        let deleted = PowerUnit(bookID: bookID, name: "待刪除")
        let lower = PowerUnit(bookID: bookID, name: "下層")
        let unrelatedA = PowerUnit(bookID: otherBookID, name: "其他 A")
        let unrelatedB = PowerUnit(bookID: otherBookID, name: "其他 B")
        [upper, deleted, lower, unrelatedA, unrelatedB].forEach(context.insert)
        let upperEdge = PowerSubordination(bookID: bookID, lowerPowerID: deleted.id, upperPowerID: upper.id)
        let lowerEdge = PowerSubordination(bookID: bookID, lowerPowerID: lower.id, upperPowerID: deleted.id)
        let unrelatedEdge = PowerSubordination(bookID: otherBookID, lowerPowerID: unrelatedA.id, upperPowerID: unrelatedB.id)
        [upperEdge, lowerEdge, unrelatedEdge].forEach(context.insert)
        try context.save()

        try PowerGraphStore.delete(deleted, edges: [upperEdge, lowerEdge, unrelatedEdge], context: context)

        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<PowerUnit>()).map(\.id)), Set([upper.id, lower.id, unrelatedA.id, unrelatedB.id]))
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerSubordination>()).map(\.id), [unrelatedEdge.id])
    }

    func testHiddenSelectedSettingFallsBackToFirstVisibleSetting() {
        XCTAssertEqual(
            SidebarSettingCatalog.resolvedSelection(.character, visibleKeys: [.power, .item]),
            .power
        )
        XCTAssertEqual(
            SidebarSettingCatalog.resolvedSelection(.item, visibleKeys: [.power, .item]),
            .item
        )
        XCTAssertEqual(
            SidebarSettingCatalog.resolvedSelection(.character, visibleKeys: []),
            .character
        )
    }

    func testLevelCandidatesAllowSkippingIntermediateLevels() throws {
        let container = try makeMainContainer()
        let context = container.mainContext
        let bookID = UUID()
        let top = PowerLevel(bookID: bookID, name: "聯盟", sortOrder: 0)
        let middle = PowerLevel(bookID: bookID, name: "國家", sortOrder: 1)
        let bottom = PowerLevel(bookID: bookID, name: "地方", sortOrder: 2)
        let alliance = PowerUnit(bookID: bookID, name: "聯邦", levelID: top.id)
        let country = PowerUnit(bookID: bookID, name: "北國", levelID: middle.id)
        let local = PowerUnit(bookID: bookID, name: "北境教會", levelID: bottom.id)
        let unassigned = PowerUnit(bookID: bookID, name: "未分級")
        [top, middle, bottom].forEach(context.insert)
        [alliance, country, local, unassigned].forEach(context.insert)
        try context.save()

        XCTAssertEqual(
            Set(PowerHierarchyStore.upperCandidates(for: local, powers: [alliance, country, local, unassigned], levels: [top, middle, bottom]).map(\.id)),
            Set([alliance.id, country.id])
        )
        XCTAssertEqual(
            Set(PowerHierarchyStore.lowerCandidates(for: alliance, powers: [alliance, country, local, unassigned], levels: [top, middle, bottom]).map(\.id)),
            Set([country.id, local.id])
        )
    }

    func testChangingLevelIsBlockedWithoutChangingExistingRelations() throws {
        let container = try makeMainContainer()
        let context = container.mainContext
        let bookID = UUID()
        let top = PowerLevel(bookID: bookID, name: "聯盟", sortOrder: 0)
        let middle = PowerLevel(bookID: bookID, name: "國家", sortOrder: 1)
        let bottom = PowerLevel(bookID: bookID, name: "地方", sortOrder: 2)
        let alliance = PowerUnit(bookID: bookID, name: "聯邦", levelID: top.id)
        let country = PowerUnit(bookID: bookID, name: "北國", levelID: middle.id)
        let local = PowerUnit(bookID: bookID, name: "北境", levelID: bottom.id)
        let upperEdge = PowerSubordination(bookID: bookID, lowerPowerID: country.id, upperPowerID: alliance.id)
        let lowerEdge = PowerSubordination(bookID: bookID, lowerPowerID: local.id, upperPowerID: country.id)
        [top, middle, bottom].forEach(context.insert)
        [alliance, country, local].forEach(context.insert)
        [upperEdge, lowerEdge].forEach(context.insert)
        try context.save()

        XCTAssertThrowsError(
            try PowerHierarchyStore.changeLevel(
                of: country,
                to: top,
                bookID: bookID,
                levels: [top, middle, bottom],
                powers: [alliance, country, local],
                edges: [upperEdge, lowerEdge],
                context: context
            )
        )
        XCTAssertEqual(country.levelID, middle.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerSubordination>()).count, 2)
    }

    func testHierarchyConflictDoesNotAlsoSetGlobalPersistenceError() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let context = container.mainContext
        let bookID = UUID()
        let top = PowerLevel(bookID: bookID, name: "聯盟", sortOrder: 0)
        let bottom = PowerLevel(bookID: bookID, name: "國家", sortOrder: 1)
        let alliance = PowerUnit(bookID: bookID, name: "聯邦", levelID: top.id)
        let country = PowerUnit(bookID: bookID, name: "北國", levelID: bottom.id)
        let edge = PowerSubordination(bookID: bookID, lowerPowerID: country.id, upperPowerID: alliance.id)
        [top, bottom].forEach(context.insert)
        [alliance, country].forEach(context.insert)
        context.insert(edge)
        try context.save()

        XCTAssertThrowsError(try store.changeLevel(of: country, to: top, bookID: bookID))
        XCTAssertNil(store.persistenceErrorMessage)
        XCTAssertEqual(country.levelID, bottom.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerSubordination>()).map(\.id), [edge.id])
    }

    func testReorderingLevelsIsAtomicAndUsedLevelCannotBeDeleted() throws {
        let container = try makeMainContainer()
        let context = container.mainContext
        let bookID = UUID()
        let top = PowerLevel(bookID: bookID, name: "聯盟", sortOrder: 0)
        let bottom = PowerLevel(bookID: bookID, name: "國家", sortOrder: 1)
        let alliance = PowerUnit(bookID: bookID, name: "聯邦", levelID: top.id)
        let country = PowerUnit(bookID: bookID, name: "北國", levelID: bottom.id)
        let edge = PowerSubordination(bookID: bookID, lowerPowerID: country.id, upperPowerID: alliance.id)
        [top, bottom].forEach(context.insert)
        [alliance, country].forEach(context.insert)
        context.insert(edge)
        try context.save()

        XCTAssertThrowsError(
            try PowerHierarchyStore.reorderLevels(
                bookID: bookID,
                orderedIDs: [bottom.id, top.id],
                levels: [top, bottom],
                powers: [alliance, country],
                edges: [edge],
                context: context
            )
        )
        XCTAssertEqual(top.sortOrder, 0)
        XCTAssertEqual(bottom.sortOrder, 1)
        XCTAssertThrowsError(
            try PowerHierarchyStore.deleteLevel(top, bookID: bookID, powers: [alliance, country], context: context)
        )
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerLevel>()).count, 2)
    }

    func testLevelNamesRejectBlankAndCaseInsensitiveDuplicates() throws {
        let container = try makeMainContainer()
        let context = container.mainContext
        let bookID = UUID()
        let alliance = PowerLevel(bookID: bookID, name: "Alliance", sortOrder: 0)
        let country = PowerLevel(bookID: bookID, name: "Country", sortOrder: 1)
        [alliance, country].forEach(context.insert)
        try context.save()

        XCTAssertThrowsError(
            try PowerHierarchyStore.renameLevel(
                country,
                to: "  ",
                bookID: bookID,
                levels: [alliance, country],
                context: context
            )
        )
        XCTAssertEqual(country.name, "Country")
        XCTAssertThrowsError(
            try PowerHierarchyStore.renameLevel(
                country,
                to: "alliance",
                bookID: bookID,
                levels: [alliance, country],
                context: context
            )
        )
        XCTAssertEqual(country.name, "Country")
    }

    func testV1SettingsMigrationPreservesSettingsAndPowersButRemovesLegacyEdges() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-settings-v2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID()
        let lowerID = UUID()
        let upperID = UUID()
        let placeID = UUID()
        let termID = UUID()
        let rowID = UUID()

        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV1.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            let context = container.mainContext
            context.insert(V5SettingsSchemaV1.BookSidebarSetting(id: rowID, bookID: bookID, key: .power, sortOrder: 0, isVisible: true))
            context.insert(V5SettingsSchemaV1.PowerUnit(id: lowerID, bookID: bookID, name: "舊下級", powerDescription: "保留簡介"))
            context.insert(V5SettingsSchemaV1.PowerUnit(id: upperID, bookID: bookID, name: "舊上級"))
            context.insert(V5SettingsSchemaV1.PowerSubordination(bookID: bookID, lowerPowerID: lowerID, upperPowerID: upperID))
            context.insert(V5SettingsSchemaV1.Place(id: placeID, bookID: bookID, name: "保留地點"))
            context.insert(V5SettingsSchemaV1.WorldTerm(id: termID, bookID: bookID, name: "保留條目"))
            try context.save()
        }

        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let context = migrated.mainContext

        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<PowerUnit>()).map(\.id)), Set([lowerID, upperID]))
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerUnit>()).first(where: { $0.id == lowerID })?.powerDescription, "保留簡介")
        XCTAssertTrue(try context.fetch(FetchDescriptor<PowerUnit>()).allSatisfy { $0.levelID == nil })
        XCTAssertTrue(try context.fetch(FetchDescriptor<PowerSubordination>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BookSidebarSetting>()).map(\.id), [rowID])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Place>()).map(\.id), [placeID])
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorldTerm>()).map(\.id), [termID])
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerLevel>()).sorted { $0.sortOrder < $1.sortOrder }.map(\.name), ["層級 1", "層級 2"])
    }

    func testV2SettingsMigrationPreservesLevelsAndRestoresNotebookFields() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-settings-v3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID()
        let levelID = UUID()
        let powerID = UUID()

        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
            let context = container.mainContext
            context.insert(V5SettingsSchemaV2.BookSidebarSetting(bookID: bookID, key: .power, sortOrder: 0, isVisible: true))
            context.insert(V5SettingsSchemaV2.PowerLevel(id: levelID, bookID: bookID, name: "自訂層級", sortOrder: 0))
            context.insert(V5SettingsSchemaV2.PowerUnit(id: powerID, bookID: bookID, name: "保留勢力", powerDescription: "保留簡介", levelID: levelID))
            try context.save()
        }

        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let context = migrated.mainContext
        let power = try XCTUnwrap(context.fetch(FetchDescriptor<PowerUnit>()).first)

        XCTAssertEqual(power.id, powerID)
        XCTAssertEqual(power.levelID, levelID)
        XCTAssertEqual(power.powerDescription, "保留簡介")
        XCTAssertEqual(power.seniorManagers, "")
        XCTAssertEqual(power.otherRoster, "")
        XCTAssertEqual(power.relationshipNotes, "")
        XCTAssertEqual(power.politics, "")
        XCTAssertEqual(power.religion, "")
        XCTAssertEqual(try context.fetch(FetchDescriptor<PowerLevel>()).map(\.name), ["自訂層級"])

        power.seniorManagers = "議長：艾琳"
        power.otherRoster = "顧問：羅恩"
        power.relationshipNotes = "與北國合作"
        power.politics = "議會制"
        power.religion = "月神信仰"
        try context.save()
        XCTAssertEqual(power.seniorManagers, "議長：艾琳")
        XCTAssertEqual(power.otherRoster, "顧問：羅恩")
        XCTAssertEqual(power.relationshipNotes, "與北國合作")
        XCTAssertEqual(power.politics, "議會制")
        XCTAssertEqual(power.religion, "月神信仰")
    }

    func testV3PlacesAndWorldTermsMigrateToV4PreservingExistingFields() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-settings-v4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID()
        let placeID = UUID()
        let termID = UUID()

        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV3.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
            let context = container.mainContext
            context.insert(V5SettingsSchemaV3.Place(id: placeID, bookID: bookID, name: "霧港", placeDescription: "北方港口"))
            context.insert(V5SettingsSchemaV3.WorldTerm(id: termID, bookID: bookID, name: "月曆", termDescription: "一年十三月", sortOrder: 4))
            try context.save()
        }

        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let migrated = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let context = migrated.mainContext
        let place = try XCTUnwrap(context.fetch(FetchDescriptor<Place>()).first)
        let term = try XCTUnwrap(context.fetch(FetchDescriptor<WorldTerm>()).first)

        XCTAssertEqual(place.id, placeID)
        XCTAssertEqual(place.name, "霧港")
        XCTAssertEqual(place.placeDescription, "北方港口")
        XCTAssertNil(place.alternateNames)
        XCTAssertNil(place.placeType)
        XCTAssertNil(place.detailedDescription)
        XCTAssertNil(place.notes)
        XCTAssertNil(place.coordinateX)
        XCTAssertNil(place.coordinateY)
        XCTAssertEqual(term.id, termID)
        XCTAssertEqual(term.name, "月曆")
        XCTAssertEqual(term.termDescription, "一年十三月")
        XCTAssertEqual(term.sortOrder, 4)
        XCTAssertNil(term.alternateNames)
        XCTAssertNil(term.termCategory)
        XCTAssertNil(term.detailedDescription)
        XCTAssertNil(term.usageExamples)
        XCTAssertNil(term.notes)
    }

    func testPlaceAndWorldTermStoreSupportsFieldsSearchAndBookIsolation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-settings-place-term-fields-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID()
        let otherBookID = UUID()

        let placeID: UUID
        let otherPlaceID: UUID
        let termID: UUID
        do {
            let container = try makeMainContainer(at: storeURL)
            let context = container.mainContext
            let store = V5SettingsStore(container: container)
            let place = store.createPlace(bookID: bookID)
            let otherPlace = store.createPlace(bookID: otherBookID)
            let term = store.createWorldTerm(bookID: bookID)
            place.name = "霧港"
            place.alternateNames = "霧之港"
            place.placeType = "港口城市"
            place.placeDescription = "北方港口"
            term.name = "月曆"
            term.alternateNames = "月之曆法"
            term.termCategory = WorldTermCategory.institution.rawValue
            term.termDescription = "一年十三月"
            term.detailedDescription = "王國共同採用的紀年制度"
            term.operationAndExpression = "由曆官觀測月相並公布月份"
            term.limitationsAndExceptions = "邊境保留地方曆法"
            term.worldImpact = "影響稅期、祭典與航運"
            try context.save()

            placeID = place.id
            otherPlaceID = otherPlace.id
            termID = term.id
        }

        let reopenedContainer = try makeMainContainer(at: storeURL)
        let reopenedStore = V5SettingsStore(container: reopenedContainer)
        let place = try XCTUnwrap(reopenedStore.places(for: bookID).first)
        let term = try XCTUnwrap(reopenedStore.worldTerms(for: bookID).first)
        XCTAssertEqual(place.id, placeID)
        XCTAssertEqual(place.alternateNames, "霧之港")
        XCTAssertEqual(place.placeType, "港口城市")
        XCTAssertEqual(place.placeDescription, "北方港口")
        XCTAssertEqual(term.id, termID)
        XCTAssertEqual(term.alternateNames, "月之曆法")
        XCTAssertEqual(term.termCategory, WorldTermCategory.institution.rawValue)
        XCTAssertEqual(term.termDescription, "一年十三月")
        XCTAssertEqual(term.detailedDescription, "王國共同採用的紀年制度")
        XCTAssertEqual(term.operationAndExpression, "由曆官觀測月相並公布月份")
        XCTAssertEqual(term.limitationsAndExceptions, "邊境保留地方曆法")
        XCTAssertEqual(term.worldImpact, "影響稅期、祭典與航運")
        XCTAssertEqual(V5SettingsSearch.places(reopenedStore.places(for: bookID), matching: "港口").map(\.id), [placeID])
        XCTAssertEqual(V5SettingsSearch.places([place], matching: "霧之港").map(\.id), [placeID])
        XCTAssertEqual(V5SettingsSearch.worldTerms([term], matching: "制度").map(\.id), [termID])

        reopenedStore.deletePlace(place, bookID: bookID)
        reopenedStore.deleteWorldTerm(term, bookID: bookID)
        XCTAssertTrue(reopenedStore.places(for: bookID).isEmpty)
        XCTAssertTrue(reopenedStore.worldTerms(for: bookID).isEmpty)
        XCTAssertEqual(reopenedStore.places(for: otherBookID).map(\.id), [otherPlaceID])
    }

    func testLegacyOrganizationCleanupPreservesCharacter() throws {
        let container = try makeLegacyMainContainer()
        let context = container.mainContext
        let book = Book(title: "測試書", author: "作者")
        let character = Character(realName: "角色", book: book)
        let organization = Organization(name: "舊組織", book: book)
        let membership = CharacterOrganization(character: character, organization: organization)
        let identity = OrganizationIdentityHistory(identity: "舊身分", membership: membership)
        membership.identityHistory.append(identity)
        context.insert(book)
        context.insert(character)
        context.insert(organization)
        context.insert(membership)
        context.insert(identity)
        try context.save()

        try V5DataCleanup.removeLegacyOrganizations(in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Organization>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CharacterOrganization>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<OrganizationIdentityHistory>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Character>()).map(\.realName), ["角色"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<Book>()).count, 1)
    }

    func testLegacyPlanningMetadataCleanup() throws {
        let schema = Schema(versionedSchema: StoryPlanningSchemaV7.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let store = try StoryPlanningStore(container: container)
        _ = try store.setRecordPlacement(
            sourceKind: .organizationJoin,
            sourceID: UUID(),
            bookID: UUID(),
            storyLineID: nil,
            stageID: nil
        )

        try store.removeLegacyOrganizationMetadata()
        XCTAssertTrue(store.planningRecordMetadata.isEmpty)
    }

    func testReleasedMainStoreOpensBesideSettingsStoreAndPreservesCoreData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-V5-split-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let mainURL = directory.appendingPathComponent("Sailune-v5.store")
        let settingsURL = directory.appendingPathComponent("Sailune-v5-settings.store")
        let bookID = UUID()
        let characterID = UUID()
        let sectionID = UUID()
        let itemID = UUID()
        let abilityID = UUID()
        let timelineID = UUID()
        let nodeID = UUID()
        let eventID = UUID()

        do {
            let schema = Schema(versionedSchema: NovelWriterSchemaV5.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: mainURL)]
            )
            let context = container.mainContext
            let book = Book(id: bookID, title: "必須保留", author: "作者")
            let volume = Volume(title: "第一卷", book: book)
            let section = Section(id: sectionID, title: "正文", content: AttributedString("不可刪除"), volume: volume)
            let character = Character(realName: "保留角色", book: book)
            character.id = characterID
            let item = Item(id: itemID, name: "保留物品", book: book)
            let ability = CharacterAbility(id: abilityID, name: "保留能力", character: character)
            let timeline = Timeline(id: timelineID, name: "保留時間軸", isPrimary: true)
            timeline.book = book
            let node = Node(id: nodeID, year: 1)
            node.timeline = timeline
            node.section = section
            let event = Event(id: eventID, title: "保留事件")
            event.node = node
            event.section = section
            let organization = Organization(name: "允許刪除的舊組織", book: book)
            let membership = CharacterOrganization(character: character, organization: organization)
            context.insert(book)
            context.insert(volume)
            context.insert(section)
            context.insert(character)
            context.insert(item)
            context.insert(ability)
            context.insert(timeline)
            context.insert(node)
            context.insert(event)
            context.insert(organization)
            context.insert(membership)
            try context.save()
        }

        do {
            let mainSchema = Schema(versionedSchema: NovelWriterSchemaV5.self)
            let settingsSchema = Schema(versionedSchema: V5SettingsSchemaV11.self)
            let mainContainer = try ModelContainer(
                for: mainSchema,
                configurations: [ModelConfiguration(schema: mainSchema, url: mainURL)]
            )
            let settingsContainer = try ModelContainer(
                for: settingsSchema,
                migrationPlan: V5SettingsMigrationPlan.self,
                configurations: [ModelConfiguration(schema: settingsSchema, url: settingsURL)]
            )
            try V5DataCleanup.removeLegacyOrganizations(in: mainContainer.mainContext)
            settingsContainer.mainContext.insert(PowerUnit(bookID: bookID, name: "新勢力"))
            try settingsContainer.mainContext.save()

            XCTAssertEqual(try mainContainer.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [bookID])
            XCTAssertEqual(try mainContainer.mainContext.fetch(FetchDescriptor<Character>()).map(\.id), [characterID])
            XCTAssertEqual(try mainContainer.mainContext.fetch(FetchDescriptor<Section>()).map(\.id), [sectionID])
            XCTAssertEqual(try mainContainer.mainContext.fetch(FetchDescriptor<Item>()).map(\.id), [itemID])
            XCTAssertEqual(try mainContainer.mainContext.fetch(FetchDescriptor<CharacterAbility>()).map(\.id), [abilityID])
            XCTAssertEqual(try mainContainer.mainContext.fetch(FetchDescriptor<Timeline>()).map(\.id), [timelineID])
            XCTAssertEqual(try mainContainer.mainContext.fetch(FetchDescriptor<Node>()).map(\.id), [nodeID])
            XCTAssertEqual(try mainContainer.mainContext.fetch(FetchDescriptor<Event>()).map(\.id), [eventID])
            XCTAssertEqual(String(try XCTUnwrap(mainContainer.mainContext.fetch(FetchDescriptor<Section>()).first).content.characters), "不可刪除")
            XCTAssertTrue(try mainContainer.mainContext.fetch(FetchDescriptor<Organization>()).isEmpty)
            XCTAssertTrue(try mainContainer.mainContext.fetch(FetchDescriptor<CharacterOrganization>()).isEmpty)
            XCTAssertEqual(try settingsContainer.mainContext.fetch(FetchDescriptor<PowerUnit>()).map(\.name), ["新勢力"])
        }

        let releasedSchema = Schema(versionedSchema: NovelWriterSchemaV5.self)
        let reopened = try ModelContainer(
            for: releasedSchema,
            configurations: [ModelConfiguration(schema: releasedSchema, url: mainURL)]
        )
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [bookID])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Character>()).map(\.id), [characterID])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Section>()).map(\.id), [sectionID])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Item>()).map(\.id), [itemID])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<CharacterAbility>()).map(\.id), [abilityID])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Timeline>()).map(\.id), [timelineID])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Node>()).map(\.id), [nodeID])
        XCTAssertEqual(try reopened.mainContext.fetch(FetchDescriptor<Event>()).map(\.id), [eventID])
        XCTAssertTrue(try reopened.mainContext.fetch(FetchDescriptor<Organization>()).isEmpty)
    }

    func testPowerWorldTermLinksAndDeletionCleanup() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let power = PowerUnit(bookID: bookID, name: "王國")
        let term = WorldTerm(bookID: bookID, name: "議會制")
        term.termCategory = WorldTermCategory.institution.rawValue
        container.mainContext.insert(power)
        container.mainContext.insert(term)
        try container.mainContext.save()

        try store.setWorldTerm(term, for: .government, on: power, bookID: bookID)
        XCTAssertEqual(power.governmentWorldTermID, term.id)
        XCTAssertNil(power.religionWorldTermID)

        store.deleteWorldTerm(term, bookID: bookID)
        XCTAssertNil(power.governmentWorldTermID)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<WorldTerm>()).isEmpty)
    }

    func testPowerWorldTermLinksRequireMatchingCategories() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let power = PowerUnit(bookID: bookID, name: "王國")
        let beliefTerm = WorldTerm(bookID: bookID, name: "國教")
        beliefTerm.termCategory = WorldTermCategory.belief.rawValue
        let institutionTerm = WorldTerm(bookID: bookID, name: "議會制")
        institutionTerm.termCategory = WorldTermCategory.institution.rawValue
        container.mainContext.insert(power)
        container.mainContext.insert(beliefTerm)
        container.mainContext.insert(institutionTerm)
        try container.mainContext.save()

        try store.setWorldTerm(beliefTerm, for: .religion, on: power, bookID: bookID)
        try store.setWorldTerm(institutionTerm, for: .government, on: power, bookID: bookID)
        XCTAssertEqual(power.religionWorldTermID, beliefTerm.id)
        XCTAssertEqual(power.governmentWorldTermID, institutionTerm.id)
        XCTAssertThrowsError(try store.setWorldTerm(institutionTerm, for: .religion, on: power, bookID: bookID))
        XCTAssertThrowsError(try store.setWorldTerm(beliefTerm, for: .government, on: power, bookID: bookID))
        XCTAssertEqual(PowerWorldTermField.allCases.map(\.title), ["宗教", "政體"])
    }

    func testPowerAliasesAssetsAndAdvantagesPersistAndRemainScoped() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let otherBookID = UUID()
        let power = PowerUnit(bookID: bookID, name: "北境聯盟")
        power.formerNames = "北境自治會"
        power.foreignNames = "Northern League"
        power.shortName = "北盟"
        let resource = WorldTerm(bookID: bookID, name: "鐵礦")
        resource.termCategory = WorldTermCategory.resource.rawValue
        let technology = WorldTerm(bookID: bookID, name: "蒸汽工坊")
        technology.termCategory = WorldTermCategory.technology.rawValue
        let wrongCategory = WorldTerm(bookID: bookID, name: "王權")
        wrongCategory.termCategory = WorldTermCategory.institution.rawValue
        container.mainContext.insert(power)
        [resource, technology, wrongCategory].forEach(container.mainContext.insert)
        try container.mainContext.save()

        _ = try store.addAsset(kind: .resource, sourceID: resource.id, sourceBookID: bookID, to: power, bookID: bookID)
        _ = try store.addAsset(kind: .technology, sourceID: technology.id, sourceBookID: bookID, to: power, bookID: bookID)
        _ = try store.addAsset(kind: .item, sourceID: UUID(), sourceBookID: bookID, to: power, bookID: bookID)
        _ = try store.addAsset(kind: .ability, sourceID: UUID(), sourceBookID: bookID, to: power, bookID: bookID)
        XCTAssertThrowsError(try store.addAsset(kind: .resource, sourceID: wrongCategory.id, sourceBookID: bookID, to: power, bookID: bookID))
        XCTAssertThrowsError(try store.addAsset(kind: .technology, sourceID: technology.id, sourceBookID: otherBookID, to: power, bookID: bookID))
        XCTAssertThrowsError(try store.addAsset(kind: .resource, sourceID: resource.id, sourceBookID: bookID, to: power, bookID: bookID))

        let military = try store.addAdvantage(kind: .military, name: "山地防線", detail: "熟悉隘口", to: power, bookID: bookID)
        let economic = try store.addAdvantage(kind: .economic, name: "礦業稅收", detail: "控制冶煉", to: power, bookID: bookID)
        XCTAssertEqual([power.formerNames, power.foreignNames, power.shortName], ["北境自治會", "Northern League", "北盟"])
        XCTAssertEqual(store.assets(for: power, bookID: bookID).count, 4)
        XCTAssertEqual(store.advantages(for: power, bookID: bookID).map(\.kind), [.military, .economic])

        store.removeAdvantage(military, bookID: bookID)
        store.removeAsset(try XCTUnwrap(store.assets(for: power, bookID: bookID).first { $0.kind == .item }), bookID: bookID)
        XCTAssertEqual(store.advantages(for: power, bookID: bookID).map(\.id), [economic.id])
        XCTAssertEqual(store.assets(for: power, bookID: bookID).count, 3)
    }

    func testDeletingWorldTermAndPowerCleansV54AssetRecords() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let power = PowerUnit(bookID: bookID, name: "工坊")
        let resource = WorldTerm(bookID: bookID, name: "銅礦")
        resource.termCategory = WorldTermCategory.resource.rawValue
        container.mainContext.insert(power)
        container.mainContext.insert(resource)
        try container.mainContext.save()
        _ = try store.addAsset(kind: .resource, sourceID: resource.id, sourceBookID: bookID, to: power, bookID: bookID)
        _ = try store.addAdvantage(kind: .economic, name: "鑄幣權", detail: "", to: power, bookID: bookID)

        store.deleteWorldTerm(resource, bookID: bookID)
        XCTAssertTrue(store.assets(for: power, bookID: bookID).isEmpty)
        store.deletePower(power, bookID: bookID)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PowerAdvantage>()).isEmpty)
    }

    func testStructuredPowerRelationsNormalizeSymmetricKindsAndPreserveSuzeraintyDirection() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID(); let otherBookID = UUID()
        let federation = PowerUnit(bookID: bookID, name: "聯邦")
        let guild = PowerUnit(bookID: bookID, name: "商會")
        let duchy = PowerUnit(bookID: bookID, name: "侯國")
        let outsider = PowerUnit(bookID: otherBookID, name: "外國")
        [federation, guild, duchy, outsider].forEach(container.mainContext.insert)
        try container.mainContext.save()

        let alliance = try store.addPowerRelation(from: federation, to: guild, kind: .alliance, detail: "共同防禦", bookID: bookID)
        XCTAssertEqual(store.powerRelations(for: federation, bookID: bookID).map(\.id), [alliance.id])
        XCTAssertEqual(store.powerRelations(for: guild, bookID: bookID).map(\.id), [alliance.id])
        XCTAssertThrowsError(try store.addPowerRelation(from: guild, to: federation, kind: .alliance, detail: "反向重複", bookID: bookID))

        let suzerainty = try store.addPowerRelation(from: federation, to: duchy, kind: .suzerainty, detail: "保留內政", bookID: bookID)
        XCTAssertEqual(suzerainty.sourcePowerID, federation.id)
        XCTAssertEqual(suzerainty.targetPowerID, duchy.id)
        XCTAssertThrowsError(try store.addPowerRelation(from: federation, to: federation, kind: .trade, detail: "", bookID: bookID))
        XCTAssertThrowsError(try store.addPowerRelation(from: federation, to: outsider, kind: .hostility, detail: "", bookID: bookID))

        store.deletePower(federation, bookID: bookID)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PowerRelation>()).isEmpty)
        XCTAssertNotNil(try container.mainContext.fetch(FetchDescriptor<PowerUnit>()).first(where: { $0.id == duchy.id }))
    }

    func testV9StoreMigratesThroughV11PreservingRelationshipNotes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Sailune-settings-v10-relation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID(); let powerID = UUID()
        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV9.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
            container.mainContext.insert(V5SettingsSchemaV9.PowerUnit(id: powerID, bookID: bookID, name: "舊勢力", relationshipNotes: "既有外交筆記"))
            try container.mainContext.save()
        }
        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let migrated = try ModelContainer(for: schema, migrationPlan: V5SettingsMigrationPlan.self, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
        let power = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<PowerUnit>()).first)
        XCTAssertEqual(power.id, powerID)
        XCTAssertEqual(power.relationshipNotes, "既有外交筆記")
        XCTAssertTrue(try migrated.mainContext.fetch(FetchDescriptor<PowerRelation>()).isEmpty)
    }

    func testV10PlaceMigratesToV11WithCoordinatesUnsetAndCanPersistPlacement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-settings-v11-map-place-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID()
        let placeID = UUID()

        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV10.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            container.mainContext.insert(
                V5SettingsSchemaV9.Place(
                    id: placeID,
                    bookID: bookID,
                    name: "霧港",
                    alternateNames: "霧之港",
                    placeType: "港口城市",
                    placeDescription: "北方港口",
                    detailedDescription: "全年多霧",
                    notes: "重要據點",
                    sortOrder: 7
                )
            )
            try container.mainContext.save()
        }

        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
            let container = try ModelContainer(
                for: schema,
                migrationPlan: V5SettingsMigrationPlan.self,
                configurations: [ModelConfiguration(schema: schema, url: storeURL)]
            )
            let place = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Place>()).first)
            XCTAssertEqual(place.id, placeID)
            XCTAssertEqual(place.bookID, bookID)
            XCTAssertEqual(place.name, "霧港")
            XCTAssertEqual(place.alternateNames, "霧之港")
            XCTAssertEqual(place.placeType, "港口城市")
            XCTAssertEqual(place.placeDescription, "北方港口")
            XCTAssertEqual(place.detailedDescription, "全年多霧")
            XCTAssertEqual(place.notes, "重要據點")
            XCTAssertEqual(place.sortOrder, 7)
            XCTAssertNil(place.coordinateX)
            XCTAssertNil(place.coordinateY)

            let store = V5SettingsStore(container: container)
            store.updateMapPlace(
                place,
                bookID: bookID,
                name: place.name,
                placeType: place.placeType,
                coordinate: MapCoordinate(x: 1_250, y: 875)
            )
        }

        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let reopened = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let place = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Place>()).first)
        XCTAssertEqual(place.coordinateX, 1_250)
        XCTAssertEqual(place.coordinateY, 875)
    }

    func testMapPlaceCreationIsBookScopedAndClampsCoordinates() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let otherBookID = UUID()

        let place = store.createMapPlace(
            bookID: bookID,
            name: "王都",
            placeType: "城市",
            coordinate: MapCoordinate(x: 4_500, y: -100)
        )
        _ = store.createPlace(bookID: otherBookID)

        XCTAssertEqual(place.coordinateX, 4_000)
        XCTAssertEqual(place.coordinateY, 0)
        XCTAssertEqual(store.places(for: bookID).map(\.id), [place.id])
        XCTAssertEqual(store.places(for: otherBookID).count, 1)
    }

    func testPowerLifecycleSuccessionAndExistenceStatus() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let predecessor = PowerUnit(bookID: bookID, name: "舊王國")
        let successor = PowerUnit(bookID: bookID, name: "新王國")
        container.mainContext.insert(predecessor); container.mainContext.insert(successor)
        try container.mainContext.save()

        let founded = try store.addLifecycleEvent(to: predecessor, kind: .established, bookID: bookID)
        founded.nodeID = UUID(); founded.detail = "建國"
        predecessor.existenceStatus = .dissolved
        let link = try store.addSuccession(predecessor: predecessor, successor: successor, kind: .renamed, bookID: bookID)
        link.nodeID = UUID()
        try container.mainContext.save()

        XCTAssertEqual(predecessor.existenceStatus, .dissolved)
        XCTAssertEqual(store.lifecycleEvents(for: predecessor, bookID: bookID).map(\.kind), [.established])
        XCTAssertEqual(store.successionLinks(for: predecessor, bookID: bookID).first?.successorPowerID, successor.id)
        XCTAssertThrowsError(try store.addSuccession(predecessor: predecessor, successor: successor, kind: .renamed, bookID: bookID))
        store.deletePower(predecessor, bookID: bookID)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PowerLifecycleEvent>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PowerSuccessionLink>()).isEmpty)
    }

    func testPowerMemberSupportsTimelineMultipleRolesAndLeadershipStates() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID(); let characterID = UUID(); let joinedNodeID = UUID(); let leftNodeID = UUID()
        let power = PowerUnit(bookID: bookID, name: "議會")
        container.mainContext.insert(power); try container.mainContext.save()
        let member = try store.addMember(characterID: characterID, characterBookID: bookID, title: "議員", to: power, bookID: bookID)
        member.joinedNodeID = joinedNodeID; member.leftNodeID = leftNodeID; member.status = .former
        let leader = try store.addRole(to: member, title: "議長", bookID: bookID)
        leader.isLeadership = true; leader.status = .dismissed; leader.startNodeID = joinedNodeID; leader.endNodeID = leftNodeID
        try container.mainContext.save()

        XCTAssertEqual(member.status, .former)
        XCTAssertEqual(store.roles(for: member, bookID: bookID).count, 2)
        XCTAssertEqual(store.roles(for: member, bookID: bookID).map(\.title), ["議員", "議長"])
        XCTAssertTrue(leader.isLeadership)
        XCTAssertEqual(leader.status, .dismissed)
        XCTAssertEqual(leader.startNodeID, joinedNodeID)
        XCTAssertEqual(leader.endNodeID, leftNodeID)
        store.removeMember(member, bookID: bookID)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PowerMemberRole>()).isEmpty)
    }

    func testV8StoreMigratesToV9AndPreservesMemberTitleAsRole() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Sailune-settings-v9-member-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID(); let powerID = UUID(); let memberID = UUID()
        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV8.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
            container.mainContext.insert(V5SettingsSchemaV8.PowerUnit(id: powerID, bookID: bookID, name: "舊勢力", formerNames: "前稱"))
            container.mainContext.insert(V5SettingsSchemaV8.PowerMember(id: memberID, bookID: bookID, powerID: powerID, characterID: UUID(), title: "舊領袖"))
            try container.mainContext.save()
        }
        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let migrated = try ModelContainer(for: schema, migrationPlan: V5SettingsMigrationPlan.self, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
        let role = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<PowerMemberRole>()).first)
        let power = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<PowerUnit>()).first)
        XCTAssertEqual(role.memberID, memberID)
        XCTAssertEqual(role.title, "舊領袖")
        XCTAssertEqual(role.status, .current)
        XCTAssertEqual(power.formerNames, "前稱")
        XCTAssertEqual(power.existenceStatus, .active)
    }

    func testPowerMemberIsUniqueWithinPowerAndRemovedWithPower() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let characterID = UUID()
        let power = PowerUnit(bookID: bookID, name: "公會")
        container.mainContext.insert(power)
        try container.mainContext.save()

        let member = try store.addMember(characterID: characterID, characterBookID: bookID, title: "會長", to: power, bookID: bookID)
        XCTAssertEqual(member.title, "會長")
        XCTAssertThrowsError(try store.addMember(characterID: characterID, characterBookID: bookID, title: "顧問", to: power, bookID: bookID))

        store.deletePower(power, bookID: bookID)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PowerMember>()).isEmpty)
    }

    func testCharacterMembershipCanMoveBetweenPowersAndRejectDuplicateDestination() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let context = container.mainContext
        let bookID = UUID()
        let characterID = UUID()
        let first = PowerUnit(bookID: bookID, name: "第一勢力")
        let second = PowerUnit(bookID: bookID, name: "第二勢力")
        let third = PowerUnit(bookID: bookID, name: "第三勢力")
        [first, second, third].forEach(context.insert)
        try context.save()

        let moving = try store.addMember(
            characterID: characterID,
            characterBookID: bookID,
            title: "隊長",
            to: first,
            bookID: bookID
        )
        _ = try store.addMember(
            characterID: characterID,
            characterBookID: bookID,
            title: "顧問",
            to: second,
            bookID: bookID
        )

        try store.moveMember(moving, to: third, bookID: bookID)
        XCTAssertEqual(moving.powerID, third.id)
        XCTAssertEqual(moving.title, "隊長")
        XCTAssertEqual(store.members(for: bookID).filter { $0.characterID == characterID }.count, 2)

        XCTAssertThrowsError(try store.moveMember(moving, to: second, bookID: bookID))
        XCTAssertEqual(moving.powerID, third.id)
    }

    func testRemovingUpperDeletesOnlySpecifiedDirectEdge() throws {
        let container = try makeMainContainer()
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let lower = PowerUnit(bookID: bookID, name: "地方")
        let upperA = PowerUnit(bookID: bookID, name: "王國")
        let upperB = PowerUnit(bookID: bookID, name: "聯盟")
        [lower, upperA, upperB].forEach(container.mainContext.insert)
        container.mainContext.insert(PowerSubordination(bookID: bookID, lowerPowerID: lower.id, upperPowerID: upperA.id))
        container.mainContext.insert(PowerSubordination(bookID: bookID, lowerPowerID: lower.id, upperPowerID: upperB.id))
        try container.mainContext.save()

        store.removeSubordination(lower: lower, upper: upperA, bookID: bookID)

        let edges = store.edges(for: bookID)
        XCTAssertEqual(edges.count, 1)
        XCTAssertEqual(edges.first?.upperPowerID, upperB.id)
    }

    private func makeMainContainer(at url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
        let configuration = if let url {
            ModelConfiguration(schema: schema, url: url)
        } else {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func makeLegacyMainContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: NovelWriterSchemaV5.self)
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

}

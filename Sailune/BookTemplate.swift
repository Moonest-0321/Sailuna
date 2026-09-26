import Foundation
import Observation
import SwiftData
import UniformTypeIdentifiers

struct BookTemplateDocument: Codable, Identifiable {
    static let currentVersion = 1

    struct SectionRecord: Codable {
        var id: UUID
        var title: String
        var sortOrder: Int
    }

    struct VolumeRecord: Codable {
        var id: UUID
        var title: String
        var sortOrder: Int
        var sections: [SectionRecord]
    }

    struct LineRecord: Codable {
        var id: UUID
        var title: String
        var kind: String
        var sortOrder: Int
    }

    struct StageRecord: Codable {
        var id: UUID
        var storyLineID: UUID
        var title: String
        var sortOrder: Int
    }

    struct ItemRecord: Codable {
        var id: UUID
        var storyLineID: UUID
        var stageID: UUID?
        var title: String
        var detail: String
        var sortOrder: Int
    }

    struct AnnotationRecord: Codable { var sectionID: UUID; var plannedOutline: String; var revisionNote: String }
    struct StageStartRecord: Codable {
        var stageID: UUID
        var volumeID: UUID
        var sectionID: UUID
        var volumeTitle: String
        var sectionTitle: String
        var headingText: String
        var headingOffset: Int?
        var granularity: String
    }

    struct PlacementRecord: Codable {
        var itemID: UUID
        var kind: String
        var relativeItemID: UUID?
        var relativeItemTitle: String
        var localOrder: Int
    }

    struct TimelineRecord: Codable { var id: UUID; var name: String; var isPrimary: Bool; var sortOrder: Double }
    struct EraRecord: Codable { var id: UUID; var name: String; var color: String; var startOrdinal: Int }
    struct NodeRecord: Codable {
        var id: UUID; var timelineID: UUID; var eraID: UUID?; var sectionID: UUID?; var year: Int; var month: Int?; var day: Int?
        var isVisible: Bool; var sortOrder: Double
    }
    struct EventRecord: Codable {
        var id: UUID; var nodeID: UUID?; var sectionID: UUID?; var title: String; var detail: String; var isVisible: Bool; var sortOrder: Double; var characterIDs: [UUID]
    }
    struct TimelineCardRecord: Codable { var eventID: UUID; var outlineItemID: UUID?; var excerptMode: String; var updatedAt: Date }
    struct PlanningMetadataRecord: Codable { var id: UUID; var kind: String; var sourceID: UUID; var storyLineID: UUID?; var stageID: UUID?; var updatedAt: Date }
    struct BookItemRecord: Codable {
        var id: UUID; var name: String; var itemDescription: String; var category: String; var appearanceAndMaterial: String
        var usage: String; var positiveAbility: String; var negativeAbility: String
    }
    struct ItemLevelRecord: Codable { var id: UUID; var itemID: UUID; var sortOrder: Int; var name: String; var itemName: String; var ability: String; var cost: String; var note: String }
    struct ItemHistoryRecord: Codable { var id: UUID; var itemID: UUID; var content: String; var sortOrder: Int; var nodeID: UUID?; var relatedCharacterIDs: [UUID] }
    struct CharacterItemRecord: Codable { var id: UUID; var characterID: UUID; var itemID: UUID; var quantity: Int }
    struct CharacterItemHistoryRecord: Codable { var id: UUID; var characterItemID: UUID; var content: String; var sortOrder: Int; var nodeID: UUID? }
    struct CharacterAbilityRecord: Codable { var id: UUID; var characterID: UUID; var name: String; var currentStage: String; var stageDescription: String; var summary: String }
    struct AbilityStageHistoryRecord: Codable { var id: UUID; var abilityID: UUID; var stage: String; var descriptionText: String; var sortOrder: Int; var nodeID: UUID? }
    struct AbilityLevelRecord: Codable { var id: UUID; var abilityID: UUID; var sortOrder: Int; var name: String; var descriptionText: String; var cost: String; var note: String }
    struct AbilityConnectionRecord: Codable { var id: UUID; var characterID: UUID; var abilityID: UUID; var currentLevelID: UUID? }
    struct AbilityProgressHistoryRecord: Codable { var id: UUID; var connectionID: UUID; var content: String; var sortOrder: Int; var nodeID: UUID? }
    struct ItemCopyRecord: Codable { var id: UUID; var itemID: UUID; var sortOrder: Int; var name: String }
    struct ItemCopyHoldingRecord: Codable { var id: UUID; var copyID: UUID; var characterID: UUID }
    struct ItemCopyHistoryRecord: Codable { var id: UUID; var copyID: UUID; var content: String; var sortOrder: Int; var nodeID: UUID?; var relatedCharacterIDs: [UUID] }
    struct ItemCopyLevelRecord: Codable { var id: UUID; var copyID: UUID; var levelID: UUID }
    struct CharacterRecord: Codable {
        var id: UUID; var isPinned: Bool; var sortOrder: Int; var realName: String
        var birthYear: String?; var birthMonth: String?; var birthDay: String?; var birthSeason: String?
        var originBackground: String?; var originStory: String?; var gender: String?; var notes: String?
        var personality: String?; var principles: String?; var createdAt: Date; var updatedAt: Date
    }
    struct KinshipRecord: Codable { var id: UUID; var sourceID: UUID; var targetID: UUID?; var role: String }
    struct CharacterProfileRecord: Codable { var id: UUID; var characterID: UUID; var role: String }
    struct CharacterAliasRecord: Codable { var id: UUID; var characterID: UUID; var name: String; var note: String; var createdAt: Date; var updatedAt: Date }
    struct OrganizationRecord: Codable { var id: UUID; var name: String; var description: String }
    struct CharacterOrganizationRecord: Codable { var id: UUID; var characterID: UUID; var organizationID: UUID; var reason: String; var note: String; var joinNodeID: UUID? }
    struct OrganizationIdentityRecord: Codable { var id: UUID; var membershipID: UUID; var nodeID: UUID?; var identity: String; var note: String; var sortOrder: Int; var createdAt: Date; var updatedAt: Date }
    struct AppearanceRecord: Codable { var id: UUID; var characterID: UUID; var nodeID: UUID?; var kind: String; var description: String; var usage: String; var note: String }
    struct PsychologyRecord: Codable { var id: UUID; var characterID: UUID; var nodeID: UUID?; var kind: String; var content: String }
    struct CharacterRelationshipRecord: Codable { var id: UUID; var sourceID: UUID?; var targetID: UUID?; var type: String; var note: String }
    struct RelationshipHistoryRecord: Codable { var id: UUID; var relationshipID: UUID; var nodeID: UUID?; var type: String; var note: String; var sortOrder: Int }
    struct CharacterSummaryRecord: Codable { var id: UUID; var characterID: UUID?; var aliasID: UUID?; var identityID: UUID?; var abilityID: UUID?; var psychologyID: UUID?; var relationshipID: UUID? }
    struct SidebarRecord: Codable { var id: UUID; var key: String; var sortOrder: Int; var visible: Bool; var catalogRevision: Int }
    struct LevelRecord: Codable { var id: UUID; var name: String; var sortOrder: Int; var createdAt: Date }
    struct PowerRecord: Codable {
        var id: UUID; var name: String; var description: String; var formerNames: String; var foreignNames: String; var shortName: String
        var existence: String; var seniorManagers: String; var otherRoster: String; var relationshipNotes: String; var politics: String; var religion: String
        var levelID: UUID?; var religionTermID: UUID?; var governmentTermID: UUID?; var legacyPowerTermID: UUID?; var legacyScopeTermID: UUID?; var purpose: String
        var createdAt: Date; var updatedAt: Date
    }
    struct SubordinationRecord: Codable { var id: UUID; var lowerID: UUID; var upperID: UUID; var createdAt: Date }
    struct MemberRecord: Codable { var id: UUID; var powerID: UUID; var characterID: UUID; var title: String; var status: String; var joinedNodeID: UUID?; var leftNodeID: UUID?; var sortOrder: Int; var createdAt: Date; var updatedAt: Date }
    struct RoleRecord: Codable { var id: UUID; var powerID: UUID; var memberID: UUID; var title: String; var isLeadership: Bool; var status: String; var startNodeID: UUID?; var endNodeID: UUID?; var sortOrder: Int; var createdAt: Date; var updatedAt: Date }
    struct LifecycleRecord: Codable { var id: UUID; var powerID: UUID; var kind: String; var title: String; var detail: String; var nodeID: UUID?; var sortOrder: Int; var createdAt: Date; var updatedAt: Date }
    struct SuccessionRecord: Codable { var id: UUID; var predecessorID: UUID; var successorID: UUID; var kind: String; var nodeID: UUID?; var detail: String; var createdAt: Date; var updatedAt: Date }
    struct AssetLinkRecord: Codable { var id: UUID; var powerID: UUID; var kind: String; var sourceID: UUID; var sortOrder: Int; var createdAt: Date; var updatedAt: Date }
    struct AdvantageRecord: Codable { var id: UUID; var powerID: UUID; var kind: String; var name: String; var detail: String; var sortOrder: Int; var createdAt: Date; var updatedAt: Date }
    struct RelationRecord: Codable { var id: UUID; var sourceID: UUID; var targetID: UUID; var kind: String; var detail: String; var createdAt: Date; var updatedAt: Date }
    struct PlaceRecord: Codable {
        var id: UUID; var name: String; var alternateNames: String?; var placeType: String?; var description: String; var detailedDescription: String?; var notes: String?; var sortOrder: Int; var x: Double?; var y: Double?
    }
    struct WorldTermRecord: Codable {
        var id: UUID; var name: String; var alternateNames: String?; var category: String?; var description: String; var detailedDescription: String?
        var operation: String?; var limitations: String?; var impact: String?; var examples: String?; var notes: String?; var sortOrder: Int
    }
    struct BookMapRecord: Codable { var id: UUID; var level: String; var name: String; var sortOrder: Int }
    struct BookMapVersionRecord: Codable { var id: UUID; var mapID: UUID; var name: String; var sortOrder: Int }
    struct MapPlacementRecord: Codable { var id: UUID; var mapID: UUID; var placeID: UUID; var x: Double; var y: Double; var targetMapID: UUID? }
    struct MapAssetRecord: Codable { var mapID: UUID; var versionID: UUID; var pdfData: Data }
    struct SettingsRecord: Codable {
        var sidebar: [SidebarRecord] = []; var levels: [LevelRecord] = []; var powers: [PowerRecord] = []
        var subordinations: [SubordinationRecord] = []; var members: [MemberRecord] = []; var roles: [RoleRecord] = []
        var lifecycleEvents: [LifecycleRecord] = []; var successions: [SuccessionRecord] = []
        var assets: [AssetLinkRecord] = []; var advantages: [AdvantageRecord] = []; var relations: [RelationRecord] = []
        var places: [PlaceRecord] = []; var worldTerms: [WorldTermRecord] = []; var maps: [BookMapRecord] = []
        var mapVersions: [BookMapVersionRecord] = []; var placements: [MapPlacementRecord] = []; var mapAssets: [MapAssetRecord] = []; var hasMapCatalogProfile = false
    }

    var formatVersion: Int
    var id: UUID
    var name: String
    var sourceBookID: UUID
    var author: String
    var synopsis: String
    var createdAt: Date
    var volumes: [VolumeRecord]
    var timelines: [TimelineRecord]
    var eras: [EraRecord]
    var nodes: [NodeRecord]
    var events: [EventRecord]
    var timelineCards: [TimelineCardRecord]
    var planningMetadata: [PlanningMetadataRecord]
    var currentEraID: UUID?
    var characters: [CharacterRecord]
    var kinships: [KinshipRecord]
    var characterProfiles: [CharacterProfileRecord]
    var characterAliases: [CharacterAliasRecord]
    var organizations: [OrganizationRecord]
    var characterOrganizations: [CharacterOrganizationRecord]
    var organizationIdentities: [OrganizationIdentityRecord]
    var appearances: [AppearanceRecord]
    var psychologies: [PsychologyRecord]
    var characterRelationships: [CharacterRelationshipRecord]
    var relationshipHistories: [RelationshipHistoryRecord]
    var characterSummaries: [CharacterSummaryRecord]
    var itemsData: [BookItemRecord]
    var itemLevels: [ItemLevelRecord]
    var itemHistories: [ItemHistoryRecord]
    var characterItems: [CharacterItemRecord]
    var characterItemHistories: [CharacterItemHistoryRecord]
    var abilities: [CharacterAbilityRecord]
    var abilityHistories: [AbilityStageHistoryRecord]
    var abilityLevels: [AbilityLevelRecord]
    var abilityConnections: [AbilityConnectionRecord]
    var abilityProgressHistories: [AbilityProgressHistoryRecord]
    var itemCopies: [ItemCopyRecord]
    var itemCopyHoldings: [ItemCopyHoldingRecord]
    var itemCopyHistories: [ItemCopyHistoryRecord]
    var itemCopyLevels: [ItemCopyLevelRecord]
    var backgroundText: String?
    var annotations: [AnnotationRecord]
    var storyLines: [LineRecord]
    var stages: [StageRecord]
    var items: [ItemRecord]
    var stageStarts: [StageStartRecord]
    var placements: [PlacementRecord]
    var settings: SettingsRecord

    var sectionCount: Int { volumes.reduce(0) { $0 + $1.sections.count } }

    var containsWritingStructure: Bool {
        !author.isEmpty || !synopsis.isEmpty || !volumes.isEmpty ||
        nodes.contains(where: { $0.sectionID != nil }) || events.contains(where: { $0.sectionID != nil || $0.nodeID == nil }) ||
        !timelineCards.isEmpty || !planningMetadata.isEmpty || backgroundText != nil || !annotations.isEmpty ||
        !storyLines.isEmpty || !stages.isEmpty || !items.isEmpty || !stageStarts.isEmpty || !placements.isEmpty
    }

    // V10.4 templates keep world time and settings, but never carry writing structure
    // or the narrative outline into a new draft. Apply this to older saved templates too.
    func withoutWritingStructure() -> Self {
        var copy = self
        copy.author = ""
        copy.synopsis = ""
        copy.volumes = []
        copy.nodes = nodes.map { var node = $0; node.sectionID = nil; return node }
        let timelineNodeIDs = Set(nodes.map(\.id))
        copy.events = events.filter { $0.nodeID.map(timelineNodeIDs.contains) ?? false }
            .map { var event = $0; event.sectionID = nil; return event }
        copy.timelineCards = []
        copy.planningMetadata = []
        copy.backgroundText = nil
        copy.annotations = []
        copy.storyLines = []
        copy.stages = []
        copy.items = []
        copy.stageStarts = []
        copy.placements = []
        return copy
    }
}

@MainActor
@Observable
final class BookTemplateStore {
    private let directory: URL
    private(set) var templates: [BookTemplateDocument] = []

    init(directory: URL) throws {
        self.directory = directory
        try reload()
    }

    func reload() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        let decoded = try urls.map { try JSONDecoder().decode(BookTemplateDocument.self, from: Data(contentsOf: $0)) }
        if let unsupported = decoded.first(where: { $0.formatVersion != BookTemplateDocument.currentVersion }) {
            throw BookTemplateError.unsupportedVersion(unsupported.formatVersion)
        }
        var current: [BookTemplateDocument] = []
        for (url, template) in zip(urls, decoded) {
            let scoped = template.withoutWritingStructure()
            if template.containsWritingStructure {
                try JSONEncoder().encode(scoped).write(to: url, options: .atomic)
            }
            current.append(scoped)
        }
        templates = current.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ template: BookTemplateDocument) throws {
        guard template.formatVersion == BookTemplateDocument.currentVersion else {
            throw BookTemplateError.unsupportedVersion(template.formatVersion)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(template)
        try data.write(to: fileURL(template.id), options: .atomic)
        try reload()
    }

    func remove(_ template: BookTemplateDocument) throws {
        try FileManager.default.removeItem(at: fileURL(template.id))
        try reload()
    }

    private func fileURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).json") }
}

enum BookTemplateError: LocalizedError {
    case unsupportedVersion(Int)
    case missingTemplate
    case invalidSnapshot(String)
    case cleanupFailure(primary: String, cleanup: [String])

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): "不支援的模板版本：\(version)"
        case .missingTemplate: "找不到這份模板。"
        case .invalidSnapshot(let detail): "模板資料無效：\(detail)"
        case .cleanupFailure(let primary, let cleanup): "建立草稿失敗：\(primary)\n另外有資料清理失敗：\(cleanup.joined(separator: "; "))"
        }
    }
}

@MainActor
enum BookTemplateCoordinator {
    private static func validate(_ template: BookTemplateDocument) throws {
        guard template.formatVersion == BookTemplateDocument.currentVersion else {
            throw BookTemplateError.unsupportedVersion(template.formatVersion)
        }
        func unique(_ ids: [UUID], _ name: String) throws {
            guard Set(ids).count == ids.count else { throw BookTemplateError.invalidSnapshot("\(name) 的識別碼重複") }
        }
        try unique(template.volumes.map(\.id), "卷")
        try unique(template.volumes.flatMap { $0.sections.map(\.id) }, "節")
        try unique(template.characters.map(\.id), "角色")
        try unique(template.timelines.map(\.id), "時間軸")
        try unique(template.eras.map(\.id), "紀元")
        try unique(template.nodes.map(\.id), "時間節點")
        try unique(template.events.map(\.id), "時間事件")
        try unique(template.storyLines.map(\.id), "故事線")
        try unique(template.stages.map(\.id), "階段")
        try unique(template.items.map(\.id), "大綱項目")
        try unique(template.settings.powers.map(\.id), "勢力")
        try unique(template.settings.levels.map(\.id), "勢力層級")
        try unique(template.settings.places.map(\.id), "地點")
        try unique(template.settings.worldTerms.map(\.id), "世界詞條")
        try unique(template.settings.maps.map(\.id), "地圖")
        try unique(template.settings.mapVersions.map(\.id), "地圖版本")
        try unique(template.itemsData.map(\.id), "物品")
        try unique(template.itemLevels.map(\.id), "物品等級")
        try unique(template.characterItems.map(\.id), "角色物品")
        try unique(template.abilities.map(\.id), "角色能力")
        try unique(template.abilityLevels.map(\.id), "能力等級")
        try unique(template.abilityConnections.map(\.id), "能力關聯")
        try unique(template.itemCopies.map(\.id), "物品實例")
        let lineIDs = Set(template.storyLines.map(\.id))
        let stageIDs = Set(template.stages.map(\.id))
        let itemIDs = Set(template.items.map(\.id))
        let volumeIDs = Set(template.volumes.map(\.id))
        let sectionIDs = Set(template.volumes.flatMap { $0.sections.map(\.id) })
        let mapIDs = Set(template.settings.maps.map(\.id))
        let versionIDs = Set(template.settings.mapVersions.map(\.id))
        let placeIDs = Set(template.settings.places.map(\.id))
        guard template.stages.allSatisfy({ lineIDs.contains($0.storyLineID) }),
              template.items.allSatisfy({ lineIDs.contains($0.storyLineID) && ($0.stageID.map(stageIDs.contains) ?? true) }),
              template.stageStarts.allSatisfy({ stageIDs.contains($0.stageID) && volumeIDs.contains($0.volumeID) && (sectionIDs.contains($0.sectionID) || $0.sectionID == $0.volumeID) }),
              template.placements.allSatisfy({ itemIDs.contains($0.itemID) && ($0.relativeItemID.map(itemIDs.contains) ?? true) }),
              template.settings.mapVersions.allSatisfy({ mapIDs.contains($0.mapID) }),
              template.settings.placements.allSatisfy({ mapIDs.contains($0.mapID) && placeIDs.contains($0.placeID) && ($0.targetMapID.map(mapIDs.contains) ?? true) }),
              template.settings.mapAssets.allSatisfy({ mapIDs.contains($0.mapID) && versionIDs.contains($0.versionID) }) else {
            throw BookTemplateError.invalidSnapshot("模板中有失效的書籍或跨資料參照")
        }
    }

    static func snapshot(
        book: Book,
        planning: StoryPlanningStore,
        settingsStore: V5SettingsStore,
        name: String,
        context: ModelContext,
        copyStore: ItemCopyStore,
        abilityStore: AbilityProgressStore
    ) throws -> BookTemplateDocument {
        let volumes = BookStructure.orderedVolumes(in: book).map { volume in
            BookTemplateDocument.VolumeRecord(
                id: volume.id,
                title: volume.title,
                sortOrder: volume.sortOrder,
                sections: BookStructure.orderedSections(in: volume).map {
                    BookTemplateDocument.SectionRecord(id: $0.id, title: $0.title, sortOrder: $0.sortOrder)
                }
            )
        }
        let lines = planning.storyLines(bookID: book.id)
        let stages = lines.flatMap { planning.stages(storyLineID: $0.id) }
        let items = planning.items(bookID: book.id)
        let lineIDs = Set(lines.map(\.id))
        let stageIDs = Set(stages.map(\.id))
        let itemIDs = Set(items.map(\.id))
        let starts = planning.stageStartAnchors.filter { stageIDs.contains($0.stageID) }.compactMap { anchor -> BookTemplateDocument.StageStartRecord? in
            guard let volume = book.volumes.first(where: { $0.id == anchor.volumeID }) else { return nil }
            let section = BookStructure.orderedSections(in: volume).first(where: { $0.id == anchor.sectionID })
            let detail = planning.stageStartDetails.first(where: { $0.stageID == anchor.stageID })
            return BookTemplateDocument.StageStartRecord(
                stageID: anchor.stageID,
                volumeID: volume.id,
                sectionID: section?.id ?? volume.id,
                volumeTitle: volume.title,
                sectionTitle: section?.title ?? anchor.sectionTitleSnapshot,
                headingText: detail?.headingTextSnapshot ?? "",
                headingOffset: nil,
                granularity: detail?.granularityRawValue ?? OutlineStageStartGranularity.section.rawValue
            )
        }
        let placements = planning.itemPlacements.filter { itemIDs.contains($0.outlineItemID) }.map {
            BookTemplateDocument.PlacementRecord(
                itemID: $0.outlineItemID,
                kind: $0.kindRawValue,
                relativeItemID: $0.relativeItemID,
                relativeItemTitle: $0.relativeItemTitleSnapshot,
                localOrder: $0.localOrder
            )
        }
        var settingData = BookTemplateDocument.SettingsRecord()
        settingData.sidebar = try settingsStore.fetchForAnalysis(BookSidebarSetting.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, key: $0.keyRawValue, sortOrder: $0.sortOrder, visible: $0.isVisible, catalogRevision: $0.catalogRevision)
        }
        settingData.levels = try settingsStore.fetchForAnalysis(PowerLevel.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, name: $0.name, sortOrder: $0.sortOrder, createdAt: $0.createdAt)
        }
        settingData.powers = try settingsStore.fetchForAnalysis(PowerUnit.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, name: $0.name, description: $0.powerDescription, formerNames: $0.formerNames, foreignNames: $0.foreignNames,
                  shortName: $0.shortName, existence: $0.existenceStatusRawValue, seniorManagers: $0.seniorManagers, otherRoster: $0.otherRoster,
                  relationshipNotes: $0.relationshipNotes, politics: $0.politics, religion: $0.religion, levelID: $0.levelID,
                  religionTermID: $0.religionWorldTermID, governmentTermID: $0.governmentWorldTermID, legacyPowerTermID: $0.powerWorldTermID,
                  legacyScopeTermID: $0.scopeWorldTermID, purpose: $0.purpose, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        settingData.subordinations = try settingsStore.fetchForAnalysis(PowerSubordination.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, lowerID: $0.lowerPowerID, upperID: $0.upperPowerID, createdAt: $0.createdAt)
        }
        settingData.members = try settingsStore.fetchForAnalysis(PowerMember.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, powerID: $0.powerID, characterID: $0.characterID, title: $0.title, status: $0.statusRawValue,
                  joinedNodeID: $0.joinedNodeID, leftNodeID: $0.leftNodeID, sortOrder: $0.sortOrder, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        settingData.roles = try settingsStore.fetchForAnalysis(PowerMemberRole.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, powerID: $0.powerID, memberID: $0.memberID, title: $0.title, isLeadership: $0.isLeadership,
                  status: $0.statusRawValue, startNodeID: $0.startNodeID, endNodeID: $0.endNodeID, sortOrder: $0.sortOrder, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        settingData.lifecycleEvents = try settingsStore.fetchForAnalysis(PowerLifecycleEvent.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, powerID: $0.powerID, kind: $0.kindRawValue, title: $0.title, detail: $0.detail, nodeID: $0.nodeID,
                  sortOrder: $0.sortOrder, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        settingData.successions = try settingsStore.fetchForAnalysis(PowerSuccessionLink.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, predecessorID: $0.predecessorPowerID, successorID: $0.successorPowerID, kind: $0.kindRawValue,
                  nodeID: $0.nodeID, detail: $0.detail, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        settingData.assets = try settingsStore.fetchForAnalysis(PowerAssetLink.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, powerID: $0.powerID, kind: $0.kindRawValue, sourceID: $0.sourceID, sortOrder: $0.sortOrder, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        settingData.advantages = try settingsStore.fetchForAnalysis(PowerAdvantage.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, powerID: $0.powerID, kind: $0.kindRawValue, name: $0.name, detail: $0.detail, sortOrder: $0.sortOrder, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        settingData.relations = try settingsStore.fetchForAnalysis(PowerRelation.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, sourceID: $0.sourcePowerID, targetID: $0.targetPowerID, kind: $0.kindRawValue, detail: $0.detail, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        settingData.places = try settingsStore.fetchForAnalysis(Place.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, name: $0.name, alternateNames: $0.alternateNames, placeType: $0.placeType, description: $0.placeDescription,
                  detailedDescription: $0.detailedDescription, notes: $0.notes, sortOrder: $0.sortOrder, x: $0.coordinateX, y: $0.coordinateY)
        }
        settingData.worldTerms = try settingsStore.fetchForAnalysis(WorldTerm.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, name: $0.name, alternateNames: $0.alternateNames, category: $0.termCategory, description: $0.termDescription,
                  detailedDescription: $0.detailedDescription, operation: $0.operationAndExpression, limitations: $0.limitationsAndExceptions,
                  impact: $0.worldImpact, examples: $0.usageExamples, notes: $0.notes, sortOrder: $0.sortOrder)
        }
        let sourceMaps = try settingsStore.fetchForAnalysis(BookMap.self).filter { $0.bookID == book.id }
        let sourceVersions = try settingsStore.fetchForAnalysis(BookMapVersion.self).filter { $0.bookID == book.id }
        settingData.maps = sourceMaps.map { .init(id: $0.id, level: $0.levelRawValue, name: $0.name, sortOrder: $0.sortOrder) }
        settingData.mapVersions = sourceVersions.map { .init(id: $0.id, mapID: $0.mapID, name: $0.name, sortOrder: $0.sortOrder) }
        settingData.placements = try settingsStore.fetchForAnalysis(MapPlacement.self).filter { $0.bookID == book.id }.map {
            .init(id: $0.id, mapID: $0.mapID, placeID: $0.placeID, x: $0.coordinateX, y: $0.coordinateY, targetMapID: $0.targetMapID)
        }
        settingData.hasMapCatalogProfile = try settingsStore.fetchForAnalysis(MapCatalogProfile.self).contains { $0.bookID == book.id }
        settingData.mapAssets = try sourceVersions.compactMap { version in
            guard let data = try BookMapPDFStore.pdfData(bookID: book.id, mapID: version.mapID, versionID: version.id) else { return nil }
            return .init(mapID: version.mapID, versionID: version.id, pdfData: data)
        }

        let characterRecords = book.characters.map {
            BookTemplateDocument.CharacterRecord(id: $0.id, isPinned: $0.isPinned, sortOrder: $0.sortOrder, realName: $0.realName,
                birthYear: $0.birthYear, birthMonth: $0.birthMonth, birthDay: $0.birthDay, birthSeason: $0.birthSeason,
                originBackground: $0.originBackground, originStory: $0.originStory, gender: $0.gender, notes: $0.notes,
                personality: $0.personality, principles: $0.principles, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        let characterIDs = Set(characterRecords.map(\.id))
        let sourceTimelines = book.timelines.sorted { $0.sortOrder < $1.sortOrder }
        let sourceNodes = sourceTimelines.flatMap(\.nodes)
        var sourceEras = sourceNodes.compactMap(\.era)
        if let currentEra = book.currentEra { sourceEras.append(currentEra) }
        var seenEraIDs = Set<UUID>()
        sourceEras = sourceEras.filter { seenEraIDs.insert($0.id).inserted }
        let sourceEvents = try context.fetch(FetchDescriptor<Event>()).filter {
            $0.node?.timeline?.book?.id == book.id || $0.section?.volume?.book?.id == book.id
        }
        let timelineRecords = sourceTimelines.map { BookTemplateDocument.TimelineRecord(id: $0.id, name: $0.name, isPrimary: $0.isPrimary, sortOrder: $0.sortOrder) }
        let eraRecords = sourceEras.map { BookTemplateDocument.EraRecord(id: $0.id, name: $0.name, color: $0.color, startOrdinal: $0.startOrdinal) }
        let nodeRecords = sourceNodes.map {
            BookTemplateDocument.NodeRecord(id: $0.id, timelineID: $0.timeline?.id ?? UUID(), eraID: $0.era?.id, sectionID: $0.section?.id,
                year: $0.year, month: $0.month, day: $0.day, isVisible: $0.isVisible, sortOrder: $0.sortOrder)
        }
        let eventRecords = sourceEvents.map {
            BookTemplateDocument.EventRecord(id: $0.id, nodeID: $0.node?.id, sectionID: $0.section?.id,
                title: $0.title, detail: $0.detail, isVisible: $0.isVisible, sortOrder: $0.sortOrder,
                characterIDs: $0.characters.map(\.id).filter(characterIDs.contains))
        }
        let kinshipRecords = book.characters.flatMap(\.kinships).filter { characterIDs.contains($0.sourceCharacter?.id ?? UUID()) }.map {
            BookTemplateDocument.KinshipRecord(id: $0.id, sourceID: $0.sourceCharacter?.id ?? UUID(), targetID: $0.targetCharacter?.id, role: $0.roleRawValue)
        }
        let eventIDs = Set(eventRecords.map(\.id))
        let timelineCards = planning.timelineEventCardMetadata.filter { eventIDs.contains($0.eventID) }.map {
            BookTemplateDocument.TimelineCardRecord(eventID: $0.eventID, outlineItemID: $0.outlineItemID,
                excerptMode: $0.excerptModeRawValue, updatedAt: $0.updatedAt)
        }
        let planningMetadata = planning.planningRecordMetadata.filter { $0.bookID == book.id }.map {
            BookTemplateDocument.PlanningMetadataRecord(id: $0.id, kind: $0.sourceKindRawValue, sourceID: $0.sourceID,
                storyLineID: $0.storyLineID, stageID: $0.stageID, updatedAt: $0.updatedAt)
        }
        let sourceItems = try context.fetch(FetchDescriptor<Item>()).filter { $0.book?.id == book.id }
        let sourceBookItemIDs = Set(sourceItems.map(\.id))
        let itemsData = sourceItems.map { BookTemplateDocument.BookItemRecord(id: $0.id, name: $0.name, itemDescription: $0.itemDescription,
            category: $0.category, appearanceAndMaterial: $0.appearanceAndMaterial, usage: $0.usage, positiveAbility: $0.positiveAbility, negativeAbility: $0.negativeAbility) }
        let itemLevels = try context.fetch(FetchDescriptor<ItemLevel>()).filter { sourceBookItemIDs.contains($0.itemID) }.map {
            BookTemplateDocument.ItemLevelRecord(id: $0.id, itemID: $0.itemID, sortOrder: $0.sortOrder, name: $0.name, itemName: $0.itemName, ability: $0.ability, cost: $0.cost, note: $0.note)
        }
        let characterProfiles = try context.fetch(FetchDescriptor<CharacterProfile>()).filter { $0.character.map { characterIDs.contains($0.id) } ?? false }.map {
            BookTemplateDocument.CharacterProfileRecord(id: $0.id, characterID: $0.character?.id ?? UUID(), role: $0.role)
        }
        let characterAliases = try context.fetch(FetchDescriptor<CharacterAlias>()).filter { $0.character.map { characterIDs.contains($0.id) } ?? false }.map {
            BookTemplateDocument.CharacterAliasRecord(id: $0.id, characterID: $0.character?.id ?? UUID(), name: $0.name, note: $0.note, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        let organizations = try context.fetch(FetchDescriptor<Organization>()).filter { $0.book?.id == book.id }
        let organizationIDs = Set(organizations.map(\.id))
        let organizationRecords = organizations.map { BookTemplateDocument.OrganizationRecord(id: $0.id, name: $0.name, description: $0.organizationDescription) }
        let memberships = try context.fetch(FetchDescriptor<CharacterOrganization>()).filter {
            $0.organization.map { organizationIDs.contains($0.id) } ?? false
        }
        let membershipIDs = Set(memberships.map(\.id))
        let characterOrganizations = memberships.compactMap { membership -> BookTemplateDocument.CharacterOrganizationRecord? in
            guard let characterID = membership.character?.id, characterIDs.contains(characterID),
                  let organizationID = membership.organization?.id else { return nil }
            return .init(id: membership.id, characterID: characterID, organizationID: organizationID, reason: membership.reason, note: membership.note, joinNodeID: membership.joinNode?.id)
        }
        let organizationIdentities = try context.fetch(FetchDescriptor<OrganizationIdentityHistory>()).filter {
            $0.membership.map { membershipIDs.contains($0.id) } ?? false
        }.map {
            BookTemplateDocument.OrganizationIdentityRecord(id: $0.id, membershipID: $0.membership?.id ?? UUID(), nodeID: $0.node?.id,
                identity: $0.identity, note: $0.note, sortOrder: $0.sortOrder, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        let appearances = try context.fetch(FetchDescriptor<CharacterAppearance>()).filter { $0.character.map { characterIDs.contains($0.id) } ?? false }.map {
            BookTemplateDocument.AppearanceRecord(id: $0.id, characterID: $0.character?.id ?? UUID(), nodeID: $0.node?.id, kind: $0.kindRawValue, description: $0.descriptionText, usage: $0.usage, note: $0.note)
        }
        let psychologies = try context.fetch(FetchDescriptor<CharacterPsychology>()).filter { $0.character.map { characterIDs.contains($0.id) } ?? false }.map {
            BookTemplateDocument.PsychologyRecord(id: $0.id, characterID: $0.character?.id ?? UUID(), nodeID: $0.node?.id, kind: $0.kindRawValue, content: $0.content)
        }
        let characterRelationships = try context.fetch(FetchDescriptor<CharacterRelationship>()).filter {
            $0.sourceCharacter.map { characterIDs.contains($0.id) } ?? false
        }.map {
            BookTemplateDocument.CharacterRelationshipRecord(id: $0.id, sourceID: $0.sourceCharacter?.id, targetID: $0.targetCharacter?.id, type: $0.type, note: $0.note)
        }
        let characterRelationshipIDs = Set(characterRelationships.map(\.id))
        let relationshipHistories = try context.fetch(FetchDescriptor<RelationshipHistory>()).filter {
            $0.relationship.map { characterRelationshipIDs.contains($0.id) } ?? false
        }.map {
            BookTemplateDocument.RelationshipHistoryRecord(id: $0.id, relationshipID: $0.relationship?.id ?? UUID(), nodeID: $0.node?.id, type: $0.type, note: $0.note, sortOrder: $0.sortOrder)
        }
        let characterSummaries = try context.fetch(FetchDescriptor<CharacterSummary>()).filter {
            $0.character.map { characterIDs.contains($0.id) } ?? false
        }.map {
            BookTemplateDocument.CharacterSummaryRecord(id: $0.id, characterID: $0.character?.id, aliasID: $0.alias?.id,
                identityID: $0.organizationIdentity?.id, abilityID: $0.ability?.id, psychologyID: $0.psychology?.id, relationshipID: $0.relationship?.id)
        }
        let itemHistories = sourceItems.flatMap(\.histories).map {
            BookTemplateDocument.ItemHistoryRecord(id: $0.id, itemID: $0.item?.id ?? UUID(), content: $0.content, sortOrder: $0.sortOrder,
                nodeID: $0.node?.id, relatedCharacterIDs: $0.relatedCharacters.map(\.id).filter(characterIDs.contains))
        }
        let characterItems = try context.fetch(FetchDescriptor<CharacterItem>()).filter { $0.character?.book?.id == book.id }.map {
            BookTemplateDocument.CharacterItemRecord(id: $0.id, characterID: $0.character?.id ?? UUID(), itemID: $0.item?.id ?? UUID(), quantity: $0.quantity)
        }
        let characterItemIDs = Set(characterItems.map(\.id))
        let characterItemHistories = try context.fetch(FetchDescriptor<CharacterItemHistory>()).filter { $0.characterItem.map { characterItemIDs.contains($0.id) } ?? false }.map {
            BookTemplateDocument.CharacterItemHistoryRecord(id: $0.id, characterItemID: $0.characterItem?.id ?? UUID(), content: $0.content, sortOrder: $0.sortOrder, nodeID: $0.node?.id)
        }
        let sourceAbilities = try context.fetch(FetchDescriptor<CharacterAbility>()).filter { $0.character?.book?.id == book.id }
        let abilityIDs = Set(sourceAbilities.map(\.id))
        let abilities = sourceAbilities.map { BookTemplateDocument.CharacterAbilityRecord(id: $0.id, characterID: $0.character?.id ?? UUID(), name: $0.name,
            currentStage: $0.currentStage, stageDescription: $0.stageDescription, summary: $0.summary) }
        let abilityHistories = sourceAbilities.flatMap(\.history).map {
            BookTemplateDocument.AbilityStageHistoryRecord(id: $0.id, abilityID: $0.ability?.id ?? UUID(), stage: $0.stage,
                descriptionText: $0.descriptionText, sortOrder: $0.sortOrder, nodeID: $0.node?.id)
        }
        let abilityLevels = abilityStore.levels.filter { abilityIDs.contains($0.abilityID) }.map {
            BookTemplateDocument.AbilityLevelRecord(id: $0.id, abilityID: $0.abilityID, sortOrder: $0.sortOrder, name: $0.name,
                descriptionText: $0.descriptionText, cost: $0.cost, note: $0.note)
        }
        let abilityConnections = abilityStore.connections.filter { abilityIDs.contains($0.abilityID) && characterIDs.contains($0.characterID) }.map {
            BookTemplateDocument.AbilityConnectionRecord(id: $0.id, characterID: $0.characterID, abilityID: $0.abilityID, currentLevelID: $0.currentLevelID)
        }
        let connectionIDs = Set(abilityConnections.map(\.id))
        let abilityProgressHistories = abilityStore.histories.filter { connectionIDs.contains($0.connectionID) }.map {
            BookTemplateDocument.AbilityProgressHistoryRecord(id: $0.id, connectionID: $0.connectionID, content: $0.content, sortOrder: $0.sortOrder, nodeID: $0.nodeID)
        }
        let copyIDs = Set(copyStore.copies.filter { sourceBookItemIDs.contains($0.itemID) }.map(\.id))
        let itemCopies = copyStore.copies.filter { sourceBookItemIDs.contains($0.itemID) }.map {
            BookTemplateDocument.ItemCopyRecord(id: $0.id, itemID: $0.itemID, sortOrder: $0.sortOrder, name: $0.name)
        }
        let itemCopyHoldings = copyStore.holdings.filter { copyIDs.contains($0.copyID) && characterIDs.contains($0.characterID) }.map {
            BookTemplateDocument.ItemCopyHoldingRecord(id: $0.id, copyID: $0.copyID, characterID: $0.characterID)
        }
        let itemCopyHistories = copyStore.histories.filter { copyIDs.contains($0.copyID) }.map {
            BookTemplateDocument.ItemCopyHistoryRecord(id: $0.id, copyID: $0.copyID, content: $0.content, sortOrder: $0.sortOrder,
                nodeID: $0.nodeID, relatedCharacterIDs: $0.relatedCharacterIDs.filter(characterIDs.contains))
        }
        let itemCopyLevels = copyStore.levelSelections.filter { copyIDs.contains($0.copyID) }.map {
            BookTemplateDocument.ItemCopyLevelRecord(id: $0.id, copyID: $0.copyID, levelID: $0.levelID)
        }

        return BookTemplateDocument(
            formatVersion: BookTemplateDocument.currentVersion,
            id: UUID(),
            name: name,
            sourceBookID: book.id,
            author: book.author,
            synopsis: book.synopsis,
            createdAt: Date(),
            volumes: volumes,
            timelines: timelineRecords,
            eras: eraRecords,
            nodes: nodeRecords,
            events: eventRecords,
            timelineCards: timelineCards,
            planningMetadata: planningMetadata,
            currentEraID: book.currentEra?.id,
            characters: characterRecords,
            kinships: kinshipRecords,
            characterProfiles: characterProfiles,
            characterAliases: characterAliases,
            organizations: organizationRecords,
            characterOrganizations: characterOrganizations,
            organizationIdentities: organizationIdentities,
            appearances: appearances,
            psychologies: psychologies,
            characterRelationships: characterRelationships,
            relationshipHistories: relationshipHistories,
            characterSummaries: characterSummaries,
            itemsData: itemsData,
            itemLevels: itemLevels,
            itemHistories: itemHistories,
            characterItems: characterItems,
            characterItemHistories: characterItemHistories,
            abilities: abilities,
            abilityHistories: abilityHistories,
            abilityLevels: abilityLevels,
            abilityConnections: abilityConnections,
            abilityProgressHistories: abilityProgressHistories,
            itemCopies: itemCopies,
            itemCopyHoldings: itemCopyHoldings,
            itemCopyHistories: itemCopyHistories,
            itemCopyLevels: itemCopyLevels,
            backgroundText: planning.profile(bookID: book.id)?.backgroundText,
            annotations: planning.annotations.filter { $0.bookID == book.id }.map {
                .init(sectionID: $0.sectionID, plannedOutline: $0.plannedOutline, revisionNote: $0.revisionNote)
            },
            storyLines: lines.filter { lineIDs.contains($0.id) }.map {
                BookTemplateDocument.LineRecord(id: $0.id, title: $0.title, kind: $0.kindRawValue, sortOrder: $0.sortOrder)
            },
            stages: stages.map {
                BookTemplateDocument.StageRecord(id: $0.id, storyLineID: $0.storyLineID, title: $0.title, sortOrder: $0.sortOrder)
            },
            items: items.map {
                BookTemplateDocument.ItemRecord(id: $0.id, storyLineID: $0.storyLineID, stageID: $0.stageID, title: $0.title, detail: $0.detail, sortOrder: $0.sortOrder)
            },
            stageStarts: starts,
            placements: placements,
            settings: settingData
        ).withoutWritingStructure()
    }

    static func apply(
        _ originalTemplate: BookTemplateDocument,
        title: String,
        author: String,
        context: ModelContext,
        planning: StoryPlanningStore,
        settingsStore: V5SettingsStore,
        copyStore: ItemCopyStore,
        abilityStore: AbilityProgressStore
    ) throws -> Book {
        let template = originalTemplate.withoutWritingStructure()
        try validate(template)
        let book = Book(title: title, author: template.author, synopsis: template.synopsis)
        let createdBookID = book.id
        let volumeIDs = Dictionary(uniqueKeysWithValues: template.volumes.map { ($0.id, UUID()) })
        var sectionIDs: [UUID: UUID] = [:]
        for volumeRecord in template.volumes {
            for section in volumeRecord.sections { sectionIDs[section.id] = UUID() }
        }
        let lineIDs = Dictionary(uniqueKeysWithValues: template.storyLines.map { ($0.id, UUID()) })
        let stageIDs = Dictionary(uniqueKeysWithValues: template.stages.map { ($0.id, UUID()) })
        let itemIDs = Dictionary(uniqueKeysWithValues: template.items.map { ($0.id, UUID()) })
        var bookItemIDs: [UUID: UUID] = [:]
        for record in template.itemsData { bookItemIDs[record.id] = UUID() }
        var itemLevelIDs: [UUID: UUID] = [:]
        for record in template.itemLevels { itemLevelIDs[record.id] = UUID() }
        var abilityIDs: [UUID: UUID] = [:]
        for record in template.abilities { abilityIDs[record.id] = UUID() }
        var abilityLevelIDs: [UUID: UUID] = [:]
        for record in template.abilityLevels { abilityLevelIDs[record.id] = UUID() }
        var itemCopyIDs: [UUID: UUID] = [:]
        for record in template.itemCopies { itemCopyIDs[record.id] = UUID() }
        var abilityConnectionIDs: [UUID: UUID] = [:]
        for record in template.abilityConnections { abilityConnectionIDs[record.id] = UUID() }
        let timelineIDs = Dictionary(uniqueKeysWithValues: template.timelines.map { ($0.id, UUID()) })
        let eraIDs = Dictionary(uniqueKeysWithValues: template.eras.map { ($0.id, UUID()) })
        let nodeIDs = Dictionary(uniqueKeysWithValues: template.nodes.map { ($0.id, UUID()) })
        let eventIDs = Dictionary(uniqueKeysWithValues: template.events.map { ($0.id, UUID()) })
        var settingIDMap: [UUID: UUID] = [:]
        let detailRecordIDs = template.characterProfiles.map(\.id) + template.characterAliases.map(\.id) + template.organizations.map(\.id)
            + template.characterOrganizations.map(\.id) + template.organizationIdentities.map(\.id) + template.appearances.map(\.id)
            + template.psychologies.map(\.id) + template.characterRelationships.map(\.id) + template.relationshipHistories.map(\.id)
            + template.characterSummaries.map(\.id) + template.itemHistories.map(\.id) + template.characterItemHistories.map(\.id)
            + template.abilityHistories.map(\.id) + template.abilityProgressHistories.map(\.id) + template.itemCopyHistories.map(\.id)
        for id in detailRecordIDs + template.kinships.map(\.id) + template.settings.levels.map(\.id) + template.settings.powers.map(\.id)
            + template.settings.places.map(\.id) + template.settings.worldTerms.map(\.id) + template.settings.maps.map(\.id)
            + template.settings.mapVersions.map(\.id) + template.settings.members.map(\.id) {
            settingIDMap[id] = UUID()
        }

        do {
        // Register the parent before attaching its SwiftData relationship graph.
        context.insert(book)
        var characterIDs: [UUID: UUID] = [:]
        for record in template.characters { characterIDs[record.id] = UUID() }
        for record in template.kinships { settingIDMap[record.id] = UUID() }
        for volumeRecord in template.volumes.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let volume = Volume(id: volumeIDs[volumeRecord.id]!, title: volumeRecord.title, sortOrder: volumeRecord.sortOrder, book: book)
            context.insert(volume)
            book.volumes.append(volume)
            for sectionRecord in volumeRecord.sections.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let section = Section(id: sectionIDs[sectionRecord.id]!, title: sectionRecord.title, content: AttributedString(""), sortOrder: sectionRecord.sortOrder, wordCount: 0, volume: volume)
                context.insert(section)
                volume.sections.append(section)
            }
        }
        var newCharacters: [UUID: Character] = [:]
        for record in template.characters {
            let character = Character(realName: record.realName, book: book)
            character.id = characterIDs[record.id]!
            character.isPinned = record.isPinned; character.sortOrder = record.sortOrder
            character.birthYear = record.birthYear; character.birthMonth = record.birthMonth; character.birthDay = record.birthDay
            character.birthSeason = record.birthSeason; character.originBackground = record.originBackground
            character.originStory = record.originStory; character.gender = record.gender; character.notes = record.notes
            character.personality = record.personality; character.principles = record.principles
            character.createdAt = record.createdAt; character.updatedAt = record.updatedAt
            book.characters.append(character); newCharacters[record.id] = character
        }
        for record in template.kinships {
            guard let source = newCharacters[record.sourceID], let role = KinshipRole(rawValue: record.role) else { continue }
            let kinship = KinshipRelation(role: role, targetCharacter: record.targetID.flatMap { newCharacters[$0] })
            kinship.id = settingIDMap[record.id]!
            kinship.sourceCharacter = source; source.kinships.append(kinship)
        }
        var newTimelines: [UUID: Timeline] = [:]
        for record in template.timelines {
            let timeline = Timeline(id: timelineIDs[record.id]!, name: record.name, isPrimary: record.isPrimary, sortOrder: record.sortOrder)
            timeline.book = book; book.timelines.append(timeline); newTimelines[record.id] = timeline
        }
        var newEras: [UUID: Era] = [:]
        for record in template.eras {
            let era = Era(id: eraIDs[record.id]!, name: record.name, color: record.color, startOrdinal: record.startOrdinal)
            newEras[record.id] = era
        }
        var newNodes: [UUID: Node] = [:]
        for record in template.nodes {
            guard let timeline = newTimelines[record.timelineID] else { throw BookTemplateError.invalidSnapshot("時間軸節點缺少所屬時間軸") }
            let node = Node(id: nodeIDs[record.id]!, year: record.year, month: record.month, day: record.day)
            node.isVisible = record.isVisible; node.sortOrder = record.sortOrder; node.timeline = timeline; node.era = record.eraID.flatMap { newEras[$0] }
            node.section = record.sectionID.flatMap { oldID in sectionIDs[oldID].flatMap { newID in book.volumes.flatMap(\.sections).first { $0.id == newID } } }
            timeline.nodes.append(node); node.era?.nodes.append(node); newNodes[record.id] = node
        }
        for record in template.events {
            let event = Event(id: eventIDs[record.id]!, title: record.title, detail: record.detail)
            context.insert(event)
            event.isVisible = record.isVisible; event.sortOrder = record.sortOrder; event.node = record.nodeID.flatMap { newNodes[$0] }
            event.section = record.sectionID.flatMap { oldID in sectionIDs[oldID].flatMap { newID in book.volumes.flatMap(\.sections).first { $0.id == newID } } }
            event.characters = record.characterIDs.compactMap { newCharacters[$0] }
            event.node?.events.append(event)
        }
        book.currentEra = template.currentEraID.flatMap { newEras[$0] }
        if book.timelines.isEmpty || book.currentEra == nil { try TimelineEngine.Bootstrap.ensure(for: book, in: context) }

        var newItems: [UUID: Item] = [:]
        for record in template.itemsData {
            let item = Item(id: bookItemIDs[record.id]!, name: record.name, itemDescription: record.itemDescription, category: record.category,
                appearanceAndMaterial: record.appearanceAndMaterial, usage: record.usage, positiveAbility: record.positiveAbility,
                negativeAbility: record.negativeAbility, book: book)
            context.insert(item); newItems[record.id] = item
        }
        var newCharacterItems: [UUID: CharacterItem] = [:]
        for record in template.characterItems {
            guard let character = newCharacters[record.characterID], let item = newItems[record.itemID] else { continue }
            let relation = CharacterItem(id: UUID(), quantity: record.quantity, character: character, item: item)
            context.insert(relation); newCharacterItems[record.id] = relation
        }
        for record in template.itemLevels {
            guard let itemID = bookItemIDs[record.itemID] else { continue }
            context.insert(ItemLevel(id: itemLevelIDs[record.id]!, itemID: itemID, sortOrder: record.sortOrder, name: record.name,
                itemName: record.itemName, ability: record.ability, cost: record.cost, note: record.note))
        }
        for record in template.itemHistories {
            guard let item = newItems[record.itemID] else { continue }
            let history = ItemHistory(id: settingIDMap[record.id]!, content: record.content, sortOrder: record.sortOrder,
                node: record.nodeID.flatMap { newNodes[$0] }, item: item, relatedCharacters: record.relatedCharacterIDs.compactMap { newCharacters[$0] })
            context.insert(history); item.histories.append(history)
        }
        for record in template.characterItemHistories {
            guard let relation = newCharacterItems[record.characterItemID] else { continue }
            let history = CharacterItemHistory(id: settingIDMap[record.id]!, content: record.content, sortOrder: record.sortOrder,
                node: record.nodeID.flatMap { newNodes[$0] }, characterItem: relation)
            context.insert(history); relation.history.append(history)
        }
        var newAbilities: [UUID: CharacterAbility] = [:]
        for record in template.abilities {
            guard let character = newCharacters[record.characterID] else { continue }
            let ability = CharacterAbility(id: abilityIDs[record.id]!, name: record.name, currentStage: record.currentStage,
                stageDescription: record.stageDescription, summary: record.summary, character: character)
            context.insert(ability); newAbilities[record.id] = ability
        }
        for record in template.abilityHistories {
            guard let ability = newAbilities[record.abilityID] else { continue }
            let history = AbilityStageHistory(id: settingIDMap[record.id]!, stage: record.stage, descriptionText: record.descriptionText,
                sortOrder: record.sortOrder, node: record.nodeID.flatMap { newNodes[$0] }, ability: ability)
            context.insert(history); ability.history.append(history)
        }
        var newOrganizations: [UUID: Organization] = [:]
        for record in template.organizations {
            let organization = Organization(id: settingIDMap[record.id]!, name: record.name, organizationDescription: record.description, book: book)
            context.insert(organization); newOrganizations[record.id] = organization
        }
        var newMemberships: [UUID: CharacterOrganization] = [:]
        for record in template.characterOrganizations {
            guard let character = newCharacters[record.characterID], let organization = newOrganizations[record.organizationID] else { continue }
            let membership = CharacterOrganization(id: settingIDMap[record.id]!, reason: record.reason, note: record.note,
                character: character, organization: organization, joinNode: record.joinNodeID.flatMap { newNodes[$0] })
            context.insert(membership); newMemberships[record.id] = membership; organization.memberships.append(membership)
        }
        var newAliases: [UUID: CharacterAlias] = [:]
        for record in template.characterProfiles {
            guard let character = newCharacters[record.characterID] else { continue }
            context.insert(CharacterProfile(id: settingIDMap[record.id]!, role: record.role, character: character))
        }
        for record in template.characterAliases {
            guard let character = newCharacters[record.characterID] else { continue }
            let alias = CharacterAlias(id: settingIDMap[record.id]!, name: record.name, note: record.note, character: character)
            alias.createdAt = record.createdAt; alias.updatedAt = record.updatedAt
            context.insert(alias); newAliases[record.id] = alias
        }
        var newIdentities: [UUID: OrganizationIdentityHistory] = [:]
        for record in template.organizationIdentities {
            guard let membership = newMemberships[record.membershipID] else { continue }
            let identity = OrganizationIdentityHistory(id: settingIDMap[record.id]!, identity: record.identity, note: record.note, sortOrder: record.sortOrder,
                node: record.nodeID.flatMap { newNodes[$0] }, membership: membership)
            identity.createdAt = record.createdAt; identity.updatedAt = record.updatedAt
            context.insert(identity); membership.identityHistory.append(identity); newIdentities[record.id] = identity
        }
        var newPsychologies: [UUID: CharacterPsychology] = [:]
        for record in template.psychologies {
            guard let character = newCharacters[record.characterID], let kind = CharacterPsychologyKind(rawValue: record.kind) else { continue }
            let psychology = CharacterPsychology(id: settingIDMap[record.id]!, kind: kind, content: record.content, node: record.nodeID.flatMap { newNodes[$0] }, character: character)
            context.insert(psychology); newPsychologies[record.id] = psychology
        }
        for record in template.appearances {
            guard let character = newCharacters[record.characterID], let kind = CharacterAppearanceKind(rawValue: record.kind) else { continue }
            context.insert(CharacterAppearance(id: settingIDMap[record.id]!, kind: kind, descriptionText: record.description, usage: record.usage, note: record.note,
                node: record.nodeID.flatMap { newNodes[$0] }, character: character))
        }
        var newRelationships: [UUID: CharacterRelationship] = [:]
        for record in template.characterRelationships {
            let relationship = CharacterRelationship(id: settingIDMap[record.id]!, type: record.type, note: record.note,
                sourceCharacter: record.sourceID.flatMap { newCharacters[$0] }, targetCharacter: record.targetID.flatMap { newCharacters[$0] })
            context.insert(relationship); newRelationships[record.id] = relationship
        }
        for record in template.relationshipHistories {
            guard let relationship = newRelationships[record.relationshipID] else { continue }
            let history = RelationshipHistory(id: settingIDMap[record.id]!, type: record.type, note: record.note, sortOrder: record.sortOrder,
                node: record.nodeID.flatMap { newNodes[$0] }, relationship: relationship)
            context.insert(history); relationship.history.append(history)
        }
        for record in template.characterSummaries {
            let summary = CharacterSummary(id: settingIDMap[record.id]!, character: record.characterID.flatMap { newCharacters[$0] })
            summary.alias = record.aliasID.flatMap { newAliases[$0] }; summary.organizationIdentity = record.identityID.flatMap { newIdentities[$0] }
            summary.ability = record.abilityID.flatMap { newAbilities[$0] }; summary.psychology = record.psychologyID.flatMap { newPsychologies[$0] }
            summary.relationship = record.relationshipID.flatMap { newRelationships[$0] }
            context.insert(summary)
        }

        let planningContext = planning.container.mainContext
        let settingsContext = settingsStore.container.mainContext

        for record in template.settings.sidebar {
            guard let key = SidebarSettingKey(rawValue: record.key) else { continue }
            settingsContext.insert(BookSidebarSetting(id: UUID(), bookID: book.id, key: key, sortOrder: record.sortOrder, isVisible: record.visible, catalogRevision: record.catalogRevision))
        }
        for record in template.settings.levels {
            settingsContext.insert(PowerLevel(id: settingIDMap[record.id]!, bookID: book.id, name: record.name, sortOrder: record.sortOrder, createdAt: record.createdAt))
        }
        for record in template.settings.places {
            settingsContext.insert(Place(id: settingIDMap[record.id]!, bookID: book.id, name: record.name, alternateNames: record.alternateNames, placeType: record.placeType, placeDescription: record.description, detailedDescription: record.detailedDescription, notes: record.notes, sortOrder: record.sortOrder, coordinateX: record.x, coordinateY: record.y))
        }
        for record in template.settings.worldTerms {
            settingsContext.insert(WorldTerm(id: settingIDMap[record.id]!, bookID: book.id, name: record.name, alternateNames: record.alternateNames, termCategory: record.category, termDescription: record.description, detailedDescription: record.detailedDescription, operationAndExpression: record.operation, limitationsAndExceptions: record.limitations, worldImpact: record.impact, usageExamples: record.examples, notes: record.notes, sortOrder: record.sortOrder))
        }
        for record in template.settings.powers {
            let existence = PowerExistenceStatus(rawValue: record.existence) ?? .active
            settingsContext.insert(PowerUnit(id: settingIDMap[record.id]!, bookID: book.id, name: record.name, powerDescription: record.description, formerNames: record.formerNames, foreignNames: record.foreignNames, shortName: record.shortName, existenceStatus: existence, seniorManagers: record.seniorManagers, otherRoster: record.otherRoster, relationshipNotes: record.relationshipNotes, politics: record.politics, religion: record.religion, levelID: record.levelID.flatMap { settingIDMap[$0] }, religionWorldTermID: record.religionTermID.flatMap { settingIDMap[$0] }, governmentWorldTermID: record.governmentTermID.flatMap { settingIDMap[$0] }, powerWorldTermID: record.legacyPowerTermID.flatMap { settingIDMap[$0] }, scopeWorldTermID: record.legacyScopeTermID.flatMap { settingIDMap[$0] }, purpose: record.purpose))
        }
        for record in template.settings.members {
            guard let powerID = settingIDMap[record.powerID], let characterID = characterIDs[record.characterID],
                  let status = PowerMembershipStatus(rawValue: record.status) else { continue }
            settingsContext.insert(PowerMember(id: settingIDMap[record.id]!, bookID: book.id, powerID: powerID, characterID: characterID, title: record.title,
                status: status, joinedNodeID: record.joinedNodeID.flatMap { nodeIDs[$0] }, leftNodeID: record.leftNodeID.flatMap { nodeIDs[$0] }, sortOrder: record.sortOrder,
                createdAt: record.createdAt, updatedAt: record.updatedAt))
        }
        for record in template.settings.roles {
            guard let powerID = settingIDMap[record.powerID], let memberID = settingIDMap[record.memberID],
                  let status = PowerRoleStatus(rawValue: record.status) else { continue }
            let role = PowerMemberRole(id: UUID(), bookID: book.id, powerID: powerID, memberID: memberID, title: record.title,
                isLeadership: record.isLeadership, status: status, startNodeID: record.startNodeID.flatMap { nodeIDs[$0] }, endNodeID: record.endNodeID.flatMap { nodeIDs[$0] },
                sortOrder: record.sortOrder)
            role.createdAt = record.createdAt
            role.updatedAt = record.updatedAt
            settingsContext.insert(role)
        }
        for record in template.settings.lifecycleEvents {
            guard let powerID = settingIDMap[record.powerID], let kind = PowerLifecycleKind(rawValue: record.kind) else { continue }
            settingsContext.insert(PowerLifecycleEvent(id: UUID(), bookID: book.id, powerID: powerID, kind: kind, title: record.title,
                detail: record.detail, nodeID: record.nodeID.flatMap { nodeIDs[$0] }, sortOrder: record.sortOrder))
        }
        for record in template.settings.successions {
            guard let predecessor = settingIDMap[record.predecessorID], let successor = settingIDMap[record.successorID],
                  let kind = PowerTransitionKind(rawValue: record.kind) else { continue }
            settingsContext.insert(PowerSuccessionLink(id: UUID(), bookID: book.id, predecessorPowerID: predecessor, successorPowerID: successor,
                kind: kind, nodeID: record.nodeID.flatMap { nodeIDs[$0] }, detail: record.detail))
        }
        for record in template.settings.subordinations {
            guard let lower = settingIDMap[record.lowerID], let upper = settingIDMap[record.upperID] else { continue }
            settingsContext.insert(PowerSubordination(id: UUID(), bookID: book.id, lowerPowerID: lower, upperPowerID: upper, createdAt: record.createdAt))
        }
        for record in template.settings.advantages {
            guard let powerID = settingIDMap[record.powerID], let kind = PowerAdvantageKind(rawValue: record.kind) else { continue }
            settingsContext.insert(PowerAdvantage(id: UUID(), bookID: book.id, powerID: powerID, kind: kind, name: record.name, detail: record.detail, sortOrder: record.sortOrder, createdAt: record.createdAt, updatedAt: record.updatedAt))
        }
        for record in template.settings.relations {
            guard let source = settingIDMap[record.sourceID], let target = settingIDMap[record.targetID], let kind = PowerRelationKind(rawValue: record.kind) else { continue }
            settingsContext.insert(PowerRelation(id: UUID(), bookID: book.id, sourcePowerID: source, targetPowerID: target, kind: kind, detail: record.detail, createdAt: record.createdAt, updatedAt: record.updatedAt))
        }
        for record in template.settings.maps {
            guard let id = settingIDMap[record.id] else { continue }
            settingsContext.insert(BookMap(id: id, bookID: book.id, levelRawValue: record.level, name: record.name, sortOrder: record.sortOrder))
        }
        for record in template.settings.mapVersions {
            guard let id = settingIDMap[record.id], let mapID = settingIDMap[record.mapID] else { continue }
            settingsContext.insert(BookMapVersion(id: id, bookID: book.id, mapID: mapID, name: record.name, sortOrder: record.sortOrder))
        }
        for record in template.settings.placements {
            guard let mapID = settingIDMap[record.mapID], let placeID = settingIDMap[record.placeID] else { continue }
            settingsContext.insert(MapPlacement(id: UUID(), bookID: book.id, mapID: mapID, placeID: placeID, coordinateX: record.x, coordinateY: record.y, targetMapID: record.targetMapID.flatMap { settingIDMap[$0] }))
        }
        for record in template.settings.assets {
            guard let powerID = settingIDMap[record.powerID], let kind = PowerAssetKind(rawValue: record.kind) else { continue }
            let newSourceID: UUID?
            switch kind {
            case .resource, .technology: newSourceID = settingIDMap[record.sourceID]
            case .item: newSourceID = bookItemIDs[record.sourceID]
            case .ability: newSourceID = abilityIDs[record.sourceID]
            }
            guard let newSourceID else { continue }
            settingsContext.insert(PowerAssetLink(id: UUID(), bookID: book.id, powerID: powerID, kind: kind,
                sourceID: newSourceID, sortOrder: record.sortOrder, createdAt: record.createdAt, updatedAt: record.updatedAt))
        }
        if template.settings.hasMapCatalogProfile { settingsContext.insert(MapCatalogProfile(id: UUID(), bookID: book.id)) }
        let abilityContext = abilityStore.container.mainContext
        for record in template.abilityLevels {
            guard let abilityID = abilityIDs[record.abilityID] else { continue }
            abilityContext.insert(AbilityLevel(id: abilityLevelIDs[record.id]!, abilityID: abilityID, sortOrder: record.sortOrder,
                name: record.name, descriptionText: record.descriptionText, cost: record.cost, note: record.note))
        }
        for record in template.abilityConnections {
            guard let characterID = characterIDs[record.characterID], let abilityID = abilityIDs[record.abilityID] else { continue }
            abilityContext.insert(CharacterAbilityConnection(id: abilityConnectionIDs[record.id]!, characterID: characterID,
                abilityID: abilityID, currentLevelID: record.currentLevelID.flatMap { abilityLevelIDs[$0] }))
        }
        for abilityID in abilityIDs.values { abilityContext.insert(AbilityBookLink(abilityID: abilityID, bookID: book.id)) }
        for record in template.abilityProgressHistories {
            guard let connectionID = abilityConnectionIDs[record.connectionID] else { continue }
            abilityContext.insert(CharacterAbilityHistory(id: UUID(), connectionID: connectionID, content: record.content,
                sortOrder: record.sortOrder, nodeID: record.nodeID.flatMap { nodeIDs[$0] }))
        }
        let copyContext = copyStore.container.mainContext
        for record in template.itemCopies {
            guard let itemID = bookItemIDs[record.itemID] else { continue }
            copyContext.insert(ItemCopy(id: itemCopyIDs[record.id]!, itemID: itemID, sortOrder: record.sortOrder, name: record.name))
        }
        for record in template.itemCopyHoldings {
            guard let copyID = itemCopyIDs[record.copyID], let characterID = characterIDs[record.characterID] else { continue }
            copyContext.insert(ItemCopyHolding(id: UUID(), copyID: copyID, characterID: characterID))
        }
        for record in template.itemCopyHistories {
            guard let copyID = itemCopyIDs[record.copyID] else { continue }
            copyContext.insert(ItemCopyHistory(id: settingIDMap[record.id]!, copyID: copyID, content: record.content, sortOrder: record.sortOrder,
                nodeID: record.nodeID.flatMap { nodeIDs[$0] }, relatedCharacterIDs: record.relatedCharacterIDs.compactMap { characterIDs[$0] }))
        }
        let itemCopyLevelRecords = template.itemCopyLevels.compactMap { record -> ItemCopyLevelSelection? in
            guard let copyID = itemCopyIDs[record.copyID], let levelID = itemLevelIDs[record.levelID] else { return nil }
            return ItemCopyLevelSelection(id: UUID(), copyID: copyID, levelID: levelID)
        }
        for asset in template.settings.mapAssets {
            guard let mapID = settingIDMap[asset.mapID], let versionID = settingIDMap[asset.versionID] else { continue }
            _ = try BookMapPDFStore.saveImportedMap(asset.pdfData, contentType: .pdf, bookID: book.id, mapID: mapID, versionID: versionID)
        }
        for card in template.timelineCards {
            guard let eventID = eventIDs[card.eventID], let excerptMode = TimelineExcerptMode(rawValue: card.excerptMode) else { continue }
            let metadata = TimelineEventCardMetadata(id: UUID(), eventID: eventID, bookID: book.id,
                outlineItemID: card.outlineItemID.flatMap { itemIDs[$0] }, excerptMode: excerptMode, manualExcerpt: "", updatedAt: card.updatedAt)
            planningContext.insert(metadata)
        }
        for record in template.planningMetadata {
            guard let kind = PlanningRecordSourceKind(rawValue: record.kind), let sourceID = settingIDMap[record.sourceID] else { continue }
            planningContext.insert(PlanningRecordMetadata(id: UUID(), sourceKind: kind, sourceID: sourceID, bookID: book.id,
                storyLineID: record.storyLineID.flatMap { lineIDs[$0] }, stageID: record.stageID.flatMap { stageIDs[$0] }, updatedAt: record.updatedAt))
        }
        if let background = template.backgroundText {
            planningContext.insert(BookPlanningProfile(bookID: book.id, backgroundText: background))
        }
        for annotation in template.annotations {
            guard let sectionID = sectionIDs[annotation.sectionID] else { continue }
            planningContext.insert(ChapterAnnotation(sectionID: sectionID, bookID: book.id, plannedOutline: annotation.plannedOutline, revisionNote: annotation.revisionNote))
        }
        for line in template.storyLines {
            guard let id = lineIDs[line.id], let kind = OutlineStoryLineKind(rawValue: line.kind) else { continue }
            planningContext.insert(OutlineStoryLine(id: id, bookID: book.id, title: line.title, kind: kind, sortOrder: line.sortOrder))
        }
        for stage in template.stages {
            guard let id = stageIDs[stage.id], let lineID = lineIDs[stage.storyLineID] else { continue }
            planningContext.insert(OutlineStage(id: id, bookID: book.id, storyLineID: lineID, title: stage.title, sortOrder: stage.sortOrder))
        }
        for item in template.items {
            guard let id = itemIDs[item.id], let lineID = lineIDs[item.storyLineID] else { continue }
            let stageID = item.stageID.flatMap { stageIDs[$0] }
            planningContext.insert(OutlineItem(id: id, bookID: book.id, storyLineID: lineID, stageID: stageID, title: item.title, detail: item.detail, status: .draft, sortOrder: item.sortOrder))
        }
        for start in template.stageStarts {
            guard let stageID = stageIDs[start.stageID], let volumeID = volumeIDs[start.volumeID] else { continue }
            let sectionID = sectionIDs[start.sectionID]
            let location = OutlineStageStartLocation(
                volumeID: volumeID,
                sectionID: sectionID,
                volumeTitle: start.volumeTitle,
                sectionTitle: start.sectionTitle,
                headingText: "",
                headingOffset: nil
            )
            planningContext.insert(OutlineStageStartAnchor(id: UUID(), stageID: stageID, bookID: book.id, location: location))
            planningContext.insert(OutlineStageStartDetail(stageID: stageID, location: location))
        }
        for placement in template.placements {
            guard let itemID = itemIDs[placement.itemID], let kind = OutlineItemPlacementKind(rawValue: placement.kind) else { continue }
            let relativeID = placement.relativeItemID.flatMap { itemIDs[$0] }
            planningContext.insert(OutlineItemPlacement(outlineItemID: itemID, kind: kind, relativeItemID: relativeID, relativeItemTitleSnapshot: placement.relativeItemTitle, localOrder: placement.localOrder))
        }
        try context.save()
        let persistedVolumes = try context.fetch(FetchDescriptor<Volume>())
        let persistedSections = try context.fetch(FetchDescriptor<Section>())
        let volumeTitles = Dictionary(uniqueKeysWithValues: persistedVolumes.filter { $0.book?.id == book.id }.map { ($0.id, $0.title) })
        let sectionTitles = Dictionary(uniqueKeysWithValues: persistedSections.filter { $0.volume?.book?.id == book.id }.map { ($0.id, $0.title) })
        guard template.volumes.allSatisfy({ volumeTitles[volumeIDs[$0.id]!] == $0.title && $0.sections.allSatisfy { sectionTitles[sectionIDs[$0.id]!] == $0.title } }),
              volumeTitles.count == template.volumes.count,
              sectionTitles.count == template.sectionCount else {
            throw BookTemplateError.invalidSnapshot("卷名或節名未完整保存")
        }
        try planningContext.save()
        try settingsContext.save()
        try abilityContext.save()
        try copyContext.save()
        try copyStore.importTemplateLevelSelections(itemCopyLevelRecords)
        settingsStore.didSave()
        try planning.reload()
        try abilityStore.reload()
        return book
        } catch {
            let originalError = error
            var cleanupErrors: [String] = []
            context.rollback()
            if let persisted = try? context.fetch(FetchDescriptor<Book>(predicate: #Predicate { $0.id == createdBookID })).first {
                do { try PersistentModelDeletion.deleteBook(persisted, in: context) }
                catch { cleanupErrors.append("書籍資料：\(error.localizedDescription)") }
            }
            planning.container.mainContext.rollback()
            do {
                try planning.reload()
                try planning.deletePlanningData(bookID: book.id)
            } catch { cleanupErrors.append("大綱資料：\(error.localizedDescription)") }
            settingsStore.container.mainContext.rollback()
            do { try settingsStore.deleteBookData(bookID: book.id) }
            catch { cleanupErrors.append("設定資料：\(error.localizedDescription)") }
            do { try BookMapPDFStore.removeMap(forID: book.id) }
            catch { cleanupErrors.append("地圖檔案：\(error.localizedDescription)") }
            do { try abilityStore.removeTemplateData(abilityIDs: Set(abilityIDs.values)) }
            catch { cleanupErrors.append("能力進度：\(error.localizedDescription)") }
            do { try copyStore.removeTemplateData(itemIDs: Set(bookItemIDs.values)) }
            catch { cleanupErrors.append("物品副本：\(error.localizedDescription)") }
            if cleanupErrors.isEmpty { throw originalError }
            throw BookTemplateError.cleanupFailure(primary: originalError.localizedDescription, cleanup: cleanupErrors)
        }
    }
}

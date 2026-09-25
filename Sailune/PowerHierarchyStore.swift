import Foundation
import SwiftData

enum PowerHierarchyError: LocalizedError {
    case invalidBook
    case invalidLevelName
    case duplicateLevelName(String)
    case levelInUse(String)
    case levelNotAssigned(String)
    case duplicateRelation
    case invalidDirection
    case invalidLevelOrder
    case conflictingRelations([String])

    var errorDescription: String? {
        switch self {
        case .invalidBook:
            "勢力與層級必須屬於同一本書。"
        case .invalidLevelName:
            "層級名稱不可空白。"
        case .duplicateLevelName(let name):
            "同一本書已經有「\(name)」層級。"
        case .levelInUse(let name):
            "「\(name)」仍有勢力使用，無法刪除。"
        case .levelNotAssigned(let name):
            "「\(name)」尚未指定層級，不能建立隸屬關係。"
        case .duplicateRelation:
            "這項直屬關係已經存在。"
        case .invalidDirection:
            "只有較低層級的勢力可以隸屬較高層級的勢力。"
        case .invalidLevelOrder:
            "層級順序不完整，無法儲存。"
        case .conflictingRelations(let relations):
            "這項變更會破壞既有隸屬：\(relations.joined(separator: "、"))"
        }
    }
}

@MainActor
enum PowerHierarchyStore {
    static func ensureDefaultLevels(bookID: UUID, context: ModelContext) throws {
        context.insert(PowerLevel(bookID: bookID, name: "層級 1", sortOrder: 0))
        context.insert(PowerLevel(bookID: bookID, name: "層級 2", sortOrder: 1))
        try context.save()
    }

    static func createLevel(
        bookID: UUID,
        levels: [PowerLevel],
        context: ModelContext
    ) throws -> PowerLevel {
        var suffix = levels.count + 1
        var name = "新層級 \(suffix)"
        while levels.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            suffix += 1
            name = "新層級 \(suffix)"
        }
        let nextOrder = (levels.map(\.sortOrder).max() ?? -1) + 1
        let level = PowerLevel(bookID: bookID, name: name, sortOrder: nextOrder)
        context.insert(level)
        try context.save()
        return level
    }

    static func renameLevel(
        _ level: PowerLevel,
        to proposedName: String,
        bookID: UUID,
        levels: [PowerLevel],
        context: ModelContext
    ) throws {
        guard level.bookID == bookID else { throw PowerHierarchyError.invalidBook }
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw PowerHierarchyError.invalidLevelName }
        guard !levels.contains(where: {
            $0.id != level.id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) else {
            throw PowerHierarchyError.duplicateLevelName(name)
        }
        let oldName = level.name
        level.name = name
        do {
            try context.save()
        } catch {
            level.name = oldName
            throw error
        }
    }

    static func deleteLevel(
        _ level: PowerLevel,
        bookID: UUID,
        powers: [PowerUnit],
        context: ModelContext
    ) throws {
        guard level.bookID == bookID else { throw PowerHierarchyError.invalidBook }
        guard !powers.contains(where: { $0.levelID == level.id }) else {
            throw PowerHierarchyError.levelInUse(level.name)
        }
        context.delete(level)
        try context.save()
    }

    static func changeLevel(
        of power: PowerUnit,
        to level: PowerLevel,
        bookID: UUID,
        levels: [PowerLevel],
        powers: [PowerUnit],
        edges: [PowerSubordination],
        context: ModelContext
    ) throws {
        guard power.bookID == bookID, level.bookID == bookID else {
            throw PowerHierarchyError.invalidBook
        }
        let levelOrders = Dictionary(uniqueKeysWithValues: levels.map { ($0.id, $0.sortOrder) })
        let conflicts = conflictingRelations(
            powers: powers,
            edges: edges,
            levelOrders: levelOrders,
            overridingPowerID: power.id,
            withLevelID: level.id
        )
        guard conflicts.isEmpty else { throw PowerHierarchyError.conflictingRelations(conflicts) }

        let oldLevelID = power.levelID
        power.levelID = level.id
        power.updatedAt = Date()
        do {
            try context.save()
        } catch {
            power.levelID = oldLevelID
            throw error
        }
    }

    static func reorderLevels(
        bookID: UUID,
        orderedIDs: [UUID],
        levels: [PowerLevel],
        powers: [PowerUnit],
        edges: [PowerSubordination],
        context: ModelContext
    ) throws {
        guard Set(orderedIDs) == Set(levels.map(\.id)), orderedIDs.count == levels.count else {
            throw PowerHierarchyError.invalidLevelOrder
        }
        let proposedOrders = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($0.element, $0.offset) })
        let conflicts = conflictingRelations(
            powers: powers,
            edges: edges,
            levelOrders: proposedOrders
        )
        guard conflicts.isEmpty else { throw PowerHierarchyError.conflictingRelations(conflicts) }

        let oldOrders = Dictionary(uniqueKeysWithValues: levels.map { ($0.id, $0.sortOrder) })
        for level in levels {
            level.sortOrder = proposedOrders[level.id] ?? level.sortOrder
        }
        do {
            try context.save()
        } catch {
            for level in levels {
                level.sortOrder = oldOrders[level.id] ?? level.sortOrder
            }
            throw error
        }
    }

    static func upperCandidates(
        for power: PowerUnit,
        powers: [PowerUnit],
        levels: [PowerLevel]
    ) -> [PowerUnit] {
        candidates(for: power, powers: powers, levels: levels) { $0 < $1 }
    }

    static func lowerCandidates(
        for power: PowerUnit,
        powers: [PowerUnit],
        levels: [PowerLevel]
    ) -> [PowerUnit] {
        candidates(for: power, powers: powers, levels: levels) { $0 > $1 }
    }

    static func level(for power: PowerUnit, levels: [PowerLevel]) -> PowerLevel? {
        guard let levelID = power.levelID else { return nil }
        return levels.first { $0.id == levelID }
    }

    private static func candidates(
        for power: PowerUnit,
        powers: [PowerUnit],
        levels: [PowerLevel],
        matches: (Int, Int) -> Bool
    ) -> [PowerUnit] {
        let levelOrders = Dictionary(uniqueKeysWithValues: levels.map { ($0.id, $0.sortOrder) })
        guard let currentLevelID = power.levelID,
              let currentOrder = levelOrders[currentLevelID] else { return [] }
        return powers.filter { candidate in
            guard candidate.id != power.id,
                  let candidateLevelID = candidate.levelID,
                  let candidateOrder = levelOrders[candidateLevelID] else { return false }
            return matches(candidateOrder, currentOrder)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func conflictingRelations(
        powers: [PowerUnit],
        edges: [PowerSubordination],
        levelOrders: [UUID: Int],
        overridingPowerID: UUID? = nil,
        withLevelID: UUID? = nil
    ) -> [String] {
        let powerByID = Dictionary(uniqueKeysWithValues: powers.map { ($0.id, $0) })
        return edges.compactMap { edge in
            guard let lower = powerByID[edge.lowerPowerID],
                  let upper = powerByID[edge.upperPowerID] else { return nil }
            let lowerLevelID = lower.id == overridingPowerID ? withLevelID : lower.levelID
            let upperLevelID = upper.id == overridingPowerID ? withLevelID : upper.levelID
            guard let lowerLevelID,
                  let upperLevelID,
                  let lowerOrder = levelOrders[lowerLevelID],
                  let upperOrder = levelOrders[upperLevelID],
                  lowerOrder > upperOrder else {
                return "\(displayName(lower)) → \(displayName(upper))"
            }
            return nil
        }
    }

    private static func displayName(_ power: PowerUnit) -> String {
        power.name.isEmpty ? "未命名勢力" : power.name
    }
}

@MainActor
enum PowerGraphStore {
    static func directUpperPowers(of power: PowerUnit, edges: [PowerSubordination], powers: [PowerUnit]) -> [PowerUnit] {
        let ids = Set(edges.filter { $0.lowerPowerID == power.id }.map(\.upperPowerID))
        return powers.filter { ids.contains($0.id) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func directLowerPowers(of power: PowerUnit, edges: [PowerSubordination], powers: [PowerUnit]) -> [PowerUnit] {
        let ids = Set(edges.filter { $0.upperPowerID == power.id }.map(\.lowerPowerID))
        return powers.filter { ids.contains($0.id) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func addDirectSubordination(
        lower: PowerUnit,
        upper: PowerUnit,
        bookID: UUID,
        levels: [PowerLevel],
        edges: inout [PowerSubordination],
        context: ModelContext
    ) throws {
        guard lower.id != upper.id,
              lower.bookID == bookID,
              upper.bookID == bookID else { throw PowerHierarchyError.invalidBook }
        guard !edges.contains(where: { $0.lowerPowerID == lower.id && $0.upperPowerID == upper.id }) else {
            throw PowerHierarchyError.duplicateRelation
        }
        guard let lowerLevel = PowerHierarchyStore.level(for: lower, levels: levels) else {
            throw PowerHierarchyError.levelNotAssigned(lower.name.isEmpty ? "未命名勢力" : lower.name)
        }
        guard let upperLevel = PowerHierarchyStore.level(for: upper, levels: levels) else {
            throw PowerHierarchyError.levelNotAssigned(upper.name.isEmpty ? "未命名勢力" : upper.name)
        }
        guard lowerLevel.sortOrder > upperLevel.sortOrder else {
            throw PowerHierarchyError.invalidDirection
        }
        let edge = PowerSubordination(bookID: bookID, lowerPowerID: lower.id, upperPowerID: upper.id)
        context.insert(edge)
        edges.append(edge)
        try context.save()
    }

    static func delete(
        _ power: PowerUnit,
        edges: [PowerSubordination],
        context: ModelContext
    ) throws {
        edges.filter { $0.lowerPowerID == power.id || $0.upperPowerID == power.id }
            .forEach(context.delete)
        context.delete(power)
        try context.save()
    }
}

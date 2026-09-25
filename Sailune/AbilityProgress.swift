import Foundation
import SwiftData
import Observation
import OSLog

enum AbilityProgressSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [AbilityLevel.self, CharacterAbilityConnection.self, CharacterAbilityHistory.self, AbilityBookLink.self]
    }
}

@Model final class AbilityLevel {
    @Attribute(.unique) var id: UUID
    var abilityID: UUID; var sortOrder: Int; var name: String
    var descriptionText: String; var cost: String; var note: String
    var createdAt: Date; var updatedAt: Date
    init(id: UUID = UUID(), abilityID: UUID, sortOrder: Int = 0, name: String = "", descriptionText: String = "", cost: String = "", note: String = "") {
        self.id = id; self.abilityID = abilityID; self.sortOrder = sortOrder; self.name = name
        self.descriptionText = descriptionText; self.cost = cost; self.note = note; self.createdAt = Date(); self.updatedAt = Date()
    }
}

@Model final class CharacterAbilityConnection {
    @Attribute(.unique) var id: UUID
    var characterID: UUID; var abilityID: UUID; var currentLevelID: UUID?
    var createdAt: Date; var updatedAt: Date
    init(id: UUID = UUID(), characterID: UUID, abilityID: UUID, currentLevelID: UUID? = nil) {
        self.id = id; self.characterID = characterID; self.abilityID = abilityID; self.currentLevelID = currentLevelID; self.createdAt = Date(); self.updatedAt = Date()
    }
}

@Model final class CharacterAbilityHistory {
    @Attribute(.unique) var id: UUID
    var connectionID: UUID; var content: String; var sortOrder: Int; var nodeID: UUID?
    var createdAt: Date; var updatedAt: Date
    init(id: UUID = UUID(), connectionID: UUID, content: String = "", sortOrder: Int = 0, nodeID: UUID? = nil) {
        self.id = id; self.connectionID = connectionID; self.content = content; self.sortOrder = sortOrder; self.nodeID = nodeID; self.createdAt = Date(); self.updatedAt = Date()
    }
}

@Model final class AbilityBookLink {
    @Attribute(.unique) var id: UUID
    var abilityID: UUID; var bookID: UUID
    init(id: UUID = UUID(), abilityID: UUID, bookID: UUID) { self.id = id; self.abilityID = abilityID; self.bookID = bookID }
}

@MainActor @Observable final class AbilityProgressStore {
    private static let logger = Logger(subsystem: "com.MooNest.Sailune", category: "AbilityProgressStore")
    /// Keep the container alive for as long as any of its model instances are
    /// displayed. Releasing it resets the context and invalidates those models.
    let container: ModelContainer
    private let context: ModelContext
    private(set) var levels: [AbilityLevel] = []; private(set) var connections: [CharacterAbilityConnection] = []
    private(set) var histories: [CharacterAbilityHistory] = []; private(set) var bookLinks: [AbilityBookLink] = []
    private(set) var persistenceErrorMessage: String?
    init(container: ModelContainer) throws { self.container = container; context = container.mainContext; context.autosaveEnabled = true; try reload() }
    func reload() throws { levels = try context.fetch(FetchDescriptor<AbilityLevel>()); connections = try context.fetch(FetchDescriptor<CharacterAbilityConnection>()); histories = try context.fetch(FetchDescriptor<CharacterAbilityHistory>()); bookLinks = try context.fetch(FetchDescriptor<AbilityBookLink>()) }
    func save() {
        do {
            try context.save()
            persistenceErrorMessage = nil
        } catch {
            context.rollback()
            do { try reload() }
            catch { Self.logger.error("Reload after save rollback failed: \(String(describing: error), privacy: .private)") }
            let nsError = error as NSError
            persistenceErrorMessage = "\(nsError.domain) \(nsError.code)：\(nsError.localizedDescription)"
        }
    }
    func clearPersistenceError() { persistenceErrorMessage = nil }
    func resolvedBookIDs(for abilities: [CharacterAbility]) -> [UUID: UUID] {
        let validAbilityIDs = Set(abilities.map(\.id))
        var result = Dictionary(uniqueKeysWithValues: abilities.compactMap { ability in
            ability.character?.book.map { (ability.id, $0.id) }
        })
        for link in bookLinks where validAbilityIDs.contains(link.abilityID) {
            result[link.abilityID] = link.bookID
        }
        return result
    }
    func register(abilityID: UUID, bookID: UUID) throws {
        guard !bookLinks.contains(where: { $0.abilityID == abilityID }) else { return }
        let link = AbilityBookLink(abilityID: abilityID, bookID: bookID)
        context.insert(link)
        do {
            try context.save()
            bookLinks.append(link)
            persistenceErrorMessage = nil
        } catch {
            context.rollback()
            do { try reload() }
            catch { Self.logger.error("Reload after link registration rollback failed: \(String(describing: error), privacy: .private)") }
            let nsError = error as NSError
            persistenceErrorMessage = "\(nsError.domain) \(nsError.code)：\(nsError.localizedDescription)"
            throw error
        }
    }
    func addLevel(abilityID: UUID) { let level = AbilityLevel(abilityID: abilityID, sortOrder: (levels.filter { $0.abilityID == abilityID }.map(\.sortOrder).max() ?? -1) + 1, name: "新等級"); context.insert(level); levels.append(level); save() }
    func deleteAbilityLevel(_ level: AbilityLevel) { connections.filter { $0.currentLevelID == level.id }.forEach { $0.currentLevelID = nil }; context.delete(level); levels.removeAll { $0.id == level.id }; save() }
    func connect(characterID: UUID, abilityID: UUID) { guard !connections.contains(where: { $0.characterID == characterID && $0.abilityID == abilityID }) else { return }; let connection = CharacterAbilityConnection(characterID: characterID, abilityID: abilityID); context.insert(connection); connections.append(connection); save() }
    func deleteConnection(_ connection: CharacterAbilityConnection) { histories.filter { $0.connectionID == connection.id }.forEach(context.delete); histories.removeAll { $0.connectionID == connection.id }; context.delete(connection); connections.removeAll { $0.id == connection.id }; save() }
    func addHistory(connectionID: UUID) { let history = CharacterAbilityHistory(connectionID: connectionID, sortOrder: (histories.filter { $0.connectionID == connectionID }.map(\.sortOrder).max() ?? -1) + 1); context.insert(history); histories.append(history); save() }
    func deleteHistory(_ history: CharacterAbilityHistory) { context.delete(history); histories.removeAll { $0.id == history.id }; save() }
    func deleteAbility(abilityID: UUID) {
        levels.filter { $0.abilityID == abilityID }.forEach(context.delete)
        let removedConnectionIDs = Set(connections.filter { $0.abilityID == abilityID }.map(\.id))
        histories.filter { removedConnectionIDs.contains($0.connectionID) }.forEach(context.delete)
        connections.filter { $0.abilityID == abilityID }.forEach(context.delete)
        bookLinks.filter { $0.abilityID == abilityID }.forEach(context.delete)
        levels.removeAll { $0.abilityID == abilityID }
        histories.removeAll { removedConnectionIDs.contains($0.connectionID) }
        connections.removeAll { $0.abilityID == abilityID }
        bookLinks.removeAll { $0.abilityID == abilityID }
        save()
    }

    func migrateLegacy(_ abilities: [CharacterAbility]) throws {
        for ability in abilities {
            guard let character = ability.character, let bookID = character.book?.id else { continue }
            if !bookLinks.contains(where: { $0.abilityID == ability.id }) {
                let link = AbilityBookLink(abilityID: ability.id, bookID: bookID)
                context.insert(link)
                bookLinks.append(link)
            }
            let connection: CharacterAbilityConnection
            if let existing = connections.first(where: { $0.abilityID == ability.id && $0.characterID == character.id }) {
                connection = existing
            } else {
                connection = CharacterAbilityConnection(characterID: character.id, abilityID: ability.id)
                context.insert(connection)
                connections.append(connection)
            }
            for entry in ability.history where !histories.contains(where: { $0.connectionID == connection.id && $0.sortOrder == entry.sortOrder }) {
                let migrated = CharacterAbilityHistory(
                    connectionID: connection.id,
                    content: [entry.stage, entry.descriptionText].filter { !$0.isEmpty }.joined(separator: "："),
                    sortOrder: entry.sortOrder,
                    nodeID: entry.node?.id
                )
                context.insert(migrated)
                histories.append(migrated)
            }
        }
        do {
            if context.hasChanges { try context.save() }
            try reload()
            persistenceErrorMessage = nil
        } catch {
            context.rollback()
            do { try reload() }
            catch { Self.logger.error("Reload after legacy migration rollback failed: \(String(describing: error), privacy: .private)") }
            throw error
        }
    }

    func reconcile(
        validBookIDs: Set<UUID>,
        characterBookIDs: [UUID: UUID],
        abilityBookIDs: [UUID: UUID],
        validNodeIDs: Set<UUID>
    ) throws {
        let orderedBookLinks = bookLinks.sorted { ($0.abilityID.uuidString, $0.id.uuidString) < ($1.abilityID.uuidString, $1.id.uuidString) }
        var seenAbilityLinks = Set<UUID>()
        for link in orderedBookLinks {
            guard let expectedBookID = abilityBookIDs[link.abilityID],
                  validBookIDs.contains(link.bookID),
                  link.bookID == expectedBookID,
                  seenAbilityLinks.insert(link.abilityID).inserted else {
                context.delete(link)
                continue
            }
        }

        for level in levels where abilityBookIDs[level.abilityID] == nil {
            context.delete(level)
        }

        let orderedConnections = connections.sorted {
            ($0.characterID.uuidString, $0.abilityID.uuidString, $0.id.uuidString)
                < ($1.characterID.uuidString, $1.abilityID.uuidString, $1.id.uuidString)
        }
        var seenConnectionKeys = Set<String>()
        var validConnectionIDs = Set<UUID>()
        for connection in orderedConnections {
            guard let characterBookID = characterBookIDs[connection.characterID],
                  let abilityBookID = abilityBookIDs[connection.abilityID],
                  characterBookID == abilityBookID else {
                context.delete(connection)
                continue
            }
            let key = "\(connection.characterID.uuidString)|\(connection.abilityID.uuidString)"
            guard seenConnectionKeys.insert(key).inserted else {
                context.delete(connection)
                continue
            }
            validConnectionIDs.insert(connection.id)
        }

        let validLevelsByID = Dictionary(uniqueKeysWithValues: levels.filter { abilityBookIDs[$0.abilityID] != nil }.map { ($0.id, $0) })
        for connection in orderedConnections where validConnectionIDs.contains(connection.id) {
            if let levelID = connection.currentLevelID,
               validLevelsByID[levelID]?.abilityID != connection.abilityID {
                connection.currentLevelID = nil
            }
        }
        for history in histories {
            guard validConnectionIDs.contains(history.connectionID) else {
                context.delete(history)
                continue
            }
            if let nodeID = history.nodeID, !validNodeIDs.contains(nodeID) {
                history.nodeID = nil
            }
        }

        do {
            if context.hasChanges { try context.save() }
            try reload()
            persistenceErrorMessage = nil
        } catch {
            context.rollback()
            do { try reload() }
            catch { Self.logger.error("Reload after reconciliation rollback failed: \(String(describing: error), privacy: .private)") }
            throw error
        }
    }
}

import Foundation
import CryptoKit
import SQLite3
import SwiftData

struct WorkspaceTransferEligibility: Identifiable {
    let id: String
    let reason: String?
    var canTransfer: Bool { reason == nil }
}

enum WorkspaceTransferError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let reason): reason }
    }
}

/// 移入是專用的本機交易；安全副本留在工作區外，不放寬一般備份的歸屬限制。
@MainActor
final class WorkspaceTransferService {
    enum Phase: String, Codable { case preparing, prepared, installing, committed, completed }
    struct Journal: Codable {
        var version = 1
        let transactionID: UUID
        let destinationID: String
        var phase: Phase
        var models: [String: String]? = nil
        var assets: [String: String]? = nil
    }
    let registry: WorkspaceRegistry
    private let fileManager = FileManager.default
    // 測試在實際落盤／rename 邊界中斷；不以替身驗證資料內容。
    var checkpoint: (String) throws -> Void = { _ in }
    var journalURL: URL { registry.root.appendingPathComponent("transfer.json") }
    var hasPendingTransfer: Bool { fileManager.fileExists(atPath: journalURL.path) }

    init(registry: WorkspaceRegistry) { self.registry = registry }

    func locations(_ id: String) throws -> SailuneDataLocations {
        SailuneDataLocations(mainStore: try registry.directory(for: id).appendingPathComponent("Sailune-v5.store"), workspaceID: id)
    }

    func sourceReason() -> String? {
        do {
            guard !hasPendingTransfer else { throw WorkspaceTransferError.invalid("上次移入尚未完成，請先重試。") }
            let source = try locations("guest")
            try validateFiles(source)
            try rejectPublishedSource(source)
            guard try hasUserData(source) else { throw WorkspaceTransferError.invalid("未登入空間沒有可移入的資料。") }
            return nil
        } catch { return error.localizedDescription }
    }

    func eligibility(for id: String) -> WorkspaceTransferEligibility {
        do {
            guard !hasPendingTransfer else { throw WorkspaceTransferError.invalid("上次移入尚未完成，請先重試。") }
            guard registry.document.accounts.contains(where: { $0.id == id && !$0.isDeleting }) else {
                throw WorkspaceTransferError.invalid("此帳號清理未完成或不存在。")
            }
            if let reason = sourceReason() { throw WorkspaceTransferError.invalid(reason) }
            let destination = try locations(id)
            try validateFiles(destination)
            for name in ["Sailune.store", "Sailune-v3.store"] where fileManager.fileExists(atPath: destination.mainStore.deletingLastPathComponent().appendingPathComponent(name).path) {
                throw WorkspaceTransferError.invalid("目的帳號含舊資料庫，無法判定為空。")
            }
            guard try !hasUserData(destination) else { throw WorkspaceTransferError.invalid("此帳號已有資料，無法移入。") }
            return WorkspaceTransferEligibility(id: id, reason: nil)
        } catch { return WorkspaceTransferEligibility(id: id, reason: error.localizedDescription) }
    }

    func prepare(destinationID: String) throws {
        let eligibility = eligibility(for: destinationID)
        guard eligibility.canTransfer else { throw WorkspaceTransferError.invalid(eligibility.reason ?? "無法移入。") }
        var journal = Journal(transactionID: UUID(), destinationID: destinationID, phase: .preparing)
        let directory = try recoveryDirectory(journal)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try write(journal)
        let source = try locations("guest")
        let destination = try locations(destinationID)
        try SailuneBackupService.createBackup(at: directory.appendingPathComponent("Guest.sailunebackup"), locations: source)
        try SailuneBackupService.createBackup(at: directory.appendingPathComponent("Destination.sailunebackup"), locations: destination)
        try checkpoint("backups")
        let stage = stageLocations(journal, directory: directory)
        try snapshot(source, to: stage)
        let before = try modelFingerprints(source)
        try checkpoint("copied")
        // 開啟的是副本，任何 repair／migration 都不能改動来源。
        do {
            let bundle = try WorkspaceBundle(locations: stage)
            try bundle.save()
        }
        let after = try modelFingerprints(stage)
        let differences = before.keys.filter { before[$0] != after[$0] }.sorted()
        let sourceAssets = try assetFingerprints(source)
        let stagedAssets = try assetFingerprints(stage)
        let assetDifferences = Set(sourceAssets.keys).union(stagedAssets.keys).filter { sourceAssets[$0] != stagedAssets[$0] }.sorted()
        guard differences.isEmpty, assetDifferences.isEmpty else {
            throw WorkspaceTransferError.invalid("暫存資料驗證不一致（\((differences + assetDifferences).joined(separator: ", "))），未登入資料仍保留。")
        }
        try checkpoint("validated")
        journal.models = before
        journal.assets = try assetFingerprints(stage)
        journal.phase = .prepared
        try write(journal)
    }

    /// 必須由 Coordinator 卸載全部工作區後呼叫。
    func install() throws -> Journal {
        var journal = try read()
        guard journal.phase == .prepared else { throw WorkspaceTransferError.invalid("移入階段不正確。") }
        let directory = try recoveryDirectory(journal)
        let target = try registry.directory(for: journal.destinationID)
        journal.phase = .installing
        try write(journal)
        try fileManager.moveItem(at: target, to: directory.appendingPathComponent("original-destination"))
        try checkpoint("destination-moved")
        try fileManager.moveItem(at: directory.appendingPathComponent("staged"), to: target)
        try checkpoint("installed")
        return journal
    }

    func commit(_ installed: Journal) throws {
        var journal = installed
        journal.phase = .committed
        try write(journal)
    }

    /// 已 commit 就完成來源重置；保留整個原 Guest 及明確標 Guest 的備份。
    func finishCommittedTransfer() throws -> String {
        var journal = try read()
        guard journal.phase == .committed || journal.phase == .completed else {
            throw WorkspaceTransferError.invalid("移入尚未提交。")
        }
        let destination = try locations(journal.destinationID)
        try validateFiles(destination)
        guard journal.models == (try modelFingerprints(destination)), journal.assets == (try assetFingerprints(destination)) else {
            throw WorkspaceTransferError.invalid("已移入資料驗證失敗，來源與安全備份仍保留。")
        }
        do {
            let verified = try WorkspaceBundle(locations: destination)
            try verified.save()
        }
        guard journal.models == (try modelFingerprints(destination)), journal.assets == (try assetFingerprints(destination)) else {
            throw WorkspaceTransferError.invalid("目的資料開啟後不一致，已停止來源重置。")
        }
        let directory = try recoveryDirectory(journal)
        let guest = try registry.directory(for: "guest")
        let original = directory.appendingPathComponent("original-guest")
        if journal.phase == .committed {
            if !fileManager.fileExists(atPath: original.path) {
                try fileManager.moveItem(at: guest, to: original)
                try checkpoint("guest-moved")
            }
            let guestLocations = try locations("guest")
            UserDefaults(suiteName: guestLocations.preferencesURL.path)?.removePersistentDomain(forName: guestLocations.preferencesURL.path)
            do {
                let empty = try WorkspaceBundle(locations: guestLocations)
                try empty.save()
            }
            try checkpoint("guest-reset")
            journal.phase = .completed
            try write(journal)
        }
        try registry.update { $0.selectedID = journal.destinationID }
        try checkpoint("registry-updated")
        try fileManager.removeItem(at: journalURL)
        return journal.destinationID
    }

    /// 啟動時在開任何正式 container 前執行。commit 前復位，commit 後完成，不重複匯入。
    func recoverIfNeeded() throws -> String? {
        guard hasPendingTransfer else { return nil }
        let journal = try read()
        if journal.phase == .committed || journal.phase == .completed { return try finishCommittedTransfer() }
        let directory = try recoveryDirectory(journal)
        let original = directory.appendingPathComponent("original-destination")
        let target = try registry.directory(for: journal.destinationID)
        if fileManager.fileExists(atPath: original.path) {
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.moveItem(at: target, to: directory.appendingPathComponent("uncommitted-destination"))
            }
            try fileManager.moveItem(at: original, to: target)
            try checkpoint("rolled-back")
        }
        try fileManager.removeItem(at: journalURL)
        return nil
    }

    private func read() throws -> Journal {
        try WorkspaceRegistry.rejectSymbolicLinks(at: journalURL)
        let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        guard journal.version == 1, registry.document.accounts.contains(where: { $0.id == journal.destinationID && !$0.isDeleting }) else {
            throw WorkspaceTransferError.invalid("移入復原紀錄無效，未變更資料。")
        }
        _ = try recoveryDirectory(journal)
        return journal
    }

    private func write(_ journal: Journal) throws {
        try WorkspaceRegistry.rejectSymbolicLinks(at: journalURL)
        try checkpoint("journal-\(journal.phase.rawValue)")
        try JSONEncoder().encode(journal).write(to: journalURL, options: .atomic)
    }

    private func recoveryDirectory(_ journal: Journal) throws -> URL {
        let directory = registry.root.appendingPathComponent("Transfer Recovery", isDirectory: true)
            .appendingPathComponent(journal.transactionID.uuidString, isDirectory: true)
        try WorkspaceRegistry.rejectSymbolicLinks(at: directory)
        if fileManager.fileExists(atPath: directory.path) { try rejectLinksRecursively(directory) }
        return directory
    }

    private func stageLocations(_ journal: Journal, directory: URL) -> SailuneDataLocations {
        SailuneDataLocations(mainStore: directory.appendingPathComponent("staged/Sailune-v5.store"), workspaceID: journal.destinationID)
    }

    private func managedAssets(_ locations: SailuneDataLocations) -> [URL] {
        [locations.coversDirectory, locations.mapsDirectory, locations.aiConversationsDirectory,
         locations.bookTemplatesDirectory, locations.publicationStatusURL, locations.publicationTagsURL,
         locations.writingStatsURL, locations.forumPostsURL, locations.preferencesURL]
    }

    private func validateFiles(_ locations: SailuneDataLocations) throws {
        let directory = locations.mainStore.deletingLastPathComponent()
        try WorkspaceRegistry.rejectSymbolicLinks(at: directory)
        guard fileManager.fileExists(atPath: directory.path) else { throw WorkspaceTransferError.invalid("資料空間尚未建立。") }
        try rejectLinksRecursively(directory)
        guard !fileManager.fileExists(atPath: locations.pendingRestoreURL.path) else {
            throw WorkspaceTransferError.invalid("此空間有待還原備份，請先完成還原。")
        }
        if fileManager.fileExists(atPath: locations.preferencesURL.path) {
            guard try PropertyListSerialization.propertyList(from: Data(contentsOf: locations.preferencesURL), format: nil) is [String: Any] else {
                throw WorkspaceTransferError.invalid("偏好資料無法辨識，未變更資料。")
            }
        }
        let stores = locations.stores.map { $0.url.lastPathComponent }
        let oldStores = ["Sailune-v3.store", "Sailune.store"]
        let allowed = Set((stores + oldStores).flatMap { [$0, $0 + "-wal", $0 + "-shm"] } + ["Sailune", "workspace-preferences.plist", ".DS_Store"])
        for item in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            guard allowed.contains(item.lastPathComponent) else { throw WorkspaceTransferError.invalid("資料空間含未辨識檔案：\(item.lastPathComponent)") }
        }
        let assetsRoot = directory.appendingPathComponent("Sailune")
        if fileManager.fileExists(atPath: assetsRoot.path) {
            let known = Set(managedAssets(locations).filter { $0.deletingLastPathComponent() == assetsRoot }.map(\.lastPathComponent) + ["Recovery Backups", ".DS_Store"])
            for item in try fileManager.contentsOfDirectory(at: assetsRoot, includingPropertiesForKeys: nil) {
                guard known.contains(item.lastPathComponent) else { throw WorkspaceTransferError.invalid("資料空間含未辨識資產：\(item.lastPathComponent)") }
            }
        }
        for store in locations.stores {
            guard fileManager.fileExists(atPath: store.url.path) else { throw WorkspaceTransferError.invalid("資料庫不完整：\(store.name)") }
            guard try TransferSQLite.rows(store.url, sql: "PRAGMA quick_check") == [["t:ok"]] else {
                throw WorkspaceTransferError.invalid("資料庫檢查失敗：\(store.name)")
            }
        }
    }

    private func rejectLinksRecursively(_ root: URL) throws {
        try WorkspaceRegistry.rejectSymbolicLinks(at: root)
        let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        if values.isDirectory == true {
            for child in try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) { try rejectLinksRecursively(child) }
        } else if values.isRegularFile != true { throw WorkspaceTransferError.invalid("資料含非一般檔案。") }
    }

    private func snapshot(_ source: SailuneDataLocations, to target: SailuneDataLocations) throws {
        try fileManager.createDirectory(at: target.mainStore.deletingLastPathComponent(), withIntermediateDirectories: true)
        for (index, store) in source.stores.enumerated() { try SailuneBackupService.sqliteSnapshot(from: store.url, to: target.stores[index].url) }
        for (old, new) in zip(managedAssets(source), managedAssets(target)) where fileManager.fileExists(atPath: old.path) {
            try fileManager.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: old, to: new)
        }
    }

    private func rejectPublishedSource(_ source: SailuneDataLocations) throws {
        let publication = try BookPublicationStore(url: source.publicationStatusURL, tagsURL: source.publicationTagsURL)
        guard publication.statuses.values.allSatisfy({ $0 == .draft }) else {
            throw WorkspaceTransferError.invalid("未登入空間含已發布紀錄，目前無法直接移入帳號。")
        }
    }

    private func modelTables(_ locations: SailuneDataLocations) throws -> [[String]] {
        let schemas: [[any PersistentModel.Type]] = [NovelWriterSchemaV5.models, V5SettingsSchemaV13.models,
            ItemCopySchemaV1.models, ItemCopyLevelSelectionSchemaV1.models, AbilityProgressSchemaV1.models, StoryPlanningSchemaV7.models]
        return try zip(locations.stores, schemas).map { store, models in
            let tables = try TransferSQLite.rows(store.url, sql: "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name").map { String($0[0].dropFirst(2)) }
            let known = Set(models.map { "Z" + String(describing: $0).uppercased() })
            let metadata: Set<String> = ["Z_PRIMARYKEY", "Z_METADATA", "Z_MODELCACHE", "ACHANGE", "ATRANSACTION", "ATRANSACTIONSTRING", "sqlite_sequence"]
            guard Set(tables).subtracting(metadata) == known else { throw WorkspaceTransferError.invalid("資料庫結構無法辨識，未變更資料。") }
            return tables.filter { known.contains($0) }
        }
    }

    private func modelFingerprints(_ locations: SailuneDataLocations) throws -> [String: String] {
        var result: [String: String] = [:]
        for (index, tables) in try modelTables(locations).enumerated() {
            for table in tables {
                // Z_OPT 是 Core Data 儲存修訂號，啟動 repair 可增加，並非使用者資料。
                let columns = try TransferSQLite.rows(locations.stores[index].url, sql: "PRAGMA table_info(\"\(table)\")")
                    .map { String($0[1].dropFirst(2)) }.filter { $0 != "Z_OPT" }
                let selection = columns.map { "\"\($0)\"" }.joined(separator: ",")
                let rows = try TransferSQLite.rows(locations.stores[index].url, sql: "SELECT \(selection) FROM \"\(table)\" ORDER BY Z_PK")
                let data = try JSONEncoder().encode(rows)
                result["\(index)/\(table)"] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            }
        }
        return result
    }

    private func assetFingerprints(_ locations: SailuneDataLocations) throws -> [String: String] {
        var result: [String: String] = [:]
        // FileManager 列目錄會將 /var 改為 /private/var；以資產內相對名稱建立 key，
        // 不用絕對路徑字元數截取，避免同一份檔案在兩個位置得到不同的摘要名稱。
        func record(_ url: URL, relativePath: String) throws {
            if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                for child in try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    try record(child, relativePath: relativePath + "/" + child.lastPathComponent)
                }
            } else {
                let data = try Data(contentsOf: url)
                result[relativePath] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            }
        }
        for (index, url) in managedAssets(locations).enumerated() where fileManager.fileExists(atPath: url.path) {
            try record(url, relativePath: "\(index)/\(url.lastPathComponent)")
        }
        return result
    }

    private func hasUserData(_ locations: SailuneDataLocations) throws -> Bool {
        for (index, tables) in try modelTables(locations).enumerated() {
            for table in tables {
                if table == "ZAUTHORPROFILE" {
                    let authors = try TransferSQLite.rows(locations.stores[index].url, sql: "SELECT ZPENNAME,ZBIO,ZAVATARDATA FROM ZAUTHORPROFILE")
                    if authors.count > 1 || authors.contains(where: { row in
                        !["n:", "t:", "t:我的筆名"].contains(row[0]) || !["n:", "t:"].contains(row[1]) || !["n:", "b:"].contains(row[2])
                    }) { return true }
                } else if try TransferSQLite.rows(locations.stores[index].url, sql: "SELECT COUNT(*) FROM \"\(table)\"") != [["i:0"]] { return true }
            }
        }
        for url in [locations.coversDirectory, locations.mapsDirectory, locations.aiConversationsDirectory, locations.bookTemplatesDirectory] where fileManager.fileExists(atPath: url.path) {
            if try containsFile(url) { return true }
        }
        let publication = try BookPublicationStore(url: locations.publicationStatusURL, tagsURL: locations.publicationTagsURL)
        if !publication.statuses.isEmpty || !publication.tagsByBookID.isEmpty { return true }
        if fileManager.fileExists(atPath: locations.writingStatsURL.path) {
            let doc = try JSONDecoder().decode(BookWritingStatsDocument.self, from: Data(contentsOf: locations.writingStatsURL))
            guard doc.version == 1 else { throw WorkspaceTransferError.invalid("統計版本無法辨識。") }
            if !doc.records.isEmpty { return true }
        }
        if fileManager.fileExists(atPath: locations.forumPostsURL.path) {
            let doc = try JSONDecoder().decode(ForumPostDocument.self, from: Data(contentsOf: locations.forumPostsURL))
            guard doc.version == 1 else { throw WorkspaceTransferError.invalid("論壇版本無法辨識。") }
            if !doc.posts.isEmpty { return true }
        }
        if fileManager.fileExists(atPath: locations.preferencesURL.path) {
            guard let values = try PropertyListSerialization.propertyList(from: Data(contentsOf: locations.preferencesURL), format: nil) as? [String: Any] else {
                throw WorkspaceTransferError.invalid("偏好資料無法辨識。")
            }
            let defaults: [String: Any] = [SectionUnitPreference.storageKey: BookTextSectionMarker.section.rawValue,
                "sailune.hasShownInlineAutosaveHint": false, "sailune.showCharacterSelectionInfo": true,
                "SailuneAIProvider": SailuneAIProvider.appleOnDevice.rawValue, "SailuneAIEndpoint": SailuneAISettings.defaultEndpoint, "SailuneAIModel": SailuneAISettings.defaultModel]
            for (key, value) in values {
                guard let initial = defaults[key], (value as? NSObject)?.isEqual(initial) == true else { return true }
            }
        }
        return false
    }

    private func containsFile(_ url: URL) throws -> Bool {
        if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory != true { return true }
        for child in try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            if try containsFile(child) { return true }
        }
        return false
    }
}

/// 僅唯讀 SQLite 快照／內容；帶型別編碼避免 NULL、文字與 blob 被誤判為相同。
private enum TransferSQLite {
    static func rows(_ url: URL, sql: String) throws -> [[String]] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            throw WorkspaceTransferError.invalid("無法讀取資料庫。")
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw WorkspaceTransferError.invalid("資料庫查詢失敗（\(url.lastPathComponent)）：\(String(cString: sqlite3_errmsg(database)))")
        }
        defer { sqlite3_finalize(statement) }
        var result: [[String]] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            var row: [String] = []
            for index in 0..<sqlite3_column_count(statement) {
                switch sqlite3_column_type(statement, index) {
                case SQLITE_INTEGER: row.append("i:\(sqlite3_column_int64(statement, index))")
                case SQLITE_FLOAT: row.append("f:\(sqlite3_column_double(statement, index))")
                case SQLITE_TEXT: row.append("t:" + String(cString: sqlite3_column_text(statement, index)))
                case SQLITE_BLOB:
                    let data = Data(bytes: sqlite3_column_blob(statement, index), count: Int(sqlite3_column_bytes(statement, index)))
                    row.append("b:" + data.base64EncodedString())
                default: row.append("n:")
                }
            }
            result.append(row)
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw WorkspaceTransferError.invalid("資料庫讀取未完成。") }
        return result
    }
}

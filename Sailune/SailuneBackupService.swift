import AppKit
import CryptoKit
import Foundation
import SQLite3
import UniformTypeIdentifiers

struct SailuneDataLocations {
    let mainStore: URL

    static var current: Self {
        #if DEBUG
        if let overridePath = ProcessInfo.processInfo.environment["SAILUNE_TEST_STORE_URL"], !overridePath.isEmpty {
            return Self(mainStore: URL(fileURLWithPath: overridePath))
        }
        #endif
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return Self(mainStore: base.appendingPathComponent("Sailune-v5.store"))
    }

    private var stem: String { mainStore.deletingPathExtension().lastPathComponent }
    private var directory: URL { mainStore.deletingLastPathComponent() }
    var settingsStore: URL { directory.appendingPathComponent("\(stem)-settings.store") }
    var itemCopyStore: URL { directory.appendingPathComponent("\(stem)-item-copies.store") }
    var itemCopyLevelStore: URL { directory.appendingPathComponent("\(stem)-item-copy-level-selections.store") }
    var abilityProgressStore: URL { directory.appendingPathComponent("\(stem)-ability-progress.store") }
    var storyPlanningStore: URL { directory.appendingPathComponent("\(stem)-story-planning.store") }
    var stores: [(name: String, url: URL, schema: String)] {
        [
            ("main.store", mainStore, "NovelWriterSchemaV5"),
            ("settings.store", settingsStore, "V5SettingsSchemaV10"),
            ("item-copies.store", itemCopyStore, "ItemCopySchemaV1"),
            ("item-copy-level-selections.store", itemCopyLevelStore, "ItemCopyLevelSelectionSchemaV1"),
            ("ability-progress.store", abilityProgressStore, "AbilityProgressSchemaV1"),
            ("story-planning.store", storyPlanningStore, "StoryPlanningSchemaV7")
        ]
    }
    var pendingRestoreURL: URL { directory.appendingPathComponent("Sailune.pending-restore.sailunebackup") }
    var recoveryDirectory: URL { directory.appendingPathComponent("Sailune/Recovery Backups", isDirectory: true) }
    var coversDirectory: URL { directory.appendingPathComponent("Sailune/Covers", isDirectory: true) }
}

enum SailuneBackupService {
    private static let archiveVersion = 1

    struct Manifest: Codable {
        struct FileEntry: Codable {
            let path: String
            let byteCount: Int
            let sha256: String
        }
        let archiveVersion: Int
        let appVersion: String
        let buildVersion: String
        let createdAt: Date
        let schemas: [String: String]
        let files: [FileEntry]
    }

    private struct ArchiveFile: Codable { let path: String; let data: Data }
    private struct Archive: Codable { let manifest: Manifest; let files: [ArchiveFile] }

    enum BackupError: LocalizedError {
        case invalidArchive(String)
        case sqlite(String)
        case pendingRestoreExists

        var errorDescription: String? {
            switch self {
            case .invalidArchive(let detail): "備份檔無效：\(detail)"
            case .sqlite(let detail): "資料庫快照失敗：\(detail)"
            case .pendingRestoreExists: "已有一份等待重新啟動還原的備份。"
            }
        }
    }

    @MainActor
    static func chooseBackupDestination(defaultName: String = "Sailune-") -> URL? {
        let panel = NSSavePanel()
        panel.title = "備份 Sailune 資料"
        panel.nameFieldStringValue = defaultName + timestamp() + ".sailunebackup"
        panel.allowedContentTypes = [UTType(exportedAs: "com.moonest.sailune.backup", conformingTo: .data)]
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    static func chooseRestoreSource() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "選擇 Sailune 備份"
        panel.allowedContentTypes = [UTType(exportedAs: "com.moonest.sailune.backup", conformingTo: .data)]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func createBackup(at destination: URL, locations: SailuneDataLocations = .current) throws {
        let archive = try makeArchive(locations: locations)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(archive).write(to: destination, options: .atomic)
    }

    static func scheduleRestore(from source: URL, locations: SailuneDataLocations = .current) throws {
        let data = try Data(contentsOf: source)
        _ = try decodeAndValidate(data)
        if FileManager.default.fileExists(atPath: locations.pendingRestoreURL.path) {
            throw BackupError.pendingRestoreExists
        }
        try data.write(to: locations.pendingRestoreURL, options: .atomic)
    }

    /// Runs before any ModelContainer opens. A failed replacement restores the
    /// exact previous files and leaves a diagnostic startup error.
    static func applyPendingRestoreIfNeeded(locations: SailuneDataLocations = .current) throws {
        let pending = locations.pendingRestoreURL
        guard FileManager.default.fileExists(atPath: pending.path) else { return }
        let data = try Data(contentsOf: pending)
        let archive = try decodeAndValidate(data)
        let fm = FileManager.default
        try fm.createDirectory(at: locations.recoveryDirectory, withIntermediateDirectories: true)
        let safetyURL = locations.recoveryDirectory.appendingPathComponent("Before-Restore-\(timestamp()).sailunebackup")
        try createBackup(at: safetyURL, locations: locations)

        let rollback = locations.mainStore.deletingLastPathComponent()
            .appendingPathComponent(".sailune-restore-rollback-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: rollback, withIntermediateDirectories: true)
        let coversURL = locations.coversDirectory
        var moved: [(original: URL, backup: URL)] = []
        do {
            for (_, storeURL, _) in locations.stores {
                for url in sqliteFamily(for: storeURL) where fm.fileExists(atPath: url.path) {
                    let backup = rollback.appendingPathComponent(url.lastPathComponent)
                    try fm.moveItem(at: url, to: backup)
                    moved.append((url, backup))
                }
            }
            if fm.fileExists(atPath: coversURL.path) {
                let backup = rollback.appendingPathComponent("Covers", isDirectory: true)
                try fm.moveItem(at: coversURL, to: backup)
                moved.append((coversURL, backup))
            }

            let files = Dictionary(uniqueKeysWithValues: archive.files.map { ($0.path, $0.data) })
            for (name, storeURL, _) in locations.stores {
                guard let storeData = files["stores/\(name)"] else {
                    throw BackupError.invalidArchive("缺少 stores/\(name)")
                }
                try storeData.write(to: storeURL, options: .atomic)
            }
            let coverFiles = archive.files.filter { $0.path.hasPrefix("covers/") }
            if !coverFiles.isEmpty {
                try fm.createDirectory(at: coversURL, withIntermediateDirectories: true)
                for file in coverFiles {
                    try file.data.write(to: coversURL.appendingPathComponent(URL(fileURLWithPath: file.path).lastPathComponent), options: .atomic)
                }
            }
            try fm.removeItem(at: pending)
            try fm.removeItem(at: rollback)
        } catch {
            for (_, storeURL, _) in locations.stores {
                for url in sqliteFamily(for: storeURL) where fm.fileExists(atPath: url.path) { try? fm.removeItem(at: url) }
            }
            if fm.fileExists(atPath: coversURL.path) { try? fm.removeItem(at: coversURL) }
            for pair in moved.reversed() where fm.fileExists(atPath: pair.backup.path) {
                try? fm.moveItem(at: pair.backup, to: pair.original)
            }
            try? fm.removeItem(at: rollback)
            try? fm.removeItem(at: pending)
            throw error
        }
    }

    private static func makeArchive(locations: SailuneDataLocations) throws -> Archive {
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent("SailuneBackup-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: temporary) }
        var files: [ArchiveFile] = []
        var schemas: [String: String] = [:]
        for (name, source, schema) in locations.stores {
            guard fm.fileExists(atPath: source.path) else { throw BackupError.invalidArchive("找不到目前資料庫 \(name)") }
            let snapshot = temporary.appendingPathComponent(name)
            try sqliteSnapshot(from: source, to: snapshot)
            files.append(ArchiveFile(path: "stores/\(name)", data: try Data(contentsOf: snapshot)))
            schemas[name] = schema
        }
        let covers = locations.coversDirectory
        if let urls = try? fm.contentsOfDirectory(at: covers, includingPropertiesForKeys: nil) {
            for url in urls where url.pathExtension.lowercased() == "png" {
                files.append(ArchiveFile(path: "covers/\(url.lastPathComponent)", data: try Data(contentsOf: url)))
            }
        }
        let entries = files.map { Manifest.FileEntry(path: $0.path, byteCount: $0.data.count, sha256: checksum($0.data)) }
        let info = Bundle.main.infoDictionary
        let manifest = Manifest(
            archiveVersion: archiveVersion,
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildVersion: info?["CFBundleVersion"] as? String ?? "unknown",
            createdAt: Date(), schemas: schemas, files: entries
        )
        return Archive(manifest: manifest, files: files)
    }

    private static func decodeAndValidate(_ data: Data) throws -> Archive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive: Archive
        do { archive = try decoder.decode(Archive.self, from: data) }
        catch { throw BackupError.invalidArchive(error.localizedDescription) }
        guard archive.manifest.archiveVersion == archiveVersion else {
            throw BackupError.invalidArchive("不支援的格式版本 \(archive.manifest.archiveVersion)")
        }
        let expectedSchemas = Dictionary(uniqueKeysWithValues: SailuneDataLocations.current.stores.map { ($0.name, $0.schema) })
        guard archive.manifest.schemas == expectedSchemas else { throw BackupError.invalidArchive("schema 版本不相容") }
        let files = Dictionary(uniqueKeysWithValues: archive.files.map { ($0.path, $0.data) })
        guard files.count == archive.files.count else { throw BackupError.invalidArchive("檔案路徑重複") }
        for entry in archive.manifest.files {
            guard let file = files[entry.path], file.count == entry.byteCount, checksum(file) == entry.sha256 else {
                throw BackupError.invalidArchive("\(entry.path) checksum 不符")
            }
        }
        let listed = Set(archive.manifest.files.map(\.path))
        guard listed == Set(files.keys) else { throw BackupError.invalidArchive("manifest 檔案清單不一致") }
        return archive
    }

    private static func sqliteSnapshot(from source: URL, to destination: URL) throws {
        var sourceDB: OpaquePointer?
        var destinationDB: OpaquePointer?
        guard sqlite3_open_v2(source.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { if sourceDB != nil { sqlite3_close(sourceDB) } }
            throw BackupError.sqlite(String(cString: sqlite3_errmsg(sourceDB)))
        }
        defer { sqlite3_close(sourceDB) }
        guard sqlite3_open_v2(destination.path, &destinationDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            defer { if destinationDB != nil { sqlite3_close(destinationDB) } }
            throw BackupError.sqlite(String(cString: sqlite3_errmsg(destinationDB)))
        }
        defer { sqlite3_close(destinationDB) }
        guard let backup = sqlite3_backup_init(destinationDB, "main", sourceDB, "main") else {
            throw BackupError.sqlite(String(cString: sqlite3_errmsg(destinationDB)))
        }
        let step = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard step == SQLITE_DONE, finish == SQLITE_OK else {
            throw BackupError.sqlite(String(cString: sqlite3_errmsg(destinationDB)))
        }
    }

    private static func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func sqliteFamily(for store: URL) -> [URL] {
        [store, URL(fileURLWithPath: store.path + "-wal"), URL(fileURLWithPath: store.path + "-shm")]
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

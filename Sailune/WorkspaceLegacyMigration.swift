import Foundation

/// 舊共用資料只複製至 Guest；原始檔保留，暫存目錄完成後才置換。
enum WorkspaceLegacyMigration {
    static func copyIfNeeded(from source: SailuneDataLocations, to destination: SailuneDataLocations) throws {
        let fm = FileManager.default
        let target = destination.mainStore.deletingLastPathComponent()
        try WorkspaceRegistry.rejectSymbolicLinks(at: target)
        guard !fm.fileExists(atPath: target.path) else { return }
        let staging = target.deletingLastPathComponent().appendingPathComponent("legacy-staging", isDirectory: true)
        try WorkspaceRegistry.rejectSymbolicLinks(at: staging)
        if fm.fileExists(atPath: staging.path) { try fm.removeItem(at: staging) }
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        let staged = SailuneDataLocations(mainStore: staging.appendingPathComponent("Sailune-v5.store"), workspaceID: "guest")
        for (index, store) in source.stores.enumerated() where fm.fileExists(atPath: store.url.path) {
            try WorkspaceRegistry.rejectSymbolicLinks(at: store.url)
            try SailuneBackupService.sqliteSnapshot(from: store.url, to: staged.stores[index].url)
        }
        for name in ["Sailune-v3.store", "Sailune.store"] {
            let old = source.mainStore.deletingLastPathComponent().appendingPathComponent(name)
            if fm.fileExists(atPath: old.path) {
                try WorkspaceRegistry.rejectSymbolicLinks(at: old)
                try SailuneBackupService.sqliteSnapshot(from: old, to: staging.appendingPathComponent(name))
            }
        }
        let pairs = [(source.coversDirectory, staged.coversDirectory), (source.mapsDirectory, staged.mapsDirectory),
                     (source.aiConversationsDirectory, staged.aiConversationsDirectory),
                     (source.publicationStatusURL, staged.publicationStatusURL), (source.publicationTagsURL, staged.publicationTagsURL),
                     (source.bookTemplatesDirectory, staged.bookTemplatesDirectory), (source.writingStatsURL, staged.writingStatsURL),
                     (source.forumPostsURL, staged.forumPostsURL), (source.pendingRestoreURL, staged.pendingRestoreURL),
                     (source.recoveryDirectory, staged.recoveryDirectory)]
        for (old, new) in pairs where fm.fileExists(atPath: old.path) {
            try WorkspaceRegistry.rejectSymbolicLinks(at: old)
            try fm.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: old, to: new)
        }
        let preferences = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("sailune.") || $0.key.hasPrefix("SailuneAI") }
        try fm.createDirectory(at: staged.preferencesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: preferences, format: .binary, options: 0).write(to: staged.preferencesURL, options: .atomic)
        try fm.moveItem(at: staging, to: target)
    }
}

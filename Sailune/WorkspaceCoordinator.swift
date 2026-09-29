import AppKit
import Foundation
import Observation
import SwiftData

/// 全域相容呼叫點由此取得目前位置；非同步服務建立時必須捕捉位置，不能在回呼重新查詢。
final class WorkspaceLocationAccess: @unchecked Sendable {
    static let shared = WorkspaceLocationAccess()
    private let lock = NSLock()
    private var locations: SailuneDataLocations?
    private var defaults: UserDefaults?
    func current() -> SailuneDataLocations? { lock.lock(); defer { lock.unlock() }; return locations }
    func preferences() -> UserDefaults { lock.lock(); defer { lock.unlock() }; return defaults ?? .standard }
    func activate(_ locations: SailuneDataLocations, preferences: UserDefaults) {
        lock.lock(); defer { lock.unlock() }; self.locations = locations; defaults = preferences
    }
}

@MainActor
final class WorkspaceBundle {
    let locations: SailuneDataLocations
    let container: ModelContainer
    let settingsStore: V5SettingsStore
    let copyStore: ItemCopyStore
    let abilityStore: AbilityProgressStore
    let planningStore: StoryPlanningStore
    let publicationStore: BookPublicationStore
    let writingStatsStore: BookWritingStatsStore
    let forumPostsStore: LocalForumPostsStore

    init(locations: SailuneDataLocations) throws {
        self.locations = locations
        (container, settingsStore, copyStore, abilityStore, planningStore) = try WorkspaceFactory.makeModelContainer(locations: locations)
        publicationStore = try BookPublicationStore(url: locations.publicationStatusURL, tagsURL: locations.publicationTagsURL)
        writingStatsStore = BookWritingStatsStore(url: locations.writingStatsURL)
        forumPostsStore = LocalForumPostsStore(url: locations.forumPostsURL)
        guard !writingStatsStore.isUnavailable, !forumPostsStore.isUnavailable else { throw WorkspaceError.saveFailed }
    }

    func save() throws {
        guard settingsStore.persistenceErrorMessage == nil, copyStore.persistenceErrorMessage == nil,
              abilityStore.persistenceErrorMessage == nil, planningStore.persistenceErrorMessage == nil,
              writingStatsStore.persistenceErrorMessage == nil, forumPostsStore.persistenceErrorMessage == nil else {
            throw WorkspaceError.saveFailed
        }
        try copyStore.saveForWorkspaceSwitch()
        for context in [container.mainContext, settingsStore.container.mainContext, copyStore.container.mainContext,
                        abilityStore.container.mainContext, planningStore.container.mainContext] {
            if context.hasChanges { try context.save() }
        }
    }
}

/// App 共用工作區生命週期；View 只送出切換／刪除意圖。
@MainActor @Observable
final class WorkspaceCoordinator {
    private(set) var bundle: WorkspaceBundle?
    private(set) var generation = UUID()
    private(set) var accounts: [WorkspaceAccount] = []
    private(set) var selectedID = "guest"
    private(set) var isWorking = false
    var errorMessage: String?
    private var registry: WorkspaceRegistry?
    @ObservationIgnored private var saveParticipants: [UUID: () throws -> Void] = [:]
    @ObservationIgnored private var operations: [UUID: () -> Bool] = [:]
    var preferences: UserDefaults { WorkspaceLocationAccess.shared.preferences() }
    var currentAccount: WorkspaceAccount? { accounts.first { $0.id == selectedID } }

    init(legacyLocations: SailuneDataLocations? = nil) {
        do {
            let original = legacyLocations ?? Self.legacyLocations()
            let root = original.mainStore.deletingLastPathComponent().appendingPathComponent("Sailune Workspaces", isDirectory: true)
            let registry = try WorkspaceRegistry(root: root)
            self.registry = registry
            try migrateLegacyIfNeeded(original: original, registry: registry)
            let selected = registry.document.accounts.first { $0.id == registry.document.selectedID }
            let id = selected?.isDeleting == true ? "guest" : registry.document.selectedID
            let locations = try locations(for: id)
            let loaded = try WorkspaceBundle(locations: locations)
            try activate(loaded, id: id)
        } catch { errorMessage = error.localizedDescription }
    }

    static func legacyLocations() -> SailuneDataLocations {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let path = environment["SAILUNE_TEST_STORE_URL"], !path.isEmpty {
            return SailuneDataLocations(mainStore: URL(fileURLWithPath: path))
        }
        if environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil {
            return SailuneDataLocations(mainStore: FileManager.default.temporaryDirectory.appendingPathComponent("Sailune-test-host-\(UUID().uuidString)/Sailune-v5.store"))
        }
        #endif
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return SailuneDataLocations(mainStore: base.appendingPathComponent("Sailune-v5.store"))
    }

    func locations(for id: String) throws -> SailuneDataLocations {
        guard let registry else { throw WorkspaceError.invalidRegistry }
        return SailuneDataLocations(mainStore: try registry.directory(for: id).appendingPathComponent("Sailune-v5.store"), workspaceID: id)
    }

    func registerParticipant(id: UUID, save: @escaping () throws -> Void) { saveParticipants[id] = save }
    func unregisterParticipant(id: UUID) { saveParticipants.removeValue(forKey: id) }
    func registerOperation(id: UUID, isBusy: @escaping () -> Bool) { operations[id] = isBusy }
    func unregisterOperation(id: UUID) { operations.removeValue(forKey: id) }

    private func prepareToLeave() throws {
        guard !operations.values.contains(where: { $0() }) else { throw WorkspaceError.busy }
        for window in NSApplication.shared.windows { window.endEditing(for: nil) }
        for save in saveParticipants.values { try save() }
        try bundle?.save()
        if let bundle { try WorkspacePreferences.save(preferences, at: bundle.locations.preferencesURL) }
    }

    func switchTo(_ id: String) {
        guard !isWorking, id != selectedID else { return }
        isWorking = true; defer { isWorking = false }
        do {
            if accounts.contains(where: { $0.id == id && $0.isDeleting }) { throw WorkspaceError.deletionPending }
            try prepareToLeave()
            let loaded = try WorkspaceBundle(locations: locations(for: id))
            try activate(loaded, id: id)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func openAuthenticatedAccount(auth: SailuneAccountAuthService) {
        guard let userID = auth.signedInUserID, let environment = auth.environmentID,
              let email = auth.signedInEmail else {
            errorMessage = WorkspaceError.identityMismatch.localizedDescription
            return
        }
        openAccount(userID: userID, environment: environment, email: email)
    }

    /// 接收 Auth 已驗證的身分；測試可注入固定身分驗證本機生命週期，不宣稱 OTP 成功。
    func openAccount(userID: UUID, environment: String, email: String) {
        guard !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        do {
            try prepareToLeave()
            guard let registry else { throw WorkspaceError.invalidRegistry }
            let account = try registry.register(userID: userID, environment: environment, email: email)
            accounts = registry.document.accounts
            let loaded = try WorkspaceBundle(locations: locations(for: account.id))
            try activate(loaded, id: account.id)
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func updateCurrentPenName(_ name: String) {
        guard let registry, selectedID != "guest" else { return }
        do {
            try registry.update { doc in
                if let index = doc.accounts.firstIndex(where: { $0.id == selectedID }) { doc.accounts[index].penName = name }
            }
            accounts = registry.document.accounts
        } catch { errorMessage = "無法保存帳號名稱：\(error.localizedDescription)" }
    }

    func canPublish(auth: SailuneAccountAuthService) -> Bool {
        guard let account = currentAccount else { return false }
        return Self.identityMatches(account: account, userID: auth.signedInUserID, environment: auth.environmentID)
    }

    static func identityMatches(account: WorkspaceAccount, userID: UUID?, environment: String?) -> Bool {
        !account.isDeleting && account.userID == userID && account.environment == environment
    }

    func signOut(auth: SailuneAccountAuthService) async {
        guard !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        do {
            try prepareToLeave()
            let guest = try WorkspaceBundle(locations: locations(for: "guest"))
            await auth.signOut(localOnly: true)
            guard auth.signedInEmail == nil, auth.errorMessage == nil else { throw WorkspaceError.saveFailed }
            try activate(guest, id: "guest")
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteAccount(_ id: String, auth: SailuneAccountAuthService) async {
        guard !isWorking else { return }
        isWorking = true; defer { isWorking = false }
        do {
            guard let registry, let account = accounts.first(where: { $0.id == id }) else { throw WorkspaceError.unknownAccount }
            try prepareToLeave()
            weak var departingBundle: WorkspaceBundle?
            if selectedID == id {
                departingBundle = bundle
                let guest = try WorkspaceBundle(locations: locations(for: "guest"))
                try activate(guest, id: "guest")
                // 讓所有視窗釋放舊工作區；清理紀錄在資料刪除前持久化。
                await Task.yield()
            }
            guard !auth.needsKeychainRetry else { throw WorkspaceError.saveFailed }
            try registry.markDeleting(id)
            accounts = registry.document.accounts
            if auth.signedInUserID == account.userID && auth.environmentID == account.environment {
                await auth.signOut(localOnly: true)
                guard auth.signedInEmail == nil, auth.errorMessage == nil else { throw WorkspaceError.saveFailed }
            }
            for _ in 0..<100 where departingBundle != nil {
                try await Task.sleep(for: .milliseconds(20))
            }
            guard departingBundle == nil else { throw WorkspaceError.busy }
            UserDefaults(suiteName: try locations(for: id).preferencesURL.path)?.removePersistentDomain(forName: try locations(for: id).preferencesURL.path)
            try registry.finishDeletion(id)
            accounts = registry.document.accounts
            errorMessage = nil
        } catch { errorMessage = "帳號資料清理未完成：\(error.localizedDescription)" }
    }

    func backupAccount(_ id: String) throws {
        try prepareToLeave()
        if let destination = SailuneBackupService.chooseBackupDestination() {
            try SailuneBackupService.createBackup(at: destination, locations: locations(for: id))
        }
    }

    private func activate(_ loaded: WorkspaceBundle, id: String) throws {
        guard let registry else { throw WorkspaceError.invalidRegistry }
        let defaults = try WorkspacePreferences.open(at: loaded.locations.preferencesURL)
        try registry.update { doc in
            doc.selectedID = id
            if let index = doc.accounts.firstIndex(where: { $0.id == id }) {
                doc.accounts[index].penName = try loaded.container.mainContext.fetch(FetchDescriptor<AuthorProfile>()).first?.penName ?? ""
            }
        }
        WorkspaceLocationAccess.shared.activate(loaded.locations, preferences: defaults)
        BookCoverStore.resetWorkspaceCache()
        bundle = loaded; selectedID = id; accounts = registry.document.accounts
        saveParticipants.removeAll(); operations.removeAll()
        generation = UUID()
    }

    private func migrateLegacyIfNeeded(original: SailuneDataLocations, registry: WorkspaceRegistry) throws {
        guard !registry.document.didMigrateLegacy else { return }
        let guest = SailuneDataLocations(mainStore: try registry.directory(for: "guest").appendingPathComponent("Sailune-v5.store"), workspaceID: "guest")
        try WorkspaceLegacyMigration.copyIfNeeded(from: original, to: guest)
        let loaded = try WorkspaceBundle(locations: guest)
        try loaded.save()
        try FileManager.default.createDirectory(at: guest.recoveryDirectory, withIntermediateDirectories: true)
        try SailuneBackupService.createBackup(at: guest.recoveryDirectory.appendingPathComponent("Before-Workspace-Migration.sailunebackup"), locations: guest)
        try registry.update { $0.didMigrateLegacy = true }
    }
}

/// 偏好存在工作區目錄，刪帳號時一併移除；AppStorage 不再共用 standard。
enum WorkspacePreferences {
    static func open(at url: URL) throws -> UserDefaults {
        try WorkspaceRegistry.rejectSymbolicLinks(at: url)
        guard let defaults = UserDefaults(suiteName: url.path) else { throw WorkspaceError.invalidRegistry }
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard let dictionary = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw WorkspaceError.invalidRegistry }
            defaults.setPersistentDomain(dictionary, forName: url.path)
        }
        return defaults
    }
    static func save(_ defaults: UserDefaults, at url: URL) throws {
        let values = defaults.persistentDomain(forName: url.path) ?? [:]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0).write(to: url, options: .atomic)
    }
}

import XCTest
import SwiftData
@testable import Sailune

@MainActor
final class WorkspaceTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("WorkspaceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    func testTwoAccountLimitDuplicateIdentityAndReopen() throws {
        let root = try temporaryRoot()
        let registry = try WorkspaceRegistry(root: root)
        let id = UUID()
        let first = try registry.register(userID: id, environment: "https://one.example", email: "a@example.com")
        XCTAssertEqual(try registry.register(userID: id, environment: "https://one.example", email: "changed@example.com").id, first.id)
        let second = try registry.register(userID: UUID(), environment: "https://one.example", email: "b@example.com")
        XCTAssertThrowsError(try registry.register(userID: UUID(), environment: "https://one.example", email: "c@example.com"))
        try registry.update { $0.selectedID = second.id }
        let reopened = try WorkspaceRegistry(root: root)
        XCTAssertEqual(reopened.document.accounts.count, 2)
        XCTAssertEqual(reopened.document.selectedID, second.id)
        XCTAssertEqual(reopened.document.accounts.first?.email, "changed@example.com")
        XCTAssertNotEqual(WorkspaceRegistry.accountID(userID: id, environment: "https://two.example"), first.id)
    }

    func testRegistryWriteFailureDoesNotClaimRegistration() throws {
        let registry = try WorkspaceRegistry(root: temporaryRoot(), write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        XCTAssertThrowsError(try registry.register(userID: UUID(), environment: "test", email: "a@example.com"))
        XCTAssertTrue(registry.document.accounts.isEmpty)
    }

    func testPartialDeletionStaysRegisteredAndRetryPreservesOtherSpaces() throws {
        let registry = try WorkspaceRegistry(root: temporaryRoot())
        let a = try registry.register(userID: UUID(), environment: "test", email: "a@example.com")
        let b = try registry.register(userID: UUID(), environment: "test", email: "b@example.com")
        for id in ["guest", a.id, b.id] {
            let directory = try registry.directory(for: id)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(id.utf8).write(to: directory.appendingPathComponent("asset"))
        }
        try registry.markDeleting(a.id)
        XCTAssertThrowsError(try registry.finishDeletion(a.id, remove: { _ in throw CocoaError(.fileWriteNoPermission) }))
        XCTAssertTrue(registry.document.accounts.first(where: { $0.id == a.id })?.isDeleting == true)
        let reopened = try WorkspaceRegistry(root: registry.root)
        try reopened.finishDeletion(a.id)
        XCTAssertEqual(reopened.document.accounts.map(\.id), [b.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: try reopened.directory(for: b.id).appendingPathComponent("asset").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try reopened.directory(for: "guest").appendingPathComponent("asset").path))
        XCTAssertNoThrow(try reopened.register(userID: UUID(), environment: "test", email: "c@example.com"))
    }

    func testDeletionRejectsSymlinkOutsideManagedSpace() throws {
        let root = try temporaryRoot()
        let registry = try WorkspaceRegistry(root: root.appendingPathComponent("registry"))
        let account = try registry.register(userID: UUID(), environment: "test", email: "a@example.com")
        let target = root.appendingPathComponent("protected")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let link = try registry.directory(for: account.id)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        try registry.markDeleting(account.id)
        XCTAssertThrowsError(try registry.finishDeletion(account.id))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
    }

    func testFactoryIsolatesSixStoresAuthorsAndSidecarsAndReopens() throws {
        let root = try temporaryRoot()
        let sharedBookID = UUID()
        for id in ["guest", "account-a", "account-b"] {
            let locations = SailuneDataLocations(mainStore: root.appendingPathComponent(id).appendingPathComponent("Sailune-v5.store"), workspaceID: id)
            let bundle = try WorkspaceBundle(locations: locations)
            let book = Book(title: id, author: id)
            book.id = sharedBookID
            bundle.container.mainContext.insert(book)
            bundle.container.mainContext.insert(AuthorProfile(penName: id))
            try bundle.container.mainContext.save()
            _ = try bundle.forumPostsStore.create(board: .writing, title: id, body: id)
            try bundle.writingStatsStore.recordSuccessfulEdits([(bookID: sharedBookID, netWordDelta: id.count)])
            try bundle.publicationStore.publish(sharedBookID, tags: [id])
            XCTAssertEqual(locations.stores.count, 6)
        }
        for id in ["guest", "account-a", "account-b"] {
            let locations = SailuneDataLocations(mainStore: root.appendingPathComponent(id).appendingPathComponent("Sailune-v5.store"), workspaceID: id)
            let reopened = try WorkspaceBundle(locations: locations)
            XCTAssertEqual(try reopened.container.mainContext.fetch(FetchDescriptor<Book>()).map(\.title), [id])
            XCTAssertEqual(try reopened.container.mainContext.fetch(FetchDescriptor<AuthorProfile>()).map(\.penName), [id])
            XCTAssertEqual(reopened.forumPostsStore.posts(in: .writing).map(\.title), [id])
            XCTAssertEqual(reopened.publicationStore.tags(for: sharedBookID), [id])
        }
    }

    func testLegacyCopyKeepsSourceUUIDsAssetsAndIsIdempotent() throws {
        let root = try temporaryRoot()
        let source = SailuneDataLocations(mainStore: root.appendingPathComponent("old/Sailune-v5.store"))
        let sourceBundle = try WorkspaceBundle(locations: source)
        let book = Book(title: "原有作品", author: "作者")
        sourceBundle.container.mainContext.insert(book)
        try sourceBundle.container.mainContext.save()
        try FileManager.default.createDirectory(at: source.mapsDirectory, withIntermediateDirectories: true)
        try Data("map".utf8).write(to: source.mapsDirectory.appendingPathComponent("test.pdf"))
        let destination = SailuneDataLocations(mainStore: root.appendingPathComponent("workspaces/guest/Sailune-v5.store"), workspaceID: "guest")
        try WorkspaceLegacyMigration.copyIfNeeded(from: source, to: destination)
        try WorkspaceLegacyMigration.copyIfNeeded(from: source, to: destination)
        let copied = try WorkspaceBundle(locations: destination)
        XCTAssertEqual(try copied.container.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [book.id])
        XCTAssertEqual(try sourceBundle.container.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [book.id])
        XCTAssertEqual(try Data(contentsOf: destination.mapsDirectory.appendingPathComponent("test.pdf")), Data("map".utf8))
    }

    func testBackupRejectsAnotherWorkspaceAndOldBackupOnlyAllowsGuest() throws {
        let root = try temporaryRoot()
        let a = SailuneDataLocations(mainStore: root.appendingPathComponent("a/Sailune-v5.store"), workspaceID: "a")
        let b = SailuneDataLocations(mainStore: root.appendingPathComponent("b/Sailune-v5.store"), workspaceID: "b")
        let bundle = try WorkspaceBundle(locations: a)
        try bundle.save()
        let archive = root.appendingPathComponent("a.sailunebackup")
        try SailuneBackupService.createBackup(at: archive, locations: a)
        XCTAssertThrowsError(try SailuneBackupService.scheduleRestore(from: archive, locations: b))
        XCTAssertNoThrow(try SailuneBackupService.scheduleRestore(from: archive, locations: a))
        let old = SailuneDataLocations(mainStore: a.mainStore)
        let oldArchive = root.appendingPathComponent("old.sailunebackup")
        try SailuneBackupService.createBackup(at: oldArchive, locations: old)
        XCTAssertThrowsError(try SailuneBackupService.scheduleRestore(from: oldArchive, locations: b))
        let guest = SailuneDataLocations(mainStore: root.appendingPathComponent("guest/Sailune-v5.store"), workspaceID: "guest")
        try FileManager.default.createDirectory(at: guest.mainStore.deletingLastPathComponent(), withIntermediateDirectories: true)
        XCTAssertNoThrow(try SailuneBackupService.scheduleRestore(from: oldArchive, locations: guest))
    }

    func testCoordinatorSwitchFailurePreservesWorkspaceAndSuccessfulSwitchReopens() throws {
        let root = try temporaryRoot()
        let coordinator = WorkspaceCoordinator(legacyLocations: SailuneDataLocations(mainStore: root.appendingPathComponent("legacy/Sailune-v5.store")))
        XCTAssertNotNil(coordinator.bundle, coordinator.errorMessage ?? "")
        let guest = try XCTUnwrap(coordinator.bundle)
        let book = Book(title: "未登入作品", author: "作者")
        guest.container.mainContext.insert(book)
        let participantID = UUID()
        coordinator.registerParticipant(id: participantID) { throw WorkspaceError.saveFailed }
        coordinator.openAccount(userID: UUID(), environment: "test", email: "a@example.com")
        XCTAssertEqual(coordinator.selectedID, "guest")
        XCTAssertTrue(coordinator.accounts.isEmpty)
        XCTAssertNotNil(coordinator.errorMessage)
        coordinator.unregisterParticipant(id: participantID)
        coordinator.openAccount(userID: UUID(), environment: "test", email: "a@example.com")
        let aID = coordinator.selectedID
        XCTAssertNotEqual(aID, "guest")
        XCTAssertTrue(try XCTUnwrap(coordinator.bundle).container.mainContext.fetch(FetchDescriptor<Book>()).isEmpty)
        let busyID = UUID()
        coordinator.registerOperation(id: busyID) { true }
        coordinator.switchTo("guest")
        XCTAssertEqual(coordinator.selectedID, aID)
        coordinator.unregisterOperation(id: busyID)
        coordinator.switchTo("guest")
        XCTAssertEqual(coordinator.selectedID, "guest")
        XCTAssertEqual(try XCTUnwrap(coordinator.bundle).container.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [book.id])
        coordinator.switchTo(aID)
        let reopened = WorkspaceCoordinator(legacyLocations: SailuneDataLocations(mainStore: root.appendingPathComponent("legacy/Sailune-v5.store")))
        XCTAssertEqual(reopened.selectedID, aID)
    }

    func testCoordinatorDeletesCurrentAccountReturnsGuestAndPreservesOtherAccount() async throws {
        let root = try temporaryRoot()
        let coordinator = WorkspaceCoordinator(legacyLocations: SailuneDataLocations(mainStore: root.appendingPathComponent("legacy/Sailune-v5.store")))
        coordinator.openAccount(userID: UUID(), environment: "fixture", email: "a@example.com")
        let aID = coordinator.selectedID
        coordinator.openAccount(userID: UUID(), environment: "fixture", email: "b@example.com")
        let bID = coordinator.selectedID
        coordinator.switchTo(aID)
        let auth = SailuneAccountAuthService(supabaseURL: nil, publishableKey: "", storage: AccountSessionFixture().storage())
        await coordinator.deleteAccount(aID, auth: auth)
        XCTAssertNil(coordinator.errorMessage)
        XCTAssertEqual(coordinator.selectedID, "guest")
        XCTAssertEqual(coordinator.accounts.map(\.id), [bID])
        coordinator.switchTo(bID)
        XCTAssertEqual(coordinator.selectedID, bID)
        await coordinator.deleteAccount(bID, auth: auth)
        XCTAssertNil(coordinator.errorMessage)
        XCTAssertEqual(coordinator.selectedID, "guest")
        XCTAssertTrue(coordinator.accounts.isEmpty)
    }

    func testPublicationIdentityRequiresMatchingUserAndEnvironment() {
        let id = UUID()
        var account = WorkspaceAccount(id: "test", userID: id, environment: "test", email: "a@example.com", penName: "")
        XCTAssertFalse(WorkspaceCoordinator.identityMatches(account: nil, userID: id, environment: "test"), "Guest 不得借用記住的帳號身分發布")
        XCTAssertTrue(WorkspaceCoordinator.identityMatches(account: account, userID: id, environment: "test"))
        XCTAssertFalse(WorkspaceCoordinator.identityMatches(account: account, userID: UUID(), environment: "test"))
        XCTAssertFalse(WorkspaceCoordinator.identityMatches(account: account, userID: id, environment: "another"))
        XCTAssertFalse(WorkspaceCoordinator.identityMatches(account: account, userID: nil, environment: nil))
        account.isDeleting = true
        XCTAssertFalse(WorkspaceCoordinator.identityMatches(account: account, userID: id, environment: "test"))
    }

    func testPublicationServiceRejectsGuestAndUnverifiedAccountBeforeCredentials() async throws {
        let root = try temporaryRoot()
        let workspace = WorkspaceCoordinator(legacyLocations: SailuneDataLocations(mainStore: root.appendingPathComponent("legacy.store")))
        XCTAssertNil(workspace.errorMessage)
        let auth = SailuneAccountAuthService()
        let statusURL = root.appendingPathComponent("publication-status.json")
        let store = try BookPublicationStore(url: statusURL)
        let book = Book(title: "不可未登入發布", author: "作者", volumes: [Sailune.Volume(title: "卷")])
        let publication = PublicationCoordinator()
        try publication.prepare(book: book, tags: [], status: .draft, sectionUnit: .section)
        XCTAssertFalse(workspace.canPublish(auth: auth))
        publication.send(auth: auth, store: store, workspace: workspace)
        await publication.waitForCompletion()
        XCTAssertEqual(publication.phase, .failure)
        XCTAssertEqual(publication.message, WorkspaceError.publicationRequiresAccount.localizedDescription)
        XCTAssertNil(publication.result)
        XCTAssertEqual(store.status(for: book.id), .draft)
        XCTAssertFalse(FileManager.default.fileExists(atPath: statusURL.path))

        workspace.openAccount(userID: UUID(), environment: "fixture", email: "a@example.com")
        XCTAssertNotNil(workspace.currentAccount)
        XCTAssertFalse(workspace.canPublish(auth: auth))
        publication.send(auth: auth, store: store, workspace: workspace)
        await publication.waitForCompletion()
        XCTAssertEqual(publication.phase, .failure)
        XCTAssertEqual(publication.message, WorkspaceError.identityMismatch.localizedDescription)
        XCTAssertNil(publication.result)
        XCTAssertEqual(store.status(for: book.id), .draft)
        XCTAssertFalse(FileManager.default.fileExists(atPath: statusURL.path))
    }

    func testWorkspacePreferencesPersistWithoutSharing() throws {
        let root = try temporaryRoot()
        let aURL = root.appendingPathComponent("a.plist")
        let bURL = root.appendingPathComponent("b.plist")
        let a = try WorkspacePreferences.open(at: aURL)
        let b = try WorkspacePreferences.open(at: bURL)
        defer {
            a.removePersistentDomain(forName: aURL.path)
            b.removePersistentDomain(forName: bURL.path)
        }
        a.set("chapter", forKey: SectionUnitPreference.storageKey)
        b.set("section", forKey: SectionUnitPreference.storageKey)
        try WorkspacePreferences.save(a, at: aURL)
        try WorkspacePreferences.save(b, at: bURL)
        XCTAssertEqual(try WorkspacePreferences.open(at: aURL).string(forKey: SectionUnitPreference.storageKey), "chapter")
        XCTAssertEqual(try WorkspacePreferences.open(at: bURL).string(forKey: SectionUnitPreference.storageKey), "section")
    }
}

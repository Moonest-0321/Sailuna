import XCTest
import SwiftData
import SQLite3
@testable import Sailune

@MainActor
final class WorkspaceTransferTests: XCTestCase {
    private func fixture() throws -> (WorkspaceTransferService, String, UUID) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TransferTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let registry = try WorkspaceRegistry(root: root)
        let account = try registry.register(userID: UUID(), environment: "fixture", email: "a@example.com")
        let service = WorkspaceTransferService(registry: registry)
        let bookID = UUID()
        do {
            let source = try WorkspaceBundle(locations: service.locations("guest"))
            let book = Book(id: bookID, title: "未登入作品", author: "原作者")
            let volume = Volume(title: "卷", book: book)
            let section = Section(title: "節", content: AttributedString("完整正文引用"), volume: volume)
            book.volumes = [volume]
            volume.sections = [section]
            source.container.mainContext.insert(book)
            source.container.mainContext.insert(AuthorProfile(penName: "來源筆名", bio: "簡介"))
            let item = Item(name: "物品", book: book)
            let level = ItemLevel(itemID: item.id, name: "等級")
            let ability = CharacterAbility(name: "能力")
            source.container.mainContext.insert(item)
            source.container.mainContext.insert(level)
            source.container.mainContext.insert(ability)
            source.settingsStore.container.mainContext.insert(WorldTerm(bookID: bookID, name: "設定"))
            source.planningStore.container.mainContext.insert(ChapterAnnotation(sectionID: section.id, bookID: bookID, plannedOutline: "章綱"))
            try source.save()
            let copy = source.copyStore.createCopy(itemID: item.id, name: "副本")
            source.copyStore.setCurrentLevel(copyID: copy.id, levelID: level.id)
            try source.abilityStore.register(abilityID: ability.id, bookID: bookID)
            source.abilityStore.container.mainContext.insert(AbilityLevel(abilityID: ability.id, name: "能力階段"))
            try source.save()
            _ = try source.forumPostsStore.create(board: .writing, title: "來源論壇", body: "內容")
            try source.writingStatsStore.recordSuccessfulEdits([(bookID: bookID, netWordDelta: 7)])
            for url in [source.locations.coversDirectory, source.locations.mapsDirectory, source.locations.aiConversationsDirectory, source.locations.bookTemplatesDirectory] {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                try Data("完整資產".utf8).write(to: url.appendingPathComponent("fixture.data"))
            }
            let values = [SectionUnitPreference.storageKey: BookTextSectionMarker.chapter.rawValue]
            try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0).write(to: source.locations.preferencesURL)
        }
        do {
            let destination = try WorkspaceBundle(locations: service.locations(account.id))
            destination.container.mainContext.insert(AuthorProfile(penName: "我的筆名"))
            try destination.save()
        }
        return (service, account.id, bookID)
    }

    func testMovePreservesUUIDRelationshipsAssetsAuthorAndLeavesGuestEmpty() throws {
        let (service, destinationID, bookID) = try fixture()
        XCTAssertTrue(service.eligibility(for: destinationID).canTransfer, service.eligibility(for: destinationID).reason ?? "")
        try service.prepare(destinationID: destinationID)
        let journal = try service.install()
        try service.commit(journal)
        XCTAssertEqual(try service.finishCommittedTransfer(), destinationID)
        XCTAssertFalse(service.hasPendingTransfer)
        let target = try WorkspaceBundle(locations: service.locations(destinationID))
        let book = try XCTUnwrap(target.container.mainContext.fetch(FetchDescriptor<Book>()).first)
        XCTAssertEqual(book.id, bookID)
        XCTAssertEqual(String(book.volumes[0].sections[0].content.characters), "完整正文引用")
        XCTAssertEqual(try target.container.mainContext.fetch(FetchDescriptor<AuthorProfile>()).first?.penName, "來源筆名")
        XCTAssertEqual(try target.settingsStore.container.mainContext.fetch(FetchDescriptor<WorldTerm>()).count, 1)
        XCTAssertEqual(try target.planningStore.container.mainContext.fetch(FetchDescriptor<ChapterAnnotation>()).count, 1)
        XCTAssertEqual(target.forumPostsStore.posts(in: .writing).count, 1)
        let copy = try XCTUnwrap(target.copyStore.container.mainContext.fetch(FetchDescriptor<ItemCopy>()).first)
        XCTAssertNotNil(target.copyStore.currentLevelID(for: copy.id))
        XCTAssertEqual(try target.abilityStore.container.mainContext.fetch(FetchDescriptor<AbilityLevel>()).count, 1)
        for url in [target.locations.coversDirectory, target.locations.mapsDirectory, target.locations.aiConversationsDirectory, target.locations.bookTemplatesDirectory] {
            XCTAssertEqual(try Data(contentsOf: url.appendingPathComponent("fixture.data")), Data("完整資產".utf8))
        }
        let guest = try WorkspaceBundle(locations: service.locations("guest"))
        XCTAssertTrue(try guest.container.mainContext.fetch(FetchDescriptor<Book>()).isEmpty)
        XCTAssertTrue(guest.forumPostsStore.posts(in: .writing).isEmpty)
        let recovery = service.registry.root.appendingPathComponent("Transfer Recovery/\(journal.transactionID.uuidString)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovery.appendingPathComponent("Guest.sailunebackup").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovery.appendingPathComponent("original-guest/Sailune-v5.store").path))
        XCTAssertNil(try service.recoverIfNeeded())
        XCTAssertEqual(try WorkspaceRegistry(root: service.registry.root).document.selectedID, destinationID)
    }

    func testNonemptyAuthorPreferencesAndUnknownFilesRefuseOverwrite() throws {
        let (service, id, _) = try fixture()
        let target = try service.locations(id)
        let extra = target.mainStore.deletingLastPathComponent().appendingPathComponent("unknown")
        try Data().write(to: extra)
        XCTAssertFalse(service.eligibility(for: id).canTransfer)
        try FileManager.default.removeItem(at: extra)
        try PropertyListSerialization.data(fromPropertyList: ["custom": true], format: .binary, options: 0).write(to: target.preferencesURL)
        XCTAssertFalse(service.eligibility(for: id).canTransfer)
        try FileManager.default.removeItem(at: target.preferencesURL)
        do {
            let bundle = try WorkspaceBundle(locations: target)
            let author = try XCTUnwrap(bundle.container.mainContext.fetch(FetchDescriptor<AuthorProfile>()).first)
            author.bio = "已有簡介"
            try bundle.save()
        }
        XCTAssertFalse(service.eligibility(for: id).canTransfer)
        XCTAssertThrowsError(try service.prepare(destinationID: id))
        XCTAssertFalse(service.hasPendingTransfer)
    }

    func testPublishedSourcePendingRestoreAndSymlinkRefuseTransfer() throws {
        let (service, id, bookID) = try fixture()
        let source = try service.locations("guest")
        let publication = try BookPublicationStore(url: source.publicationStatusURL, tagsURL: source.publicationTagsURL)
        try publication.publish(bookID, tags: [])
        XCTAssertTrue(service.eligibility(for: id).reason?.contains("已發布") == true)
        try FileManager.default.removeItem(at: source.publicationStatusURL)
        try Data().write(to: source.pendingRestoreURL)
        XCTAssertTrue(service.eligibility(for: id).reason?.contains("還原") == true)
        try FileManager.default.removeItem(at: source.pendingRestoreURL)
        try FileManager.default.createSymbolicLink(at: source.coversDirectory.appendingPathComponent("outside"), withDestinationURL: service.registry.root)
        XCTAssertFalse(service.eligibility(for: id).canTransfer)
    }

    func testPublishedGuestIsRejectedByDefaultWithoutChangingEitherSpace() throws {
        let (service, id, bookID) = try fixture()
        let source = try service.locations("guest")
        let publication = try BookPublicationStore(url: source.publicationStatusURL, tagsURL: source.publicationTagsURL)
        try publication.publish(bookID, tags: ["原有標籤"])
        for status in [BookStatus.ongoing, .completed, .delisted] {
            if status == .completed { try publication.advance(bookID) }
            if status == .delisted { try publication.delist(bookID) }
            XCTAssertTrue(service.eligibility(for: id).reason?.contains("已發布") == true)
            XCTAssertThrowsError(try service.prepare(destinationID: id))
            XCTAssertEqual(publication.status(for: bookID), status)
            XCTAssertEqual(publication.tags(for: bookID), ["原有標籤"])
            XCTAssertFalse(service.hasPendingTransfer)
        }
        let sourceBundle = try WorkspaceBundle(locations: source)
        XCTAssertEqual(try sourceBundle.container.mainContext.fetch(FetchDescriptor<Book>()).first?.id, bookID)
        let destination = try WorkspaceBundle(locations: service.locations(id))
        XCTAssertTrue(try destination.container.mainContext.fetch(FetchDescriptor<Book>()).isEmpty)
    }

    func testPreparingFailuresKeepSourceAndDestinationAndRecoverOnReopen() throws {
        for boundary in ["journal-preparing", "backups", "copied", "validated", "journal-prepared"] {
            let (service, id, bookID) = try fixture()
            var reachedBoundary = false
            service.checkpoint = { if $0 == boundary { reachedBoundary = true; throw CocoaError(.fileWriteNoPermission) } }
            XCTAssertThrowsError(try service.prepare(destinationID: id), boundary)
            XCTAssertTrue(reachedBoundary, "未到達預期故障邊界：\(boundary)")
            let reopened = WorkspaceTransferService(registry: try WorkspaceRegistry(root: service.registry.root))
            XCTAssertNil(try reopened.recoverIfNeeded())
            XCTAssertFalse(reopened.hasPendingTransfer)
            let source = try WorkspaceBundle(locations: reopened.locations("guest"))
            XCTAssertEqual(try source.container.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [bookID])
            let target = try WorkspaceBundle(locations: reopened.locations(id))
            XCTAssertTrue(try target.container.mainContext.fetch(FetchDescriptor<Book>()).isEmpty)
        }
    }

    func testInstallFailuresRollBackWithoutDuplicateSourceOnRepeatedRecovery() throws {
        for boundary in ["journal-installing", "destination-moved", "installed", "journal-committed"] {
            let (service, id, bookID) = try fixture()
            try service.prepare(destinationID: id)
            var reachedBoundary = false
            service.checkpoint = { if $0 == boundary { reachedBoundary = true; throw CocoaError(.fileWriteNoPermission) } }
            XCTAssertThrowsError(try { let journal = try service.install(); try service.commit(journal) }(), boundary)
            XCTAssertTrue(reachedBoundary, "未到達預期故障邊界：\(boundary)")
            let reopened = WorkspaceTransferService(registry: try WorkspaceRegistry(root: service.registry.root))
            XCTAssertNil(try reopened.recoverIfNeeded())
            XCTAssertNil(try reopened.recoverIfNeeded())
            let source = try WorkspaceBundle(locations: reopened.locations("guest"))
            XCTAssertEqual(try source.container.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [bookID])
            let target = try WorkspaceBundle(locations: reopened.locations(id))
            XCTAssertTrue(try target.container.mainContext.fetch(FetchDescriptor<Book>()).isEmpty)
        }
    }

    func testCommittedFailuresResumeGuestResetExactlyOnce() throws {
        for boundary in ["guest-moved", "guest-reset", "journal-completed", "registry-updated"] {
            let (service, id, bookID) = try fixture()
            try service.prepare(destinationID: id)
            try service.commit(service.install())
            var reachedBoundary = false
            service.checkpoint = { if $0 == boundary { reachedBoundary = true; throw CocoaError(.fileWriteNoPermission) } }
            XCTAssertThrowsError(try service.finishCommittedTransfer(), boundary)
            XCTAssertTrue(reachedBoundary, "未到達預期故障邊界：\(boundary)")
            let reopened = WorkspaceTransferService(registry: try WorkspaceRegistry(root: service.registry.root))
            XCTAssertEqual(try reopened.recoverIfNeeded(), id)
            XCTAssertNil(try reopened.recoverIfNeeded())
            let target = try WorkspaceBundle(locations: reopened.locations(id))
            XCTAssertEqual(try target.container.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [bookID])
            let guest = try WorkspaceBundle(locations: reopened.locations("guest"))
            XCTAssertTrue(try guest.container.mainContext.fetch(FetchDescriptor<Book>()).isEmpty)
        }
    }

    func testCorruptSourcePreferencesAreRejectedBeforeStaging() throws {
        let (service, id, _) = try fixture()
        try Data("broken preferences".utf8).write(to: service.locations("guest").preferencesURL)
        XCTAssertFalse(service.eligibility(for: id).canTransfer)
        XCTAssertThrowsError(try service.prepare(destinationID: id))
        XCTAssertFalse(service.hasPendingTransfer)
    }

    func testOrphanDataInNonMainStoreIsNotAnEmptyAccount() throws {
        let (service, id, _) = try fixture()
        do {
            let target = try WorkspaceBundle(locations: service.locations(id))
            target.settingsStore.container.mainContext.insert(WorldTerm(bookID: UUID(), name: "既有設定"))
            try target.save()
        }
        XCTAssertFalse(service.eligibility(for: id).canTransfer)
        XCTAssertThrowsError(try service.prepare(destinationID: id))
        XCTAssertFalse(service.hasPendingTransfer)
    }

    func testCommittedCorruptionStopsGuestResetAndPreservesRecovery() throws {
        let (service, id, bookID) = try fixture()
        try service.prepare(destinationID: id)
        let journal = try service.install()
        try service.commit(journal)
        let target = try service.locations(id)
        try Data("changed".utf8).write(to: target.coversDirectory.appendingPathComponent("fixture.data"))
        let reopened = WorkspaceTransferService(registry: try WorkspaceRegistry(root: service.registry.root))
        XCTAssertThrowsError(try reopened.recoverIfNeeded())
        XCTAssertTrue(reopened.hasPendingTransfer)
        let source = try WorkspaceBundle(locations: reopened.locations("guest"))
        XCTAssertEqual(try source.container.mainContext.fetch(FetchDescriptor<Book>()).map(\.id), [bookID])
    }

    func testCoordinatorMoveSwitchesAndReopensWithOtherAccountPreserved() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CoordinatorTransfer-\(UUID())")
        addTeardownBlock { if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) } }
        let legacy = SailuneDataLocations(mainStore: root.appendingPathComponent("legacy/Sailune-v5.store"))
        let coordinator = WorkspaceCoordinator(legacyLocations: legacy)
        do {
            let source = try XCTUnwrap(coordinator.bundle)
            source.container.mainContext.insert(Book(title: "移入作品", author: "原作者"))
        }
        coordinator.openAccount(userID: UUID(), environment: "fixture", email: "a@example.com")
        let aID = coordinator.selectedID
        coordinator.openAccount(userID: UUID(), environment: "fixture", email: "b@example.com")
        let bID = coordinator.selectedID
        do {
            let b = try XCTUnwrap(coordinator.bundle)
            b.container.mainContext.insert(Book(title: "另一帳號作品", author: "B"))
        }
        coordinator.switchTo("guest")
        await coordinator.transferGuest(to: aID)
        XCTAssertNil(coordinator.errorMessage)
        XCTAssertEqual(coordinator.selectedID, aID)
        XCTAssertEqual(coordinator.transferCompletionMessage, "移入完成")
        XCTAssertEqual(try XCTUnwrap(coordinator.bundle).container.mainContext.fetch(FetchDescriptor<Book>()).map(\.title), ["移入作品"])
        coordinator.switchTo(bID)
        XCTAssertEqual(try XCTUnwrap(coordinator.bundle).container.mainContext.fetch(FetchDescriptor<Book>()).map(\.title), ["另一帳號作品"])
        coordinator.switchTo(aID)
        let reopened = WorkspaceCoordinator(legacyLocations: legacy)
        XCTAssertEqual(reopened.selectedID, aID)
        reopened.switchTo("guest")
        XCTAssertTrue(try XCTUnwrap(reopened.bundle).container.mainContext.fetch(FetchDescriptor<Book>()).isEmpty)
    }
}

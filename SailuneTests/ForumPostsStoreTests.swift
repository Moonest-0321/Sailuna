import XCTest
@testable import Sailune

@MainActor
final class ForumPostsStoreTests: XCTestCase {
    func testPostsCreateUpdateDeleteAndPersistByBoardAndModificationDate() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneForumPosts-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Forum Posts.json")
        let store = LocalForumPostsStore(url: url)
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)

        let first = try store.create(board: .writing, title: "  人物登場  ", body: "  想請教出場節奏。  ", at: baseDate)
        let second = try store.create(board: .writing, title: "場景轉換", body: "如何安排？", at: baseDate.addingTimeInterval(1))
        _ = try store.create(board: .works, title: "作品簡介", body: "新的故事。", at: baseDate.addingTimeInterval(2))

        XCTAssertEqual(first.title, "人物登場")
        XCTAssertEqual(first.body, "想請教出場節奏。")
        XCTAssertEqual(store.posts(in: .writing).map(\.id), [second.id, first.id])
        XCTAssertEqual(store.posts(in: .works).map(\.title), ["作品簡介"])

        let updated = try store.update(
            id: first.id,
            title: "角色登場節奏",
            body: "調整後的問題。",
            at: baseDate.addingTimeInterval(3)
        )
        XCTAssertEqual(updated.id, first.id)
        XCTAssertEqual(updated.board, .writing)
        XCTAssertEqual(updated.createdAt, baseDate)
        XCTAssertEqual(updated.updatedAt, baseDate.addingTimeInterval(3))
        XCTAssertEqual(store.posts(in: .writing).first?.id, first.id)

        let reopened = LocalForumPostsStore(url: url)
        XCTAssertEqual(reopened.posts(in: .writing).first, updated)
        XCTAssertEqual(reopened.posts(in: .works).count, 1)

        try reopened.delete(id: first.id)
        XCTAssertNil(reopened.post(id: first.id))
        XCTAssertEqual(LocalForumPostsStore(url: url).posts(in: .writing).map(\.id), [second.id])
    }

    func testBlankTitleAndBodyAreRejected() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneForumValidation-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalForumPostsStore(url: directory.appendingPathComponent("posts.json"))

        XCTAssertThrowsError(try store.create(board: .writing, title: " \n ", body: "內文")) { error in
            XCTAssertEqual(error as? LocalForumPostsStore.StoreError, .emptyTitle)
        }
        XCTAssertThrowsError(try store.create(board: .writing, title: "標題", body: " \n ")) { error in
            XCTAssertEqual(error as? LocalForumPostsStore.StoreError, .emptyBody)
        }
        XCTAssertTrue(store.posts(in: .writing).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("posts.json").path))
    }

    func testCorruptDocumentIsNotOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneForumCorrupt-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("posts.json")
        let original = Data("not a forum document".utf8)
        try original.write(to: url)

        let store = LocalForumPostsStore(url: url)
        XCTAssertTrue(store.isUnavailable)
        XCTAssertNotNil(store.unavailableReason)
        XCTAssertThrowsError(try store.create(board: .writing, title: "新文章", body: "不應覆寫"))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testFailedWriteKeepsThePreviouslyLoadedPosts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneForumWriteFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("posts.json")
        let store = LocalForumPostsStore(url: url)
        let saved = try store.create(board: .writing, title: "既有文章", body: "原本內容")

        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.create(board: .writing, title: "新文章", body: "寫入失敗"))
        XCTAssertEqual(store.posts(in: .writing), [saved])
        XCTAssertNotNil(store.persistenceErrorMessage)
    }
}

import XCTest
import Supabase
import SwiftData
@testable import Sailune

@MainActor
final class CommunityContractTests: XCTestCase {
    func testMissingCommunityTableHasActionableMessage() {
        let error = PostgrestError(code: "PGRST205", message: "Could not find the table in the schema cache")
        XCTAssertEqual(CommunityFailure.message(for: error), "共享功能尚未啟用，請聯絡管理員。")

        let hiddenSchema = PostgrestError(code: "PGRST106", message: "The schema must be one of the following")
        XCTAssertEqual(CommunityFailure.message(for: hiddenSchema), "共享功能尚未啟用，請聯絡管理員。")
    }

    func testForumRecordDecodesDatabaseColumnNamesAndBoard() throws {
        let data = Data("""
        {"id":"22222222-2222-4222-8222-222222222222",
         "author_id":"00000000-0000-0000-0000-00000000000b",
         "display_name":"作者乙","board":"writing","title":"討論","body":"內容",
         "created_at":"2026-10-03T00:00:00Z","updated_at":"2026-10-03T00:00:00Z"}
        """.utf8)
        let post = try JSONDecoder().decode(SharedForumPost.self, from: data)
        XCTAssertEqual(post.board, .writing)
        XCTAssertEqual(post.displayName, "作者乙")
        XCTAssertEqual(post.authorId.uuidString.lowercased(), "00000000-0000-0000-0000-00000000000b")
    }

    func testTemplateSummaryDecodesPublishedListing() throws {
        let data = Data("""
        {"id":"11111111-1111-4111-8111-111111111111",
         "owner_id":"00000000-0000-0000-0000-00000000000a",
         "display_name":"作者甲","name":"世界模板","summary":"地圖",
         "format_version":1,"worldview_categories":["fantasy","post_apocalyptic"],"created_at":"2026-10-03T00:00:00Z"}
        """.utf8)
        let template = try JSONDecoder().decode(SharedTemplateSummary.self, from: data)
        XCTAssertEqual(template.name, "世界模板")
        XCTAssertEqual(template.formatVersion, BookTemplateDocument.currentVersion)
        XCTAssertEqual(template.displayName, "作者甲")
        XCTAssertEqual(template.worldviewCategories, [.fantasy, .postApocalyptic])
    }

    func testWorldviewCategoriesDeduplicateAndUseFixedOrder() {
        XCTAssertEqual(TemplateWorldviewCategory.ordered([.fantasy, .reality, .fantasy]), [.reality, .fantasy])
        XCTAssertEqual(TemplateWorldviewCategory.label(for: []), "未分類")
        XCTAssertEqual(TemplateWorldviewCategory.label(for: [.fantasy, .reality]), "現實・奇幻")
    }

    func testLegacyTemplateJSONOpensUnclassifiedAndSavedCategoriesSurviveReload() throws {
        func container(_ models: [any PersistentModel.Type]) throws -> ModelContainer {
            let schema = Schema(models)
            return try ModelContainer(for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        }
        let main = try container(NovelWriterSchemaV5.models)
        let planning = try StoryPlanningStore(container: container(StoryPlanningSchemaV7.models))
        let settings = V5SettingsStore(container: try container(V5SettingsSchemaV13.models))
        let copies = try ItemCopyStore(container: container(ItemCopySchemaV1.models))
        let abilities = try AbilityProgressStore(container: container(AbilityProgressSchemaV1.models))
        let book = Book(title: "舊模板來源", author: "作者")
        main.mainContext.insert(book)
        try main.mainContext.save()
        let snapshot = try BookTemplateCoordinator.snapshot(book: book, planning: planning,
            settingsStore: settings, name: "舊模板", context: main.mainContext,
            copyStore: copies, abilityStore: abilities)
        XCTAssertEqual(snapshot.sourcePenName, "作者")
        XCTAssertEqual(snapshot.author, "")
        var oldObject = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as? [String: Any])
        oldObject.removeValue(forKey: "worldviewCategories")
        oldObject.removeValue(forKey: "sourcePenName")
        let legacy = try JSONSerialization.data(withJSONObject: oldObject)
        let decoded = try JSONDecoder().decode(BookTemplateDocument.self, from: legacy)
        XCTAssertNil(decoded.worldviewCategories)
        XCTAssertNil(decoded.sourcePenName)

        let applied = try BookTemplateCoordinator.apply(decoded, title: "套用草稿", author: "套用者",
            context: main.mainContext, planning: planning, settingsStore: settings,
            copyStore: copies, abilityStore: abilities)
        XCTAssertEqual(applied.author, "套用者")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var legacyWithAuthor = oldObject
        legacyWithAuthor["author"] = "舊來源筆名"
        try JSONSerialization.data(withJSONObject: legacyWithAuthor)
            .write(to: directory.appendingPathComponent("\(snapshot.id.uuidString).json"))
        XCTAssertEqual(try BookTemplateStore(directory: directory).templates.first?.sourcePenName,
            "舊來源筆名")
        let store = try BookTemplateStore(directory: directory)
        try store.save(decoded)
        var edited = try XCTUnwrap(store.templates.first)
        edited.worldviewCategories = [.fantasy, .reality, .fantasy]
        try store.save(edited)
        XCTAssertEqual(try BookTemplateStore(directory: directory).templates.first?.worldviewCategories,
            [.reality, .fantasy])
    }
}

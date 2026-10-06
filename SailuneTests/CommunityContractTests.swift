import XCTest
import Supabase
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
         "format_version":1,"created_at":"2026-10-03T00:00:00Z"}
        """.utf8)
        let template = try JSONDecoder().decode(SharedTemplateSummary.self, from: data)
        XCTAssertEqual(template.name, "世界模板")
        XCTAssertEqual(template.formatVersion, BookTemplateDocument.currentVersion)
        XCTAssertEqual(template.displayName, "作者甲")
    }
}

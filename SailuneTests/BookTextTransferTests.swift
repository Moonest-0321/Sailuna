import XCTest
import AppKit
import SwiftData
@testable import Sailune

@MainActor
final class BookTextTransferTests: XCTestCase {
    func testParserKeepsVolumeTitleAndSectionsInSourceOrder() throws {
        let text = """
        第一卷 霧港
        謎霧初現
        第一節 相遇
        林雨在港口醒來。

        海面無聲。
        第二節 離開
        她登上船。
        第二卷 遠方
        新的旅程
        第一節 抵達
        船靠岸了。
        """

        let document = try XCTUnwrap(BookTextImportParser.parse(text: text, marker: .section).get())
        XCTAssertEqual(document.volumes.map(\.title), ["霧港 謎霧初現", "遠方 新的旅程"])
        XCTAssertEqual(document.volumes[0].sections.map(\.title), ["相遇", "離開"])
        XCTAssertEqual(document.volumes[0].sections.map(\.content), ["林雨在港口醒來。\n\n海面無聲。", "她登上船。"])
        XCTAssertEqual(document.volumes[1].sections.first?.content, "船靠岸了。")
    }

    func testParserSupportsEachMarkerIndividually() throws {
        for marker in BookTextSectionMarker.allCases {
            let text = "第一卷 旅程\n第一\(marker.label) 相遇\n正文"
            let document = try XCTUnwrap(BookTextImportParser.parse(text: text, marker: marker).get())
            XCTAssertEqual(document.volumes[0].sections[0].title, "相遇")
        }
    }

    func testParserRejectsMixedMarkersAndReportsLine() {
        let result = BookTextImportParser.parse(
            text: "第一卷 旅程\n第一章 相遇\n正文\n第二節 離開\n正文",
            marker: .chapter
        )
        XCTAssertEqual(try? result.get(), nil)
        guard case .failure(.mixedSectionMarkers(line: 4, selected: "章", found: "節")) = result else {
            return XCTFail("應指出混用標記的行數")
        }
    }

    func testParserReportsInvalidUTF8AndMissingMarkers() {
        XCTAssertEqual(BookTextImportParser.parse(data: Data([0xFF]), marker: .chapter), .failure(.invalidUTF8))
        XCTAssertEqual(BookTextImportParser.parse(text: "\n  ", marker: .chapter), .failure(.emptyFile))
        XCTAssertEqual(BookTextImportParser.parse(text: "沒有標記", marker: .chapter), .failure(.noSectionMarker))
        XCTAssertEqual(BookTextImportParser.parse(text: "第一卷 旅程", marker: .chapter), .failure(.noSectionMarker))
    }

    func testTXTExportUsesChosenHeadingMarkerWithoutHashPrefixes() {
        let section = Sailune.Section(title: "第一節 相遇", content: AttributedString("正文"), sortOrder: 0)
        XCTAssertTrue(ExportManager.exportSectionToTXT(section: section, marker: .chapter).hasPrefix("第一章 相遇\n\n"))
        XCTAssertTrue(ExportManager.exportSectionToTXT(section: section, marker: .section).hasPrefix("第一節 相遇\n\n"))

        let content = NSMutableAttributedString(string: "## 幕標題\n一般內文")
        content.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 18), range: NSRange(location: 0, length: 7))
        let attributed = AttributedString(content)
        let exported = ExportManager.exportSectionToTXT(
            section: Sailune.Section(title: "相遇", content: attributed, sortOrder: 0),
            marker: .chapter
        )
        XCTAssertTrue(exported.contains(" 幕標題\n"))
        XCTAssertFalse(exported.contains("#"))
        XCTAssertTrue(exported.contains("一般內文"))
    }

    func testWholeAndVolumeTXTExportsPrefixVolumeOrdinalAndRemoveHashHeadings() {
        let section = Sailune.Section(title: "第一節 相遇", content: AttributedString("幕標題與正文"), sortOrder: 0)
        let volume = Sailune.Volume(title: "第一卷 霧港", sortOrder: 0, sections: [section])
        let book = Book(title: "旅程", author: "作者", volumes: [volume])

        let bookTXT = ExportManager.exportBookToTXT(book: book)
        XCTAssertTrue(bookTXT.hasPrefix("旅程\n作者：作者"))
        XCTAssertTrue(bookTXT.contains("\n第一卷 霧港\n\n"))
        XCTAssertTrue(bookTXT.contains("\n第一節 相遇\n\n"))
        XCTAssertFalse(bookTXT.contains("#"))

        let volumeTXT = ExportManager.exportVolumeToTXT(volume: volume, bookTitle: book.title)
        XCTAssertTrue(volumeTXT.hasPrefix("旅程\n\n第一卷 霧港\n\n"))
        XCTAssertFalse(volumeTXT.contains("#"))
    }

    func testImportCoordinatorPersistsOnlyTheNewBookAndItsOrderedContents() throws {
        let schema = Schema(versionedSchema: NovelWriterSchemaV5.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let existing = Book(title: "既有書", author: "作者")
        container.mainContext.insert(existing)
        try container.mainContext.save()
        let document = BookTextImportDocument(volumes: [
            .init(title: "第一卷", sections: [
                .init(title: "相遇", content: "正文一"),
                .init(title: "離開", content: "正文二")
            ])
        ])

        let importedID = try BookImportCoordinator.createBook(
            title: "匯入書",
            author: "作者乙",
            document: document,
            in: container
        )

        let books = try container.mainContext.fetch(FetchDescriptor<Book>())
        XCTAssertEqual(books.count, 2)
        let retainedBook = books.first { $0.id == existing.id }
        XCTAssertEqual(retainedBook?.title, "既有書")
        let imported = try XCTUnwrap(books.first(where: { $0.id == importedID }))
        XCTAssertEqual(imported.title, "匯入書")
        let orderedVolumes = imported.volumes.sorted { $0.sortOrder < $1.sortOrder }
        let importedVolume = try XCTUnwrap(orderedVolumes.first)
        let orderedSections = importedVolume.sections.sorted { $0.sortOrder < $1.sortOrder }
        XCTAssertEqual(orderedSections.map(\.title), ["相遇", "離開"])
        XCTAssertEqual(orderedSections.first?.content.characters.map(String.init).joined(), "正文一")
    }
}

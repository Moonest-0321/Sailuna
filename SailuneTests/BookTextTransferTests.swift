import XCTest
import AppKit
import SwiftData
import UniformTypeIdentifiers
@testable import Sailune

@MainActor
final class BookTextTransferTests: XCTestCase {
    func testReaderJSONExportPreservesIdentityOrderAndReadableChinese() throws {
        let styled = NSMutableAttributedString(string: "幕一\n內文\n")
        styled.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 18), range: NSRange(location: 0, length: 2))
        let section = Sailune.Section(title: "相遇", content: AttributedString(styled), sortOrder: 4, wordCount: 4)
        let volume = Sailune.Volume(title: "霧港", sortOrder: 8, sections: [section])
        let book = Book(title: "旅程/測試", author: "作者", synopsis: "簡介", volumes: [volume])
        let exportedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let package = BookJSONExporter.makePackage(
            book: book, categories: ["奇幻"], status: .ongoing, sectionUnit: .section, exportedAt: exportedAt
        )
        let request = try BookJSONExporter.exportRequest(
            book: book, categories: ["奇幻"], status: .ongoing, sectionUnit: .section, onSaved: { _ in }
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BookJSONExporter.Package.self, from: request.document.data)

        XCTAssertEqual(request.defaultFilename, "旅程_測試.json")
        XCTAssertEqual(request.contentType, .json)
        XCTAssertEqual(decoded.format, "sailune.reader-book")
        XCTAssertEqual(decoded.version, 1)
        XCTAssertEqual(decoded.book.id, book.id)
        XCTAssertEqual(decoded.book.author, "作者")
        XCTAssertEqual(decoded.book.synopsis, "簡介")
        XCTAssertEqual(decoded.book.categories, ["奇幻"])
        XCTAssertEqual(decoded.book.publicationStatus, "ongoing")
        XCTAssertEqual(decoded.book.volumes[0].id, volume.id)
        XCTAssertEqual(decoded.book.volumes[0].order, 0)
        XCTAssertEqual(decoded.book.volumes[0].sections[0].id, section.id)
        XCTAssertEqual(decoded.book.volumes[0].sections[0].wordCount, 4)
        XCTAssertEqual(decoded.book.volumes[0].sections[0].blocks.map(\.type), ["sceneHeading", "paragraph", "paragraph"])
        XCTAssertEqual(decoded.book.volumes[0].sections[0].blocks.map(\.text), ["幕一", "內文", ""])
        XCTAssertEqual(decoded.book.volumes[0].sections[0].contentHash, package.book.volumes[0].sections[0].contentHash)
        XCTAssertNil(decoded.book.cover)
        XCTAssertLessThan(request.document.data.count, 4_096)
        let jsonText = try XCTUnwrap(String(data: request.document.data, encoding: .utf8))
        XCTAssertTrue(jsonText.contains("旅程/測試"))
        XCTAssertTrue(jsonText.contains("幕一"))
        XCTAssertFalse(jsonText.contains("\\u65c5"))

        section.content = AttributedString("幕一\n新內文\n")
        let changed = BookJSONExporter.makePackage(
            book: book, categories: ["奇幻"], status: .ongoing, sectionUnit: .section, exportedAt: exportedAt
        )
        XCTAssertNotEqual(changed.book.volumes[0].sections[0].contentHash, package.book.volumes[0].sections[0].contentHash)
    }

    func testPublishingStateChangesOnlyAfterExportSaveAndUpdateKeepsState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneReaderPublish-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try BookPublicationStore(url: directory.appendingPathComponent("Publication Status.json"))
        let book = Book(title: "待發布", author: "作者")
        var statusError: Error?
        let request = try PublicationExportCoordinator.initialRequest(
            book: book,
            categories: ["冒險"],
            sectionUnit: .chapter,
            publicationStore: store,
            onStatusError: { statusError = $0 }
        )

        XCTAssertEqual(store.status(for: book.id), .draft)
        XCTAssertTrue(store.tags(for: book.id).isEmpty)
        request.onSaved?(directory.appendingPathComponent(request.defaultFilename))
        XCTAssertNil(statusError)
        XCTAssertEqual(store.status(for: book.id), .ongoing)
        XCTAssertEqual(store.tags(for: book.id), ["冒險"])

        let update = try PublicationExportCoordinator.updateRequest(
            book: book, sectionUnit: .chapter, publicationStore: store
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BookJSONExporter.Package.self, from: update.document.data)
        XCTAssertEqual(decoded.book.id, book.id)
        XCTAssertEqual(decoded.book.categories, ["冒險"])
        XCTAssertEqual(decoded.book.publicationStatus, "ongoing")
        XCTAssertEqual(store.status(for: book.id), .ongoing)
    }

    func testSavedExportReportsLocalPublicationFailureWithoutChangingState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneReaderPublishFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let statusURL = directory.appendingPathComponent("Publication Status.json")
        let store = try BookPublicationStore(url: statusURL)
        let book = Book(title: "待發布", author: "作者")
        var statusError: Error?
        let request = try PublicationExportCoordinator.initialRequest(
            book: book,
            categories: ["奇幻"],
            sectionUnit: .section,
            publicationStore: store,
            onStatusError: { statusError = $0 }
        )
        try FileManager.default.createDirectory(at: statusURL, withIntermediateDirectories: true)
        request.onSaved?(directory.appendingPathComponent(request.defaultFilename))

        XCTAssertNotNil(statusError)
        XCTAssertEqual(store.status(for: book.id), .draft)
        XCTAssertTrue(store.tags(for: book.id).isEmpty)
    }

    func testReaderJSONExportSortsVolumesAndSections() {
        let laterSection = Sailune.Section(title: "後節", sortOrder: 9)
        let earlierSection = Sailune.Section(title: "前節", sortOrder: 1)
        let laterVolume = Sailune.Volume(title: "後卷", sortOrder: 8, sections: [laterSection, earlierSection])
        let earlierVolume = Sailune.Volume(title: "前卷", sortOrder: 2)
        let book = Book(title: "順序", author: "作者", volumes: [laterVolume, earlierVolume])

        let package = BookJSONExporter.makePackage(
            book: book, categories: [], status: .ongoing, sectionUnit: .section
        )
        XCTAssertEqual(package.book.volumes.map(\.id), [earlierVolume.id, laterVolume.id])
        XCTAssertEqual(package.book.volumes.map(\.order), [0, 1])
        XCTAssertEqual(package.book.volumes[1].sections.map(\.id), [earlierSection.id, laterSection.id])
        XCTAssertEqual(package.book.volumes[1].sections.map(\.order), [0, 1])
    }

    func testReaderJSONExportIncludesCustomCover() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneReaderCover-\(UUID().uuidString)", isDirectory: true)
        defer {
            BookCoverStore.setDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: directory)
        }
        BookCoverStore.setDirectoryOverrideForTesting(directory)
        let book = Book(title: "自訂封面", author: "作者")
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        try BookCoverStore.save(image: image, for: book)

        let package = BookJSONExporter.makePackage(
            book: book, categories: [], status: .ongoing, sectionUnit: .section
        )
        let cover = try XCTUnwrap(package.book.cover)
        XCTAssertEqual(cover.mediaType, "image/png")
        XCTAssertEqual(Data(base64Encoded: cover.base64), BookCoverStore.pngData(for: book))
    }

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

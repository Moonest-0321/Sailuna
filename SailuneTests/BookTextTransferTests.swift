import XCTest
import AppKit
import SwiftData
import UniformTypeIdentifiers
@testable import Sailune

@MainActor
final class BookTextTransferTests: XCTestCase {
    func testShiyePackagePreservesIdentityHashBlocksAndOneBasedOrder() throws {
        let styled = NSMutableAttributedString(string: "第一幕\n　　海風。\n\n## 純文字")
        styled.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 18), range: NSRange(location: 0, length: 3))
        let section = Sailune.Section(title: "相遇", content: AttributedString(styled), sortOrder: 4, wordCount: 9)
        section.id = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let volume = Sailune.Volume(title: "霧港", sortOrder: 8, sections: [section])
        let book = Book(title: "測試書", author: "測試作者", volumes: [volume])
        let package = try BookJSONExporter.makePackage(book: book, categories: ["奇幻", "奇幻"], status: .ongoing, sectionUnit: .chapter)
        XCTAssertEqual(package.manifest.format, "sailune.shiye-book")
        XCTAssertEqual(package.manifest.book.id, book.id)
        XCTAssertEqual(package.manifest.book.sectionUnit, "chapter")
        XCTAssertEqual(package.manifest.book.tags, ["奇幻"])
        XCTAssertEqual(package.manifest.volumes.first?.index, 1)
        let entry = try XCTUnwrap(package.manifest.volumes.first?.sections.first)
        XCTAssertEqual(entry.index, 1)
        let bytes = try XCTUnwrap(package.entries[entry.file])
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Shiye/section.json")
        XCTAssertEqual(bytes, try Data(contentsOf: fixture))
        XCTAssertEqual(entry.contentHash, "sha256:" + BookJSONExporter.hash(bytes))
        XCTAssertEqual(Array(package.data.prefix(4)), [0x50, 0x4b, 0x03, 0x04])
        XCTAssertNil(package.entries["cover.png"])
        if let path = ProcessInfo.processInfo.environment["SHIYE_CROSS_LANGUAGE_PACKAGE"] {
            try package.data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        section.content = AttributedString("新內容")
        let changed = try BookJSONExporter.makePackage(book: book, categories: [], status: .ongoing, sectionUnit: .section)
        XCTAssertNotEqual(changed.manifest.volumes[0].sections[0].contentHash, entry.contentHash)
    }

    func testShiyePackageContainsSeparateCustomPNGAndRemoteReadableZip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShiyeCover-\(UUID())")
        defer { BookCoverStore.setDirectoryOverrideForTesting(nil); try? FileManager.default.removeItem(at: directory) }
        BookCoverStore.setDirectoryOverrideForTesting(directory)
        let book = Book(title: "封面測試", author: "作者", volumes: [Sailune.Volume(title: "卷")])
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus(); NSColor.red.setFill(); NSRect(x: 0, y: 0, width: 8, height: 8).fill(); image.unlockFocus()
        try BookCoverStore.save(image: image, for: book)
        let package = try BookJSONExporter.makePackage(book: book, categories: [], status: .ongoing, sectionUnit: .section)
        XCTAssertEqual(package.manifest.book.cover, "cover.png")
        XCTAssertEqual(package.entries["cover.png"], BookCoverStore.pngData(for: book))
        if let path = ProcessInfo.processInfo.environment["SHIYE_CROSS_LANGUAGE_COVER_PACKAGE"] {
            try package.data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    func testShiyeRejectsTooManyVolumesBeforePreparingUpload() {
        let volumes = (0..<4095).map { Sailune.Volume(title: "", sortOrder: $0) }
        let book = Book(title: "容量測試", author: "作者", volumes: volumes)
        XCTAssertThrowsError(try BookJSONExporter.makePackage(book: book, categories: [], status: .ongoing, sectionUnit: .section))
    }

    func testEmptySectionAndNFCTextAreRepresentedWithoutPrivateSettings() throws {
        let section = Sailune.Section(title: "e\u{301}", content: AttributedString(""))
        let book = Book(title: "空節", author: "作者", volumes: [Sailune.Volume(title: "", sections: [section])])
        let package = try BookJSONExporter.makePackage(book: book, categories: [], status: .completed, sectionUnit: .zhang)
        let bytes = try XCTUnwrap(package.entries["sections/\(section.id.uuidString).json"])
        let decoded = try JSONDecoder().decode(BookJSONExporter.SectionContent.self, from: bytes)
        XCTAssertEqual(decoded.title, "é")
        XCTAssertTrue(decoded.blocks.isEmpty)
        XCTAssertEqual(package.manifest.book.status, "completed")
        XCTAssertEqual(package.manifest.book.sectionUnit, "zhang")
        XCTAssertThrowsError(try BookJSONExporter.makePackage(book: book, categories: [], status: .delisted, sectionUnit: .section))
    }

    func testRemoteFailureLeavesDraftUntouchedAndRetryKeepsSameAttempt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShiyePublish-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try BookPublicationStore(url: directory.appendingPathComponent("status.json"))
        let book = Book(title: "待發布", author: "作者", volumes: [Sailune.Volume(title: "卷")])
        let coordinator = PublicationCoordinator()
        try coordinator.prepare(book: book, tags: ["冒險"], status: .draft, sectionUnit: .section)
        var firstAttempt: UUID?
        coordinator.send(store: store) { attempt, _, _ in firstAttempt = attempt.id; throw PublicationFailure.connection }
        await coordinator.waitForCompletion()
        XCTAssertEqual(store.status(for: book.id), .draft)
        XCTAssertTrue(store.tags(for: book.id).isEmpty)
        coordinator.send(store: store) { attempt, _, commit in
            XCTAssertEqual(attempt.id, firstAttempt)
            commit()
            return PublicationResult(bookId: book.id.uuidString, createdChapters: 0, updatedChapters: 0, unchangedChapters: 0, hiddenChapters: 0, hiddenVolumes: 0)
        }
        await coordinator.waitForCompletion()
        XCTAssertEqual(coordinator.phase, .success)
        XCTAssertEqual(store.status(for: book.id), .ongoing)
        XCTAssertEqual(store.tags(for: book.id), ["冒險"])
    }

    func testLocalSaveFailureRetriesWithoutAnotherRemotePublication() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ShiyeLocalFailure-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let statusURL = directory.appendingPathComponent("status.json")
        let store = try BookPublicationStore(url: statusURL)
        let book = Book(title: "待發布", author: "作者", volumes: [Sailune.Volume(title: "卷")])
        let coordinator = PublicationCoordinator()
        try coordinator.prepare(book: book, tags: ["奇幻"], status: .draft, sectionUnit: .section)
        try FileManager.default.createDirectory(at: statusURL, withIntermediateDirectories: true)
        var calls = 0
        let operation: @MainActor (PublicationAttempt, @escaping @MainActor @Sendable (Double) -> Void, @escaping @MainActor () -> Void) async throws -> PublicationResult = { _, _, commit in
            calls += 1; commit()
            return PublicationResult(bookId: book.id.uuidString, createdChapters: 0, updatedChapters: 0, unchangedChapters: 0, hiddenChapters: 0, hiddenVolumes: 0)
        }
        coordinator.send(store: store, operation: operation)
        await coordinator.waitForCompletion()
        XCTAssertEqual(coordinator.phase, .failure)
        XCTAssertEqual(store.status(for: book.id), .draft)
        XCTAssertNotNil(coordinator.result)
        try FileManager.default.removeItem(at: statusURL)
        coordinator.send(store: store, operation: operation)
        await coordinator.waitForCompletion()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(store.status(for: book.id), .ongoing)
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

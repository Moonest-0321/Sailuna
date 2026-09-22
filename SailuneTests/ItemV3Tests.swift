import XCTest
import SwiftData
import AppKit
import SQLite3
import UniformTypeIdentifiers
@testable import Sailune

private final class UndoGroupingProbe: NSObject, NSTextViewDelegate {
    var auxiliaryValue = 1

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView,
              let undoManager = textView.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { probe in
            probe.auxiliaryValue = 1
        }
        auxiliaryValue = 0
    }
}

@MainActor
final class ItemV3Tests: XCTestCase {
    func testSwiftUIExportRequestsPreserveTXTAndEPUBPayloadsAndNames() throws {
        let textRequest = ExportManager.textExportRequest(
            defaultName: "測試/書名",
            content: "匯出內容"
        )
        XCTAssertEqual(textRequest.defaultFilename, "測試_書名.txt")
        XCTAssertEqual(textRequest.contentType, .plainText)
        XCTAssertEqual(String(data: textRequest.document.data, encoding: .utf8), "匯出內容")

        let book = Book(title: "EPUB 測試", author: "作者")
        let epubRequest = EpubExporter.exportRequest(book: book)
        XCTAssertEqual(epubRequest.defaultFilename, "EPUB 測試.epub")
        XCTAssertEqual(epubRequest.contentType, .epub)
        XCTAssertEqual(Array(epubRequest.document.data.prefix(2)), [0x50, 0x4B])
    }

    func testDebugAndReleaseAllowWritingUserSelectedExportFiles() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectFileURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sailune.xcodeproj/project.pbxproj")
        let project = try String(contentsOf: projectFileURL, encoding: .utf8)
        let targetConfigurations = project.components(separatedBy: "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
        XCTAssertGreaterThanOrEqual(targetConfigurations.count, 3)
        for configuration in targetConfigurations.dropFirst().prefix(2) {
            XCTAssertTrue(
                configuration.contains("ENABLE_USER_SELECTED_FILES = readwrite;"),
                "Debug and Release app targets must include user-selected file read/write entitlement."
            )
        }
    }

    func testEpubUsesDisplayedDefaultCoverAndLatestCustomCover() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneEpubCoverTest-\(UUID().uuidString)", isDirectory: true)
        let book = Book(title: "封面 EPUB 測試", author: "作者")
        defer {
            BookCoverStore.setDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: directory)
        }
        BookCoverStore.setDirectoryOverrideForTesting(directory)

        let defaultCover = try XCTUnwrap(BookCoverStore.displayedCoverPNGData(for: book))
        let fallbackEpub = EpubExporter.exportRequest(book: book).document.data
        XCTAssertTrue(fallbackEpub.containsUTF8("properties=\"cover-image\""))
        XCTAssertTrue(fallbackEpub.containsUTF8("OEBPS/cover.png"))
        XCTAssertTrue(fallbackEpub.containsUTF8("<img src=\"cover.png\" alt=\"封面 EPUB 測試\"/>"))
        XCTAssertNotNil(fallbackEpub.range(of: defaultCover))

        let red = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
        let blue = NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1)
        try BookCoverStore.save(image: testCoverImage(color: red), for: book)
        let firstPNG = try XCTUnwrap(BookCoverStore.pngData(for: book))
        let firstEpub = EpubExporter.exportRequest(book: book).document.data
        XCTAssertTrue(firstEpub.containsUTF8("href=\"cover.png\" media-type=\"image/png\" properties=\"cover-image\""))
        XCTAssertTrue(firstEpub.containsUTF8("<img src=\"cover.png\" alt=\"封面 EPUB 測試\"/>"))
        XCTAssertNotNil(firstEpub.range(of: firstPNG))

        try BookCoverStore.save(image: testCoverImage(color: blue), for: book)
        let replacementPNG = try XCTUnwrap(BookCoverStore.pngData(for: book))
        let replacementEpub = EpubExporter.exportRequest(book: book).document.data
        XCTAssertNotEqual(firstPNG, replacementPNG)
        XCTAssertNil(replacementEpub.range(of: firstPNG))
        XCTAssertNotNil(replacementEpub.range(of: replacementPNG))

        try BookCoverStore.removeCover(for: book)
        let removedCoverEpub = EpubExporter.exportRequest(book: book).document.data
        XCTAssertTrue(removedCoverEpub.containsUTF8("properties=\"cover-image\""))
        XCTAssertTrue(removedCoverEpub.containsUTF8("OEBPS/cover.png"))
        XCTAssertNotNil(removedCoverEpub.range(of: defaultCover))
    }

    func testBookCoverStoreReplacesCachedCoverAndRemovesItInAnIsolatedDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneCoverTest-\(UUID().uuidString)", isDirectory: true)
        let book = Book(title: "封面測試", author: "作者")
        var changedBookIDs: [UUID] = []
        let observer = NotificationCenter.default.addObserver(
            forName: BookCoverStore.didChange,
            object: nil,
            queue: nil
        ) { notification in
            if let changedID = notification.object as? NSUUID,
               let uuid = UUID(uuidString: changedID.uuidString) {
                changedBookIDs.append(uuid)
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
            BookCoverStore.setDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: directory)
        }
        BookCoverStore.setDirectoryOverrideForTesting(directory)

        let firstCover = testCoverImage(color: .systemRed)
        let replacementCover = testCoverImage(color: .systemBlue)
        try BookCoverStore.save(image: firstCover, for: book)
        let displayedFirstCover = try XCTUnwrap(BookCoverStore.image(for: book))

        try BookCoverStore.save(image: replacementCover, for: book)
        let displayedReplacementCover = try XCTUnwrap(BookCoverStore.image(for: book))

        XCTAssertTrue(BookCoverStore.hasCover(for: book))
        XCTAssertTrue(displayedFirstCover === firstCover)
        XCTAssertTrue(displayedReplacementCover === replacementCover)
        XCTAssertFalse(displayedReplacementCover === firstCover)

        try BookCoverStore.removeCover(for: book)

        XCTAssertFalse(BookCoverStore.hasCover(for: book))
        XCTAssertNil(BookCoverStore.image(for: book))
        XCTAssertEqual(changedBookIDs, [book.id, book.id, book.id])
    }

    func testBookStatusDefaultsToDraftAndSupportsAllStatusesWithoutChangingV5Schema() {
        let book = Book(title: "測試書", author: "作者")

        XCTAssertEqual(book.status, .draft)

        book.status = .ongoing
        XCTAssertEqual(book.status, .ongoing)
        book.status = .completed
        XCTAssertEqual(book.status, .completed)
    }

    private func testCoverImage(color: NSColor) -> NSImage {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmap.setColor(color, atX: 0, y: 0)
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.addRepresentation(bitmap)
        return image
    }


    func testTextViewDelegateUndoRegistrationJoinsTheSameEditingStep() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let textView = NSTextView(frame: window.contentView?.bounds ?? .zero)
        let probe = UndoGroupingProbe()
        textView.delegate = probe
        textView.allowsUndo = true
        window.contentView = textView
        textView.string = "原文"
        textView.undoManager?.removeAllActions()
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        textView.insertText("刪", replacementRange: textView.selectedRange())
        XCTAssertEqual(textView.string, "原文刪")
        XCTAssertEqual(probe.auxiliaryValue, 0)

        textView.undoManager?.undo()

        XCTAssertEqual(textView.string, "原文")
        XCTAssertEqual(probe.auxiliaryValue, 1)
    }

    func testAppDeclaresTraditionalChineseAsDevelopmentLanguage() {
        XCTAssertEqual(Bundle.main.developmentLocalization, "zh-Hant")
    }

    func testEditorContextMenuKeepsApprovedToolOrderAndTagKinds() {
        let textView = contextTextView(text: "反白文字", selectedLength: 4)

        let menu = textView.menu(for: contextMenuEvent())
        XCTAssertEqual(
            Array(menu?.items.dropFirst(2).prefix(6).map(\.title) ?? []),
            ["敘事大綱", "修改", "草稿", "角色", "物品", "能力"]
        )
        XCTAssertEqual(menu?.items[2].representedObject as? String, StoryTagKind.main.rawValue)
        XCTAssertEqual(menu?.items[3].representedObject as? String, StoryTagKind.revision.rawValue)
        XCTAssertEqual(menu?.items[4].representedObject as? String, StoryTagKind.plannedAddition.rawValue)
        XCTAssertTrue(menu?.items[2].isEnabled == true)
        XCTAssertTrue(menu?.items[3].isEnabled == true)
        XCTAssertTrue(menu?.items[4].isEnabled == true)

        let writingToolsItem = menu?.items.first(where: { $0.title == "寫作工具" })
        let writingToolsTitles = writingToolsItem?.submenu?.items.map(\.title) ?? []
        // Availability and submenu population are controlled by macOS.
        if !writingToolsTitles.isEmpty {
            XCTAssertTrue(writingToolsTitles.contains("校對"))
            XCTAssertTrue(writingToolsTitles.contains("改寫"))
            XCTAssertTrue(writingToolsTitles.contains("摘要"))
            XCTAssertTrue(writingToolsTitles.contains("撰寫…"))
        }
    }

    func testEditorContextMenuDisablesTextTagsWithoutSelection() {
        let textView = contextTextView(text: "沒有反白", selectedLength: 0)

        let menu = textView.menu(for: contextMenuEvent())
        XCTAssertFalse(menu?.items[2].isEnabled == true)
        XCTAssertFalse(menu?.items[3].isEnabled == true)
        XCTAssertFalse(menu?.items[4].isEnabled == true)
    }

    private func contextMenuEvent() -> NSEvent {
        NSEvent.mouseEvent(
            with: .rightMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )!
    }

    private func contextTextView(text: String, selectedLength: Int) -> SailuneTextView {
        let storage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        let textView = SailuneTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), textContainer: container)
        textView.setSelectedRange(NSRange(location: 0, length: selectedLength))
        return textView
    }

    func testEditorBridgeKeepsCrossSectionSelectionUntilTargetSectionConsumesIt() {
        let bridge = EditorBridge()
        let sourceSectionID = UUID()
        let targetSectionID = UUID()
        let targetRange = NSRange(location: 27, length: 0)

        bridge.requestSelect(sectionID: targetSectionID, range: targetRange)

        XCTAssertNil(bridge.takePendingSelection(for: sourceSectionID))
        XCTAssertEqual(bridge.takePendingSelection(for: targetSectionID), targetRange)
        XCTAssertNil(bridge.takePendingSelection(for: targetSectionID))
    }

    func testEditorBridgeDefersSelectionWhileTargetSectionContentIsLoading() {
        let bridge = EditorBridge()
        let coordinator = RichEditorView.Coordinator()
        let sectionID = UUID()
        let targetRange = NSRange(location: 41, length: 0)
        coordinator.lastSectionID = sectionID
        coordinator.contentLoadSectionID = sectionID
        bridge.coordinator = coordinator

        bridge.requestSelect(sectionID: sectionID, range: targetRange)

        XCTAssertEqual(bridge.takePendingSelection(for: sectionID), targetRange)
    }

    func testCalendarDatesAndEditedEventsSurviveReopeningStore() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Sailune-calendar-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: url.path + suffix)
            }
        }
        func openStore() throws -> ModelContainer {
            let schema = Schema(versionedSchema: NovelWriterSchemaV5.self)
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        }
        func writeStore() throws {
            let container = try openStore()
            let context = container.mainContext
            let book = Book(title: "重開測試", author: "作者")
            context.insert(book)
            try TimelineEngine.Bootstrap.ensure(for: book, in: context)
            let axis = try TimelineEngine.addSecondaryTimeline(for: book, name: "前史", in: context)
            let node = Node(year: -3, month: 2)
            context.insert(node)
            node.timeline = axis
            node.era = book.currentEra
            let event = Event(title: "原標題", detail: "原內容")
            context.insert(event)
            event.node = node
            try context.save()
            event.title = "更新標題"
            event.detail = "更新內容"
            event.isVisible = false
            try context.save()
        }
        try writeStore()
        let reopened = try openStore()
        let book = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Book>()).first)
        XCTAssertEqual(book.timelines.count, 2)
        let node = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Node>()).first)
        XCTAssertEqual(node.year, -3)
        XCTAssertEqual(node.month, 2)
        XCTAssertNil(node.day)
        XCTAssertEqual(node.timeline?.name, "前史")
        XCTAssertEqual(node.era?.id, book.currentEra?.id)
        let event = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<Event>()).first)
        XCTAssertEqual(event.node?.id, node.id)
        XCTAssertEqual(event.title, "更新標題")
        XCTAssertEqual(event.detail, "更新內容")
        XCTAssertFalse(event.isVisible)
    }

    func testCalendarProjectionGroupsDatesAndKeepsErasSeparate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let era = Era(name: "第一紀元")
        let otherEra = Era(name: "另一紀元")
        context.insert(era)
        context.insert(otherEra)
        let nodes = [Node(year: 1), Node(year: 1, month: 2), Node(year: 1, month: 2, day: 3), Node(year: 1, month: 2, day: 4), Node(year: 0), Node(year: 1)]
        for node in nodes { context.insert(node); node.era = era }
        nodes[5].era = otherEra
        let event = Event(title: "事件", detail: "")
        context.insert(event)
        event.node = nodes[2]
        try context.save()
        let yearCells = TimelineDateProjection.cells(nodes: nodes, events: [event], primary: true, granularity: .year)
        XCTAssertEqual(yearCells.count, 2)
        XCTAssertEqual(Set(yearCells.compactMap(\.eraID)), Set([era.id, otherEra.id]))
        XCTAssertFalse(yearCells.flatMap(\.nodes).contains { $0.year == 0 })
        XCTAssertEqual(TimelineDateProjection.cells(nodes: Array(nodes.prefix(4)), events: [event], primary: true, granularity: .month).count, 2)
        XCTAssertEqual(TimelineDateProjection.cells(nodes: Array(nodes.prefix(4)), events: [event], primary: true, granularity: .day).count, 4)
        event.isVisible = false
        XCTAssertTrue(TimelineDateProjection.cells(nodes: nodes, events: [event], primary: true, granularity: .day).flatMap(\.events).isEmpty)
        XCTAssertEqual(TimelineDateProjection.cells(nodes: nodes, events: [event], primary: false, granularity: .day).flatMap(\.events).count, 1)
        nodes[2].isVisible = false
        XCTAssertFalse(TimelineDateProjection.cells(nodes: nodes, events: [event], primary: true, granularity: .day).flatMap(\.nodes).contains { $0.id == nodes[2].id })
    }

    func testTimelineEraGroupsKeepChronologyAndEventOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstEra = Era(name: "第一紀元")
        let secondEra = Era(name: "第二紀元")
        context.insert(firstEra)
        context.insert(secondEra)
        let firstNode = Node(year: 1, month: 1)
        let secondNode = Node(year: 2, month: 1)
        let noEraNode = Node(year: 3, month: 1)
        context.insert(firstNode)
        context.insert(secondNode)
        context.insert(noEraNode)
        firstNode.era = firstEra
        secondNode.era = secondEra
        let later = Event(title: "稍後")
        let earlier = Event(title: "較早")
        context.insert(later)
        context.insert(earlier)
        later.node = firstNode
        earlier.node = firstNode
        later.sortOrder = 2
        earlier.sortOrder = 1
        try context.save()

        let cells = TimelineDateProjection.cells(
            nodes: [noEraNode, secondNode, firstNode],
            events: [later, earlier],
            primary: false,
            granularity: .month
        )
        let groups = TimelineDateProjection.eraGroups(cells: cells)

        XCTAssertEqual(groups.map(\.name), ["第一紀元", "第二紀元", "未指定紀元"])
        XCTAssertEqual(groups.flatMap(\.cells).map(\.ordinal), groups.flatMap(\.cells).map(\.ordinal).sorted())
        XCTAssertEqual(groups.first?.cells.first?.events.map(\.id), [earlier.id, later.id])
        XCTAssertEqual(TimelineDateProjection.eventsInDisplayOrder(cells: cells).map(\.id), [earlier.id, later.id])
    }

    func testTimelineBootstrapAndEraChangeKeepExistingDates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "曆法測試", author: "作者")
        context.insert(book)
        try TimelineEngine.Bootstrap.ensure(for: book, in: context)
        let primary = try XCTUnwrap(TimelineEngine.Query.primaryTimeline(for: book))
        let era = try XCTUnwrap(book.currentEra)
        try TimelineEngine.Bootstrap.ensure(for: book, in: context)
        XCTAssertEqual(book.timelines.count, 1)
        XCTAssertEqual(book.currentEra?.id, era.id)
        let node = Node(year: 12, month: nil, day: nil)
        context.insert(node)
        node.timeline = primary
        node.era = era
        try context.save()
        let result = try TimelineEngine.EraChange.perform(for: book, input: .init(newName: "新紀元", newColor: "#2980B9"), in: context)
        XCTAssertEqual(result.era.startOrdinal, era.startOrdinal + 12)
        XCTAssertEqual(node.year, 12)
        XCTAssertNil(node.month)
        XCTAssertEqual(node.era?.id, era.id)
        XCTAssertEqual(result.node.year, 1)
        XCTAssertEqual(result.node.timeline?.id, primary.id)
    }

    func testTimelineOrderingKeepsEarlierEraBeforeLaterEraDateMagnitude() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "紀元排序", author: "作者")
        let timeline = Timeline(name: "主軸", isPrimary: true)
        let earlierEra = Era(name: "前紀元", startOrdinal: 1)
        let laterEra = Era(name: "後紀元", startOrdinal: 6)
        let earlierNode = Node(year: 12)
        let laterNode = Node(year: 1, month: 1, day: 1)
        context.insert(book)
        context.insert(timeline)
        context.insert(earlierEra)
        context.insert(laterEra)
        context.insert(earlierNode)
        context.insert(laterNode)
        timeline.book = book
        earlierNode.timeline = timeline
        earlierNode.era = earlierEra
        laterNode.timeline = timeline
        laterNode.era = laterEra
        try context.save()

        XCTAssertEqual(TimelineEngine.Query.sorted([laterNode, earlierNode]).map(\.id), [earlierNode.id, laterNode.id])
        let cells = TimelineDateProjection.cells(
            nodes: [laterNode, earlierNode], events: [], primary: false, granularity: .day
        )
        XCTAssertEqual(cells.map(\.eraID), [earlierEra.id, laterEra.id])
    }

    func testEraChangeAppendsAfterLastEraWhenCurrentEraIsEarlier() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "末端改元", author: "作者")
        context.insert(book)
        try TimelineEngine.Bootstrap.ensure(for: book, in: context)
        let primary = try XCTUnwrap(TimelineEngine.Query.primaryTimeline(for: book))
        let firstEra = try XCTUnwrap(book.currentEra)
        firstEra.name = "初元"
        let lastEra = Era(name: "後元", color: "#888888", startOrdinal: 10)
        let lastNode = Node(year: 7)
        context.insert(lastEra)
        context.insert(lastNode)
        lastNode.era = lastEra
        lastNode.timeline = primary
        book.currentEra = firstEra
        try context.save()

        let result = try TimelineEngine.EraChange.perform(
            for: book,
            input: .init(newName: "新元", newColor: "#2980B9"),
            in: context
        )

        XCTAssertEqual(result.era.startOrdinal, 17)
        XCTAssertEqual(book.currentEra?.id, result.era.id)
        XCTAssertEqual(lastNode.era?.id, lastEra.id)
        XCTAssertEqual(lastNode.year, 7)
    }

    func testEraChangeTreatsCurrentEraWithoutNodesAsYearOne() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "空年號改元", author: "作者")
        let era = Era(name: "空元", color: "#888888", startOrdinal: 20)
        context.insert(book)
        context.insert(era)
        book.currentEra = era
        try TimelineEngine.Bootstrap.ensure(for: book, in: context)

        let result = try TimelineEngine.EraChange.perform(
            for: book,
            input: .init(newName: "次元", newColor: "#2980B9"),
            in: context
        )

        XCTAssertEqual(result.era.startOrdinal, 21)
        XCTAssertEqual(result.node.year, 1)
        XCTAssertEqual(book.currentEra?.id, result.era.id)
    }

    func testTimelineDeletionPreservesOtherAxisAndProse() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "刪除測試", author: "作者")
        context.insert(book)
        try TimelineEngine.Bootstrap.ensure(for: book, in: context)
        let primary = try XCTUnwrap(TimelineEngine.Query.primaryTimeline(for: book))
        let secondary = try TimelineEngine.addSecondaryTimeline(for: book, name: "前史", in: context)
        let section = Section(title: "正文", content: AttributedString("保留文字"))
        context.insert(section)
        let first = Node(year: 1)
        let second = Node(year: 2, month: 3, day: 4)
        context.insert(first)
        context.insert(second)
        first.timeline = primary
        second.timeline = secondary
        second.section = section
        let event = Event(title: "副軸事件", detail: "內容")
        context.insert(event)
        event.node = second
        try context.save()
        let firstID = first.id
        let sectionID = section.id
        try PersistentModelDeletion.deleteTimeline(secondary, in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Node>()).map(\.id), [firstID])
        XCTAssertTrue(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Section>()).first?.id, sectionID)
        XCTAssertEqual(String(section.content.characters), "保留文字")
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(
            NovelWriterSchemaV5.models + [
                ItemCopy.self, ItemCopyHolding.self, ItemCopyHistory.self,
                ItemCopyLevelSelection.self
            ]
        )
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makePlanningContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: StoryPlanningSchemaV7.self)
        return try ModelContainer(
            for: schema,
            migrationPlan: StoryPlanningMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    private func writeSQLiteValue(_ value: Int, at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw NSError(domain: "SQLiteTest", code: 1)
        }
        defer { sqlite3_close(database) }
        let sql = "CREATE TABLE IF NOT EXISTS marker(value INTEGER); DELETE FROM marker; INSERT INTO marker(value) VALUES (\(value));"
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLiteTest", code: 2)
        }
    }

    private func readSQLiteValue(at url: URL) throws -> Int {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw NSError(domain: "SQLiteTest", code: 3)
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT value FROM marker LIMIT 1", -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW else {
            sqlite3_finalize(statement)
            throw NSError(domain: "SQLiteTest", code: 4)
        }
        defer { sqlite3_finalize(statement) }
        return Int(sqlite3_column_int(statement, 0))
    }

    private func createV5Store(at url: URL) throws {
        let schema = Schema(versionedSchema: NovelWriterSchemaV5.self)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = container.mainContext
        let book = Book(title: "遷移測試", author: "作者")
        let character = Character(realName: "持有人", book: book)
        let item = Item(name: "制式藥水", book: book)
        context.insert(book)
        context.insert(character)
        context.insert(item)
        context.insert(CharacterItem(quantity: 2, character: character, item: item))
        try context.save()
    }

    func testExistingV5StoreOpensUnchangedBesideCopyStore() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        let identifier = UUID().uuidString
        let mainURL = directory.appendingPathComponent("Sailune-v5-main-\(identifier).store")
        let copyURL = directory.appendingPathComponent("Sailune-v5-copies-\(identifier).store")
        defer {
            for url in [mainURL, copyURL] {
                for suffix in ["", "-shm", "-wal"] {
                    try? FileManager.default.removeItem(atPath: url.path + suffix)
                }
            }
        }

        try createV5Store(at: mainURL)

        let mainSchema = Schema(versionedSchema: NovelWriterSchemaV5.self)
        let copySchema = Schema(versionedSchema: ItemCopySchemaV1.self)
        let mainContainer: ModelContainer
        let copyContainer: ModelContainer
        do {
            mainContainer = try ModelContainer(
                for: mainSchema,
                configurations: [ModelConfiguration(schema: mainSchema, url: mainURL)]
            )
            copyContainer = try ModelContainer(
                for: copySchema,
                configurations: [ModelConfiguration(schema: copySchema, url: copyURL)]
            )
        } catch {
            let nsError = error as NSError
            XCTFail("V5 主庫與副本庫共同載入失敗：\(nsError.domain) \(nsError.code) \(nsError.userInfo)")
            return
        }
        try V6ItemCopyBackfill.run(
            source: mainContainer.mainContext,
            destination: copyContainer.mainContext
        )

        XCTAssertEqual(try mainContainer.mainContext.fetchCount(FetchDescriptor<Item>()), 1)
        XCTAssertEqual(try mainContainer.mainContext.fetchCount(FetchDescriptor<CharacterItem>()), 1)
        XCTAssertEqual(try copyContainer.mainContext.fetchCount(FetchDescriptor<ItemCopy>()), 2)
        XCTAssertEqual(try copyContainer.mainContext.fetchCount(FetchDescriptor<ItemCopyHolding>()), 2)
    }

    func testStoryTagKeepsItsAnchorWhenTextIsInsertedBeforeIt() throws {
        let tag = StoryTag(
            title: "小黑回到了家中",
            kind: .main,
            anchorText: "小黑回到了家中",
            anchorOffset: 3,
            bookID: UUID(),
            sectionID: UUID()
        )
        let rewritten = "前言。新的段落。小黑回到了家中，雨還沒有停。"
        XCTAssertEqual(tag.resolvedOffset(in: rewritten), (rewritten as NSString).range(of: "小黑回到了家中").location)
    }

    func testStoryTagKindsOnlyExposeForeshadowingAndRevision() {
        XCTAssertTrue(StoryTagKind.allCases.contains(.revision))
        XCTAssertTrue(StoryTagKind.allCases.contains(.foreshadowing))
        XCTAssertFalse(StoryTagKind.allCases.contains(.plannedAddition))
        XCTAssertEqual(StoryTagKind.revision.rawValue, "修改")
        XCTAssertEqual(StoryTagKind.plannedAddition.rawValue, "計劃加入")
    }

    func testStoryTagMarkerRangesFollowTheirKind() {
        let selectedText = "這是一段完整反白的文字"
        let selectionLength = (selectedText as NSString).length
        let common = (anchorText: selectedText, anchorOffset: 0, bookID: UUID(), sectionID: UUID())

        for kind in [StoryTagKind.revision] {
            let tag = StoryTag(title: kind.rawValue, kind: kind, anchorText: common.anchorText, anchorOffset: common.anchorOffset, bookID: common.bookID, sectionID: common.sectionID)
            XCTAssertEqual(tag.markerLength(availableFromOffset: 100), selectionLength)
        }

        for kind in [StoryTagKind.main, .branch, .foreshadowing, .plannedAddition] {
            let tag = StoryTag(title: kind.rawValue, kind: kind, anchorText: common.anchorText, anchorOffset: common.anchorOffset, bookID: common.bookID, sectionID: common.sectionID)
            XCTAssertEqual(tag.markerLength(availableFromOffset: 100), 1)
        }
    }

    func testStoryTagPersistsWithItsSectionAndClassification() throws {
        let container = try makePlanningContainer()
        let context = container.mainContext
        let bookID = UUID()
        let sectionID = UUID()
        let tag = StoryTag(title: "小黑回到了家中", kind: .foreshadowing, anchorText: "小黑", anchorOffset: 0, bookID: bookID, sectionID: sectionID)
        context.insert(tag)
        try context.save()

        let tags = try context.fetch(FetchDescriptor<StoryTag>())
        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags.first?.kind, .foreshadowing)
        XCTAssertEqual(tags.first?.bookID, bookID)
        XCTAssertEqual(tags.first?.sectionID, sectionID)
    }

    func testSectionPersistsPlannedOutlineAndRevisionNote() throws {
        let container = try makePlanningContainer()
        let context = container.mainContext
        let sectionID = UUID()
        let annotation = ChapterAnnotation(sectionID: sectionID, bookID: UUID(), plannedOutline: "角色抵達舊宅", revisionNote: "補上雨夜氣氛")
        context.insert(annotation)
        try context.save()

        let saved = try context.fetch(FetchDescriptor<ChapterAnnotation>()).first
        XCTAssertEqual(saved?.plannedOutline, "角色抵達舊宅")
        XCTAssertEqual(saved?.revisionNote, "補上雨夜氣氛")
    }

    func testAddingCopyKeepsOneSharedItemAndIndependentName() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "測試小說", author: "作者")
        let item = Item(
            name: "霜紋長劍",
            itemDescription: "概要",
            category: "武器",
            appearanceAndMaterial: "深銀色劍身",
            usage: "近身戰鬥",
            book: book
        )
        context.insert(book)
        context.insert(item)
        let first = ItemCopyOperations.create(for: item, existingCopies: [], context: context)
        let second = ItemCopyOperations.create(for: item, existingCopies: [first], context: context, name: "守衛隊長之劍")
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Item>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ItemCopy>()), 2)
        XCTAssertEqual(first.displayName(for: item), "霜紋長劍")
        XCTAssertEqual(second.displayName(for: item), "守衛隊長之劍")
        XCTAssertEqual(second.sortOrder, 1)
    }

    func testCopyKeepsItsParentItemAndManualLevel() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "測試小說", author: "作者")
        let firstItem = Item(name: "短劍", book: book)
        let firstLevel = ItemLevel(itemID: firstItem.id, name: "初始")
        let holder = Character(realName: "艾琳", book: book)
        context.insert(book)
        context.insert(firstItem)
        context.insert(firstLevel)
        context.insert(holder)
        try context.save()

        let store = try ItemCopyStore(container: container)
        let copy = store.createCopy(itemID: firstItem.id, name: "艾琳的劍", holderID: holder.id)
        let history = store.addHistory(copyID: copy.id, content: "在遺跡中取得。")
        store.setCurrentLevel(copyID: copy.id, levelID: firstLevel.id)
        XCTAssertEqual(store.currentLevelID(for: copy.id), firstLevel.id)

        XCTAssertEqual(copy.itemID, firstItem.id)
        XCTAssertEqual(copy.name, "艾琳的劍")
        XCTAssertEqual(store.holdings.first(where: { $0.copyID == copy.id })?.characterID, holder.id)
        XCTAssertEqual(store.histories.first(where: { $0.id == history.id })?.content, "在遺跡中取得。")
        XCTAssertEqual(store.currentLevelID(for: copy.id), firstLevel.id)
        XCTAssertTrue(store.copies.contains { $0.id == copy.id && $0.itemID == firstItem.id })
    }

    func testDeletingLevelClearsCurrentLevelImmediately() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = Item(name: "短劍")
        let level = ItemLevel(itemID: item.id, name: "初始")
        context.insert(item)
        context.insert(level)
        try context.save()

        let store = try ItemCopyStore(container: container)
        let copy = store.createCopy(itemID: item.id)
        store.setCurrentLevel(copyID: copy.id, levelID: level.id)
        store.clearCurrentLevelSelections(levelID: level.id)

        XCTAssertNil(store.currentLevelID(for: copy.id))
    }

    func testDeletingCharacterImmediatelyReleasesTheirCopies() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = Item(name: "短劍")
        let deletedCharacter = Character(realName: "艾琳")
        let remainingCharacter = Character(realName: "洛恩")
        context.insert(item)
        context.insert(deletedCharacter)
        context.insert(remainingCharacter)
        try context.save()

        let store = try ItemCopyStore(container: container)
        let releasedCopy = store.createCopy(itemID: item.id, holderID: deletedCharacter.id)
        let retainedCopy = store.createCopy(itemID: item.id, holderID: remainingCharacter.id)

        store.removeHoldings(characterID: deletedCharacter.id)

        XCTAssertNil(store.holdings.first(where: { $0.copyID == releasedCopy.id }))
        XCTAssertEqual(
            store.holdings.first(where: { $0.copyID == retainedCopy.id })?.characterID,
            remainingCharacter.id
        )
        XCTAssertTrue(store.copies.contains { $0.id == releasedCopy.id })
    }

    func testCopyReconcileRemovesCrossBookAndInvalidReferencesWithoutDeletingValidHistoryText() throws {
        let container = try makeContainer()
        let store = try ItemCopyStore(container: container)
        let bookA = UUID(), bookB = UUID()
        let itemID = UUID(), characterA = UUID(), characterB = UUID()
        let validNode = UUID(), invalidNode = UUID(), validLevel = UUID()
        let copy = store.createCopy(itemID: itemID, holderID: characterB)
        let history = store.addHistory(copyID: copy.id, content: "保留這段歷史")
        history.nodeID = invalidNode
        history.relatedCharacterIDs = [characterA, characterA, characterB]
        store.setCurrentLevel(copyID: copy.id, levelID: UUID())

        try store.reconcile(
            itemBookIDs: [itemID: bookA],
            characterBookIDs: [characterA: bookA, characterB: bookB],
            validNodeIDs: [validNode],
            itemLevelItemIDs: [validLevel: itemID]
        )

        XCTAssertTrue(store.copies.contains { $0.id == copy.id })
        XCTAssertNil(store.holdings.first { $0.copyID == copy.id })
        let retained = try XCTUnwrap(store.histories.first { $0.id == history.id })
        XCTAssertEqual(retained.content, "保留這段歷史")
        XCTAssertNil(retained.nodeID)
        XCTAssertEqual(retained.relatedCharacterIDs, [characterA])
        XCTAssertNil(store.currentLevelID(for: copy.id))
    }

    func testFullBackupRestoresAllSixSQLiteSnapshotsCoversAndMaps() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SailuneBackupTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let locations = SailuneDataLocations(mainStore: root.appendingPathComponent("Sailune-v5.store"))
        for (index, store) in locations.stores.enumerated() { try writeSQLiteValue(index + 10, at: store.url) }
        try FileManager.default.createDirectory(at: locations.coversDirectory, withIntermediateDirectories: true)
        let coverData = Data([1, 2, 3, 4])
        try coverData.write(to: locations.coversDirectory.appendingPathComponent("cover.png"))
        try FileManager.default.createDirectory(at: locations.mapsDirectory, withIntermediateDirectories: true)
        let mapData = Data([5, 6, 7, 8])
        try mapData.write(to: locations.mapsDirectory.appendingPathComponent("map.pdf"))
        let backup = root.appendingPathComponent("test.sailunebackup")

        try SailuneBackupService.createBackup(at: backup, locations: locations)
        for store in locations.stores { try writeSQLiteValue(999, at: store.url) }
        try Data([9]).write(to: locations.coversDirectory.appendingPathComponent("cover.png"))
        try Data([9]).write(to: locations.mapsDirectory.appendingPathComponent("map.pdf"))
        try SailuneBackupService.scheduleRestore(from: backup, locations: locations)
        try SailuneBackupService.applyPendingRestoreIfNeeded(locations: locations)

        for (index, store) in locations.stores.enumerated() {
            XCTAssertEqual(try readSQLiteValue(at: store.url), index + 10)
        }
        XCTAssertEqual(try Data(contentsOf: locations.coversDirectory.appendingPathComponent("cover.png")), coverData)
        XCTAssertEqual(try Data(contentsOf: locations.mapsDirectory.appendingPathComponent("map.pdf")), mapData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: locations.pendingRestoreURL.path))
        XCTAssertFalse((try FileManager.default.contentsOfDirectory(atPath: locations.recoveryDirectory.path)).isEmpty)
    }

    func testRestoringBackupWithoutMapsClearsCurrentMapAssets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneBackupNoMapsTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let locations = SailuneDataLocations(mainStore: root.appendingPathComponent("Sailune-v5.store"))
        for (index, store) in locations.stores.enumerated() {
            try writeSQLiteValue(index + 20, at: store.url)
        }
        let backup = root.appendingPathComponent("without-maps.sailunebackup")
        try SailuneBackupService.createBackup(at: backup, locations: locations)

        try FileManager.default.createDirectory(at: locations.mapsDirectory, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: locations.mapsDirectory.appendingPathComponent("current.pdf"))
        try SailuneBackupService.scheduleRestore(from: backup, locations: locations)
        try SailuneBackupService.applyPendingRestoreIfNeeded(locations: locations)

        XCTAssertFalse(FileManager.default.fileExists(atPath: locations.mapsDirectory.path))
    }

    func testV10SettingsBackupManifestRemainsRestorableAfterV11Upgrade() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneBackupV10ManifestTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let locations = SailuneDataLocations(mainStore: root.appendingPathComponent("Sailune-v5.store"))
        for (index, store) in locations.stores.enumerated() {
            try writeSQLiteValue(index + 30, at: store.url)
        }
        let backup = root.appendingPathComponent("v10-manifest.sailunebackup")
        try SailuneBackupService.createBackup(at: backup, locations: locations)

        var archive = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: backup)) as? [String: Any]
        )
        var manifest = try XCTUnwrap(archive["manifest"] as? [String: Any])
        var schemas = try XCTUnwrap(manifest["schemas"] as? [String: String])
        schemas["settings.store"] = "V5SettingsSchemaV10"
        manifest["schemas"] = schemas
        archive["manifest"] = manifest
        try JSONSerialization.data(withJSONObject: archive, options: [.sortedKeys])
            .write(to: backup, options: .atomic)

        XCTAssertNoThrow(try SailuneBackupService.scheduleRestore(from: backup, locations: locations))
        XCTAssertTrue(FileManager.default.fileExists(atPath: locations.pendingRestoreURL.path))
    }

    func testDeletingBookImmediatelyRemovesItsCopies() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "測試小說", author: "作者")
        let item = Item(name: "短劍", book: book)
        context.insert(book)
        context.insert(item)
        try context.save()

        let store = try ItemCopyStore(container: container)
        let copy = store.createCopy(itemID: item.id)

        try PersistentModelDeletion.deleteBook(book, in: context, copyStore: store)

        XCTAssertFalse(store.copies.contains { $0.id == copy.id })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ItemCopy>()), 0)
    }

    func testCrossStoreCoordinatorDeletesEventAndTimelineMetadata() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let planningStore = try StoryPlanningStore(container: makePlanningContainer())
        let book = Book(title: "時間書", author: "作者")
        context.insert(book)
        try TimelineEngine.Bootstrap.ensure(for: book, in: context)
        let timeline = try XCTUnwrap(TimelineEngine.Query.primaryTimeline(for: book))
        let node = Node(year: 1)
        node.timeline = timeline
        context.insert(node)
        let event = Event(title: "待刪事件", detail: "")
        event.node = node
        context.insert(event)
        try context.save()
        let eventID = event.id
        try planningStore.ensureTimelineMetadata(eventID: eventID, bookID: book.id)

        try CrossStoreDeletionCoordinator.deleteEvent(
            event,
            in: context,
            planningStore: planningStore
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        XCTAssertNil(planningStore.timelineMetadata(eventID: eventID))
    }

    func testCrossStoreCoordinatorDeletesEraAndAllLinkedNodesAcrossBookTimelines() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let planningStore = try StoryPlanningStore(container: makePlanningContainer())
        let abilitySchema = Schema(versionedSchema: AbilityProgressSchemaV1.self)
        let abilityContainer = try ModelContainer(
            for: abilitySchema,
            configurations: [ModelConfiguration(schema: abilitySchema, isStoredInMemoryOnly: true)]
        )
        let abilityStore = try AbilityProgressStore(container: abilityContainer)
        let copySchema = Schema(versionedSchema: ItemCopySchemaV1.self)
        let copyContainer = try ModelContainer(
            for: copySchema,
            configurations: [ModelConfiguration(schema: copySchema, isStoredInMemoryOnly: true)]
        )
        let copyStore = try ItemCopyStore(container: copyContainer)

        let firstBook = Book(title: "紀元刪除一", author: "作者")
        let secondBook = Book(title: "紀元刪除二", author: "作者")
        let character = Character(realName: "時間角色", book: firstBook)
        let ability = CharacterAbility(name: "時間能力", character: character)
        let item = Item(name: "時間物品", book: firstBook)
        let era = Era(name: "待刪紀元")
        let otherEra = Era(name: "另一書紀元", startOrdinal: 20)
        let firstTimeline = Timeline(name: "第一書主軸", isPrimary: true)
        let secondTimeline = Timeline(name: "第二書副軸")
        let otherTimeline = Timeline(name: "第二書主軸", isPrimary: true)
        context.insert(firstBook)
        context.insert(secondBook)
        context.insert(character)
        context.insert(ability)
        context.insert(item)
        context.insert(era)
        context.insert(otherEra)
        context.insert(firstTimeline)
        context.insert(secondTimeline)
        context.insert(otherTimeline)
        firstBook.currentEra = era
        secondBook.currentEra = otherEra
        firstTimeline.book = firstBook
        secondTimeline.book = firstBook
        otherTimeline.book = secondBook

        let firstNode = Node(year: 1)
        let secondNode = Node(year: 2, month: 3)
        let retainedNode = Node(year: 1, month: 1, day: 1)
        context.insert(firstNode)
        context.insert(secondNode)
        context.insert(retainedNode)
        firstNode.era = era
        firstNode.timeline = firstTimeline
        secondNode.era = era
        secondNode.timeline = secondTimeline
        retainedNode.era = otherEra
        retainedNode.timeline = otherTimeline

        let firstEvent = Event(title: "第一書待刪事件", detail: "事件內容")
        let secondEvent = Event(title: "第一書副軸待刪事件", detail: "事件內容")
        let retainedEvent = Event(title: "保留事件", detail: "保留內容")
        context.insert(firstEvent)
        context.insert(secondEvent)
        context.insert(retainedEvent)
        firstEvent.node = firstNode
        secondEvent.node = secondNode
        retainedEvent.node = retainedNode

        let appearance = CharacterAppearance(
            kind: .outfit,
            descriptionText: "歷史外觀仍保留",
            node: firstNode
        )
        context.insert(appearance)
        try context.save()

        try abilityStore.register(abilityID: ability.id, bookID: firstBook.id)
        abilityStore.connect(characterID: character.id, abilityID: ability.id)
        let abilityConnection = try XCTUnwrap(
            abilityStore.connections.first { $0.characterID == character.id && $0.abilityID == ability.id }
        )
        abilityStore.addHistory(connectionID: abilityConnection.id)
        let abilityHistory = try XCTUnwrap(abilityStore.histories.first { $0.connectionID == abilityConnection.id })
        abilityHistory.content = "能力歷史仍保留"
        abilityHistory.nodeID = firstNode.id
        abilityStore.save()
        XCTAssertNil(abilityStore.persistenceErrorMessage)

        let copy = copyStore.createCopy(itemID: item.id, name: "有時間定位的副本")
        let copyHistory = copyStore.addHistory(copyID: copy.id, content: "物品歷史仍保留")
        copyHistory.nodeID = firstNode.id
        copyStore.save()
        XCTAssertNil(copyStore.persistenceErrorMessage)

        try planningStore.ensureTimelineMetadata(eventID: firstEvent.id, bookID: firstBook.id)
        try planningStore.ensureTimelineMetadata(eventID: secondEvent.id, bookID: firstBook.id)
        try planningStore.ensureTimelineMetadata(eventID: retainedEvent.id, bookID: secondBook.id)

        let outcome = try CrossStoreDeletionCoordinator.deleteEra(
            era,
            for: firstBook,
            in: context,
            planningStore: planningStore,
            copyStore: copyStore,
            abilityStore: abilityStore
        )

        XCTAssertFalse(outcome.requiresRepair)
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<Era>()).map(\.id)), Set([otherEra.id]))
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<Node>()).map(\.id)), Set([retainedNode.id]))
        XCTAssertEqual(Set(try context.fetch(FetchDescriptor<Event>()).map(\.id)), Set([retainedEvent.id]))
        XCTAssertNil(firstBook.currentEra)
        XCTAssertEqual(secondBook.currentEra?.id, otherEra.id)
        XCTAssertEqual(otherTimeline.nodes.map(\.id), [retainedNode.id])
        XCTAssertEqual(try context.fetch(FetchDescriptor<CharacterAppearance>()).first?.descriptionText, "歷史外觀仍保留")
        XCTAssertNil(try context.fetch(FetchDescriptor<CharacterAppearance>()).first?.node)
        XCTAssertEqual(abilityStore.histories.first?.content, "能力歷史仍保留")
        XCTAssertNil(abilityStore.histories.first?.nodeID)
        XCTAssertEqual(copyStore.histories.first?.content, "物品歷史仍保留")
        XCTAssertNil(copyStore.histories.first?.nodeID)
        XCTAssertNil(planningStore.timelineMetadata(eventID: firstEvent.id))
        XCTAssertNil(planningStore.timelineMetadata(eventID: secondEvent.id))
        XCTAssertNotNil(planningStore.timelineMetadata(eventID: retainedEvent.id))
    }

    func testCrossStoreCoordinatorDeletingBookRemovesPlanningData() throws {
        let mapDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-delete-book-map-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: mapDirectory, withIntermediateDirectories: true)
        BookMapPDFStore.setDirectoryOverrideForTesting(mapDirectory)
        defer {
            BookMapPDFStore.setDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: mapDirectory)
        }
        let container = try makeContainer()
        let context = container.mainContext
        let planningStore = try StoryPlanningStore(container: makePlanningContainer())
        let book = Book(title: "整書刪除", author: "作者")
        context.insert(book)
        try context.save()
        _ = try planningStore.ensureProfile(bookID: book.id)
        _ = try planningStore.createStoryLine(bookID: book.id, kind: .main)
        let bookID = book.id
        try BookMapPDFStore.saveImportedPDF(
            MapPDFGenerator.templateData(style: .blank),
            forID: bookID
        )

        try CrossStoreDeletionCoordinator.deleteBook(
            book,
            in: context,
            copyStore: nil,
            planningStore: planningStore
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<Book>()).isEmpty)
        XCTAssertNil(planningStore.profile(bookID: bookID))
        XCTAssertTrue(planningStore.storyLines(bookID: bookID).isEmpty)
        XCTAssertNil(try BookMapPDFStore.pdfData(forID: bookID))
    }

    func testCrossStoreCoordinatorDistinguishesPrimaryFailureFromDeferredCleanup() throws {
        enum SimulatedFailure: Error { case primary, cleanup }
        var cleanupRan = false

        XCTAssertThrowsError(
            try CrossStoreDeletionCoordinator.coordinate(
                primary: { throw SimulatedFailure.primary },
                cleanupDescription: "測試清理",
                cleanup: { cleanupRan = true }
            )
        )
        XCTAssertFalse(cleanupRan)

        let outcome = try CrossStoreDeletionCoordinator.coordinate(
            primary: { },
            cleanupDescription: "測試清理",
            cleanup: { throw SimulatedFailure.cleanup }
        )
        XCTAssertTrue(outcome.requiresRepair)
        XCTAssertEqual(outcome.deferredCleanupErrors.count, 1)
    }

    func testCopiesCanMoveWithoutChangingTheirParentItem() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = Item(name: "短劍")
        context.insert(item)
        try context.save()

        let store = try ItemCopyStore(container: container)
        let first = store.createCopy(itemID: item.id, name: "第一把")
        let second = store.createCopy(itemID: item.id, name: "第二把")
        store.moveCopy(second, by: -1)

        XCTAssertEqual(store.copies.filter { $0.itemID == item.id }.map(\.id), [second.id, first.id])
        XCTAssertEqual(first.itemID, item.id)
        XCTAssertEqual(second.itemID, item.id)
    }

    func testLevelContentDoesNotChangeMainItemName() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = Item(name: "主要名稱")
        let level = ItemLevel(itemID: item.id, name: "完全體", itemName: "階段名稱")
        context.insert(item)
        context.insert(level)
        level.itemName = "新的階段名稱"
        level.ability = "新的能力"
        level.cost = "新的代價"
        try context.save()

        XCTAssertEqual(item.name, "主要名稱")
    }

    func testInvalidHoldingQuantityIsNormalized() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = Item(name: "藥水")
        let character = Character(realName: "角色")
        let holding = CharacterItem(quantity: 0, character: character, item: item)
        context.insert(item)
        context.insert(character)
        context.insert(holding)
        try context.save()

        try V5DataBackfill.removeOrphanedItemLevels(in: context)

        XCTAssertEqual(holding.quantity, 1)
    }

    func testBackfillRepairsRequiredTextAndRemovesOnlyOrphanLevels() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let item = Item(name: "   ")
        let validLevel = ItemLevel(itemID: item.id, name: "\n")
        let orphanLevel = ItemLevel(itemID: UUID(), name: "孤兒")
        let history = ItemHistory(content: "  ", item: item)
        context.insert(item)
        context.insert(validLevel)
        context.insert(orphanLevel)
        context.insert(history)
        try context.save()

        try V5DataBackfill.removeOrphanedItemLevels(in: context)

        XCTAssertEqual(item.name, "未命名物品")
        XCTAssertEqual(validLevel.name, "未命名等級")
        XCTAssertEqual(history.content, "未填寫描述")
        let levels = try context.fetch(FetchDescriptor<ItemLevel>())
        XCTAssertEqual(Set(levels.map(\.id)), Set([validLevel.id]))
    }

    func testLegacyQuantityBecomesIndependentCopies() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "測試小說", author: "作者")
        let holder = Character(realName: "艾琳", book: book)
        let source = Item(name: "治療藥水", book: book)
        let holding = CharacterItem(quantity: 3, character: holder, item: source)
        let history = ItemHistory(content: "在藥房取得。", item: source, relatedCharacters: [holder])
        context.insert(book)
        context.insert(holder)
        context.insert(source)
        context.insert(holding)
        context.insert(history)
        try context.save()

        try V6ItemCopyBackfill.run(source: context, destination: context)

        let copies = try context.fetch(FetchDescriptor<ItemCopy>()).filter { $0.itemID == source.id }
        let copyIDs = Set(copies.map(\.id))
        let copyHoldings = try context.fetch(FetchDescriptor<ItemCopyHolding>()).filter { copyIDs.contains($0.copyID) }
        let histories = try context.fetch(FetchDescriptor<ItemCopyHistory>()).filter { copyIDs.contains($0.copyID) }
        XCTAssertEqual(copies.count, 3)
        XCTAssertEqual(copyHoldings.count, 3)
        XCTAssertTrue(copyHoldings.allSatisfy { $0.characterID == holder.id })
        XCTAssertEqual(histories.count, 1)
        XCTAssertEqual(histories.first?.copyID, copies.sorted { $0.sortOrder < $1.sortOrder }.first?.id)
        XCTAssertEqual(histories.first?.content, "在藥房取得。")
    }

    func testMultipleHoldersAndUnifiedHistoryPersistTogether() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "測試小說", author: "作者")
        let firstCharacter = Character(realName: "洛恩", book: book)
        let secondCharacter = Character(realName: "艾琳", book: book)
        let item = Item(name: "霜紋長劍", book: book)
        let firstHolding = CharacterItem(quantity: 1, character: firstCharacter, item: item)
        let secondHolding = CharacterItem(quantity: 3, character: secondCharacter, item: item)
        let node = Node(year: 417)
        let history = ItemHistory(
            content: "洛恩將長劍交給艾琳保管。",
            node: node,
            item: item,
            relatedCharacters: [firstCharacter, secondCharacter]
        )
        context.insert(book)
        context.insert(firstCharacter)
        context.insert(secondCharacter)
        context.insert(item)
        context.insert(firstHolding)
        context.insert(secondHolding)
        context.insert(node)
        context.insert(history)
        try context.save()

        XCTAssertEqual(Set(item.characterItems.map(\.quantity)), Set([1, 3]))
        XCTAssertEqual(Set(history.relatedCharacters.map(\.realName)), Set(["洛恩", "艾琳"]))
        XCTAssertEqual(history.node?.year, 417)
        XCTAssertEqual(item.histories.map(\.id), [history.id])
    }

    func testWritingReferencesRemainOnSharedItemDefinition() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let book = Book(title: "測試小說", author: "作者")
        let volume = Volume(title: "第一卷", book: book)
        let section = Section(title: "冰原遺跡", content: AttributedString("洛恩在遺跡中找到霜紋長劍。"), volume: volume)
        let item = Item(name: "霜紋長劍", book: book)
        book.volumes.append(volume)
        volume.sections.append(section)
        context.insert(book)
        context.insert(volume)
        context.insert(section)
        context.insert(item)

        let copy = ItemCopyOperations.create(for: item, existingCopies: [], context: context, name: "洛恩之劍")
        try context.save()

        XCTAssertEqual(WritingReferenceScanner.sections(for: item, in: book).map(\.id), [section.id])
        XCTAssertEqual(copy.displayName(for: item), "洛恩之劍")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Item>()), 1)
    }

    func testLevelCompactOverviewUsesExistingFieldsOnly() throws {
        let level = ItemLevel(
            itemID: UUID(),
            name: "覺醒",
            itemName: "霜紋長劍",
            ability: "提高寒冷耐受力",
            cost: "持續消耗體力",
            note: "劍身出現白色紋路"
        )

        XCTAssertEqual(
            level.compactOverview,
            "名稱：霜紋長劍 · 能力：提高寒冷耐受力 · 代價：持續消耗體力 · 其他：劍身出現白色紋路"
        )
        XCTAssertEqual(ItemLevel(itemID: UUID(), name: "初始").compactOverview, "尚未填寫概述")
    }

    func testTimelineRelativeLabelsRestartAtViewportAndDateBoundaries() {
        let eraID = UUID()
        func cell(_ id: String, _ year: Int, _ month: Int, _ day: Int) -> TimelineCell {
            TimelineCell(
                id: id,
                kind: .day,
                ordinal: year * 10_000 + month * 100 + day,
                eraID: eraID,
                eraHex: "#888888",
                eraName: "安夢",
                era: nil,
                nodes: [],
                repYear: year,
                repMonth: month,
                repDay: day,
                events: []
            )
        }
        let cells = [cell("a", 4, 6, 18), cell("b", 4, 7, 16), cell("c", 4, 7, 21), cell("d", 5, 1, 3)]

        XCTAssertEqual(
            TimelineDateProjection.relativeLabels(cells: cells, granularity: .day, firstVisibleIndex: 0),
            ["4年6月18日", "7月16日", "21日", "5年1月3日"]
        )
        XCTAssertEqual(
            Array(TimelineDateProjection.relativeLabels(cells: cells, granularity: .day, firstVisibleIndex: 1)[1...]),
            ["4年7月16日", "21日", "5年1月3日"]
        )
    }

    func testTimelineSlotsExpandEventsHorizontallyAndKeepEmptyCells() {
        let first = Event(title: "第一件")
        let second = Event(title: "第二件")
        first.sortOrder = 2
        second.sortOrder = 1
        let eventCell = TimelineCell(
            id: "event", kind: .day, ordinal: 40_618, eraID: nil, eraHex: "#888888",
            eraName: "", era: nil, nodes: [], repYear: 4, repMonth: 6, repDay: 18,
            events: [first, second]
        )
        let emptyCell = TimelineCell(
            id: "empty", kind: .day, ordinal: 40_721, eraID: nil, eraHex: "#888888",
            eraName: "", era: nil, nodes: [], repYear: 4, repMonth: 7, repDay: 21,
            events: []
        )

        let slots = TimelineDateProjection.slots(cells: [eventCell, emptyCell])

        XCTAssertEqual(slots.count, 3)
        XCTAssertEqual(slots.compactMap(\.event?.id), [second.id, first.id])
        XCTAssertNil(slots.last?.event)
        XCTAssertEqual(
            TimelineDateProjection.relativeLabels(slots: slots, granularity: .day, firstVisibleIndex: 0),
            ["4年6月18日", "18日", "7月21日"]
        )
    }

    func testTimelineSlotsRespectExplicitSameDateInsertionOrder() {
        let first = Event(title: "先加入")
        let second = Event(title: "後加入")
        first.sortOrder = 0
        second.sortOrder = 1
        let cell = TimelineCell(
            id: "same-date", kind: .day, ordinal: 40_618, eraID: nil, eraHex: "#888888",
            eraName: "", era: nil, nodes: [], repYear: 4, repMonth: 6, repDay: 18,
            events: [second, first]
        )

        XCTAssertEqual(
            TimelineDateProjection.slots(cells: [cell]).compactMap(\.event?.title),
            ["先加入", "後加入"]
        )
    }

    func testTimelineExcerptCountsEmojiAsVisibleCharacters() {
        let value = String(repeating: "🌙", count: 31)
        XCTAssertEqual(TimelineCardProjection.normalizedExcerpt(value).count, 30)
    }
}

private extension Data {
    func containsUTF8(_ text: String) -> Bool {
        range(of: Data(text.utf8)) != nil
    }
}

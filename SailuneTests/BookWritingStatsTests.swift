import XCTest
@testable import Sailune

@MainActor
final class BookWritingStatsTests: XCTestCase {
    func testDailyNetDeltasAreIsolatedByBookAndLocalDateAndPersistOnReopen() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneWritingStats-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Writing Stats.json")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 12))!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let book = UUID()
        let otherBook = UUID()
        let store = BookWritingStatsStore(url: url)

        try store.recordSuccessfulEdits([
            (bookID: book, netWordDelta: 18),
            (bookID: book, netWordDelta: -6),
            (bookID: otherBook, netWordDelta: 2)
        ], at: day, calendar: calendar)
        try store.recordSuccessfulEdits([(bookID: book, netWordDelta: 3)], at: nextDay, calendar: calendar)
        XCTAssertEqual(store.netWordDelta(bookID: book, on: day, calendar: calendar), 12)
        XCTAssertEqual(store.netWordDelta(bookID: otherBook, on: day, calendar: calendar), 2)

        let reopened = BookWritingStatsStore(url: url)
        XCTAssertEqual(reopened.netWordDelta(bookID: book, on: day, calendar: calendar), 12)
        XCTAssertEqual(reopened.netWordDelta(bookID: book, on: nextDay, calendar: calendar), 3)
        XCTAssertNil(reopened.netWordDelta(bookID: book, on: calendar.date(byAdding: .day, value: -1, to: day)!, calendar: calendar))
    }

    func testZeroNetIsKnownAndSevenDayProjectionUsesLocalCalendarDays() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneWritingStatsWeek-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 19))!
        let store = BookWritingStatsStore(url: root.appendingPathComponent("Writing Stats.json"))
        let book = UUID()
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: today))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        try store.recordSuccessfulEdits([(bookID: book, netWordDelta: 7)], at: start, calendar: calendar)
        try store.recordSuccessfulEdits([(bookID: book, netWordDelta: -7)], at: today, calendar: calendar)
        try store.recordSuccessfulEdits([
            (bookID: book, netWordDelta: 4),
            (bookID: book, netWordDelta: -4)
        ], at: yesterday, calendar: calendar)
        XCTAssertEqual(store.netWordDelta(bookID: book, on: yesterday, calendar: calendar), 0)

        let days = store.lastSevenDays(bookID: book, endingAt: today, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first?.value, 7)
        XCTAssertEqual(days[5].value, 0)
        XCTAssertEqual(days.last?.value, -7)
        XCTAssertTrue(days[1...4].allSatisfy { $0.value == nil })

        try store.recordSuccessfulEdits([(bookID: book, netWordDelta: 7)], at: today, calendar: calendar)
        try store.recordSuccessfulEdits([(bookID: book, netWordDelta: -7)], at: today, calendar: calendar)
        XCTAssertEqual(store.netWordDelta(bookID: book, on: today, calendar: calendar), -7)
    }

    func testRemovingBookClearsOnlyItsRecords() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneWritingStatsDelete-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = BookWritingStatsStore(url: root.appendingPathComponent("Writing Stats.json"))
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let removedBook = UUID()
        let retainedBook = UUID()
        try store.recordSuccessfulEdits([
            (bookID: removedBook, netWordDelta: 8),
            (bookID: retainedBook, netWordDelta: 4)
        ], at: date)

        try store.removeBook(removedBook)

        XCTAssertNil(store.netWordDelta(bookID: removedBook, on: date))
        XCTAssertEqual(store.netWordDelta(bookID: retainedBook, on: date), 4)
    }

    func testCorruptOrUnwritableStoreKeepsStatisticsBlank() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneWritingStatsFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let corruptURL = root.appendingPathComponent("corrupt.json")
        try Data("not json".utf8).write(to: corruptURL)
        let corrupt = BookWritingStatsStore(url: corruptURL)
        XCTAssertNil(corrupt.netWordDelta(bookID: UUID(), on: .now))
        XCTAssertNotNil(corrupt.persistenceErrorMessage)

        let unwritableURL = root.appendingPathComponent("blocked.json")
        let unwritable = BookWritingStatsStore(url: unwritableURL)
        let retainedBook = UUID()
        let blockedBook = UUID()
        let date = Date.now
        try unwritable.recordSuccessfulEdits([(bookID: retainedBook, netWordDelta: 5)], at: date)
        try FileManager.default.removeItem(at: unwritableURL)
        try FileManager.default.createDirectory(at: unwritableURL, withIntermediateDirectories: true)
        XCTAssertThrowsError(try unwritable.recordSuccessfulEdits([(bookID: blockedBook, netWordDelta: 2)]))
        XCTAssertFalse(unwritable.isUnavailable)
        XCTAssertNotNil(unwritable.persistenceErrorMessage)
        XCTAssertNil(unwritable.netWordDelta(bookID: blockedBook, on: .now))
        XCTAssertEqual(unwritable.netWordDelta(bookID: retainedBook, on: date), 5)
    }
}

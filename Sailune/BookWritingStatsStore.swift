import Foundation
import Observation

struct BookWritingStatsRecord: Codable, Equatable, Identifiable {
    var id: String { "\(bookID.uuidString):\(day)" }
    let bookID: UUID
    let day: String
    var netWordDelta: Int
}

struct BookWritingStatsDocument: Codable, Equatable {
    var version: Int = 1
    var records: [BookWritingStatsRecord] = []
}

struct BookWritingDayValue: Identifiable, Equatable {
    let date: Date
    let value: Int?
    var id: Date { date }
}

@MainActor @Observable
final class BookWritingStatsStore {
    private let url: URL
    private var document: BookWritingStatsDocument
    private var unavailableBookIDs: Set<UUID> = []
    private(set) var persistenceErrorMessage: String?
    private(set) var isUnavailable = false

    init(url: URL) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let loaded = try JSONDecoder().decode(BookWritingStatsDocument.self, from: Data(contentsOf: url))
                guard loaded.version == 1 else { throw StoreError.unsupportedVersion(loaded.version) }
                document = loaded
            } catch {
                document = BookWritingStatsDocument()
                persistenceErrorMessage = "無法讀取每日編輯統計：\(error.localizedDescription)"
                isUnavailable = true
            }
        } else {
            document = BookWritingStatsDocument()
        }
    }

    func netWordDelta(bookID: UUID, on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int? {
        guard !isUnavailable, !unavailableBookIDs.contains(bookID) else { return nil }
        let day = Self.dayKey(for: date, calendar: calendar)
        return document.records.first { $0.bookID == bookID && $0.day == day }?.netWordDelta
    }

    func lastSevenDays(bookID: UUID, endingAt today: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> [BookWritingDayValue] {
        guard let today = calendar.dateInterval(of: .day, for: today)?.start else { return [] }
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            return BookWritingDayValue(date: date, value: netWordDelta(bookID: bookID, on: date, calendar: calendar))
        }
    }

    func recordSuccessfulEdits(_ edits: [(bookID: UUID, netWordDelta: Int)], at date: Date = .now, calendar: Calendar = .autoupdatingCurrent) throws {
        guard !isUnavailable else { throw StoreError.unavailable }
        guard !edits.contains(where: { unavailableBookIDs.contains($0.bookID) }) else { throw StoreError.unavailable }
        guard !edits.isEmpty else { return }
        let day = Self.dayKey(for: date, calendar: calendar)
        var updated = document
        for edit in edits {
            if let index = updated.records.firstIndex(where: { $0.bookID == edit.bookID && $0.day == day }) {
                let (sum, overflow) = updated.records[index].netWordDelta.addingReportingOverflow(edit.netWordDelta)
                guard !overflow else {
                    unavailableBookIDs.formUnion(edits.map(\.bookID))
                    persistenceErrorMessage = StoreError.valueOverflow.localizedDescription
                    throw StoreError.valueOverflow
                }
                updated.records[index].netWordDelta = sum
            } else {
                updated.records.append(BookWritingStatsRecord(bookID: edit.bookID, day: day, netWordDelta: edit.netWordDelta))
            }
        }
        do {
            try persist(updated)
        } catch {
            unavailableBookIDs.formUnion(edits.map(\.bookID))
            throw error
        }
    }

    func removeBook(_ bookID: UUID) throws {
        guard !isUnavailable else { throw StoreError.unavailable }
        var updated = document
        updated.records.removeAll { $0.bookID == bookID }
        guard updated != document else {
            unavailableBookIDs.remove(bookID)
            return
        }
        try persist(updated)
        unavailableBookIDs.remove(bookID)
    }

    func clearPersistenceError() {
        persistenceErrorMessage = nil
    }

    private func persist(_ updated: BookWritingStatsDocument) throws {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(updated).write(to: url, options: .atomic)
            document = updated
        } catch {
            persistenceErrorMessage = "無法儲存每日編輯統計：\(error.localizedDescription)"
            throw error
        }
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    enum StoreError: LocalizedError {
        case unsupportedVersion(Int)
        case unavailable
        case valueOverflow

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version): "不支援的每日編輯統計格式版本：\(version)"
            case .unavailable: "每日編輯統計目前無法使用。"
            case .valueOverflow: "每日編輯字數超出可保存範圍。"
            }
        }
    }
}

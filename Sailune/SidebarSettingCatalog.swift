import Foundation
import SwiftData

@MainActor
enum SidebarSettingCatalog {
    static let currentRevision = 1

    static func rows(for bookID: UUID, in context: ModelContext) throws -> [BookSidebarSetting] {
        let rows = try context.fetch(FetchDescriptor<BookSidebarSetting>())
            .filter { $0.bookID == bookID }
        if !rows.isEmpty { return rows.sorted { $0.sortOrder < $1.sortOrder } }
        return try ensureDefaults(for: bookID, in: context)
    }

    @discardableResult
    static func ensureDefaults(for bookID: UUID, in context: ModelContext) throws -> [BookSidebarSetting] {
        var rows = try context.fetch(FetchDescriptor<BookSidebarSetting>()).filter { $0.bookID == bookID }
        let existing = Set(rows.compactMap(\.key))
        for (index, key) in SidebarSettingKey.defaultOrder.enumerated() where !existing.contains(key) {
            let row = BookSidebarSetting(
                bookID: bookID,
                key: key,
                sortOrder: index,
                isVisible: key.isDefaultVisible,
                catalogRevision: currentRevision
            )
            context.insert(row)
            rows.append(row)
        }
        if rows.contains(where: { $0.catalogRevision < currentRevision }) {
            for row in rows {
                if let key = row.key,
                   let index = SidebarSettingKey.defaultOrder.firstIndex(of: key) {
                    row.sortOrder = index
                    if key == .worldTerm {
                        row.isVisible = true
                    }
                }
                row.catalogRevision = currentRevision
            }
        }
        try context.save()
        return rows.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func visibleKeys(rows: [BookSidebarSetting]) -> [SidebarSettingKey] {
        rows.sorted { $0.sortOrder < $1.sortOrder }.compactMap { $0.isVisible ? $0.key : nil }
    }

    static func resolvedSelection(
        _ current: SidebarSettingKey,
        visibleKeys: [SidebarSettingKey]
    ) -> SidebarSettingKey {
        visibleKeys.contains(current) ? current : (visibleKeys.first ?? current)
    }
}

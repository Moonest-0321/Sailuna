import Foundation

/// 將匯出檔案與本機發布狀態的保存順序集中在同一個入口。
@MainActor
enum PublicationExportCoordinator {
    static func initialRequest(
        book: Book,
        categories: [String],
        sectionUnit: BookTextSectionMarker,
        publicationStore: BookPublicationStore,
        onStatusError: @escaping (Error) -> Void
    ) throws -> SailuneExportRequest {
        let bookID = book.id
        return try BookJSONExporter.exportRequest(
            book: book,
            categories: categories,
            status: .ongoing,
            sectionUnit: sectionUnit
        ) { _ in
            do {
                try publicationStore.publish(bookID, tags: categories)
            } catch {
                onStatusError(error)
            }
        }
    }

    static func updateRequest(
        book: Book,
        sectionUnit: BookTextSectionMarker,
        publicationStore: BookPublicationStore
    ) throws -> SailuneExportRequest {
        try BookJSONExporter.exportRequest(
            book: book,
            categories: publicationStore.tags(for: book.id),
            status: publicationStore.status(for: book.id),
            sectionUnit: sectionUnit,
            onSaved: { _ in }
        )
    }
}

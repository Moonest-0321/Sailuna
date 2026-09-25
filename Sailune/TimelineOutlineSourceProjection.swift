import Foundation

/// 時間軸事件來源選取使用的大綱順序及標題投影。
@MainActor
enum TimelineOutlineSourceProjection {
    static func orderedItems(book: Book, planningStore: StoryPlanningStore) -> [OutlineItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: planningStore.items(bookID: book.id).map { ($0.id, $0) })
        return planningStore.narrativeOutlineList(book: book).itemIDsInDisplayOrder.compactMap { itemsByID[$0] }
    }

    static func eventTitle(for item: OutlineItem) -> String {
        String(item.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(10))
    }
}

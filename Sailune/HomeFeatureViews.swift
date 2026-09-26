import SwiftUI

struct StartAchievementsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("成就")
                    .font(.title2.weight(.semibold))

                GroupBox("最多閱讀") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("書名") { blankValue }
                        LabeledContent("閱讀量") { blankValue }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("訂閱最高") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("書名") { blankValue }
                        LabeledContent("訂閱量") { blankValue }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("獲得榮耀") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("書名") { blankValue }
                        LabeledContent("榮耀") { blankValue }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var blankValue: some View {
        Text(" ")
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .accessibilityHidden(true)
    }
}

struct StartPublishingView: View {
    let books: [Book]
    let statusForBook: (UUID) -> BookStatus
    let onAdvance: (UUID) -> Void
    let onResume: (UUID) -> Void
    let writingStats: BookWritingStatsStore
    @State private var selectedBookID: UUID?

    var body: some View {
        Group {
            if let selectedBookID, let book = books.first(where: { $0.id == selectedBookID }) {
                BookAnalyticsView(book: book, writingStats: writingStats) {
                    self.selectedBookID = nil
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("發布")
                            .font(.title2.weight(.semibold))

                        ForEach(books) { book in
                            let status = statusForBook(book.id)
                            HStack(spacing: 16) {
                                Button {
                                    selectedBookID = book.id
                                } label: {
                                    Text(book.title.isEmpty ? "未命名作品" : book.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("開啟《\(book.title)》的數據")

                                Text(status.publicationTitle)
                                    .foregroundStyle(.secondary)
                                if status == .completed {
                                    Button("恢復連載") { onResume(book.id) }
                                        .accessibilityLabel("恢復《\(book.title)》連載")
                                } else {
                                    Button(status == .draft ? "發布" : "完結") {
                                        onAdvance(book.id)
                                    }
                                    .accessibilityLabel("\(status == .draft ? "發布" : "完結")《\(book.title)》")
                                }
                            }
                            .padding(12)
                            Divider()
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

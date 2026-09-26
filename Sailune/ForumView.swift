import SwiftUI

struct ForumView: View {
    @State private var selectedBoard: ForumBoard = .announcements

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("論壇")
                    .font(.title2.weight(.semibold))
                Spacer(minLength: 12)
                ForEach(ForumBoard.allCases) { board in
                    boardButton(board)
                }
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                Text(selectedBoard.title)
                    .font(.title2.weight(.semibold))
                Text(selectedBoard.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                Divider()
                    .padding(.top, 16)

                ContentUnavailableView(
                    "尚無內容",
                    systemImage: SailuneSymbol.forum.systemName,
                    description: Text("目前沒有內容。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func boardButton(_ board: ForumBoard) -> some View {
        Button {
            selectedBoard = board
        } label: {
            Text(board.title)
                .fontWeight(selectedBoard == board ? .semibold : .regular)
        }
        .buttonStyle(.bordered)
        .tint(selectedBoard == board ? .accentColor : .secondary)
        .accessibilityValue(selectedBoard == board ? "目前分類" : "")
    }
}

private enum ForumBoard: String, CaseIterable, Identifiable {
    case announcements
    case writing
    case works
    case sailune
    case suggestions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .announcements: "官方公告"
        case .writing: "寫作交流"
        case .works: "作品交流"
        case .sailune: "帆夢交流"
        case .suggestions: "功能建議"
        }
    }

    var summary: String {
        switch self {
        case .announcements: "版本更新與重要消息"
        case .writing: "情節、人物、節奏與寫作卡關"
        case .works: "分享作品簡介或摘錄，交流回饋"
        case .sailune: "使用方法與問題排除"
        case .suggestions: "分享功能想法與使用問題"
        }
    }
}

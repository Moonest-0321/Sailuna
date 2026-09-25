import SwiftUI
import SwiftData

// MARK: - 個人卡片時間投影（PRD 第 10 節主入口）

@MainActor
struct CharacterTimelineProjectionView: View {
    let character: Character
    @Query private var allEvents: [Event]
    @Environment(\.modelContext) private var modelContext

    private var myEvents: [Event] {
        allEvents
            .filter { $0.characters.contains(where: { $0.id == character.id }) }
            .sorted { ordinal(of: $0) < ordinal(of: $1) }
    }

    private var visibleCount: Int {
        myEvents.filter { TimelineEngine.Visibility.isVisibleOnPrimaryAxis($0) }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.5)
            if myEvents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(myEvents, id: \.id) { e in
                            EventProjectionRow(event: e)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.05), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(sailuneDisplayName(character))
                .font(.system(.headline, design: .serif))
                .lineLimit(1)
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                statBlock(value: myEvents.count, label: "筆事件")
                statBlock(value: visibleCount, label: "上主軸", accent: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.accentColor.opacity(0.5), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(height: 1.5)
        }
    }

    private func statBlock(value: Int, label: String, accent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(value)")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(accent ? Color.accentColor : .primary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("尚未踏入時間")
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.secondary)
            Text("在右欄時間軸為這角色記錄事件後，其一生足跡將在此呈現。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func ordinal(of e: Event) -> Int {
        guard let n = e.node else { return Int.max }
        return TimelineEngine.Core.ordinal(
            eraStart: n.era?.startOrdinal ?? 1,
            year: n.year, month: n.month, day: n.day
        )
    }
}

// MARK: - 投影事件列（含 isVisible 主開關）

@MainActor
private struct EventProjectionRow: View {
    @Bindable var event: Event
    @Environment(\.modelContext) private var modelContext
    @State private var hovering = false
    @State private var saveErrorMessage: String?

    private var bandColor: Color {
        if !event.isVisible { return .secondary.opacity(0.25) }
        if let hex = event.node?.era?.color, let c = Color(hex: hex) { return c }
        return .accentColor
    }

    private var timeLabel: String {
        guard let n = event.node else { return "未定時間" }
        var s = n.year > 0 ? "\(n.year)年" : ""
        if let m = n.month {
            s += "\(m)月"
            if let d = n.day { s += "\(d)日" }
        }
        return s.isEmpty ? "未設定世界時間" : s
    }

    private var nodeHidesIt: Bool {
        event.isVisible && (event.node?.isVisible == false)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(bandColor)
                .frame(width: hovering ? 4 : 3)
                .padding(.vertical, 4)
                .animation(.easeInOut(duration: 0.15), value: hovering)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title.isEmpty ? "（無標題事件）" : event.title)
                    .font(.caption)
                    .foregroundStyle(event.isVisible ? .primary : .secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(timeLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if nodeHidesIt {
                        Text("· 所在節點已隱藏")
                            .font(.caption2)
                            .foregroundStyle(.orange.opacity(0.8))
                    }
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    event.isVisible.toggle()
                }
                do { try modelContext.save() }
                catch { modelContext.rollback(); saveErrorMessage = error.localizedDescription }
            } label: {
                ZStack {
                    Circle()
                        .fill(event.isVisible ? Color.accentColor : Color.secondary.opacity(0.15))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(
                                event.isVisible ? Color.clear : Color.secondary.opacity(0.4),
                                lineWidth: 1
                            )
                        )
                        .scaleEffect(hovering ? 1.08 : 1.0)
                    Image(systemName: event.isVisible ? "eye.fill" : "eye.slash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(event.isVisible ? .white : .secondary)
                }
            }
            .buttonStyle(.plain)
            .help(SailuneAccessibilityCopy.showOnMainTimeline)
            .padding(.trailing, 10)
            .padding(.top, 7)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(hovering ? 0.05 : 0.0))
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
        .alert("事件顯示狀態無法儲存", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) { Button(SailuneActionCopy.acknowledge) { saveErrorMessage = nil } } message: {
            Text(saveErrorMessage ?? "請稍後再試。")
        }
    }
}

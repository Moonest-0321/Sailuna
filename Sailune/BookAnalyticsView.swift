import Charts
import SwiftData
import SwiftUI

struct BookAnalyticsView: View {
    let book: Book
    let writingStats: BookWritingStatsStore
    let onBack: () -> Void

    private var writingDays: [BookWritingDayValue] {
        writingStats.lastSevenDays(bookID: book.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SailuneLayout.spacingXL) {
                HStack(alignment: .center) {
                    Button(action: onBack) {
                        Label("返回發布", systemImage: SailuneSymbol.back.systemName)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(book.title.isEmpty ? "未命名作品" : book.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: SailuneLayout.spacingL) {
                    Text("創作者")
                        .font(.title3.weight(.semibold))
                    DailyMetricCard(title: "今日編輯字數", value: writingStats.netWordDelta(bookID: book.id, on: .now).map { "\($0) 字" })
                    AnalyticsLineChart(title: "近一週每日編輯字數", days: writingDays, suffix: " 字")
                }

                VStack(alignment: .leading, spacing: SailuneLayout.spacingL) {
                    Text("讀者")
                        .font(.title3.weight(.semibold))
                    DailyMetricCard(title: "今日閱讀數", value: nil)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SailuneLayout.spacingL) {
                        AnalyticsLineChart(title: "近一週每日閱讀數", days: blankWeek, suffix: "")
                        AnalyticsLineChart(title: "近一週每日保有書櫃讀者數", days: blankWeek, suffix: "")
                        AnalyticsLineChart(title: "近一週每日追更率", days: blankWeek, suffix: "%")
                        AnalyticsLineChart(title: "近一週每日收益", days: blankWeek, suffix: "")
                    }
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var blankWeek: [BookWritingDayValue] {
        writingDays.map { BookWritingDayValue(date: $0.date, value: nil) }
    }
}

private struct DailyMetricCard: View {
    let title: String
    let value: String?

    var body: some View {
        GroupBox {
            Text(value ?? " ")
                .font(.title3.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .accessibilityHidden(value == nil)
        } label: {
            Text(title)
        }
    }
}

private struct AnalyticsLineChart: View {
    let title: String
    let days: [BookWritingDayValue]
    let suffix: String

    private var points: [BookWritingDayValue] { days.filter { $0.value != nil } }

    private var segments: [[BookWritingDayValue]] {
        var result: [[BookWritingDayValue]] = []
        var current: [BookWritingDayValue] = []
        for day in days {
            if day.value == nil {
                if !current.isEmpty { result.append(current); current = [] }
            } else {
                current.append(day)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    var body: some View {
        GroupBox {
            Chart {
                ForEach(segments.indices, id: \.self) { segmentIndex in
                    ForEach(segments[segmentIndex]) { day in
                        if let value = day.value {
                            LineMark(
                                x: .value("日期", day.date),
                                y: .value(title, value),
                                series: .value("資料區段", segmentIndex)
                            )
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                }
                ForEach(points) { day in
                    if let value = day.value {
                        PointMark(x: .value("日期", day.date), y: .value(title, value))
                            .foregroundStyle(Color.accentColor)
                            .annotation(position: .top, spacing: 4) {
                                Text("\(value)\(suffix)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
            }
            .chartXScale(domain: dateDomain)
            .chartXAxis {
                AxisMarks(values: days.map(\.date)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 210)
        } label: {
            Text(title)
        }
        .accessibilityElement(children: .contain)
    }

    private var dateDomain: ClosedRange<Date> {
        guard let first = days.first?.date, let last = days.last?.date else {
            return Date.now...Date.now.addingTimeInterval(1)
        }
        return first...last
    }
}

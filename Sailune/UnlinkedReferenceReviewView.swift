import SwiftUI

struct UnlinkedReferenceReviewView: View {
    @Binding var candidates: [UnlinkedReferenceCandidate]
    let onApply: () -> Void
    let onDismiss: () -> Void

    private var selectedCount: Int { candidates.filter(\.isSelected).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.magnifyingglass")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("發現未連結的舊名稱")
                        .font(.subheadline.weight(.semibold))
                    Text("已連結文字已同步；以下文字請依上下文決定是否替換。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: SailuneSymbol.cancel.systemName)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("暫不處理")
            }

            HStack(spacing: 10) {
                Button("全選") { candidates.indices.forEach { candidates[$0].isSelected = true } }
                Button("全不選") { candidates.indices.forEach { candidates[$0].isSelected = false } }
                Spacer()
                Text("共 \(candidates.count) 處")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .font(.caption)

            VStack(alignment: .leading, spacing: 7) {
                ForEach($candidates) { $candidate in
                    Toggle(isOn: $candidate.isSelected) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(candidate.sourceLabel)：\(candidate.sourceName) → \(candidate.replacement)")
                                .font(.caption.weight(.medium))
                            Text("\(candidate.section.title.isEmpty ? "未命名章節" : candidate.section.title)　\(candidate.preview)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Button("套用已選 \(selectedCount) 處", action: onApply)
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}


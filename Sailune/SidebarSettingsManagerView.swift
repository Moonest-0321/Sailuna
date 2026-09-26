import SwiftUI
import SwiftData

struct SidebarSettingsManagerView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly

    private var rows: [BookSidebarSetting] {
        settingsStore.sidebarRows(for: book.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("管理設定集").font(.headline)
                Spacer()
                Button(SailuneActionCopy.done) { dismiss() }
            }
            Text("預設項目也可以隱藏；隱藏只影響側邊欄，不會刪除資料。")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                SwiftUI.Section("側邊欄順序") {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Toggle(isOn: binding(for: row)) {
                                Label(row.key?.title ?? "未知設定", systemImage: row.key?.systemImage ?? "questionmark")
                            }
                            .disabled(bookIsReadOnly)
                            Spacer()
                            Button { move(row, offset: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(.borderless)
                                .disabled(bookIsReadOnly || row.sortOrder == rows.first?.sortOrder)
                            Button { move(row, offset: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.borderless)
                                .disabled(bookIsReadOnly || row.sortOrder == rows.last?.sortOrder)
                        }
                    }
                }
            }
            HStack {
                Button("重設預設顯示", action: reset).disabled(bookIsReadOnly)
                Spacer()
                Text("可選項目：地點")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 420, minHeight: 360)
        .task { if !bookIsReadOnly { settingsStore.ensureDefaults(for: book.id) } }
    }

    private func binding(for row: BookSidebarSetting) -> Binding<Bool> {
        Binding(get: { row.isVisible }, set: { guard !bookIsReadOnly else { return }; row.isVisible = $0; settingsStore.save() })
    }

    private func move(_ row: BookSidebarSetting, offset: Int) {
        guard !bookIsReadOnly else { return }
        guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
        let target = index + offset
        guard rows.indices.contains(target) else { return }
        let other = rows[target]
        let order = row.sortOrder
        row.sortOrder = other.sortOrder
        other.sortOrder = order
        settingsStore.save()
    }

    private func reset() {
        for row in rows {
            if let key = row.key,
               let index = SidebarSettingKey.defaultOrder.firstIndex(of: key) {
                row.sortOrder = index
            }
            row.isVisible = row.key?.isDefaultVisible ?? false
        }
        settingsStore.save()
    }
}


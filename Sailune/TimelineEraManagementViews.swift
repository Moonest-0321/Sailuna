import SwiftUI
import SwiftData
import OSLog

// MARK: - 年號管理 popover

@MainActor
struct EraManagerPopover: View {
    let book: Book
    @Query private var eras: [Era]
    @Environment(\.modelContext) private var modelContext
    @Environment(StoryPlanningStore.self) private var planningStore
    @Environment(ItemCopyStore.self) private var copyStore
    @Environment(V5SettingsStore.self) private var settingsStore
    @Environment(AbilityProgressStore.self) private var abilityStore
    @Environment(\.dismiss) private var dismiss
    @State private var saveError: String?
    @State private var pendingDeleteEra: Era?

    private var sortedEras: [Era] { eras.sorted { $0.startOrdinal < $1.startOrdinal } }

    private var deleteEraBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteEra != nil },
            set: { if !$0 { pendingDeleteEra = nil } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("年號管理").font(.system(.headline, design: .serif))
            if let saveError { Text(saveError).font(.caption).foregroundStyle(.red) }
            Text("紀元為全書共享的時間皮膚。序數較小者排在時間河上游；填負數可建立前史紀元，供副軸落釘。改元（踰年推進敘事）請於主軸操作。")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(sortedEras) { era in
                        EraRow(era: era) {
                            pendingDeleteEra = era
                        }
                    }
                }
            }
            .frame(maxHeight: 260)
            Button { addEra() } label: {
                Label("新增紀元", systemImage: SailuneSymbol.addCircle.systemName)
            }
            .buttonStyle(PlanningActionStyle())
            HStack {
                Spacer()
                Button(SailuneActionCopy.done) {
                    do { try modelContext.save() }
                    catch { saveError = error.localizedDescription; return }
                    dismiss()
                }
                .buttonStyle(PlanningActionStyle(prominent: true))
            }
        }
        .alert(
            deleteTitle(for: pendingDeleteEra),
            isPresented: deleteEraBinding,
            presenting: pendingDeleteEra
        ) { era in
            Button(SailuneActionCopy.cancel, role: .cancel) { pendingDeleteEra = nil }
            Button(SailuneActionCopy.delete, role: .destructive) { performDeleteEra(era) }
        } message: { era in
            Text(deleteWarning(for: era))
        }
        .padding(16)
        .frame(width: 320)
    }

    private func addEra() {
        let next = (eras.map(\.startOrdinal).max() ?? 0) + 1
        let e = Era(name: "", color: "#888888", startOrdinal: next)
        modelContext.insert(e)
    }

    private func deleteTitle(for era: Era?) -> String {
        guard let era else { return "刪除紀元？" }
        let name = era.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return "刪除紀元「\(name.isEmpty ? "未命名紀元" : name)」？"
    }

    private func deleteWarning(for era: Era) -> String {
        let isCurrentEra = book.currentEra?.id == era.id
        var warning = "目前這本書所有時間軸中仍掛在此紀元下的時間點與世界時間事件將一併刪除，且無法復原。角色、能力、物品與關係歷史內容會保留，但失去這些時間定位；正文與敘事大綱保留。"
        if isCurrentEra {
            warning += "此紀元是目前紀元，之後會建立空白預設紀元。"
        }
        return warning
    }

    private func performDeleteEra(_ era: Era) {
        saveError = nil
        do {
            let outcome = try CrossStoreDeletionCoordinator.deleteEra(
                era,
                for: book,
                in: modelContext,
                planningStore: planningStore,
                copyStore: copyStore,
                settingsStore: settingsStore,
                abilityStore: abilityStore
            )
            if outcome.requiresRepair {
                saveError = "紀元已刪除，但部分附屬資料尚未清理，將由啟動修復重試。\n\(outcome.deferredCleanupErrors.joined(separator: "\n"))"
            }
        } catch {
            saveError = "無法刪除紀元；主要資料尚未刪除。\n\(error.localizedDescription)"
        }
        pendingDeleteEra = nil
    }
}

@MainActor
private struct EraRow: View {
    @Bindable var era: Era
    let onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: era.color) ?? .gray).frame(width: 12, height: 12)
                SailuneFormTextField(title: "紀元名", text: $era.name)
                    .font(.caption)
                Button(role: .destructive, action: onDelete) {
                    Label(SailuneActionCopy.delete, systemImage: SailuneSymbol.delete.systemName)
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                Text("序").font(.caption2).foregroundStyle(.secondary)
                TextField("", value: $era.startOrdinal, format: .number)
                    .textFieldStyle(.roundedBorder).font(.caption).frame(width: 72)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(eraPalette, id: \.self) { hex in
                            Button { era.color = hex } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .gray)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(era.color == hex ? Color.primary : .clear, lineWidth: 1.5))
                                    .scaleEffect(hovering && era.color == hex ? 1.12 : 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(Color.primary.opacity(hovering ? 0.05 : 0.025))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovering)
    }
}

// MARK: - 改元 popover

private let eraPalette: [String] = [
    "#C0392B", "#E67E22", "#F1C40F", "#27AE60",
    "#2980B9", "#8E44AD", "#16A085", "#7F8C8D"
]

@MainActor
struct EraChangePopover: View {
    private static let logger = Logger(subsystem: "com.MooNest.Sailune", category: "EraChangePopover")

    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var selectedHex = eraPalette[0]
    @State private var saveError: String?

    private var continuationText: String? {
        let era: Era
        do {
            guard let lastEra = try TimelineEngine.Query.lastEra(for: book, in: modelContext) else { return nil }
            era = lastEra
        } catch {
            Self.logger.error("Last era lookup failed for book \(self.book.id, privacy: .private): \(error.localizedDescription, privacy: .private)")
            return nil
        }
        let year: Int?
        do {
            year = try TimelineEngine.Query.maxYear(of: era, for: book, in: modelContext)
        } catch {
            Self.logger.error("Max year lookup failed for book \(self.book.id, privacy: .private), era \(era.id, privacy: .private): \(error.localizedDescription, privacy: .private)")
            year = nil
        }
        let name = era.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return "接續於：〈\(name.isEmpty ? "未命名年號" : name)〉第 \(year ?? 1) 年之後"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("改元（踰年）").font(.system(.headline, design: .serif))
            if let continuationText {
                Text(continuationText).font(.caption).foregroundStyle(.secondary)
            }
            if let saveError { Text(saveError).font(.caption).foregroundStyle(.red) }
            TextField("新年號名", text: $name)
            Text("年號色").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(eraPalette, id: \.self) { hex in
                    Button { selectedHex = hex } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(selectedHex == hex ? Color.primary : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Button(SailuneActionCopy.cancel) { dismiss() }
                Spacer()
                Button("確認改元") {
                    do {
                    _ = try TimelineEngine.EraChange.perform(
                        for: book,
                        input: .init(newName: name, newColor: selectedHex),
                        in: modelContext
                    )
                    } catch { saveError = error.localizedDescription; return }
                    dismiss()
                }
                .buttonStyle(PlanningActionStyle(prominent: true))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

// MARK: - 編輯既有年號 popover

@MainActor
struct EraEditPopover: View {
    @Bindable var era: Era
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("編輯年號").font(.system(.headline, design: .serif))
            if let saveError { Text(saveError).font(.caption).foregroundStyle(.red) }
            TextField("年號名", text: $era.name)
            Text("年號色").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(eraPalette, id: \.self) { hex in
                    Button { era.color = hex } label: {
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(era.color == hex ? Color.primary : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Spacer()
                Button(SailuneActionCopy.done) {
                    do { try modelContext.save() }
                    catch { saveError = error.localizedDescription; return }
                    dismiss()
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }
}

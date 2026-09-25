import SwiftUI
import SwiftData

struct CharacterAppearanceSectionView: View {
    let character: Character
    let book: Book
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CharacterAppearance.createdAt) private var allAppearances: [CharacterAppearance]
    private var appearances: [CharacterAppearance] { allAppearances.filter { $0.character?.id == character.id } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if appearances.isEmpty {
                CharacterSectionEmptyState(title: "尚無外觀資料", detail: "可新增服裝與身體特徵。")
            } else {
                ForEach(appearances) { appearance in AppearanceRow(appearance: appearance, book: book, onDelete: { modelContext.delete(appearance) }) }
            }
            Menu("新增外觀") {
                Button("服裝") { add(.outfit) }
                Button("身體特徵") { add(.bodyFeature) }
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func add(_ kind: CharacterAppearanceKind) {
        modelContext.insert(CharacterAppearance(kind: kind, descriptionText: "新外觀", character: character))
    }
}

private struct AppearanceRow: View {
    @Bindable var appearance: CharacterAppearance
    let book: Book
    let onDelete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Picker("類型", selection: $appearance.kindRawValue) {
                    Text("服裝").tag(CharacterAppearanceKind.outfit.rawValue)
                    Text("身體特徵").tag(CharacterAppearanceKind.bodyFeature.rawValue)
                }.frame(width: 150)
                SailuneIconButton(
                    symbol: .delete,
                    label: SailuneActionCopy.deleteAppearance,
                    role: .destructive,
                    action: onDelete
                )
            }
            Text("外觀描述").font(.caption).foregroundStyle(.secondary)
            InsetTextEditor(text: $appearance.descriptionText, minHeight: 110)
            SailuneFormTextField(
                title: appearance.kind == .outfit ? "場景／用途" : "備註",
                text: appearance.kind == .outfit ? $appearance.usage : $appearance.note
            )
            HStack {
                Text("時間定位").font(.caption).foregroundStyle(.secondary)
                CharacterTimelinePlacementEditor(book: book, node: $appearance.node) {
                    appearance.updatedAt = Date()
                }
            }
        }
    }
}


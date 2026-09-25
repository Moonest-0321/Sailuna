import SwiftUI

struct StoryTagListView: View {
    let book: Book
    let currentSection: Section?
    let onOpen: ((StoryTag) -> Void)?
    @Environment(StoryPlanningStore.self) private var planningStore
    @State private var searchText = ""
    @State private var showCurrentSectionOnly = false
    @State private var deleteTarget: StoryTag?
    @State private var errorMessage: String?

    private var allTags: [StoryTag] {
        planningStore.tags(bookID: book.id)
    }

    private var referencedTags: [StoryTag] {
        guard let currentSection else { return [] }
        return allTags.filter { $0.sectionID == currentSection.id }
    }

    private var tags: [StoryTag] {
        let source = showCurrentSectionOnly && currentSection != nil ? referencedTags : allTags
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return source.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        let sectionOrder = Dictionary(uniqueKeysWithValues: BookStructure.orderedSections(in: book).enumerated().map { ($0.element.id, $0.offset) })
        VStack(spacing: 0) {
            InspectorLinkedItemsRow(
                title: "本節連結標籤",
                entries: referencedTags.map { InspectorLinkedEntry(id: $0.id, name: $0.title.isEmpty ? "未命名標籤" : $0.title) },
                onOpen: { id in
                    if let tag = allTags.first(where: { $0.id == id }) { onOpen?(tag) }
                }
            )
            SailuneSearchField(placeholder: "搜尋標籤", text: $searchText)
            if currentSection != nil {
                Toggle("只顯示本節相關標籤", isOn: $showCurrentSectionOnly)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            List {
                SwiftUI.ForEach(0..<StoryTagKind.allCases.count, id: \.self) { index in
                    let kind = StoryTagKind.allCases[index]
                    let grouped = tags.filter { $0.kindRawValue == kind.rawValue }.sorted { lhs, rhs in
                        let left = sectionOrder[lhs.sectionID] ?? Int.max
                        let right = sectionOrder[rhs.sectionID] ?? Int.max
                        return left == right ? lhs.anchorOffset < rhs.anchorOffset : left < right
                    }
                    if !grouped.isEmpty {
                        SwiftUI.Section(kind.rawValue) {
                            SwiftUI.ForEach(grouped) { tag in
                                HStack(spacing: 8) {
                                    Button { onOpen?(tag) } label: {
                                        Text(tag.title.isEmpty ? "未命名標籤" : tag.title)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    Text(sectionTitle(for: tag))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Button(SailuneActionCopy.delete, role: .destructive) { deleteTarget = tag }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.workspacePanelBackground)
        }
        .confirmationDialog("刪除標籤？", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), presenting: deleteTarget) { tag in
            Button(SailuneActionCopy.delete, role: .destructive) { delete(tag) }
            Button(SailuneActionCopy.cancel, role: .cancel) { deleteTarget = nil }
        } message: { tag in
            Text("「\(tag.title.isEmpty ? "未命名標籤" : tag.title)」的標籤提示會消失，但正文不會被刪除。")
        }
        .alert("標籤無法刪除", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(SailuneActionCopy.acknowledge) { errorMessage = nil }
        } message: { Text(errorMessage ?? "未知錯誤") }
    }

    private func section(for tag: StoryTag) -> Section? {
        BookStructure.orderedSections(in: book).first { $0.id == tag.sectionID }
    }

    private func sectionTitle(for tag: StoryTag) -> String {
        guard let title = section(for: tag)?.title, !title.isEmpty else { return "" }
        return title
    }

    private func delete(_ tag: StoryTag) {
        do {
            try planningStore.deleteStoryTag(tag)
            deleteTarget = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

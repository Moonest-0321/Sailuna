import SwiftUI
import AppKit
import SwiftData

extension Notification.Name {
    static let sailuneFindNext = Notification.Name("Sailune.FindNextSearchResult")
}

enum SearchScope: String, CaseIterable, Identifiable {
    case section = "本節次"
    case book = "全書"

    var id: String { rawValue }
}

struct SearchMatch: Identifiable {
    let id = UUID()
    let section: Section
    let range: NSRange
}

private struct SearchReplaceSnapshot {
    let section: Section
    let content: AttributedString
    let wordCount: Int
    let updatedAt: Date
    let book: Book?
    let bookUpdatedAt: Date?

    init(section: Section) {
        self.section = section
        content = section.content
        wordCount = section.wordCount
        updatedAt = section.updatedAt
        let owningBook = section.volume?.book
        book = owningBook
        bookUpdatedAt = owningBook?.updatedAt
    }

    func restore() {
        section.content = content
        section.wordCount = wordCount
        section.updatedAt = updatedAt
        if let book, let bookUpdatedAt { book.updatedAt = bookUpdatedAt }
    }
}

private func plainText(of section: Section) -> String {
    NSAttributedString(section.content).string
}

private func matches(in text: String, query: String) -> [NSRange] {
    guard !query.isEmpty else { return [] }
    let source = text as NSString
    var result: [NSRange] = []
    var searchLocation = 0
    while searchLocation < source.length {
        let range = source.range(
            of: query,
            options: [.caseInsensitive],
            range: NSRange(location: searchLocation, length: source.length - searchLocation)
        )
        guard range.location != NSNotFound else { break }
        result.append(range)
        searchLocation = NSMaxRange(range)
    }
    return result
}

private func orderedSections(in book: Book) -> [Section] {
    book.volumes
        .sorted { $0.sortOrder < $1.sortOrder }
        .flatMap { $0.sections.sorted { $0.sortOrder < $1.sortOrder } }
}

private func replace(_ match: SearchMatch, with replacement: String) -> Int {
    let attributed = NSMutableAttributedString(attributedString: NSAttributedString(match.section.content))
    guard match.range.location != NSNotFound,
          NSMaxRange(match.range) <= attributed.length else { return 0 }
    let previousCount = countWords(attributed.string)

    let attributes = attributed.attributes(at: match.range.location, effectiveRange: nil)
    attributed.replaceCharacters(in: match.range, with: replacement)
    if !replacement.isEmpty {
        attributed.addAttributes(attributes, range: NSRange(location: match.range.location, length: (replacement as NSString).length))
    }
    match.section.content = AttributedString(attributed)
    match.section.wordCount = countWords(attributed.string)
    match.section.updatedAt = Date()
    match.section.volume?.book?.updatedAt = Date()
    return match.section.wordCount - previousCount
}

struct SearchReplaceView: View {
    let book: Book
    @Binding var selectedSection: Section?
    let bridge: EditorBridge
    @Environment(\.modelContext) private var modelContext
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @Environment(\.sectionUnit) private var sectionUnit
    @Environment(BookWritingStatsStore.self) private var writingStatsStore

    @State private var query = ""
    @State private var replacement = ""
    @State private var replacementEnabled = false
    @State private var scope: SearchScope = .section
    @State private var results: [SearchMatch] = []
    @State private var currentIndex = 0
    @State private var saveErrorMessage: String?
    @FocusState private var queryFocused: Bool

    private var currentMatch: SearchMatch? {
        guard results.indices.contains(currentIndex) else { return nil }
        return results[currentIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("查找與替換").font(.headline)
                Spacer()
                Text(resultSummary).font(.caption).foregroundStyle(.secondary)
            }

            TextField("查找文字", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($queryFocused)
                .onSubmit { advanceSearch() }

            Toggle("啟用替換", isOn: $replacementEnabled).disabled(bookIsReadOnly)

            if replacementEnabled {
                TextField("替換為", text: $replacement)
                    .disabled(bookIsReadOnly)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { advanceSearch() }
            }

            Picker("查找範圍", selection: $scope) {
                ForEach(SearchScope.allCases) { scope in
                    Text(scope == .section ? "本\(sectionUnit.unitLabel)" : scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button("上一筆") { reveal(offset: -1) }
                Button("下一筆") { reveal(offset: 1) }
                Spacer()
                if replacementEnabled {
                    Button("替換") { replaceCurrent() }
                        .disabled(bookIsReadOnly || currentMatch == nil)
                    Button("全部替換") { replaceAll() }
                        .disabled(bookIsReadOnly || results.isEmpty)
                }
            }

            if let currentMatch, scope == .book {
                Text("目前：\(sectionUnit.displayTitle(currentMatch.section.title))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 360)
        .onAppear {
            bridge.isSearchMode = true
            queryFocused = true
            refresh()
        }
        .onDisappear {
            bridge.isSearchMode = false
        }
        .alert("無法儲存替換內容", isPresented: saveErrorBinding) {
            Button(SailuneActionCopy.acknowledge) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "未知錯誤")
        }
        .onReceive(NotificationCenter.default.publisher(for: .sailuneFindNext)) { _ in
            advanceSearch()
        }
        .onChange(of: query) { _, _ in refresh() }
        .onChange(of: scope) { _, _ in refresh() }
        .onChange(of: selectedSection?.id) { _, _ in
            if scope == .section { refresh() }
        }
    }

    private var resultSummary: String {
        results.isEmpty ? "沒有結果" : "\(currentIndex + 1) / \(results.count)"
    }

    private func refresh() {
        let sections: [Section]
        if scope == .section, let selectedSection {
            sections = [selectedSection]
        } else if scope == .book {
            sections = orderedSections(in: book)
        } else {
            sections = []
        }

        results = sections.flatMap { section in
            matches(in: plainText(of: section), query: query).map { SearchMatch(section: section, range: $0) }
        }
        currentIndex = min(currentIndex, max(0, results.count - 1))
    }

    private func refreshAndRevealFirst() {
        refresh()
        guard !results.isEmpty else { return }
        currentIndex = 0
        revealCurrent()
    }

    private func advanceSearch() {
        if results.isEmpty {
            refreshAndRevealFirst()
        } else {
            reveal(offset: 1)
        }
    }

    private func reveal(offset: Int) {
        guard !results.isEmpty else { return }
        currentIndex = (currentIndex + offset + results.count) % results.count
        revealCurrent()
    }

    private func revealCurrent() {
        guard let match = currentMatch else { return }
        if selectedSection?.id != match.section.id {
            selectedSection = match.section
        }
        bridge.requestSelect(sectionID: match.section.id, range: match.range)
    }

    private func replaceCurrent() {
        guard !bookIsReadOnly, let match = currentMatch else { return }
        let snapshot = SearchReplaceSnapshot(section: match.section)
        let delta = replace(match, with: replacement)
        guard persistReplacement(delta: delta, snapshots: [snapshot]) else { return }
        if selectedSection?.id == match.section.id { bridge.reloadVisibleContent() }
        refresh()
        currentIndex = min(currentIndex, max(0, results.count - 1))
        revealCurrent()
    }

    private func replaceAll() {
        guard !bookIsReadOnly else { return }
        let matchesToReplace = results
        var snapshotsBySectionID: [UUID: SearchReplaceSnapshot] = [:]
        for match in matchesToReplace where snapshotsBySectionID[match.section.id] == nil {
            snapshotsBySectionID[match.section.id] = SearchReplaceSnapshot(section: match.section)
        }
        // 同一節次的範圍來自替換前的文字，必須由後往前替換才不會因長度變化而偏移。
        let delta = matchesToReplace.reversed().reduce(into: 0) { total, match in
            total += replace(match, with: replacement)
        }
        guard persistReplacement(delta: delta, snapshots: Array(snapshotsBySectionID.values)) else { return }
        if let selectedSection, matchesToReplace.contains(where: { $0.section.id == selectedSection.id }) {
            bridge.reloadVisibleContent()
        }
        refresh()
    }

    private func persistReplacement(delta: Int, snapshots: [SearchReplaceSnapshot]) -> Bool {
        guard !bookIsReadOnly else { return false }
        do {
            try modelContext.save()
        } catch {
            snapshots.forEach { $0.restore() }
            saveErrorMessage = error.localizedDescription
            return false
        }
        do {
            try writingStatsStore.recordSuccessfulEdits([(bookID: book.id, netWordDelta: delta)])
        } catch {
            // Store exposes the save error and leaves this book's statistics blank.
        }
        return true
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )
    }
}

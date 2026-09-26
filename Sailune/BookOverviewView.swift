import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Foundation
import AppKit

// MARK: - 拖曳層級標記
enum DragKind: Equatable {
    case volume(UUID)
    case section(UUID, volumeID: UUID)
}

enum OutlineRowID: Hashable {
    case volume(UUID)
    case section(UUID, volumeID: UUID)
}

enum DropInsertionSide: Equatable {
    case before
    case after
}

struct OutlineDropTarget: Equatable {
    let rowID: OutlineRowID
    let side: DropInsertionSide
}

private struct OutlineGestureRowModifier: ViewModifier {
    let rowID: OutlineRowID
    let coordinateSpace: String
    let dropTarget: OutlineDropTarget?
    @Binding var rowFrames: [OutlineRowID: CGRect]

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .named(coordinateSpace))
            } action: { frame in
                if rowFrames[rowID] != frame {
                    rowFrames[rowID] = frame
                }
            }
            .onDisappear { rowFrames.removeValue(forKey: rowID) }
            .overlay(alignment: dropTarget?.side == .after ? .bottom : .top) {
                if dropTarget?.rowID == rowID {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.accentColor)
                        .frame(height: 3)
                        .padding(.horizontal, 4)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func outlineGestureRow(
        id: OutlineRowID,
        coordinateSpace: String,
        dropTarget: OutlineDropTarget?,
        rowFrames: Binding<[OutlineRowID: CGRect]>
    ) -> some View {
        modifier(OutlineGestureRowModifier(
            rowID: id,
            coordinateSpace: coordinateSpace,
            dropTarget: dropTarget,
            rowFrames: rowFrames
        ))
    }
}

// MARK: - 刪除確認用的列舉
enum DeleteTarget: Identifiable {
    case volume(Volume)
    case section(Section)
    var id: UUID {
        switch self {
        case .volume(let v): return v.id
        case .section(let s): return s.id
        }
    }
}

// MARK: - 書本總覽畫面 (PRD 3.2)
struct BookOverviewView: View {
    @Bindable var book: Book
    @Environment(BookPublicationStore.self) private var publicationStore
    @State private var sectionToOpen: Section?
    @State private var isEditingBackground = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HSplitView {
                    BookInfoPanel(book: book, onOpenBackground: { isEditingBackground = true })
                        .frame(minWidth: 300, idealWidth: 350, maxWidth: 450)
                    VolumeSectionTreeView(book: book, onSelectSection: openEditor)
                        .frame(minWidth: 300, idealWidth: 400)
                }

                if isEditingBackground {
                    backgroundOverlay(in: proxy.size)
                        .zIndex(1)
                }
            }
        }
        .navigationTitle(book.title)
        .navigationSubtitle("書籍總覽")
        .environment(\.bookIsReadOnly, publicationStore.status(for: book.id) == .completed)
        .navigationDestination(item: $sectionToOpen) { section in
            EditorWorkspaceView(book: book, initialSection: section)
        }
    }

    private func openEditor(_ section: Section) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            sectionToOpen = section
        }
    }

    @ViewBuilder
    private func backgroundOverlay(in availableSize: CGSize) -> some View {
        let modalWidth = max(320, min(900, availableSize.width - 48))
        let modalHeight = max(360, min(760, availableSize.height - 48))

        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { isEditingBackground = false }

            VStack(spacing: 0) {
                HStack {
                    Text("故事背景")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    SailuneIconButton(symbol: .close, label: SailuneActionCopy.closeStoryBackground) {
                        isEditingBackground = false
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Divider()

                ScrollView {
                    BookBackgroundView(book: book)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: modalWidth, height: modalHeight)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
        }
    }
}

// MARK: - 左側：書本基本資訊面板
struct BookInfoPanel: View {
    @Bindable var book: Book
    let onOpenBackground: () -> Void
    @Environment(StoryPlanningStore.self) private var planningStore
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @State private var showingCoverImporter = false
    @State private var hasCustomCover = false
    @State private var coverOperationError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 14) {
                    BookCoverArtwork(book: book)
                        .frame(width: 112, height: 158)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("更換封面…", systemImage: SailuneSymbol.imageAsset.systemName) {
                                showingCoverImporter = true
                            }
                            .disabled(bookIsReadOnly)
                            if hasCustomCover {
                                Divider()
                                Button(role: .destructive) {
                                    removeCover()
                                } label: {
                                    Label("移除封面", systemImage: SailuneSymbol.removeCover.systemName)
                                }
                                .disabled(bookIsReadOnly)
                            }
                        }
                        .accessibilityLabel("書籍封面")
                        .accessibilityHint("按右鍵可更換封面")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("書名").font(.subheadline).foregroundStyle(.secondary)
                        SailuneFormTextField(title: "書名", text: Binding(
                            get: { book.title },
                            set: { book.title = $0; book.updatedAt = Date() }
                        ))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("作者").font(.subheadline).foregroundStyle(.secondary)
                        SailuneFormTextField(title: "作者", text: Binding(
                            get: { book.author },
                            set: { book.author = $0; book.updatedAt = Date() }
                        ))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(bookIsReadOnly)
                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("簡介").font(.headline).foregroundStyle(.secondary)
                    TextField("簡介（選填）", text: Binding(
                        get: { book.synopsis },
                        set: { book.synopsis = $0; book.updatedAt = Date() }
                    ), axis: .vertical).lineLimit(4...8).textFieldStyle(.roundedBorder)
                        .disabled(bookIsReadOnly)
                }
                Divider()
                Button(action: onOpenBackground) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("故事背景")
                                .font(.headline)
                            Spacer()
                            Image(systemName: SailuneSymbol.disclosure.systemName)
                                .foregroundStyle(.secondary)
                        }
                        Text(backgroundSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(SailuneTheme.navigationCardSurface, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("展開並編輯整本書的故事背景")
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("統計").font(.headline).foregroundStyle(.secondary)
                    HStack {
                        Text("全書總字數").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(calculateTotalWords()) 字").fontWeight(.semibold).font(.title3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .background(Color.appBackground)
        .onAppear { hasCustomCover = BookCoverStore.hasCover(for: book) }
        .alert("無法更新封面", isPresented: Binding(
            get: { coverOperationError != nil },
            set: { if !$0 { coverOperationError = nil } }
        )) {
            Button(SailuneActionCopy.acknowledge, role: .cancel) { coverOperationError = nil }
        } message: {
            Text(coverOperationError ?? "")
        }
        .fileImporter(
            isPresented: $showingCoverImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            importCover(from: url)
        }
    }

    private var backgroundSummary: String {
        guard let profile = planningStore.profile(bookID: book.id) else {
            return "尚未設定。展開後可填寫世界背景、故事前提、主要衝突、主角目標與核心主題。"
        }
        let content = StoryBackgroundContent(storedValue: profile.backgroundText)
        let values = [
            content.worldBackground,
            content.premise,
            content.mainConflict,
            content.protagonistGoal,
            content.coreTheme,
            content.otherBackground
        ]
        let firstValue = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return firstValue ?? "尚未設定。展開後可填寫世界背景、故事前提、主要衝突、主角目標與核心主題。"
    }

    private func importCover(from url: URL) {
        guard !bookIsReadOnly else { return }
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        guard let image = NSImage(contentsOf: url) else {
            coverOperationError = "無法讀取這張圖片；目前封面沒有變更。"
            return
        }
        do {
            try BookCoverStore.save(image: image, for: book)
            hasCustomCover = true
            book.updatedAt = Date()
        } catch {
            coverOperationError = "封面沒有變更。\n\n\(error.localizedDescription)"
        }
    }

    private func removeCover() {
        guard !bookIsReadOnly else { return }
        do {
            try BookCoverStore.removeCover(for: book)
            hasCustomCover = false
            book.updatedAt = Date()
        } catch {
            coverOperationError = "封面沒有變更。\n\n\(error.localizedDescription)"
        }
    }

    private func calculateTotalWords() -> Int {
        var total = 0
        for volume in book.volumes { for section in volume.sections { total += section.wordCount } }
        return total
    }
}

// MARK: - 右側：卷/節目錄樹
struct VolumeSectionTreeView: View {
    let book: Book
    var onSelectSection: ((Section) -> Void)? = nil
    private let dragCoordinateSpace = "book-overview-outline-drag"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.sectionUnit) private var sectionUnit
    @Environment(\.bookIsReadOnly) private var bookIsReadOnly
    @State private var renamingID: UUID? = nil
    @State private var renameBuffer: String = ""
    @FocusState private var renameFocused: Bool
    @State private var collapsedVolumeIDs: Set<UUID> = []
    @State private var deleteTarget: DeleteTarget? = nil
    @State private var undoTarget: DeleteTarget? = nil
    @State private var draggingKind: DragKind?
    @State private var outlineRowFrames: [OutlineRowID: CGRect] = [:]
    @State private var outlineDropTarget: OutlineDropTarget?

    @State private var exportRequest: SailuneExportRequest?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("目錄").font(.headline).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button {
                        let content = ExportManager.exportBookToTXT(book: book, marker: sectionUnit)
                        exportRequest = ExportManager.textExportRequest(defaultName: book.title, content: content)
                    } label: {
                        Label(SailuneActionCopy.exportText, systemImage: SailuneSymbol.exportText.systemName)
                    }
                    Button { exportRequest = EpubExporter.exportRequest(book: book) } label: {
                        Label(SailuneActionCopy.exportEpub, systemImage: SailuneSymbol.exportEpub.systemName)
                    }
                } label: {
                    Label("匯出", systemImage: SailuneSymbol.export.systemName)
                }
                .help("選擇 TXT 或 EPUB 後匯出整本書")
                Button { addVolume() } label: {
                    Label(SailuneActionCopy.addVolume, systemImage: SailuneSymbol.addVolume.systemName).labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless).help(SailuneActionCopy.addVolume)
                .disabled(bookIsReadOnly)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            if book.volumes.isEmpty { emptyStateView } else { listView }
        }
        .background(Color.appBackground)
        .alert("確認刪除",
               isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
               presenting: deleteTarget) { target in
            Button(SailuneActionCopy.cancel, role: .cancel) { }
            Button(SailuneActionCopy.delete, role: .destructive) { performDelete(target) }
        } message: { target in
            switch target {
            case .volume(let v): Text("確定要刪除卷「\(v.title)」嗎？其下所有\(sectionUnit.unitLabel)將一併刪除，且無法復原。")
            case .section(let s): Text("確定要刪除\(sectionUnit.unitLabel)「\(sectionUnit.displayTitle(s.title))」嗎？此操作無法復原。")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let undoTarget {
                HStack(spacing: 12) {
                    Text(deleteSummary(undoTarget))
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Button(SailuneActionCopy.restore) { restore(undoTarget) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(10)
            }
        }
        .sailuneFileExporter(request: $exportRequest)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder").font(.system(size: 36)).foregroundStyle(.tertiary)
            Text("還沒有任何卷").foregroundStyle(.secondary)
            Button("新增第一卷") { addVolume() }.buttonStyle(.borderedProminent).disabled(bookIsReadOnly)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(book.volumes.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { volume in
                    volumeRow(for: volume)
                    Divider()
                    if !collapsedVolumeIDs.contains(volume.id) {
                        if volume.sections.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("這一卷還沒有\(sectionUnit.unitLabel)").font(.subheadline).foregroundStyle(.secondary)
                                Button(SailuneActionCopy.addFirstSection(unit: sectionUnit), systemImage: SailuneSymbol.add.systemName) { addSection(to: volume) }
                                    .buttonStyle(.borderedProminent)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 54).padding(.vertical, 10)
                            Divider()
                        } else {
                            ForEach(volume.sections.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { section in
                                sectionRow(for: section, in: volume)
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .background(Color.appBackground)
        .coordinateSpace(name: dragCoordinateSpace)
    }
    
    // MARK: 輔助函數：計算節次序號
    private func sectionIndex(for section: Section, in volume: Volume) -> Int {
        let sortedSections = volume.sections.sorted { $0.sortOrder < $1.sortOrder }
        if let index = sortedSections.firstIndex(where: { $0.id == section.id }) {
            return index + 1
        }
        return 1
    }

    // MARK: 卷的列
    @ViewBuilder
    private func volumeRow(for volume: Volume) -> some View {
        HStack(spacing: 6) {
            dragHandle
                .highPriorityGesture(outlineDragGesture(for: .volume(volume.id)))
            Image(systemName: collapsedVolumeIDs.contains(volume.id) ? "chevron.right" : "chevron.down")
                .font(.caption).foregroundStyle(.secondary).frame(width: 14)
                .contentShape(Rectangle())
                .onTapGesture {
                    commitCurrentRename()
                    toggleVolume(volume.id)
                }
            if renamingID == volume.id {
                renameEditor(commit: { newName in
                    volume.title = newName.isEmpty ? volume.title : newName
                    book.updatedAt = Date()
                })
            } else {
                Text(volume.title).lineLimit(1).fontWeight(.semibold)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture { startRenaming(id: volume.id, currentName: volume.title) }
            }
            Button {
                commitCurrentRename()
                addSection(to: volume)
            } label: { Image(systemName: SailuneSymbol.add.systemName).foregroundStyle(.secondary) }
                .buttonStyle(.borderless).help(SailuneAccessibilityCopy.addSectionInVolume(unit: sectionUnit))
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
                .onTapGesture {
                    commitCurrentRename()
                    toggleVolume(volume.id)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .outlineGestureRow(
            id: .volume(volume.id),
            coordinateSpace: dragCoordinateSpace,
            dropTarget: outlineDropTarget,
            rowFrames: $outlineRowFrames
        )
        .contextMenu {
            Button { addSection(to: volume) } label: { Label(SailuneActionCopy.addSection(unit: sectionUnit), systemImage: SailuneSymbol.addSection.systemName) }
            Button { addVolume() } label: { Label(SailuneActionCopy.addVolume, systemImage: SailuneSymbol.addVolume.systemName) }
            Divider()
            Button(role: .destructive) { deleteTarget = .volume(volume) } label: { Label(SailuneActionCopy.deleteVolume, systemImage: SailuneSymbol.delete.systemName) }
        }
    }

    // MARK: 節的列
    @ViewBuilder
    private func sectionRow(for section: Section, in volume: Volume) -> some View {
        let index = sectionIndex(for: section, in: volume)
        
        HStack(spacing: 6) {
            dragHandle
                .highPriorityGesture(outlineDragGesture(for: .section(section.id, volumeID: volume.id)))
            Image(systemName: SailuneSymbol.sectionDocument.systemName).foregroundStyle(.secondary).frame(width: 14)
                .contentShape(Rectangle())
                .onTapGesture { onSelectSection?(section) }
            if renamingID == section.id {
                renameEditor(commit: { newName in
                    section.title = newName.isEmpty ? section.title : newName
                    section.updatedAt = Date()
                    book.updatedAt = Date()
                })
            } else {
                HStack(spacing: 0) {
                    Text("\(sectionUnit.numberedTitle(index))｜")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            commitCurrentRename()
                            onSelectSection?(section)
                        }
                    Text(sectionUnit.displayTitle(section.title)).lineLimit(1)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture { startRenaming(id: section.id, currentName: sectionUnit.displayTitle(section.title)) }
                }
            }
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
                .onTapGesture {
                    commitCurrentRename()
                    onSelectSection?(section)
                }
        }
        .padding(.leading, 20).padding(.trailing, 12).padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .outlineGestureRow(
            id: .section(section.id, volumeID: volume.id),
            coordinateSpace: dragCoordinateSpace,
            dropTarget: outlineDropTarget,
            rowFrames: $outlineRowFrames
        )
        .contextMenu {
            Button { startRenaming(id: section.id, currentName: sectionUnit.displayTitle(section.title)) } label: { Label(SailuneActionCopy.rename, systemImage: SailuneSymbol.edit.systemName) }
            Button {
                commitCurrentRename()
                addSection(to: volume)
            } label: { Label(SailuneActionCopy.addSection(unit: sectionUnit), systemImage: SailuneSymbol.addSection.systemName) }
            Divider()
            Button(role: .destructive) { deleteTarget = .section(section) } label: { Label(SailuneActionCopy.deleteSection(unit: sectionUnit), systemImage: SailuneSymbol.delete.systemName) }
        }
    }

    // MARK: 拖曳把手
    private var dragHandle: some View {
        Image(systemName: SailuneSymbol.reorderHandle.systemName).font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
            .frame(width: 24, height: 22).contentShape(Rectangle()).help("拖曳以排序")
    }

    // MARK: 改名編輯態
    @ViewBuilder
    private func renameEditor(commit: @escaping (String) -> Void) -> some View {
        HStack(spacing: 4) {
            ZStack(alignment: .leading) {
                Text(renameBuffer.isEmpty ? "名稱" : renameBuffer)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.trailing, 12)
                    .opacity(0)
                TextField("", text: $renameBuffer)
                    .textFieldStyle(.roundedBorder)
                    .focused($renameFocused)
                    .submitLabel(.done)
                    .onAppear { renameFocused = true }
                    .onSubmit { commitAndClose(commit: commit) }
            }
            .frame(minWidth: 60)
            Button { commitAndClose(commit: commit) } label: { Image(systemName: SailuneSymbol.confirm.systemName).foregroundStyle(.green) }
                .buttonStyle(.borderless).help(SailuneAccessibilityCopy.confirmEnter)
            Button { cancelRenaming() } label: { Image(systemName: SailuneSymbol.cancel.systemName).foregroundStyle(.secondary) }
                .buttonStyle(.borderless).help(SailuneActionCopy.cancel)
        }
        .onChange(of: renameFocused) { _, focused in if !focused { commitAndClose(commit: commit) } }
    }
    private func startRenaming(id: UUID, currentName: String) {
        guard !bookIsReadOnly else { return }
        commitCurrentRename()
        renameBuffer = currentName
        renamingID = id
    }
    private func commitCurrentRename() {
        guard !bookIsReadOnly else { cancelRenaming(); return }
        guard let id = renamingID else { return }
        if let volume = book.volumes.first(where: { $0.id == id }) {
            volume.title = renameBuffer.isEmpty ? volume.title : renameBuffer
            book.updatedAt = Date()
        } else if let section = book.volumes.flatMap(\.sections).first(where: { $0.id == id }) {
            section.title = renameBuffer.isEmpty ? section.title : renameBuffer
            section.updatedAt = Date()
            book.updatedAt = Date()
        }
        renamingID = nil
        renameFocused = false
    }
    private func commitAndClose(commit: (String) -> Void) { commit(renameBuffer); renamingID = nil; renameFocused = false }
    private func cancelRenaming() { renamingID = nil; renameFocused = false }

    private func toggleVolume(_ id: UUID) {
        if collapsedVolumeIDs.contains(id) { collapsedVolumeIDs.remove(id) } else { collapsedVolumeIDs.insert(id) }
    }

    private func addVolume() {
        guard !bookIsReadOnly else { return }
        let next = (book.volumes.map(\.sortOrder).max() ?? -1) + 1
        book.volumes.append(Volume(title: "新卷", sortOrder: next, book: book))
        book.updatedAt = Date()
    }
    private func addSection(to volume: Volume) {
        guard !bookIsReadOnly else { return }
        let next = (volume.sections.map(\.sortOrder).max() ?? -1) + 1
        let newSection = Section(title: sectionUnit.draftTitle, sortOrder: next, volume: volume)
        volume.sections.append(newSection)
        book.updatedAt = Date()
        onSelectSection?(newSection)
    }

    private func outlineDragGesture(for kind: DragKind) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(dragCoordinateSpace))
            .onChanged { value in
                if draggingKind != kind { draggingKind = kind }
                let nextTarget = dropTarget(for: kind, y: value.location.y)
                if outlineDropTarget != nextTarget { outlineDropTarget = nextTarget }
            }
            .onEnded { _ in
                finishOutlineDrag()
            }
    }

    private func dropTarget(for kind: DragKind, y: CGFloat) -> OutlineDropTarget? {
        for (rowID, frame) in outlineRowFrames where y >= frame.minY && y <= frame.maxY {
            let isAccepted: Bool
            switch (kind, rowID) {
            case (.volume(let draggedID), .volume(let targetID)):
                isAccepted = draggedID != targetID
            case (.section(let draggedID, let sourceVolumeID), .section(let targetID, let targetVolumeID)):
                isAccepted = sourceVolumeID == targetVolumeID && draggedID != targetID
            default:
                isAccepted = false
            }
            if isAccepted {
                return OutlineDropTarget(rowID: rowID, side: y < frame.midY ? .before : .after)
            }
        }
        return nil
    }

    private func finishOutlineDrag() {
        guard !bookIsReadOnly else { draggingKind = nil; outlineDropTarget = nil; return }
        let kind = draggingKind
        let target = outlineDropTarget
        draggingKind = nil
        outlineDropTarget = nil
        guard let kind, let target else { return }

        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.animation = nil
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                switch (kind, target.rowID) {
                case (.volume(let draggedID), .volume(let targetID)):
                    moveVolume(draggedID: draggedID, relativeTo: targetID, side: target.side)
                case (.section(let draggedID, let volumeID), .section(let targetID, let targetVolumeID))
                    where volumeID == targetVolumeID:
                    guard let volume = book.volumes.first(where: { $0.id == volumeID }) else { return }
                    moveSection(in: volume, draggedID: draggedID, relativeTo: targetID, side: target.side)
                default:
                    break
                }
            }
        }
    }

    private func moveVolume(draggedID: UUID, relativeTo targetID: UUID, side: DropInsertionSide) {
        guard !bookIsReadOnly else { return }
        guard draggedID != targetID else { return }
        var arr = book.volumes.sorted { $0.sortOrder < $1.sortOrder }
        let originalIDs = arr.map(\.id)
        guard let from = arr.firstIndex(where: { $0.id == draggedID }) else { return }
        let item = arr.remove(at: from)
        guard let to = arr.firstIndex(where: { $0.id == targetID }) else { return }
        arr.insert(item, at: side == .before ? to : to + 1)
        guard arr.map(\.id) != originalIDs else { return }
        for (i, v) in arr.enumerated() where v.sortOrder != i { v.sortOrder = i }
        book.updatedAt = Date()
    }
    private func moveSection(in volume: Volume, draggedID: UUID, relativeTo targetID: UUID, side: DropInsertionSide) {
        guard !bookIsReadOnly else { return }
        guard draggedID != targetID else { return }
        var arr = volume.sections.sorted { $0.sortOrder < $1.sortOrder }
        let originalIDs = arr.map(\.id)
        guard let from = arr.firstIndex(where: { $0.id == draggedID }) else { return }
        let item = arr.remove(at: from)
        guard let to = arr.firstIndex(where: { $0.id == targetID }) else { return }
        arr.insert(item, at: side == .before ? to : to + 1)
        guard arr.map(\.id) != originalIDs else { return }
        for (i, s) in arr.enumerated() where s.sortOrder != i { s.sortOrder = i }
        book.updatedAt = Date()
    }

    private func performDelete(_ target: DeleteTarget) {
        guard !bookIsReadOnly else { return }
        undoTarget = target
        switch target {
        case .volume(let v): CrossStoreDeletionCoordinator.stageDeleteVolume(v, in: modelContext)
        case .section(let s): CrossStoreDeletionCoordinator.stageDeleteSection(s, in: modelContext)
        }
        book.updatedAt = Date()
        deleteTarget = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if undoTarget?.id == target.id {
                do { try CrossStoreDeletionCoordinator.commitStagedDeletion(in: modelContext); undoTarget = nil }
                catch { presentPersistenceError(error) }
            }
        }
    }

    private func deleteSummary(_ target: DeleteTarget) -> String {
        switch target {
        case .volume(let volume): return "已刪除卷「\(volume.title)」"
        case .section(let section): return "已刪除\(sectionUnit.unitLabel)「\(sectionUnit.displayTitle(section.title))」"
        }
    }

    private func restore(_ target: DeleteTarget) {
        guard !bookIsReadOnly else { return }
        switch target {
        case .volume(let volume):
            if !book.volumes.contains(where: { $0.id == volume.id }) {
                volume.book = book
                book.volumes.append(volume)
            }
            modelContext.insert(volume)
        case .section(let section):
            guard let volume = section.volume else { return }
            if !volume.sections.contains(where: { $0.id == section.id }) {
                volume.sections.append(section)
            }
            modelContext.insert(section)
            onSelectSection?(section)
        }
        book.updatedAt = Date()
        do { try modelContext.save(); undoTarget = nil }
        catch { modelContext.rollback(); presentPersistenceError(error) }
    }

    private func presentPersistenceError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "目錄資料無法儲存"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}

import SwiftUI
import SwiftData

struct BookTextImportSource: Identifiable {
    let id = UUID()
    let fileName: String
    let data: Data?
    let readError: String?
}

struct BookTextImportOverlay: View {
    let source: BookTextImportSource
    let onCancel: () -> Void
    let onCreated: (UUID) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onCancel)

                BookTextImportForm(source: source, onCancel: onCancel, onCreated: onCreated)
                    .frame(
                        width: min(580, max(360, geometry.size.width - 48)),
                        height: min(720, max(480, geometry.size.height - 48))
                    )
                    .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .zIndex(30)
    }
}

private struct BookTextImportForm: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [AuthorProfile]

    let source: BookTextImportSource
    let onCancel: () -> Void
    let onCreated: (UUID) -> Void

    @State private var selectedMarker: BookTextSectionMarker?
    @State private var parseResult: Result<BookTextImportDocument, BookTextImportError>?
    @State private var isParsing = false
    @State private var title: String
    @State private var author = ""
    @State private var saveError: String?
    @State private var isSaving = false

    init(source: BookTextImportSource, onCancel: @escaping () -> Void, onCreated: @escaping (UUID) -> Void) {
        self.source = source
        self.onCancel = onCancel
        self.onCreated = onCreated
        _title = State(initialValue: URL(fileURLWithPath: source.fileName).deletingPathExtension().lastPathComponent)
    }

    private var parsedDocument: BookTextImportDocument? {
        guard case .success(let document) = parseResult else { return nil }
        return document
    }

    private var parseError: String? {
        if let readError = source.readError { return readError }
        guard case .failure(let error) = parseResult else { return nil }
        return error.localizedDescription
    }

    private var canImport: Bool {
        parsedDocument != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving && !isParsing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("匯入書籍")
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(source.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Picker("節標記用字", selection: $selectedMarker) {
                Text("選擇標記").tag(BookTextSectionMarker?.none)
                ForEach(BookTextSectionMarker.allCases) { marker in
                    Text(marker.label).tag(Optional(marker))
                }
            }
            .pickerStyle(.segmented)
            .disabled(source.data == nil)

            HStack(spacing: 12) {
                SailuneFormTextField(title: "書名", text: $title)
                SailuneFormTextField(title: "作者", text: $author)
            }

            Group {
                if isParsing {
                    ContentUnavailableView {
                        ProgressView()
                    } description: {
                        Text("正在解析 TXT…")
                    }
                } else if let parseError {
                    ContentUnavailableView("無法解析 TXT", systemImage: "doc.questionmark", description: Text(parseError))
                } else if let parsedDocument {
                    importPreview(parsedDocument)
                } else {
                    ContentUnavailableView("選擇節標記", systemImage: "text.alignleft", description: Text("選擇這份 TXT 使用的章、張或節標記。"))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let saveError {
                Text(saveError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(SailuneActionCopy.cancel, action: onCancel)
                    .buttonStyle(.bordered)
                Button(isSaving ? "匯入中…" : "建立並匯入", action: createImportedBook)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canImport)
            }
        }
        .padding(22)
        .onAppear {
            if author.isEmpty {
                author = profiles.first?.penName ?? NSFullUserName()
            }
        }
        .task(id: selectedMarker) {
            guard let selectedMarker, let data = source.data else {
                parseResult = nil
                isParsing = false
                return
            }
            isParsing = true
            let result = await Task.detached(priority: .userInitiated) {
                BookTextImportParser.parse(data: data, marker: selectedMarker)
            }.value
            guard !Task.isCancelled else { return }
            parseResult = result
            isParsing = false
        }
    }

    private func importPreview(_ document: BookTextImportDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("內容預覽")
                .font(.headline)
                .foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(document.volumes.enumerated()), id: \.offset) { volumeIndex, volume in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("第\(chineseNumeral(volumeIndex + 1))卷：\(volume.title)")
                                .font(.headline)
                            ForEach(Array(volume.sections.enumerated()), id: \.offset) { sectionIndex, section in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("第\(chineseNumeral(sectionIndex + 1))\(selectedMarker?.label ?? "節")：\(section.title)")
                                        .font(.subheadline.weight(.semibold))
                                    Text(section.content)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(5)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.leading, 16)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
            .background(SailuneTheme.windowSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private func createImportedBook() {
        guard canImport, let parsedDocument else { return }
        isSaving = true
        saveError = nil
        do {
            let bookID = try BookImportCoordinator.createBook(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                document: parsedDocument,
                in: modelContext.container
            )
            onCreated(bookID)
        } catch {
            isSaving = false
            saveError = "無法建立匯入書籍：\(error.localizedDescription)"
        }
    }

    private func chineseNumeral(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

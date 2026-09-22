import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct MapWorkspaceView: View {
    let book: Book

    @Environment(V5SettingsStore.self) private var settingsStore
    @State private var pdfData: Data?
    @State private var isImporting = false
    @State private var exportRequest: SailuneExportRequest?
    @State private var markerDraft: MapMarkerDraft?
    @State private var errorMessage: String?

    private var placedPlaces: [Place] {
        settingsStore.places(for: book.id).filter {
            guard let x = $0.coordinateX, let y = $0.coordinateY else { return false }
            return x.isFinite && y.isFinite
                && (0...MapCoordinate.maximumX).contains(x)
                && (0...MapCoordinate.maximumY).contains(y)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Menu {
                    ForEach(MapTemplateStyle.allCases) { style in
                        Button(style.title) { exportTemplate(style) }
                    }
                } label: {
                    Label("匯出地圖 PDF", systemImage: "square.and.arrow.up")
                }

                Button { isImporting = true } label: {
                    Label("匯入地圖 PDF", systemImage: "square.and.arrow.down")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            GeometryReader { proxy in
                let bounds = CGRect(origin: .zero, size: proxy.size)
                let availableBounds = bounds.insetBy(dx: 24, dy: 24)
                let mapRect = MapCoordinateTransform.fittedMapRect(in: availableBounds)

                MapSurfaceView(
                    pdfData: pdfData,
                    places: placedPlaces,
                    onCreateMarker: { coordinate in
                        markerDraft = MapMarkerDraft(coordinate: coordinate)
                    },
                    onEditMarker: { place, coordinate in
                        markerDraft = MapMarkerDraft(place: place, coordinate: coordinate)
                    }
                )
                .frame(width: mapRect.width, height: mapRect.height)
                .position(x: mapRect.midX, y: mapRect.midY)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf], allowsMultipleSelection: false) {
            handleImport($0)
        }
        .sheet(item: $markerDraft) { draft in
            MapMarkerEditorView(draft: draft) { name, placeType in
                saveMarker(draft, name: name, placeType: placeType)
            }
        }
        .alert("地圖處理失敗", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
        .onAppear(perform: reloadMap)
        .onReceive(NotificationCenter.default.publisher(for: BookMapPDFStore.didChange)) { notification in
            guard notification.object as? NSUUID == book.id as NSUUID else { return }
            reloadMap()
        }
        .sailuneFileExporter(request: $exportRequest)
    }

    private func exportTemplate(_ style: MapTemplateStyle) {
        do {
            let data = try MapPDFGenerator.templateData(style: style)
            let cleanedTitle = sanitizedFilename(book.title)
            exportRequest = SailuneExportRequest(
                document: SailuneExportDocument(data: data),
                contentType: .pdf,
                defaultFilename: "\(cleanedTitle)-地圖-\(style.title).pdf"
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let sourceURL = try result.get().first
            guard let sourceURL else { return }
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }
            let sourceData = try Data(contentsOf: sourceURL)
            pdfData = try BookMapPDFStore.saveImportedPDF(sourceData, forID: book.id)
        } catch {
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reloadMap() {
        do {
            pdfData = try BookMapPDFStore.pdfData(forID: book.id)
        } catch {
            pdfData = nil
            errorMessage = error.localizedDescription
        }
    }

    private func saveMarker(_ draft: MapMarkerDraft, name: String, placeType: String?) {
        if let placeID = draft.placeID,
           let place = settingsStore.places(for: book.id).first(where: { $0.id == placeID }) {
            settingsStore.updateMapPlace(
                place,
                bookID: book.id,
                name: name,
                placeType: placeType,
                coordinate: draft.coordinate
            )
        } else {
            settingsStore.createMapPlace(
                bookID: book.id,
                name: name,
                placeType: placeType,
                coordinate: draft.coordinate
            )
        }
    }

    private func sanitizedFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Sailune" : cleaned
    }
}

private struct MapSurfaceView: View {
    let pdfData: Data?
    let places: [Place]
    let onCreateMarker: (MapCoordinate) -> Void
    let onEditMarker: (Place, MapCoordinate) -> Void

    var body: some View {
        GeometryReader { proxy in
            let mapRect = CGRect(origin: .zero, size: proxy.size)

            ZStack(alignment: .topLeading) {
                Group {
                    if let pdfData {
                        MapPDFPageView(data: pdfData)
                    } else {
                        Color.white
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { event in
                        guard let coordinate = MapCoordinateTransform.coordinate(
                            for: event.location,
                            in: mapRect
                        ) else { return }
                        onCreateMarker(coordinate)
                    }
                )

                MapCoordinateOverlay()
                    .allowsHitTesting(false)

                ForEach(places) { place in
                    if let x = place.coordinateX, let y = place.coordinateY {
                        let coordinate = MapCoordinate(x: x, y: y)
                        let point = MapCoordinateTransform.viewPoint(for: coordinate, in: mapRect)
                        Button {
                            onEditMarker(place, coordinate)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                Text(place.name.isEmpty ? "未命名地點" : place.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                if let placeType = place.placeType, !placeType.isEmpty {
                                    Text(placeType)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .position(point)
                        .help("\(place.name)（\(Int(coordinate.x)), \(Int(coordinate.y))）")
                    }
                }
            }
            .clipShape(Rectangle())
            .overlay(Rectangle().stroke(.primary.opacity(0.55), lineWidth: 1))
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

private struct MapCoordinateOverlay: View {
    var body: some View {
        ZStack {
            Canvas { context, size in
                var path = Path()
                path.move(to: CGPoint(x: 0.5, y: 0))
                path.addLine(to: CGPoint(x: 0.5, y: size.height - 0.5))
                path.addLine(to: CGPoint(x: size.width, y: size.height - 0.5))
                context.stroke(path, with: .color(.black.opacity(0.7)), lineWidth: 1)

                for index in 0...8 {
                    let x = size.width * CGFloat(index) / 8
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: size.height - 6))
                    tick.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(tick, with: .color(.black.opacity(0.55)), lineWidth: 1)
                }
                for index in 0...6 {
                    let y = size.height * CGFloat(index) / 6
                    var tick = Path()
                    tick.move(to: CGPoint(x: 0, y: y))
                    tick.addLine(to: CGPoint(x: 6, y: y))
                    context.stroke(tick, with: .color(.black.opacity(0.55)), lineWidth: 1)
                }
            }

            VStack {
                HStack {
                    axisLabel("y = 3000")
                    Spacer()
                    axisLabel("(4000, 3000)")
                }
                Spacer()
                HStack {
                    axisLabel("(0, 0)")
                    Spacer()
                    axisLabel("x = 4000")
                }
            }
            .font(.caption2.monospacedDigit())
            .padding(8)
        }
    }

    private func axisLabel(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Color.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct MapMarkerDraft: Identifiable {
    let id = UUID()
    let placeID: UUID?
    let coordinate: MapCoordinate
    let initialName: String
    let initialPlaceType: String

    init(coordinate: MapCoordinate) {
        placeID = nil
        self.coordinate = coordinate
        initialName = ""
        initialPlaceType = "城市"
    }

    init(place: Place, coordinate: MapCoordinate) {
        placeID = place.id
        self.coordinate = coordinate
        initialName = place.name
        initialPlaceType = place.placeType ?? ""
    }
}

private struct MapMarkerEditorView: View {
    let draft: MapMarkerDraft
    let onSave: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var placeType: String
    @FocusState private var nameFocused: Bool

    init(draft: MapMarkerDraft, onSave: @escaping (String, String?) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _name = State(initialValue: draft.initialName)
        _placeType = State(initialValue: draft.initialPlaceType)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.placeID == nil ? "新增地圖標記" : "編輯地圖標記")
                .font(.headline)

            Text("座標：\(Int(draft.coordinate.x)), \(Int(draft.coordinate.y))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            TextField("地點名稱", text: $name)
                .focused($nameFocused)
                .onSubmit(save)
            TextField("地點類型（例如城市）", text: $placeType)

            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                Button("儲存", action: save)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { nameFocused = true }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        let trimmedType = placeType.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmedName, trimmedType.isEmpty ? nil : trimmedType)
        dismiss()
    }
}

private struct MapPDFPageView: NSViewRepresentable {
    let data: Data

    func makeNSView(context: Context) -> MapPDFDrawingView {
        MapPDFDrawingView()
    }

    func updateNSView(_ nsView: MapPDFDrawingView, context: Context) {
        nsView.pdfData = data
    }
}

private final class MapPDFDrawingView: NSView {
    var pdfData: Data? {
        didSet {
            document = pdfData.flatMap(PDFDocument.init(data:))
            page = document?.page(at: 0)
            needsDisplay = true
        }
    }

    /// PDFPage keeps only a weak document relationship; retain the document so
    /// redraws remain supported after SwiftUI releases the temporary Data view.
    private var document: PDFDocument?
    private var page: PDFPage?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.setFill()
        bounds.fill()
        guard let page, let context = NSGraphicsContext.current?.cgContext else { return }
        let pageBounds = page.bounds(for: .mediaBox).standardized
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }
        context.saveGState()
        context.scaleBy(x: bounds.width / pageBounds.width, y: bounds.height / pageBounds.height)
        context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
    }
}

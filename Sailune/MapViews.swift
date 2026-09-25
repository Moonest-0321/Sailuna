import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

private final class MapScrollWheelMonitor {
    private var monitor: Any?
    var isPointerInside = false

    func start(onScroll: @escaping (CGSize, NSEvent.ModifierFlags) -> Bool) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard self?.isPointerInside == true else { return event }
            let delta = CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY)
            return onScroll(delta, event.modifierFlags) ? nil : event
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isPointerInside = false
    }

    deinit { stop() }
}

private struct AdaptiveToolbarLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label(title, systemImage: systemImage)
            Image(systemName: systemImage)
        }
        .accessibilityLabel(title)
    }
}

struct MapWorkspaceView: View {
    let book: Book
    @Binding var viewport: MapViewport
    let onOpenPlaceSettings: (UUID) -> Void

    @Environment(V5SettingsStore.self) private var settingsStore
    @State private var pdfData: Data?
    @State private var isImporting = false
    @State private var exportRequest: SailuneExportRequest?
    @State private var markerDraft: MapMarkerDraft?
    @State private var errorMessage: String?
    @State private var viewportSize: CGSize = .zero
    @State private var magnifyStartViewport: MapViewport?
    @State private var panStartViewport: MapViewport?
    @State private var scrollWheelMonitor = MapScrollWheelMonitor()
    @State private var isDraggingMarker = false
    @State private var selectedLevel: MapLevel = .overview
    @State private var selectedMapID: UUID?
    @State private var selectedVersionID: UUID?
    @State private var isManagingMaps = false
    @State private var isManagingVersions = false
    @State private var viewportsByMapID: [UUID: MapViewport] = [:]

    private var visibleMaps: [BookMap] { settingsStore.maps(for: book.id, level: selectedLevel) }
    private var currentMap: BookMap? { visibleMaps.first { $0.id == selectedMapID } }
    private var currentVersions: [BookMapVersion] { currentMap.map(settingsStore.versions) ?? [] }
    private var currentVersion: BookMapVersion? { currentVersions.first { $0.id == selectedVersionID } }
    private var markerRecords: [MapMarkerRecord] {
        currentMap.map(settingsStore.markerRecords) ?? []
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button { adjustZoom(by: -1) } label: {
                Image(systemName: "minus")
            }
            .help("縮小 25%")
            .disabled(viewport.zoom <= MapViewport.minimumZoom)

            Button { resetViewport() } label: {
                Text(zoomPercentage)
                    .monospacedDigit()
                    .frame(minWidth: 44)
            }
            .help("回到 100%")

            Button { adjustZoom(by: 1) } label: {
                Image(systemName: SailuneSymbol.zoomIn.systemName)
            }
            .help("放大 25%")
            .disabled(viewport.zoom >= MapViewport.maximumZoom)

            Button { resetViewport() } label: {
                Text("=")
            }
            .help(SailuneAccessibilityCopy.fitWindow)
            .accessibilityLabel(SailuneAccessibilityCopy.fitWindow)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var layerControls: some View {
        if selectedLevel.supportsMultipleVersions, let currentMap {
            HStack(spacing: 3) {
                Picker("圖層", selection: $selectedVersionID) {
                    ForEach(settingsStore.versions(for: currentMap)) { version in
                        Text(version.name).tag(Optional(version.id))
                    }
                }
                .labelsHidden()
                .frame(minWidth: 110, maxWidth: 160)
                .onChange(of: selectedVersionID) { _, _ in reloadMap() }

                Button { isManagingVersions = true } label: {
                    Image(systemName: SailuneSymbol.mapStack.systemName)
                }
                .help(SailuneAccessibilityCopy.manageLayers)
                .accessibilityLabel(SailuneAccessibilityCopy.manageLayers)
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.primary)
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
                    Label("匯出地圖 PDF", systemImage: SailuneSymbol.export.systemName)
                }
                .help("匯出地圖 PDF")

                Button { isImporting = true } label: {
                    AdaptiveToolbarLabel("匯入地圖", systemImage: "square.and.arrow.down")
                }
                .help("匯入地圖")
                .disabled(currentMap == nil || currentVersion == nil)

                Spacer(minLength: 12)

                HStack(spacing: 2) {
                    Picker("層級", selection: $selectedLevel) {
                        ForEach(MapLevel.allCases) { level in Text(level.title).tag(level) }
                    }
                    .labelsHidden()
                    .fixedSize(horizontal: true, vertical: false)
                    .onChange(of: selectedLevel) { _, _ in
                        if !visibleMaps.contains(where: { $0.id == selectedMapID }) { selectFirstMap() }
                    }

                    Picker("地圖", selection: Binding(
                        get: { selectedMapID },
                        set: { selectMap($0) }
                    )) {
                        if visibleMaps.isEmpty { Text("尚無地圖").tag(UUID?.none) }
                        ForEach(visibleMaps) { map in Text(map.name).tag(Optional(map.id)) }
                    }
                    .labelsHidden()
                    .fixedSize(horizontal: true, vertical: false)

                    Button { isManagingMaps = true } label: {
                        Image(systemName: SailuneSymbol.mapStack.systemName)
                    }
                    .help(SailuneAccessibilityCopy.manageMaps)
                    .accessibilityLabel(SailuneAccessibilityCopy.manageMaps)
                }

                Button { markerDraft = MapMarkerDraft() } label: {
                    Image(systemName: "mappin")
                }
                .help(SailuneAccessibilityCopy.enterCoordinates)
                .accessibilityLabel(SailuneAccessibilityCopy.enterCoordinates)
                .disabled(currentMap == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(SailuneTheme.windowSurface)
            .zIndex(1)

            Divider()

            GeometryReader { proxy in
                let bounds = CGRect(origin: .zero, size: proxy.size)
                let availableBounds = bounds.insetBy(dx: 24, dy: 24)
                let viewportRect = MapCoordinateTransform.fittedMapRect(in: availableBounds)
                let mapRect = viewport.mapRect(in: availableBounds)

                ZStack(alignment: .topLeading) {
                    Color(nsColor: .windowBackgroundColor)

                    ZStack(alignment: .topLeading) {
                        Color(nsColor: .windowBackgroundColor)

                        MapSurfaceView(
                            pdfData: pdfData,
                            markers: markerRecords,
                            zoom: viewport.zoom,
                            selectedPlaceID: markerDraft?.placeID,
                            onCreateMarker: { coordinate in
                                markerDraft = MapMarkerDraft(coordinate: coordinate)
                            },
                            onEditMarker: { marker in
                                markerDraft = MapMarkerDraft(marker: marker)
                            },
                            onMoveMarker: moveMarker,
                            onMarkerDragChanged: { isDragging in
                                isDraggingMarker = isDragging
                            }
                        )
                        .frame(width: mapRect.width, height: mapRect.height)
                        .offset(
                            x: mapRect.minX - viewportRect.minX,
                            y: mapRect.minY - viewportRect.minY
                        )
                    }
                    .frame(width: viewportRect.width, height: viewportRect.height, alignment: .topLeading)
                    .clipShape(Rectangle())
                    // Visual clipping does not constrain SwiftUI hit testing. Keep the
                    // enlarged map content from receiving clicks in the toolbar/letterbox.
                    .contentShape(.interaction, Rectangle())
                    .overlay(Rectangle().stroke(.primary.opacity(0.55), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .position(x: viewportRect.midX, y: viewportRect.midY)
                    .simultaneousGesture(panGesture(in: availableBounds))
                    .simultaneousGesture(magnifyGesture(in: availableBounds))
                    .onHover { isInside in
                        scrollWheelMonitor.isPointerInside = isInside
                    }
                }
            }
            .contentShape(.interaction, Rectangle())
            .clipped()
            .background(SailuneTheme.windowSurface)
            .zIndex(0)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                viewportSize = size
                constrainViewport(to: availableBounds(for: size))
            }

            Divider()

            HStack {
                zoomControls
                Spacer()
                layerControls
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(SailuneTheme.windowSurface)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: false
        ) {
            handleImport($0)
        }
        .sheet(item: $markerDraft) { draft in
            MapMarkerEditorView(
                draft: draft,
                onSave: { name, placeType, coordinate in
                    saveMarker(draft, name: name, placeType: placeType, coordinate: coordinate)
                },
                onDelete: draft.placeID == nil ? nil : {
                    deleteMarker(draft)
                },
                onOpenSettings: draft.placeID.map { placeID in
                    {
                        markerDraft = nil
                        DispatchQueue.main.async {
                            onOpenPlaceSettings(placeID)
                        }
                    }
                },
                destinationTitle: selectedLevel.destinationLevel.map { "前往\($0.title)地圖" },
                onNavigate: draft.placeID == nil ? nil : {
                    try navigateFromMarker(draft)
                }
            )
        }
        .sheet(isPresented: $isManagingMaps) {
            MapManagementView(
                bookID: book.id,
                selectedLevel: $selectedLevel,
                selectedMapID: $selectedMapID,
                onSelectionChanged: synchronizeSelection
            )
        }
        .sheet(isPresented: $isManagingVersions) {
            if let currentMap {
                MapVersionManagementView(
                    map: currentMap,
                    selectedVersionID: $selectedVersionID,
                    onSelectionChanged: synchronizeVersionSelection
                )
            }
        }
        .alert("地圖處理失敗", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(SailuneActionCopy.acknowledge, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "未知錯誤")
        }
        .onAppear(perform: bootstrapMapCatalog)
        .onAppear {
            scrollWheelMonitor.start { delta, modifiers in
                panWithScrollWheel(delta, modifiers: modifiers)
            }
        }
        .onDisappear { scrollWheelMonitor.stop() }
        .onReceive(NotificationCenter.default.publisher(for: BookMapPDFStore.didChange)) { notification in
            guard notification.object as? NSUUID == book.id as NSUUID else { return }
            reloadMap()
        }
        .sailuneFileExporter(request: $exportRequest)
    }

    private var zoomPercentage: String {
        "\(Int((viewport.zoom * 100).rounded()))%"
    }

    private func availableBounds(for size: CGSize) -> CGRect {
        CGRect(origin: .zero, size: size).insetBy(dx: 24, dy: 24)
    }

    private func adjustZoom(by steps: Int) {
        viewport.zoom(by: steps, in: availableBounds(for: viewportSize))
    }

    private func resetViewport() {
        viewport.reset()
    }

    private func constrainViewport(to bounds: CGRect) {
        viewport.setPan(viewport.pan, in: bounds)
    }

    private func panWithScrollWheel(_ delta: CGSize, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard viewport.zoom > 1 else { return false }
        let usesVerticalWheelForHorizontalPan = modifiers.contains(.shift)
            && abs(delta.width) < abs(delta.height)
        let translation = CGSize(
            width: usesVerticalWheelForHorizontalPan ? delta.height : delta.width,
            height: usesVerticalWheelForHorizontalPan ? 0 : delta.height
        )
        viewport.setPan(
            CGSize(
                width: viewport.pan.width + translation.width,
                height: viewport.pan.height + translation.height
            ),
            in: availableBounds(for: viewportSize)
        )
        return true
    }

    private func panGesture(in bounds: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard viewport.zoom > 1, !isDraggingMarker else { return }
                if panStartViewport == nil { panStartViewport = viewport }
                guard var start = panStartViewport else { return }
                start.setPan(
                    CGSize(
                        width: start.pan.width + value.translation.width,
                        height: start.pan.height + value.translation.height
                    ),
                    in: bounds
                )
                viewport = start
            }
            .onEnded { _ in panStartViewport = nil }
    }

    private func magnifyGesture(in bounds: CGRect) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnifyStartViewport == nil { magnifyStartViewport = viewport }
                guard var start = magnifyStartViewport else { return }
                let anchor = CGPoint(
                    x: bounds.minX + bounds.width * value.startAnchor.x,
                    y: bounds.minY + bounds.height * value.startAnchor.y
                )
                start.setZoom(start.zoom * value.magnification, anchor: anchor, in: bounds)
                viewport = start
            }
            .onEnded { _ in magnifyStartViewport = nil }
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
            let contentType = try sourceURL.resourceValues(forKeys: [.contentTypeKey]).contentType
            guard let contentType else {
                throw MapPDFGenerator.MapPDFError.unsupportedFormat
            }
            pdfData = try BookMapPDFStore.saveImportedMap(
                sourceData,
                contentType: contentType,
                bookID: book.id,
                mapID: try requireCurrentMap().id,
                versionID: try requireCurrentVersion().id
            )
        } catch {
            if (error as NSError).code != NSUserCancelledError {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reloadMap() {
        do {
            guard let currentMap, let currentVersion else { pdfData = nil; return }
            pdfData = try BookMapPDFStore.pdfData(bookID: book.id, mapID: currentMap.id, versionID: currentVersion.id)
        } catch {
            pdfData = nil
            errorMessage = error.localizedDescription
        }
    }

    private func saveMarker(
        _ draft: MapMarkerDraft,
        name: String,
        placeType: String?,
        coordinate: MapCoordinate
    ) {
        guard let currentMap else { return }
        do {
            if draft.placeID != nil || draft.placementID != nil {
                guard let placeID = draft.placeID, let placementID = draft.placementID else {
                    throw MapCatalogError.invalidMarkerSource
                }
                let (place, placement) = try settingsStore.markerSource(
                    placeID: placeID, placementID: placementID, bookID: book.id, on: currentMap
                )
                try settingsStore.updateMapPlace(place, placement: placement, map: currentMap, name: name, placeType: placeType, coordinate: coordinate)
            } else {
                try settingsStore.createMapPlace(bookID: book.id, map: currentMap, name: name, placeType: placeType, coordinate: coordinate)
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func deleteMarker(_ draft: MapMarkerDraft) {
        guard let placeID = draft.placeID else { return }
        do {
            guard let place = try settingsStore.markerPlaceForDeletion(placeID: placeID, bookID: book.id) else {
                throw MapCatalogError.invalidMarkerSource
            }
            try settingsStore.deletePlaceForMap(place, bookID: book.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveMarker(_ marker: MapMarkerRecord, to coordinate: MapCoordinate) {
        guard let currentMap else { return }
        do { try settingsStore.updatePlacement(marker.placement, for: marker.place, on: currentMap, coordinate: coordinate) }
        catch { errorMessage = error.localizedDescription }
    }

    private func navigateFromMarker(_ draft: MapMarkerDraft) throws {
        guard let currentMap, let placeID = draft.placeID, let placementID = draft.placementID
        else { throw MapCatalogError.invalidNavigationSource }
        let (place, placement) = try settingsStore.markerSource(
            placeID: placeID, placementID: placementID, bookID: book.id, on: currentMap,
            missingError: .invalidNavigationSource
        )
        let destination = try settingsStore.destinationMap(for: place, placement: placement, on: currentMap)
        markerDraft = nil
        selectedLevel = MapLevel(rawValue: destination.levelRawValue) ?? selectedLevel
        selectMap(destination.id)
    }

    private func bootstrapMapCatalog() {
        do {
            guard let (map, version) = try settingsStore.ensureDefaultMap(for: book.id) else {
                selectedMapID = nil; selectedVersionID = nil; pdfData = nil; return
            }
            selectedLevel = MapLevel(rawValue: map.levelRawValue) ?? .overview
            selectedMapID = map.id; selectedVersionID = version.id
            reloadMap()
        } catch { errorMessage = error.localizedDescription }
    }

    private func selectFirstMap() {
        selectMap(visibleMaps.first?.id)
    }

    private func selectMap(_ mapID: UUID?) {
        if let selectedMapID { viewportsByMapID[selectedMapID] = viewport }
        selectedMapID = mapID
        if let mapID { viewport = viewportsByMapID[mapID] ?? MapViewport() }
        synchronizeVersionSelection()
    }

    private func synchronizeSelection() {
        if let map = settingsStore.maps(for: book.id).first(where: { $0.id == selectedMapID }) {
            selectedLevel = MapLevel(rawValue: map.levelRawValue) ?? selectedLevel
            selectMap(map.id)
        } else { selectFirstMap() }
    }

    private func synchronizeVersionSelection() {
        guard let currentMap else { selectedVersionID = nil; pdfData = nil; return }
        let versions = settingsStore.versions(for: currentMap)
        if !versions.contains(where: { $0.id == selectedVersionID }) { selectedVersionID = versions.first?.id }
        reloadMap()
    }

    private func requireCurrentMap() throws -> BookMap {
        guard let currentMap else { throw MapCatalogError.invalidBook }; return currentMap
    }

    private func requireCurrentVersion() throws -> BookMapVersion {
        guard let currentVersion else { throw MapCatalogError.invalidBook }; return currentVersion
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
    let markers: [MapMarkerRecord]
    let zoom: CGFloat
    let selectedPlaceID: UUID?
    let onCreateMarker: (MapCoordinate) -> Void
    let onEditMarker: (MapMarkerRecord) -> Void
    let onMoveMarker: (MapMarkerRecord, MapCoordinate) -> Void
    let onMarkerDragChanged: (Bool) -> Void

    var body: some View {
        GeometryReader { proxy in
            let mapRect = CGRect(origin: .zero, size: proxy.size)

            ZStack(alignment: .topLeading) {
                Group {
                    if let pdfData {
                        MapPDFPageView(data: pdfData)
                    } else {
                        Color(red: 0.72, green: 0.72, blue: 0.72)
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

                ForEach(markers) { marker in
                    let coordinate = marker.coordinate
                    let point = MapCoordinateTransform.viewPoint(for: coordinate, in: mapRect)
                    MapMarkerView(
                        place: marker.place,
                        coordinate: coordinate,
                        point: point,
                        mapRect: mapRect,
                        zoom: zoom,
                        isSelected: selectedPlaceID == marker.place.id,
                        onOpen: { onEditMarker(marker) },
                        onMove: { onMoveMarker(marker, $0) },
                        onDragChanged: onMarkerDragChanged
                    )
                    .help(markerHelp(for: marker.place, coordinate: coordinate))
                }
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
    }

    private func markerHelp(for place: Place, coordinate: MapCoordinate) -> String {
        let type = place.placeType.flatMap { $0.isEmpty ? nil : $0 } ?? "未分類"
        return "\(place.name)・\(type)（\(Int(coordinate.x)), \(Int(coordinate.y))）"
    }
}

private struct MapMarkerView: View {
    let place: Place
    let coordinate: MapCoordinate
    let point: CGPoint
    let mapRect: CGRect
    let zoom: CGFloat
    let isSelected: Bool
    let onOpen: () -> Void
    let onMove: (MapCoordinate) -> Void
    let onDragChanged: (Bool) -> Void

    @State private var isHovered = false
    @State private var dragTranslation: CGSize = .zero
    @State private var previewCoordinate: MapCoordinate?
    @State private var didCompleteDrag = false

    private var showsName: Bool {
        MapMarkerPresentation.showsName(
            zoom: zoom,
            isHovered: isHovered,
            isSelected: isSelected
        )
    }

    var body: some View {
        Button {
            guard !didCompleteDrag else { return }
            onOpen()
        } label: {
            HStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(Color.red.opacity(0.85), lineWidth: 1)
                            .frame(width: 12, height: 12)
                    }
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                }
                .frame(width: 24, height: 24)

                if showsName || previewCoordinate != nil {
                    markerLabel
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        // The HStack's leading 24 pt cell is anchored so the dot center remains
        // exactly on the projected world coordinate while the label grows rightward.
        .offset(
            x: point.x - 12 + dragTranslation.width,
            y: point.y - 12 + dragTranslation.height
        )
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
            case .ended:
                isHovered = false
            }
        }
        .highPriorityGesture(markerDragGesture)
    }

    @ViewBuilder
    private var markerLabel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(place.name.isEmpty ? "未命名地點" : place.name)
                .font(.caption2.weight(.semibold))
            if let previewCoordinate {
                Text("X: \(Int(previewCoordinate.x.rounded()))  Y: \(Int(previewCoordinate.y.rounded()))")
                    .font(.caption2.monospacedDigit())
            }
        }
        .foregroundStyle(Color.black)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 4))
    }

    private var markerDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                onDragChanged(true)
                dragTranslation = value.translation
                previewCoordinate = MapCoordinateTransform.clampedCoordinate(
                    for: CGPoint(
                        x: point.x + value.translation.width,
                        y: point.y + value.translation.height
                    ),
                    in: mapRect
                )
            }
            .onEnded { value in
                let destination = CGPoint(
                    x: point.x + value.translation.width,
                    y: point.y + value.translation.height
                )
                if let coordinate = MapCoordinateTransform.clampedCoordinate(for: destination, in: mapRect) {
                    onMove(coordinate)
                }
                dragTranslation = .zero
                previewCoordinate = nil
                onDragChanged(false)
                didCompleteDrag = true
                DispatchQueue.main.async { didCompleteDrag = false }
            }
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
    let placementID: UUID?
    let initialCoordinate: MapCoordinate?
    let initialName: String
    let initialPlaceType: String

    init() {
        placeID = nil
        placementID = nil
        initialCoordinate = nil
        initialName = ""
        initialPlaceType = "城市"
    }

    init(coordinate: MapCoordinate) {
        placeID = nil
        placementID = nil
        initialCoordinate = coordinate
        initialName = ""
        initialPlaceType = "城市"
    }

    init(marker: MapMarkerRecord) {
        placeID = marker.place.id
        placementID = marker.placement.id
        initialCoordinate = marker.coordinate
        initialName = marker.place.name
        initialPlaceType = marker.place.placeType ?? ""
    }
}

private struct MapMarkerEditorView: View {
    let draft: MapMarkerDraft
    let onSave: (String, String?, MapCoordinate) -> Void
    let onDelete: (() -> Void)?
    let onOpenSettings: (() -> Void)?
    let destinationTitle: String?
    let onNavigate: (() throws -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var placeType: String
    @State private var xCoordinate: String
    @State private var yCoordinate: String
    @State private var showingDeleteConfirmation = false
    @State private var navigationError: String?
    @FocusState private var nameFocused: Bool

    init(
        draft: MapMarkerDraft,
        onSave: @escaping (String, String?, MapCoordinate) -> Void,
        onDelete: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        destinationTitle: String? = nil,
        onNavigate: (() throws -> Void)? = nil
    ) {
        self.draft = draft
        self.onSave = onSave
        self.onDelete = onDelete
        self.onOpenSettings = onOpenSettings
        self.destinationTitle = destinationTitle
        self.onNavigate = onNavigate
        _name = State(initialValue: draft.initialName)
        _placeType = State(initialValue: draft.initialPlaceType)
        _xCoordinate = State(initialValue: draft.initialCoordinate.map { String(Int($0.x.rounded())) } ?? "")
        _yCoordinate = State(initialValue: draft.initialCoordinate.map { String(Int($0.y.rounded())) } ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsedCoordinate: MapCoordinate? {
        MapCoordinateInput.parse(x: xCoordinate, y: yCoordinate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.placeID == nil ? "新增地圖標記" : "編輯地圖標記")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("座標")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    TextField("X（0–4000）", text: $xCoordinate)
                    TextField("Y（0–3000）", text: $yCoordinate)
                }
                .textFieldStyle(.roundedBorder)
                .font(.body.monospacedDigit())

                if parsedCoordinate == nil {
                    Text("X 需為 0–4000、Y 需為 0–3000 的整數")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            TextField("地點名稱", text: $name)
                .focused($nameFocused)
                .onSubmit(save)
            TextField("地點類型（例如城市）", text: $placeType)

            if let destinationTitle, let onNavigate {
                Button(destinationTitle) {
                    do {
                        try onNavigate()
                        dismiss()
                    } catch {
                        navigationError = error.localizedDescription
                    }
                }
            }

            if let navigationError {
                Text(navigationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                if onDelete != nil {
                    Button(SailuneActionCopy.deletePlace, role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
                if let onOpenSettings {
                    Button {
                        onOpenSettings()
                        dismiss()
                    } label: {
                        Label("前往地點設定", systemImage: "arrow.up.forward.square")
                    }
                }
                Spacer()
                Button(SailuneActionCopy.cancel, role: .cancel) { dismiss() }
                Button(SailuneActionCopy.save, action: save)
                    .disabled(trimmedName.isEmpty || parsedCoordinate == nil)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { nameFocused = true }
        .alert("刪除地點「\(trimmedName.isEmpty ? "未命名地點" : trimmedName)」？", isPresented: $showingDeleteConfirmation) {
            Button(SailuneActionCopy.cancel, role: .cancel) {}
            Button(SailuneActionCopy.delete, role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("此地點會從地圖與設定集中永久刪除，且無法復原。")
        }
    }

    private func save() {
        guard !trimmedName.isEmpty, let parsedCoordinate else { return }
        let trimmedType = placeType.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmedName, trimmedType.isEmpty ? nil : trimmedType, parsedCoordinate)
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

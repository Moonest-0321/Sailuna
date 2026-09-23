import AppKit
import PDFKit
import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import Sailune

@MainActor
final class MapV7Tests: XCTestCase {
    func testWorkspaceModesAreAClosedMutuallyExclusiveSet() {
        XCTAssertEqual(EditorWorkspaceMode.allCases, [.writing, .planning, .map])
        XCTAssertEqual(Set(EditorWorkspaceMode.allCases.map(\.title)), ["編輯", "大綱", "地圖"])
        XCTAssertEqual(
            EditorWorkspaceMode.allCases.map(\.systemImage),
            ["text.book.closed", "rectangle.3.group", "map"]
        )
    }

    func testViewportZoomStepsClampAndReset() {
        let bounds = CGRect(x: 24, y: 24, width: 800, height: 600)
        var viewport = MapViewport()

        viewport.zoom(by: 1, in: bounds)
        XCTAssertEqual(viewport.zoom, 1.25)
        viewport.setZoom(20, anchor: CGPoint(x: bounds.midX, y: bounds.midY), in: bounds)
        XCTAssertEqual(viewport.zoom, MapViewport.maximumZoom)
        viewport.setZoom(0.1, anchor: CGPoint(x: bounds.midX, y: bounds.midY), in: bounds)
        XCTAssertEqual(viewport.zoom, MapViewport.minimumZoom)

        viewport.reset()
        XCTAssertEqual(viewport, MapViewport())
    }

    func testViewportKeepsAnchorOnSameWorldCoordinateWhenZooming() throws {
        let bounds = CGRect(x: 24, y: 24, width: 800, height: 600)
        let anchor = CGPoint(x: 470, y: 310)
        var viewport = MapViewport()
        let before = try XCTUnwrap(MapCoordinateTransform.coordinate(for: anchor, in: viewport.mapRect(in: bounds)))

        viewport.setZoom(2, anchor: anchor, in: bounds)

        let after = try XCTUnwrap(MapCoordinateTransform.coordinate(for: anchor, in: viewport.mapRect(in: bounds)))
        XCTAssertEqual(after.x, before.x, accuracy: 0.0001)
        XCTAssertEqual(after.y, before.y, accuracy: 0.0001)
    }

    func testViewportClampsPanAndCoordinateRoundTripsAfterTransform() throws {
        let bounds = CGRect(x: 24, y: 24, width: 800, height: 600)
        var viewport = MapViewport()
        viewport.setZoom(2, anchor: CGPoint(x: bounds.midX, y: bounds.midY), in: bounds)
        viewport.setPan(CGSize(width: 10_000, height: -10_000), in: bounds)
        let mapRect = viewport.mapRect(in: bounds)

        XCTAssertLessThanOrEqual(mapRect.minX, bounds.minX)
        XCTAssertGreaterThanOrEqual(mapRect.maxX, bounds.maxX)
        XCTAssertLessThanOrEqual(mapRect.minY, bounds.minY)
        XCTAssertGreaterThanOrEqual(mapRect.maxY, bounds.maxY)

        let coordinate = MapCoordinate(x: 2_100, y: 1_400)
        let point = MapCoordinateTransform.viewPoint(for: coordinate, in: mapRect)
        let roundTrip = try XCTUnwrap(MapCoordinateTransform.coordinate(for: point, in: mapRect))
        XCTAssertEqual(roundTrip.x, coordinate.x, accuracy: 0.0001)
        XCTAssertEqual(roundTrip.y, coordinate.y, accuracy: 0.0001)
    }

    func testViewportUsesFixedFourByThreeClipInsideWideWorkspace() {
        let availableBounds = CGRect(x: 24, y: 24, width: 1_200, height: 600)
        let fixedViewport = MapCoordinateTransform.fittedMapRect(in: availableBounds)
        var viewport = MapViewport()

        XCTAssertEqual(fixedViewport.size, CGSize(width: 800, height: 600))
        XCTAssertEqual(viewport.mapRect(in: availableBounds), fixedViewport)

        viewport.setZoom(2, anchor: CGPoint(x: fixedViewport.midX, y: fixedViewport.midY), in: availableBounds)
        viewport.setPan(CGSize(width: 10_000, height: 0), in: availableBounds)
        let contentRect = viewport.mapRect(in: availableBounds)

        XCTAssertEqual(contentRect.width, fixedViewport.width * 2)
        XCTAssertEqual(contentRect.minX, fixedViewport.minX, accuracy: 0.0001)
        XCTAssertEqual(fixedViewport.minX, 224, accuracy: 0.0001)
        XCTAssertGreaterThan(fixedViewport.minX, availableBounds.minX)
    }

    func testMarkerNameUsesSemanticZoomThreshold() {
        XCTAssertFalse(MapMarkerPresentation.showsName(zoom: 1.49, isHovered: false, isSelected: false))
        XCTAssertTrue(MapMarkerPresentation.showsName(zoom: 1.5, isHovered: false, isSelected: false))
        XCTAssertTrue(MapMarkerPresentation.showsName(zoom: 1, isHovered: true, isSelected: false))
        XCTAssertTrue(MapMarkerPresentation.showsName(zoom: 1, isHovered: false, isSelected: true))
    }

    func testDraggedMapPointClampsToMapEdges() throws {
        let mapRect = CGRect(x: 100, y: 50, width: 800, height: 600)

        XCTAssertEqual(
            try XCTUnwrap(MapCoordinateTransform.clampedCoordinate(
                for: CGPoint(x: -500, y: 900),
                in: mapRect
            )),
            MapCoordinate(x: 0, y: 0)
        )
        XCTAssertEqual(
            try XCTUnwrap(MapCoordinateTransform.clampedCoordinate(
                for: CGPoint(x: 1_500, y: -300),
                in: mapRect
            )),
            MapCoordinate(x: 4_000, y: 3_000)
        )

        let coordinate = try XCTUnwrap(MapCoordinateTransform.clampedCoordinate(
            for: CGPoint(x: 500, y: 350),
            in: mapRect
        ))
        XCTAssertEqual(coordinate.x, 2_000, accuracy: 0.0001)
        XCTAssertEqual(coordinate.y, 1_500, accuracy: 0.0001)
    }

    func testMovingMapPlaceChangesOnlyItsCoordinatesAndStaysBookScoped() throws {
        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let otherBookID = UUID()
        let place = store.createMapPlace(
            bookID: bookID,
            name: "王都",
            placeType: "城市",
            coordinate: MapCoordinate(x: 100, y: 200)
        )

        store.updateMapPlaceCoordinate(
            place,
            bookID: otherBookID,
            coordinate: MapCoordinate(x: 3_000, y: 2_000)
        )
        XCTAssertEqual(place.coordinateX, 100)
        XCTAssertEqual(place.coordinateY, 200)

        store.updateMapPlaceCoordinate(
            place,
            bookID: bookID,
            coordinate: MapCoordinate(x: 3_000, y: 2_000)
        )
        XCTAssertEqual(place.coordinateX, 3_000)
        XCTAssertEqual(place.coordinateY, 2_000)
        XCTAssertEqual(place.name, "王都")
        XCTAssertEqual(place.placeType, "城市")
    }

    func testBlankAndGridTemplatesAreSinglePageFourByThreePDFs() throws {
        let blankData = try MapPDFGenerator.templateData(style: .blank)
        let gridData = try MapPDFGenerator.templateData(style: .grid)

        for data in [blankData, gridData] {
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(document.pageCount, 1)
            let bounds = try XCTUnwrap(document.page(at: 0)).bounds(for: .mediaBox)
            XCTAssertEqual(bounds.width / bounds.height, 4.0 / 3.0, accuracy: 0.0001)
        }
        XCTAssertNotEqual(blankData, gridData)
    }

    func testWidePDFIsAspectFittedWithWhitePaddingAndNoCrop() throws {
        let sourceData = try makeSolidPDF(size: CGSize(width: 1_600, height: 800), color: .systemRed)
        let normalizedData = try MapPDFGenerator.normalizedMapData(from: sourceData)
        let document = try XCTUnwrap(PDFDocument(data: normalizedData))
        let page = try XCTUnwrap(document.page(at: 0))
        let bounds = page.bounds(for: .mediaBox)

        XCTAssertEqual(bounds.size, MapPDFGenerator.pageSize)
        let bitmap = try render(page: page, size: MapPDFGenerator.pageSize)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 600, y: 450)), resembles: .systemRed)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 600, y: 850)), resembles: .white)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 600, y: 50)), resembles: .white)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 10, y: 450)), resembles: .systemRed)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 1_190, y: 450)), resembles: .systemRed)
    }

    func testMapImportRejectsMultiplePagesAndInvalidData() throws {
        XCTAssertThrowsError(
            try MapPDFGenerator.normalizedMapData(
                from: makeSolidPDF(size: CGSize(width: 400, height: 300), color: .white, pageCount: 2)
            )
        ) { error in
            XCTAssertEqual(error.localizedDescription, MapPDFGenerator.MapPDFError.requiresSinglePage.localizedDescription)
        }
        XCTAssertThrowsError(try MapPDFGenerator.normalizedMapData(from: Data("not pdf".utf8)))
    }

    func testWidePNGIsAspectFittedAndTransparentPixelsBecomeWhite() throws {
        let sourceData = try makeImageData(
            size: CGSize(width: 1_600, height: 800),
            type: .png,
            draw: { context, bounds in
                context.clear(bounds)
                context.setFillColor(NSColor.systemRed.cgColor)
                context.fill(CGRect(x: 0, y: 0, width: 800, height: 800))
            }
        )
        let normalizedData = try MapPDFGenerator.normalizedMapData(from: sourceData, contentType: .png)
        let document = try XCTUnwrap(PDFDocument(data: normalizedData))
        let page = try XCTUnwrap(document.page(at: 0))
        let bitmap = try render(page: page, size: MapPDFGenerator.pageSize)

        XCTAssertEqual(page.bounds(for: .mediaBox).size, MapPDFGenerator.pageSize)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 200, y: 450)), resembles: .systemRed)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 1_000, y: 450)), resembles: .white)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 600, y: 850)), resembles: .white)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 600, y: 50)), resembles: .white)
    }

    func testTallJPEGIsAspectFittedWithSidePadding() throws {
        let sourceData = try makeImageData(
            size: CGSize(width: 400, height: 800),
            type: .jpeg,
            draw: { context, bounds in
                context.setFillColor(NSColor.systemBlue.cgColor)
                context.fill(bounds)
            }
        )
        let normalizedData = try MapPDFGenerator.normalizedMapData(from: sourceData, contentType: .jpeg)
        let document = try XCTUnwrap(PDFDocument(data: normalizedData))
        let page = try XCTUnwrap(document.page(at: 0))
        let bitmap = try render(page: page, size: MapPDFGenerator.pageSize)

        assertColor(try XCTUnwrap(bitmap.colorAt(x: 600, y: 450)), resembles: .systemBlue)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 100, y: 450)), resembles: .white)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 1_100, y: 450)), resembles: .white)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 600, y: 10)), resembles: .systemBlue)
        assertColor(try XCTUnwrap(bitmap.colorAt(x: 600, y: 890)), resembles: .systemBlue)
    }

    func testImageImportRejectsInvalidDataWithoutReplacingStoredMap() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-map-invalid-image-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            BookMapPDFStore.setDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: directory)
        }
        BookMapPDFStore.setDirectoryOverrideForTesting(directory)

        let bookID = UUID()
        let original = try BookMapPDFStore.saveImportedPDF(
            makeSolidPDF(size: CGSize(width: 400, height: 300), color: .systemGreen),
            forID: bookID
        )
        XCTAssertThrowsError(
            try BookMapPDFStore.saveImportedMap(Data("not an image".utf8), contentType: .png, forID: bookID)
        )
        XCTAssertEqual(try BookMapPDFStore.pdfData(forID: bookID), original)
    }

    func testCoordinateInputAcceptsOnlyIntegersInsideMapBounds() throws {
        XCTAssertEqual(MapCoordinateInput.parse(x: "0", y: "0"), MapCoordinate(x: 0, y: 0))
        XCTAssertEqual(
            MapCoordinateInput.parse(x: " 4000 ", y: "3000\n"),
            MapCoordinate(x: 4_000, y: 3_000)
        )
        XCTAssertEqual(MapCoordinateInput.parse(x: "1234", y: "567"), MapCoordinate(x: 1_234, y: 567))
        XCTAssertNil(MapCoordinateInput.parse(x: "", y: "1"))
        XCTAssertNil(MapCoordinateInput.parse(x: "one", y: "1"))
        XCTAssertNil(MapCoordinateInput.parse(x: "1.5", y: "1"))
        XCTAssertNil(MapCoordinateInput.parse(x: "-1", y: "1"))
        XCTAssertNil(MapCoordinateInput.parse(x: "4001", y: "1"))
        XCTAssertNil(MapCoordinateInput.parse(x: "1", y: "3001"))
    }

    func testDeletingPlacedPlaceKeepsOtherPlacesAndBooks() throws {
        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let otherBookID = UUID()
        let target = store.createMapPlace(
            bookID: bookID,
            name: "刪除目標",
            placeType: "城市",
            coordinate: MapCoordinate(x: 100, y: 200)
        )
        let sibling = store.createMapPlace(
            bookID: bookID,
            name: "保留地點",
            placeType: "村莊",
            coordinate: MapCoordinate(x: 300, y: 400)
        )
        let otherBookPlace = store.createMapPlace(
            bookID: otherBookID,
            name: "他書地點",
            placeType: nil,
            coordinate: MapCoordinate(x: 500, y: 600)
        )

        store.deletePlace(target, bookID: otherBookID)
        XCTAssertTrue(store.places(for: bookID).contains { $0.id == target.id })

        store.deletePlace(target, bookID: bookID)

        XCTAssertFalse(store.places(for: bookID).contains { $0.id == target.id })
        XCTAssertTrue(store.places(for: bookID).contains { $0.id == sibling.id })
        XCTAssertTrue(store.places(for: otherBookID).contains { $0.id == otherBookPlace.id })
    }

    func testCoordinateTransformUsesBottomLeftOriginAndRoundTripsAtAnyScale() throws {
        for bounds in [
            CGRect(x: 0, y: 0, width: 800, height: 600),
            CGRect(x: 0, y: 0, width: 1_000, height: 500),
            CGRect(x: 20, y: 30, width: 500, height: 900)
        ] {
            let mapRect = MapCoordinateTransform.fittedMapRect(in: bounds)
            XCTAssertEqual(mapRect.width / mapRect.height, 4.0 / 3.0, accuracy: 0.0001)

            for coordinate in [
                MapCoordinate(x: 0, y: 0),
                MapCoordinate(x: 4_000, y: 3_000),
                MapCoordinate(x: 2_000, y: 1_500),
                MapCoordinate(x: 725, y: 2_640)
            ] {
                let point = MapCoordinateTransform.viewPoint(for: coordinate, in: mapRect)
                let roundTrip = try XCTUnwrap(MapCoordinateTransform.coordinate(for: point, in: mapRect))
                XCTAssertEqual(roundTrip.x, coordinate.x, accuracy: 0.0001)
                XCTAssertEqual(roundTrip.y, coordinate.y, accuracy: 0.0001)
            }
        }

        let mapRect = CGRect(x: 0, y: 0, width: 400, height: 300)
        XCTAssertEqual(MapCoordinateTransform.viewPoint(for: MapCoordinate(x: 0, y: 0), in: mapRect), CGPoint(x: 0, y: 300))
        XCTAssertEqual(MapCoordinateTransform.viewPoint(for: MapCoordinate(x: 4_000, y: 3_000), in: mapRect), CGPoint(x: 400, y: 0))
        XCTAssertNil(MapCoordinateTransform.coordinate(for: CGPoint(x: -1, y: 100), in: mapRect))
    }

    func testReplacingMapPDFDoesNotChangeStoredPlaceCoordinates() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-map-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            BookMapPDFStore.setDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: directory)
        }
        BookMapPDFStore.setDirectoryOverrideForTesting(directory)

        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let place = store.createMapPlace(
            bookID: bookID,
            name: "王都",
            placeType: "城市",
            coordinate: MapCoordinate(x: 1_234, y: 2_345)
        )

        let first = try makeSolidPDF(size: CGSize(width: 400, height: 300), color: .systemBlue)
        let second = try makeImageData(
            size: CGSize(width: 300, height: 600),
            type: .jpeg,
            draw: { context, bounds in
                context.setFillColor(NSColor.systemGreen.cgColor)
                context.fill(bounds)
            }
        )
        try BookMapPDFStore.saveImportedPDF(first, forID: bookID)
        let firstStored = try XCTUnwrap(BookMapPDFStore.pdfData(forID: bookID))
        try BookMapPDFStore.saveImportedMap(second, contentType: .jpeg, forID: bookID)
        let secondStored = try XCTUnwrap(BookMapPDFStore.pdfData(forID: bookID))

        XCTAssertNotEqual(firstStored, secondStored)
        XCTAssertEqual(place.coordinateX, 1_234)
        XCTAssertEqual(place.coordinateY, 2_345)
        try BookMapPDFStore.removeMap(forID: bookID)
        XCTAssertNil(try BookMapPDFStore.pdfData(forID: bookID))
        XCTAssertEqual(place.coordinateX, 1_234)
        XCTAssertEqual(place.coordinateY, 2_345)
    }

    func testV12DefaultMapBackfillsLegacyCoordinatesOnlyOnce() throws {
        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let placed = store.createMapPlace(bookID: bookID, name: "舊王都", placeType: "城市", coordinate: MapCoordinate(x: 800, y: 900))
        _ = store.createPlace(bookID: bookID)

        let first = try XCTUnwrap(store.ensureDefaultMap(for: bookID))
        let second = try XCTUnwrap(store.ensureDefaultMap(for: bookID))

        XCTAssertEqual(first.0.id, second.0.id)
        XCTAssertEqual(first.1.id, second.1.id)
        XCTAssertEqual(store.maps(for: bookID).count, 1)
        XCTAssertEqual(store.versions(for: first.0).count, 1)
        let placements = store.placements(for: first.0)
        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placements.first?.placeID, placed.id)
        XCTAssertEqual(placements.first?.coordinateX, 800)
        XCTAssertEqual(placements.first?.coordinateY, 900)
    }

    func testV11StoreMigratesToV12AndBackfillsDefaultPlacement() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-settings-v12-map-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("settings.store")
        let bookID = UUID(), placeID = UUID()

        do {
            let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: storeURL)])
            container.mainContext.insert(V5SettingsSchemaV11.Place(
                id: placeID,
                bookID: bookID,
                name: "舊地點",
                coordinateX: 1_234,
                coordinateY: 2_345
            ))
            try container.mainContext.save()
        }

        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: storeURL)]
        )
        let store = V5SettingsStore(container: container)
        let map = try XCTUnwrap(store.ensureDefaultMap(for: bookID)).0
        let placement = try XCTUnwrap(store.placements(for: map).first)

        XCTAssertEqual(placement.placeID, placeID)
        XCTAssertEqual(placement.coordinateX, 1_234)
        XCTAssertEqual(placement.coordinateY, 2_345)
        XCTAssertEqual(store.placements(for: map).count, 1)
    }

    func testSamePlaceCanUseDifferentCoordinatesOnIndependentMaps() throws {
        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let firstMap = try XCTUnwrap(store.ensureDefaultMap(for: bookID)).0
        let secondMap = try store.createMap(bookID: bookID, level: .country, name: "北境").0
        let place = try store.createMapPlace(bookID: bookID, map: firstMap, name: "王都", placeType: "城市", coordinate: MapCoordinate(x: 100, y: 200))
        let secondPlacement = MapPlacement(bookID: bookID, mapID: secondMap.id, placeID: place.id, coordinateX: 3_000, coordinateY: 2_500)
        container.mainContext.insert(secondPlacement)
        try container.mainContext.save()

        let firstRecord = try XCTUnwrap(store.markerRecords(for: firstMap).first)
        let secondRecord = try XCTUnwrap(store.markerRecords(for: secondMap).first)
        try store.updatePlacement(firstRecord.placement, for: place, on: firstMap, coordinate: MapCoordinate(x: 400, y: 500))

        XCTAssertEqual(firstRecord.placement.coordinateX, 400)
        XCTAssertEqual(firstRecord.placement.coordinateY, 500)
        XCTAssertEqual(secondRecord.placement.coordinateX, 3_000)
        XCTAssertEqual(secondRecord.placement.coordinateY, 2_500)
        XCTAssertNil(place.coordinateX)
        XCTAssertNil(place.coordinateY)
    }

    func testDeletingMapKeepsPlacesAndDeletingPlaceClearsAllPlacements() throws {
        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let firstMap = try XCTUnwrap(store.ensureDefaultMap(for: bookID)).0
        let secondMap = try store.createMap(bookID: bookID, level: .province, name: "中央省").0
        let place = try store.createMapPlace(bookID: bookID, map: firstMap, name: "中央城", placeType: nil, coordinate: MapCoordinate(x: 100, y: 100))
        container.mainContext.insert(MapPlacement(bookID: bookID, mapID: secondMap.id, placeID: place.id, coordinateX: 200, coordinateY: 200))
        try container.mainContext.save()

        try store.deleteMap(firstMap)
        XCTAssertTrue(store.places(for: bookID).contains { $0.id == place.id })
        XCTAssertEqual(store.placements(for: secondMap).count, 1)

        store.deletePlace(place, bookID: bookID)
        XCTAssertTrue(store.placements(for: secondMap).isEmpty)
    }

    func testMapVersionsHaveIsolatedNestedAssets() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sailune-map-versions-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            BookMapPDFStore.setDirectoryOverrideForTesting(nil)
            try? FileManager.default.removeItem(at: directory)
        }
        BookMapPDFStore.setDirectoryOverrideForTesting(directory)
        let bookID = UUID(), mapID = UUID(), firstVersionID = UUID(), secondVersionID = UUID()
        let blue = try makeSolidPDF(size: CGSize(width: 400, height: 300), color: .systemBlue)
        let green = try makeSolidPDF(size: CGSize(width: 400, height: 300), color: .systemGreen)

        try BookMapPDFStore.saveImportedMap(blue, contentType: .pdf, bookID: bookID, mapID: mapID, versionID: firstVersionID)
        try BookMapPDFStore.saveImportedMap(green, contentType: .pdf, bookID: bookID, mapID: mapID, versionID: secondVersionID)

        XCTAssertNotEqual(
            try BookMapPDFStore.pdfData(bookID: bookID, mapID: mapID, versionID: firstVersionID),
            try BookMapPDFStore.pdfData(bookID: bookID, mapID: mapID, versionID: secondVersionID)
        )
        try BookMapPDFStore.removeVersion(bookID: bookID, mapID: mapID, versionID: firstVersionID)
        XCTAssertNil(try BookMapPDFStore.pdfData(bookID: bookID, mapID: mapID, versionID: firstVersionID))
        XCTAssertNotNil(try BookMapPDFStore.pdfData(bookID: bookID, mapID: mapID, versionID: secondVersionID))
    }

    private func makeSolidPDF(
        size: CGSize,
        color: NSColor,
        pageCount: Int = 1
    ) throws -> Data {
        let output = NSMutableData()
        let consumer = try XCTUnwrap(CGDataConsumer(data: output as CFMutableData))
        var mediaBox = CGRect(origin: .zero, size: size)
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        for _ in 0..<pageCount {
            context.beginPDFPage(nil)
            context.setFillColor(color.cgColor)
            context.fill(mediaBox)
            context.endPDFPage()
        }
        context.closePDF()
        return output as Data
    }

    private func makeImageData(
        size: CGSize,
        type: UTType,
        draw: (CGContext, CGRect) -> Void
    ) throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext)
        draw(context, CGRect(origin: .zero, size: size))
        if type == .png {
            return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        }
        return try XCTUnwrap(bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.95]
        ))
    }

    func testMarkerNavigationCreatesThenKeepsBoundMapAfterRename() throws {
        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(for: schema, migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let province = try store.createMap(bookID: bookID, level: .province, name: "中央省").0
        let place = try store.createMapPlace(bookID: bookID, map: province, name: "王都", placeType: "城市", coordinate: MapCoordinate(x: 100, y: 200))
        let placement = try XCTUnwrap(store.placements(for: province).first)

        let city = try store.destinationMap(for: place, placement: placement, on: province)
        XCTAssertEqual(city.levelRawValue, MapLevel.city.rawValue)
        XCTAssertEqual(city.name, "王都")
        XCTAssertEqual(placement.targetMapID, city.id)
        XCTAssertEqual(store.versions(for: city).count, 1)
        try store.renameMap(city, to: "新王都")
        let again = try store.destinationMap(for: place, placement: placement, on: province)
        XCTAssertEqual(again.id, city.id)
        XCTAssertEqual(store.maps(for: bookID, level: .city).count, 1)

        let district = try store.createMapPlace(bookID: bookID, map: city, name: "舊城區", placeType: nil, coordinate: MapCoordinate(x: 300, y: 400))
        let closeUp = try store.destinationMap(for: district, placement: XCTUnwrap(store.placements(for: city).first), on: city)
        XCTAssertEqual(closeUp.levelRawValue, MapLevel.closeUp.rawValue)
        XCTAssertThrowsError(try store.destinationMap(for: district, placement: MapPlacement(bookID: bookID, mapID: closeUp.id, placeID: district.id, coordinateX: 1, coordinateY: 1), on: closeUp))
    }

    func testMarkerNavigationBindsExistingMapAndRebindsAfterDeletion() throws {
        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let container = try ModelContainer(for: schema, migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let store = V5SettingsStore(container: container)
        let bookID = UUID()
        let source = try store.createMap(bookID: bookID, level: .overview, name: "總體").0
        let existing = try store.createMap(bookID: bookID, level: .city, name: "王都").0
        let place = try store.createMapPlace(bookID: bookID, map: source, name: "王都", placeType: nil, coordinate: MapCoordinate(x: 100, y: 200))
        let placement = try XCTUnwrap(store.placements(for: source).first)

        XCTAssertEqual(try store.destinationMap(for: place, placement: placement, on: source).id, existing.id)
        XCTAssertEqual(store.maps(for: bookID, level: .city).count, 1)
        try store.deleteMap(existing)
        XCTAssertNil(placement.targetMapID)
        XCTAssertEqual(store.places(for: bookID).first?.id, place.id)
        let replacement = try store.destinationMap(for: place, placement: placement, on: source)
        XCTAssertNotEqual(replacement.id, existing.id)
        XCTAssertEqual(replacement.name, "王都")

        let otherBook = try store.createMap(bookID: UUID(), level: .city, name: "別書").0
        placement.targetMapID = otherBook.id
        try container.mainContext.save()
        XCTAssertEqual(try store.destinationMap(for: place, placement: placement, on: source).id, replacement.id)
        XCTAssertThrowsError(try store.destinationMap(for: place, placement: placement, on: otherBook))

        let blank = try store.createMapPlace(bookID: bookID, map: source, name: "   ", placeType: nil, coordinate: MapCoordinate(x: 400, y: 500))
        let blankPlacement = try XCTUnwrap(store.placements(for: source).first { $0.placeID == blank.id })
        XCTAssertThrowsError(try store.destinationMap(for: blank, placement: blankPlacement, on: source))
        XCTAssertEqual(store.maps(for: bookID, level: .city).count, 1)
    }

    func testV12MapPlacementMigratesToV13WithoutChangingCoordinates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Sailune-settings-v13-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("settings.store")
        let bookID = UUID(), mapID = UUID(), placeID = UUID(), placementID = UUID()
        do {
            let oldSchema = Schema(versionedSchema: V5SettingsSchemaV12.self)
            let old = try ModelContainer(for: oldSchema, configurations: [ModelConfiguration(schema: oldSchema, url: url)])
            old.mainContext.insert(V5SettingsSchemaV12.BookMap(id: mapID, bookID: bookID, levelRawValue: MapLevel.province.rawValue, name: "中央省"))
            old.mainContext.insert(V5SettingsSchemaV12.Place(id: placeID, bookID: bookID, name: "王都"))
            old.mainContext.insert(V5SettingsSchemaV12.MapPlacement(id: placementID, bookID: bookID, mapID: mapID, placeID: placeID, coordinateX: 123, coordinateY: 456))
            try old.mainContext.save()
        }
        let schema = Schema(versionedSchema: V5SettingsSchemaV13.self)
        let current = try ModelContainer(for: schema, migrationPlan: V5SettingsMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)])
        let placements = try current.mainContext.fetch(FetchDescriptor<MapPlacement>())
        let placement = try XCTUnwrap(placements.first)
        XCTAssertEqual(placements.count, 1)
        XCTAssertEqual(placement.id, placementID)
        XCTAssertEqual(placement.coordinateX, 123)
        XCTAssertEqual(placement.coordinateY, 456)
        XCTAssertNil(placement.targetMapID)
    }

    private func render(page: PDFPage, size: CGSize) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ))
        let graphicsContext = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        page.draw(with: .mediaBox, to: graphicsContext.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private func assertColor(
        _ actual: NSColor,
        resembles expected: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualRGB = actual.usingColorSpace(.deviceRGB) ?? actual
        let expectedRGB = expected.usingColorSpace(.deviceRGB) ?? expected
        XCTAssertEqual(actualRGB.redComponent, expectedRGB.redComponent, accuracy: 0.08, file: file, line: line)
        XCTAssertEqual(actualRGB.greenComponent, expectedRGB.greenComponent, accuracy: 0.08, file: file, line: line)
        XCTAssertEqual(actualRGB.blueComponent, expectedRGB.blueComponent, accuracy: 0.08, file: file, line: line)
    }
}

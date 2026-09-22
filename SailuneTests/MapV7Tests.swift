import AppKit
import PDFKit
import SwiftData
import XCTest
@testable import Sailune

@MainActor
final class MapV7Tests: XCTestCase {
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

        let schema = Schema(versionedSchema: V5SettingsSchemaV11.self)
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
        let second = try makeSolidPDF(size: CGSize(width: 300, height: 600), color: .systemGreen)
        try BookMapPDFStore.saveImportedPDF(first, forID: bookID)
        let firstStored = try XCTUnwrap(BookMapPDFStore.pdfData(forID: bookID))
        try BookMapPDFStore.saveImportedPDF(second, forID: bookID)
        let secondStored = try XCTUnwrap(BookMapPDFStore.pdfData(forID: bookID))

        XCTAssertNotEqual(firstStored, secondStored)
        XCTAssertEqual(place.coordinateX, 1_234)
        XCTAssertEqual(place.coordinateY, 2_345)
        try BookMapPDFStore.removeMap(forID: bookID)
        XCTAssertNil(try BookMapPDFStore.pdfData(forID: bookID))
        XCTAssertEqual(place.coordinateX, 1_234)
        XCTAssertEqual(place.coordinateY, 2_345)
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

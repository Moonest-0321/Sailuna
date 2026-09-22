import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Stores one normalized map PDF per book outside SwiftData. Coordinates live on
/// Place records, so replacing or removing this background never moves markers.
@MainActor
enum BookMapPDFStore {
    static let didChange = Notification.Name("Sailune.BookMapPDFStore.didChange")
    private static var directoryOverrideForTesting: URL?

    static var backupDirectoryURL: URL { mapsDirectoryURL() }

    /// Keeps map-file tests isolated from the author's Application Support data.
    static func setDirectoryOverrideForTesting(_ directory: URL?) {
        directoryOverrideForTesting = directory
    }

    static func pdfData(forID bookID: UUID) throws -> Data? {
        let mapURL = url(forID: bookID)
        guard FileManager.default.fileExists(atPath: mapURL.path) else { return nil }
        let data = try Data(contentsOf: mapURL)
        guard let document = PDFDocument(data: data), document.pageCount == 1 else {
            throw MapPDFGenerator.MapPDFError.invalidPDF
        }
        return data
    }

    @discardableResult
    static func saveImportedPDF(_ sourceData: Data, forID bookID: UUID) throws -> Data {
        try saveImportedMap(sourceData, contentType: .pdf, forID: bookID)
    }

    @discardableResult
    static func saveImportedMap(
        _ sourceData: Data,
        contentType: UTType,
        forID bookID: UUID
    ) throws -> Data {
        let normalizedData = try MapPDFGenerator.normalizedMapData(
            from: sourceData,
            contentType: contentType
        )
        let directory = try mapsDirectory()
        try normalizedData.write(
            to: directory.appendingPathComponent("\(bookID.uuidString).pdf"),
            options: .atomic
        )
        NotificationCenter.default.post(name: didChange, object: bookID as NSUUID)
        return normalizedData
    }

    static func removeMap(forID bookID: UUID) throws {
        let mapURL = url(forID: bookID)
        if FileManager.default.fileExists(atPath: mapURL.path) {
            try FileManager.default.removeItem(at: mapURL)
        }
        NotificationCenter.default.post(name: didChange, object: bookID as NSUUID)
    }

    private static func url(forID bookID: UUID) -> URL {
        mapsDirectoryURL().appendingPathComponent("\(bookID.uuidString).pdf")
    }

    private static func mapsDirectoryURL() -> URL {
        if let directoryOverrideForTesting { return directoryOverrideForTesting }
        return SailuneDataLocations.current.mapsDirectory
    }

    private static func mapsDirectory() throws -> URL {
        let directory = mapsDirectoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Stores normalized backgrounds outside SwiftData. V12 uses one nested file per
/// map version; the legacy flat file remains readable only during migration.
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
        let mapURL = legacyURL(forID: bookID)
        guard FileManager.default.fileExists(atPath: mapURL.path) else { return nil }
        let data = try Data(contentsOf: mapURL)
        guard let document = PDFDocument(data: data), document.pageCount == 1 else {
            throw MapPDFGenerator.MapPDFError.invalidPDF
        }
        return data
    }

    static func pdfData(bookID: UUID, mapID: UUID, versionID: UUID) throws -> Data? {
        let mapURL = versionURL(bookID: bookID, mapID: mapID, versionID: versionID)
        guard FileManager.default.fileExists(atPath: mapURL.path) else { return nil }
        return try validatedPDFData(at: mapURL)
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

    @discardableResult
    static func saveImportedMap(
        _ sourceData: Data,
        contentType: UTType,
        bookID: UUID,
        mapID: UUID,
        versionID: UUID
    ) throws -> Data {
        let normalizedData = try MapPDFGenerator.normalizedMapData(from: sourceData, contentType: contentType)
        let destination = versionURL(bookID: bookID, mapID: mapID, versionID: versionID)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try normalizedData.write(to: destination, options: .atomic)
        NotificationCenter.default.post(name: didChange, object: bookID as NSUUID)
        return normalizedData
    }

    static func removeMap(forID bookID: UUID) throws {
        let mapURL = legacyURL(forID: bookID)
        if FileManager.default.fileExists(atPath: mapURL.path) {
            try FileManager.default.removeItem(at: mapURL)
        }
        let directory = mapsDirectoryURL().appendingPathComponent(bookID.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        NotificationCenter.default.post(name: didChange, object: bookID as NSUUID)
    }

    static func removeMap(bookID: UUID, mapID: UUID) throws {
        let directory = mapsDirectoryURL()
            .appendingPathComponent(bookID.uuidString, isDirectory: true)
            .appendingPathComponent(mapID.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
        NotificationCenter.default.post(name: didChange, object: bookID as NSUUID)
    }

    static func removeVersion(bookID: UUID, mapID: UUID, versionID: UUID) throws {
        let url = versionURL(bookID: bookID, mapID: mapID, versionID: versionID)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        NotificationCenter.default.post(name: didChange, object: bookID as NSUUID)
    }

    /// Copies before deleting so a failed V12 asset migration always leaves the
    /// original V7 file available for a later retry.
    static func migrateLegacyMapIfNeeded(bookID: UUID, mapID: UUID, versionID: UUID) throws {
        let source = legacyURL(forID: bookID)
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let destination = versionURL(bookID: bookID, mapID: mapID, versionID: versionID)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try validatedPDFData(at: destination)
            try FileManager.default.removeItem(at: source)
            return
        }
        let data = try validatedPDFData(at: source)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        _ = try validatedPDFData(at: destination)
        try FileManager.default.removeItem(at: source)
        NotificationCenter.default.post(name: didChange, object: bookID as NSUUID)
    }

    private static func validatedPDFData(at url: URL) throws -> Data {
        let data = try Data(contentsOf: url)
        guard let document = PDFDocument(data: data), document.pageCount == 1 else {
            throw MapPDFGenerator.MapPDFError.invalidPDF
        }
        return data
    }

    private static func legacyURL(forID bookID: UUID) -> URL {
        mapsDirectoryURL().appendingPathComponent("\(bookID.uuidString).pdf")
    }

    private static func versionURL(bookID: UUID, mapID: UUID, versionID: UUID) -> URL {
        mapsDirectoryURL()
            .appendingPathComponent(bookID.uuidString, isDirectory: true)
            .appendingPathComponent(mapID.uuidString, isDirectory: true)
            .appendingPathComponent("\(versionID.uuidString).pdf")
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

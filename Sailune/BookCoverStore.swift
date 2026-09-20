import AppKit
import Foundation

/// Stores optional custom book covers outside SwiftData so existing libraries
/// remain compatible when the cover feature is introduced.
@MainActor
enum BookCoverStore {
    private static let directoryName = "Sailune/Covers"
    private static let imageCache = NSCache<NSUUID, NSImage>()
    private static var missingCoverIDs = Set<UUID>()
    private static var directoryOverrideForTesting: URL?
    static let didChange = Notification.Name("Sailune.BookCoverStore.didChange")
    static var backupDirectoryURL: URL { coversDirectoryURL() }

    /// Keeps cover-file tests isolated from the author's Application Support directory.
    static func setDirectoryOverrideForTesting(_ directory: URL?) {
        directoryOverrideForTesting = directory
        imageCache.removeAllObjects()
        missingCoverIDs.removeAll()
    }

    static func image(for book: Book) -> NSImage? {
        let key = book.id as NSUUID
        if let cached = imageCache.object(forKey: key) { return cached }
        guard !missingCoverIDs.contains(book.id),
              let image = NSImage(contentsOf: url(for: book)) else {
            missingCoverIDs.insert(book.id)
            return nil
        }
        imageCache.setObject(image, forKey: key)
        return image
    }

    static func hasCover(for book: Book) -> Bool {
        hasCover(forID: book.id)
    }

    static func hasCover(forID bookID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: url(forID: bookID).path)
    }

    /// Reads the persisted PNG directly so exports always use the latest file,
    /// independent of the in-memory artwork cache used by the UI.
    static func pngData(for book: Book) -> Data? {
        guard let data = try? Data(contentsOf: url(for: book)),
              !data.isEmpty,
              NSImage(data: data) != nil else {
            return nil
        }
        return data
    }

    /// Returns the artwork the user actually sees: a custom cover when one is
    /// stored, otherwise the deterministic title-initial cover used by the UI.
    static func displayedCoverPNGData(for book: Book) -> Data? {
        pngData(for: book) ?? defaultCoverPNGData(for: book)
    }

    static func defaultColor(for book: Book) -> NSColor {
        var hash = 0
        for character in book.title.unicodeScalars {
            hash = Int(character.value) &+ (hash << 5) &- hash
        }
        let red = Double((hash >> 16) & 0xFF) / 255.0 * 0.3 + 0.7
        let green = Double((hash >> 8) & 0xFF) / 255.0 * 0.3 + 0.7
        let blue = Double(hash & 0xFF) / 255.0 * 0.3 + 0.7
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }

    private static func defaultCoverPNGData(for book: Book) -> Data? {
        let pixelWidth = 1_200
        let pixelHeight = 1_800
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        defaultColor(for: book).setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        let initial = String(book.title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
        shadow.shadowBlurRadius = 18
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "New York", size: 430) ?? NSFont.systemFont(ofSize: 430, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
            .shadow: shadow
        ]
        let attributedInitial = NSAttributedString(string: initial, attributes: attributes)
        let textSize = attributedInitial.size()
        attributedInitial.draw(in: NSRect(
            x: 0,
            y: (CGFloat(pixelHeight) - textSize.height) / 2,
            width: CGFloat(pixelWidth),
            height: textSize.height
        ))
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }

    static func save(image: NSImage, for book: Book) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CoverStoreError.invalidImage
        }

        let directory = try coversDirectory()
        try pngData.write(to: directory.appendingPathComponent("\(book.id.uuidString).png"), options: .atomic)
        imageCache.setObject(image, forKey: book.id as NSUUID)
        missingCoverIDs.remove(book.id)
        NotificationCenter.default.post(name: didChange, object: book.id as NSUUID)
    }

    static func removeCover(for book: Book) throws {
        try removeCover(forID: book.id)
    }

    static func removeCover(forID bookID: UUID) throws {
        let coverURL = url(forID: bookID)
        if FileManager.default.fileExists(atPath: coverURL.path) {
            try FileManager.default.removeItem(at: coverURL)
        }
        imageCache.removeObject(forKey: bookID as NSUUID)
        missingCoverIDs.insert(bookID)
        NotificationCenter.default.post(name: didChange, object: bookID as NSUUID)
    }

    private static func url(for book: Book) -> URL {
        url(forID: book.id)
    }

    private static func url(forID bookID: UUID) -> URL {
        let directory = coversDirectoryURL()
        return directory.appendingPathComponent("\(bookID.uuidString).png")
    }

    private static func coversDirectoryURL() -> URL {
        if let directoryOverrideForTesting {
            return directoryOverrideForTesting
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func coversDirectory() throws -> URL {
        let directory = coversDirectoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private enum CoverStoreError: LocalizedError {
        case invalidImage

        var errorDescription: String? { "無法讀取這張封面圖片。" }
    }
}

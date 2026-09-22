import AppKit
import Foundation
import PDFKit

enum MapTemplateStyle: String, CaseIterable, Identifiable {
    case blank
    case grid

    var id: Self { self }

    var title: String {
        switch self {
        case .blank: "純白"
        case .grid: "網格"
        }
    }
}

/// Creates the fixed 4:3 map surface and normalizes imported single-page PDFs.
/// Imported content is aspect-fitted onto white, so no author artwork is cropped
/// or stretched and any padding becomes part of the map coordinate plane.
enum MapPDFGenerator {
    static let pageSize = CGSize(width: 1_200, height: 900)

    enum MapPDFError: LocalizedError {
        case cannotCreatePDF
        case invalidPDF
        case requiresSinglePage
        case invalidPageBounds

        var errorDescription: String? {
            switch self {
            case .cannotCreatePDF: "無法建立地圖 PDF。"
            case .invalidPDF: "無法讀取這份 PDF。"
            case .requiresSinglePage: "地圖只支援單頁 PDF。"
            case .invalidPageBounds: "PDF 頁面尺寸無效。"
            }
        }
    }

    static func templateData(style: MapTemplateStyle) throws -> Data {
        try makePDF { context, pageRect in
            context.setFillColor(NSColor.white.cgColor)
            context.fill(pageRect)
            guard style == .grid else { return }

            let columns = 40
            let rows = 30
            for column in 0...columns {
                let position = CGFloat(column) / CGFloat(columns)
                let x = pageRect.minX + pageRect.width * position
                let isMajor = column.isMultiple(of: 5)
                context.setStrokeColor(NSColor.black.withAlphaComponent(isMajor ? 0.28 : 0.12).cgColor)
                context.setLineWidth(isMajor ? 1.2 : 0.6)
                context.move(to: CGPoint(x: x, y: pageRect.minY))
                context.addLine(to: CGPoint(x: x, y: pageRect.maxY))
                context.strokePath()
            }
            for row in 0...rows {
                let position = CGFloat(row) / CGFloat(rows)
                let y = pageRect.minY + pageRect.height * position
                let isMajor = row.isMultiple(of: 5)
                context.setStrokeColor(NSColor.black.withAlphaComponent(isMajor ? 0.28 : 0.12).cgColor)
                context.setLineWidth(isMajor ? 1.2 : 0.6)
                context.move(to: CGPoint(x: pageRect.minX, y: y))
                context.addLine(to: CGPoint(x: pageRect.maxX, y: y))
                context.strokePath()
            }
        }
    }

    static func normalizedMapData(from sourceData: Data) throws -> Data {
        guard let document = PDFDocument(data: sourceData) else {
            throw MapPDFError.invalidPDF
        }
        guard document.pageCount == 1 else {
            throw MapPDFError.requiresSinglePage
        }
        guard let page = document.page(at: 0) else {
            throw MapPDFError.invalidPDF
        }
        let sourceRect = page.bounds(for: .cropBox).standardized
        guard sourceRect.width > 0, sourceRect.height > 0,
              sourceRect.width.isFinite, sourceRect.height.isFinite else {
            throw MapPDFError.invalidPageBounds
        }

        return try makePDF { context, pageRect in
            context.setFillColor(NSColor.white.cgColor)
            context.fill(pageRect)

            let scale = min(pageRect.width / sourceRect.width, pageRect.height / sourceRect.height)
            let fittedSize = CGSize(width: sourceRect.width * scale, height: sourceRect.height * scale)
            let fittedRect = CGRect(
                x: pageRect.midX - fittedSize.width / 2,
                y: pageRect.midY - fittedSize.height / 2,
                width: fittedSize.width,
                height: fittedSize.height
            )

            context.saveGState()
            context.translateBy(x: fittedRect.minX, y: fittedRect.minY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -sourceRect.minX, y: -sourceRect.minY)
            page.draw(with: .cropBox, to: context)
            context.restoreGState()
        }
    }

    private static func makePDF(
        drawPage: (CGContext, CGRect) throws -> Void
    ) throws -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            throw MapPDFError.cannotCreatePDF
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw MapPDFError.cannotCreatePDF
        }
        context.beginPDFPage(nil)
        try drawPage(context, mediaBox)
        context.endPDFPage()
        context.closePDF()
        return output as Data
    }
}

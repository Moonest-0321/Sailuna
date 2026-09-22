import CoreGraphics
import Foundation

struct MapCoordinate: Equatable {
    static let maximumX = 4_000.0
    static let maximumY = 3_000.0

    let x: Double
    let y: Double

    init(x: Double, y: Double) {
        self.x = min(max(x, 0), Self.maximumX)
        self.y = min(max(y, 0), Self.maximumY)
    }
}

/// Converts between the fixed bottom-left world coordinates and SwiftUI's
/// top-left view coordinates. The same fitted 4:3 rect is shared by PDF and markers.
enum MapCoordinateTransform {
    static let aspectRatio = 4.0 / 3.0

    static func fittedMapRect(in bounds: CGRect) -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        let availableRatio = bounds.width / bounds.height
        let size: CGSize
        if availableRatio > aspectRatio {
            size = CGSize(width: bounds.height * aspectRatio, height: bounds.height)
        } else {
            size = CGSize(width: bounds.width, height: bounds.width / aspectRatio)
        }
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func viewPoint(for coordinate: MapCoordinate, in mapRect: CGRect) -> CGPoint {
        CGPoint(
            x: mapRect.minX + mapRect.width * coordinate.x / MapCoordinate.maximumX,
            y: mapRect.maxY - mapRect.height * coordinate.y / MapCoordinate.maximumY
        )
    }

    static func coordinate(for point: CGPoint, in mapRect: CGRect) -> MapCoordinate? {
        guard mapRect.width > 0, mapRect.height > 0 else { return nil }
        let tolerance = 0.0001
        guard point.x >= mapRect.minX - tolerance,
              point.x <= mapRect.maxX + tolerance,
              point.y >= mapRect.minY - tolerance,
              point.y <= mapRect.maxY + tolerance else { return nil }
        let containedPoint = CGPoint(
            x: min(max(point.x, mapRect.minX), mapRect.maxX),
            y: min(max(point.y, mapRect.minY), mapRect.maxY)
        )
        return MapCoordinate(
            x: Double((containedPoint.x - mapRect.minX) / mapRect.width) * MapCoordinate.maximumX,
            y: Double((mapRect.maxY - containedPoint.y) / mapRect.height) * MapCoordinate.maximumY
        )
    }
}

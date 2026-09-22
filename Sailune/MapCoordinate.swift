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

enum MapCoordinateInput {
    static func parse(x xText: String, y yText: String) -> MapCoordinate? {
        guard let x = parseInteger(xText, maximum: Int(MapCoordinate.maximumX)),
              let y = parseInteger(yText, maximum: Int(MapCoordinate.maximumY)) else {
            return nil
        }
        return MapCoordinate(x: Double(x), y: Double(y))
    }

    private static func parseInteger(_ text: String, maximum: Int) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.allSatisfy(\.isNumber),
              let value = Int(trimmed),
              (0...maximum).contains(value) else {
            return nil
        }
        return value
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

    static func clampedCoordinate(for point: CGPoint, in mapRect: CGRect) -> MapCoordinate? {
        guard mapRect.width > 0, mapRect.height > 0 else { return nil }
        return coordinate(
            for: CGPoint(
                x: min(max(point.x, mapRect.minX), mapRect.maxX),
                y: min(max(point.y, mapRect.minY), mapRect.maxY)
            ),
            in: mapRect
        )
    }
}

struct MapViewport: Equatable {
    static let minimumZoom: CGFloat = 0.5
    static let maximumZoom: CGFloat = 4
    static let zoomStep: CGFloat = 0.25

    private(set) var zoom: CGFloat = 1
    private(set) var pan: CGSize = .zero

    mutating func reset() {
        zoom = 1
        pan = .zero
    }

    func mapRect(in bounds: CGRect) -> CGRect {
        let fittedRect = MapCoordinateTransform.fittedMapRect(in: bounds)
        let size = CGSize(width: fittedRect.width * zoom, height: fittedRect.height * zoom)
        let constrainedPan = clampedPan(pan, mapSize: size, in: bounds)
        return CGRect(
            x: fittedRect.midX - size.width / 2 + constrainedPan.width,
            y: fittedRect.midY - size.height / 2 + constrainedPan.height,
            width: size.width,
            height: size.height
        )
    }

    mutating func zoom(by steps: Int, in bounds: CGRect) {
        setZoom(zoom + CGFloat(steps) * Self.zoomStep, anchor: CGPoint(x: bounds.midX, y: bounds.midY), in: bounds)
    }

    mutating func setZoom(_ proposedZoom: CGFloat, anchor: CGPoint, in bounds: CGRect) {
        let oldRect = mapRect(in: bounds)
        guard oldRect.width > 0, oldRect.height > 0 else { return }
        let anchorRatio = CGPoint(
            x: (anchor.x - oldRect.minX) / oldRect.width,
            y: (anchor.y - oldRect.minY) / oldRect.height
        )
        zoom = min(max(proposedZoom, Self.minimumZoom), Self.maximumZoom)

        let fittedRect = MapCoordinateTransform.fittedMapRect(in: bounds)
        let mapSize = CGSize(width: fittedRect.width * zoom, height: fittedRect.height * zoom)
        let desiredOrigin = CGPoint(
            x: anchor.x - anchorRatio.x * mapSize.width,
            y: anchor.y - anchorRatio.y * mapSize.height
        )
        let proposedPan = CGSize(
            width: desiredOrigin.x + mapSize.width / 2 - fittedRect.midX,
            height: desiredOrigin.y + mapSize.height / 2 - fittedRect.midY
        )
        pan = clampedPan(proposedPan, mapSize: mapSize, in: bounds)
    }

    mutating func setPan(_ proposedPan: CGSize, in bounds: CGRect) {
        let fittedRect = MapCoordinateTransform.fittedMapRect(in: bounds)
        let mapSize = CGSize(width: fittedRect.width * zoom, height: fittedRect.height * zoom)
        pan = clampedPan(proposedPan, mapSize: mapSize, in: bounds)
    }

    private func clampedPan(_ proposedPan: CGSize, mapSize: CGSize, in bounds: CGRect) -> CGSize {
        let maximumX = max(0, (mapSize.width - bounds.width) / 2)
        let maximumY = max(0, (mapSize.height - bounds.height) / 2)
        return CGSize(
            width: min(max(proposedPan.width, -maximumX), maximumX),
            height: min(max(proposedPan.height, -maximumY), maximumY)
        )
    }
}

enum MapMarkerPresentation {
    static let labelZoomThreshold: CGFloat = 1.5

    static func showsName(zoom: CGFloat, isHovered: Bool, isSelected: Bool) -> Bool {
        isHovered || isSelected || zoom >= labelZoomThreshold
    }
}

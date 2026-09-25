import Foundation
import SwiftData

enum MapLevel: String, CaseIterable, Identifiable {
    case overview
    case country
    case province
    case city
    case closeUp

    var id: Self { self }
    var title: String {
        switch self {
        case .overview: "總體"
        case .country: "國家"
        case .province: "省份"
        case .city: "城市"
        case .closeUp: "特寫"
        }
    }

    var supportsMultipleVersions: Bool {
        self == .overview || self == .country || self == .province
    }

    var destinationLevel: Self? {
        switch self {
        case .overview, .country, .province: .city
        case .city: .closeUp
        case .closeUp: nil
        }
    }
}

enum MapCatalogError: LocalizedError {
    case invalidBook
    case invalidName
    case duplicateMapName(String)
    case duplicateVersionName(String)
    case lastVersion
    case invalidCoordinate
    case invalidNavigationSource
    case invalidMarkerSource

    var errorDescription: String? {
        switch self {
        case .invalidBook: "地圖資料必須屬於同一本書。"
        case .invalidName: "名稱不可空白。"
        case .duplicateMapName(let name): "此層級已有「\(name)」地圖。"
        case .duplicateVersionName(let name): "此地圖已有「\(name)」版本。"
        case .lastVersion: "每張地圖至少要保留一個版本。"
        case .invalidCoordinate: "地圖座標超出有效範圍。"
        case .invalidNavigationSource: "此地圖標記無法跳轉至下一層級地圖。"
        case .invalidMarkerSource: "找不到原有地圖標記，請重新載入地圖。"
        }
    }
}

struct MapMarkerRecord: Identifiable {
    let place: Place
    let placement: MapPlacement
    var id: UUID { placement.id }
    var coordinate: MapCoordinate {
        MapCoordinate(x: placement.coordinateX, y: placement.coordinateY)
    }
}

@MainActor
extension V5SettingsStore {
    func maps(for bookID: UUID, level: MapLevel? = nil) -> [BookMap] {
        _ = revision
        return fetchOrEmptyWithDiagnostic(BookMap.self, operation: "maps")
            .filter { $0.bookID == bookID && (level == nil || $0.levelRawValue == level?.rawValue) }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder
                    ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    : lhs.sortOrder < rhs.sortOrder
            }
    }

    func versions(for map: BookMap) -> [BookMapVersion] {
        _ = revision
        return fetchOrEmptyWithDiagnostic(BookMapVersion.self, operation: "versions")
            .filter { $0.bookID == map.bookID && $0.mapID == map.id }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder
                    ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    : lhs.sortOrder < rhs.sortOrder
            }
    }

    func placements(for map: BookMap) -> [MapPlacement] {
        _ = revision
        return fetchOrEmptyWithDiagnostic(MapPlacement.self, operation: "placements")
            .filter { $0.bookID == map.bookID && $0.mapID == map.id }
    }

    private func mapsForDecision(bookID: UUID, level: MapLevel? = nil) throws -> [BookMap] {
        try context.fetch(FetchDescriptor<BookMap>())
            .filter { $0.bookID == bookID && (level == nil || $0.levelRawValue == level?.rawValue) }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : lhs.sortOrder < rhs.sortOrder
            }
    }

    private func versionsForDecision(map: BookMap) throws -> [BookMapVersion] {
        try context.fetch(FetchDescriptor<BookMapVersion>())
            .filter { $0.bookID == map.bookID && $0.mapID == map.id }
            .sorted { $0.sortOrder == $1.sortOrder ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.sortOrder < $1.sortOrder }
    }

    func markerRecords(for map: BookMap) -> [MapMarkerRecord] {
        let placesByID = Dictionary(uniqueKeysWithValues: places(for: map.bookID).map { ($0.id, $0) })
        return placements(for: map).compactMap { placement in
            guard placement.coordinateX.isFinite, placement.coordinateY.isFinite,
                  (0...MapCoordinate.maximumX).contains(placement.coordinateX),
                  (0...MapCoordinate.maximumY).contains(placement.coordinateY),
                  let place = placesByID[placement.placeID]
            else { return nil }
            return MapMarkerRecord(place: place, placement: placement)
        }
    }

    /// Creates the V12 default catalog and copies each valid V11 position once.
    /// Repeating this after an interrupted startup never duplicates records.
    @discardableResult
    func ensureDefaultMap(for bookID: UUID) throws -> (BookMap, BookMapVersion)? {
        let profiles = try context.fetch(FetchDescriptor<MapCatalogProfile>())
        let bookMaps = try mapsForDecision(bookID: bookID)
        if profiles.contains(where: { $0.bookID == bookID }) {
            guard let map = bookMaps.first else { return nil }
            let version: BookMapVersion
            if let existing = try versionsForDecision(map: map).first {
                version = existing
            } else {
                version = BookMapVersion(bookID: bookID, mapID: map.id, name: "地圖")
                context.insert(version); try context.save(); didSave()
            }
            try BookMapPDFStore.migrateLegacyMapIfNeeded(bookID: bookID, mapID: map.id, versionID: version.id)
            return (map, version)
        }
        let existingMap = bookMaps.first
        let map = existingMap ?? BookMap(bookID: bookID, levelRawValue: MapLevel.overview.rawValue, name: "總體地圖")
        let existingVersion = try existingMap.flatMap { try versionsForDecision(map: $0).first }
        let version = existingVersion ?? BookMapVersion(bookID: bookID, mapID: map.id, name: "地圖")
        let existingPlaceIDs = Set(try context.fetch(FetchDescriptor<MapPlacement>())
            .filter { $0.bookID == bookID && $0.mapID == map.id }
            .map(\.placeID))
        let bookPlaces = try context.fetch(FetchDescriptor<Place>())
            .filter { $0.bookID == bookID }

        context.insert(MapCatalogProfile(bookID: bookID))
        if existingMap == nil { context.insert(map) }
        if existingVersion == nil { context.insert(version) }
        for place in bookPlaces where !existingPlaceIDs.contains(place.id) {
            guard let x = place.coordinateX, let y = place.coordinateY,
                  x.isFinite, y.isFinite,
                  (0...MapCoordinate.maximumX).contains(x),
                  (0...MapCoordinate.maximumY).contains(y)
            else { continue }
            context.insert(MapPlacement(bookID: bookID, mapID: map.id, placeID: place.id, coordinateX: x, coordinateY: y))
        }
        try context.save()
        didSave()
        try BookMapPDFStore.migrateLegacyMapIfNeeded(bookID: bookID, mapID: map.id, versionID: version.id)
        return (map, version)
    }

    @discardableResult
    func createMap(bookID: UUID, level: MapLevel, name: String) throws -> (BookMap, BookMapVersion) {
        let cleaned = try validatedMapName(name, bookID: bookID, level: level, excluding: nil)
        let order = (try mapsForDecision(bookID: bookID, level: level).map(\.sortOrder).max() ?? -1) + 1
        let map = BookMap(bookID: bookID, levelRawValue: level.rawValue, name: cleaned, sortOrder: order)
        let version = BookMapVersion(bookID: bookID, mapID: map.id, name: "地圖")
        context.insert(map); context.insert(version)
        try context.save(); didSave()
        return (map, version)
    }

    func renameMap(_ map: BookMap, to name: String) throws {
        guard let level = MapLevel(rawValue: map.levelRawValue) else { throw MapCatalogError.invalidBook }
        map.name = try validatedMapName(name, bookID: map.bookID, level: level, excluding: map.id)
        try context.save(); didSave()
    }

    func deleteMap(_ map: BookMap) throws {
        let mapVersions = try context.fetch(FetchDescriptor<BookMapVersion>())
            .filter { $0.bookID == map.bookID && $0.mapID == map.id }
        // A destination can be shared by markers on several source maps.
        let bookPlacements = try context.fetch(FetchDescriptor<MapPlacement>())
            .filter { $0.bookID == map.bookID }
        mapVersions.forEach(context.delete)
        bookPlacements.filter { $0.mapID == map.id }.forEach(context.delete)
        let linkedPlacements = bookPlacements.filter { $0.targetMapID == map.id }
        linkedPlacements.forEach { $0.targetMapID = nil }
        context.delete(map)
        try context.save(); didSave()
        try BookMapPDFStore.removeMap(bookID: map.bookID, mapID: map.id)
    }

    /// Resolves the saved marker without treating a failed fetch as a missing marker.
    func markerSource(
        placeID: UUID, placementID: UUID, bookID: UUID, on map: BookMap,
        missingError: MapCatalogError = .invalidMarkerSource
    ) throws -> (Place, MapPlacement) {
        guard map.bookID == bookID else { throw missingError }
        let bookPlaces = try context.fetch(FetchDescriptor<Place>())
        let bookPlacements = try context.fetch(FetchDescriptor<MapPlacement>())
        guard let place = bookPlaces.first(where: { $0.id == placeID && $0.bookID == bookID }),
              let placement = bookPlacements.first(where: {
                  $0.id == placementID && $0.bookID == bookID && $0.mapID == map.id && $0.placeID == placeID
              })
        else { throw missingError }
        return (place, placement)
    }

    func markerPlaceForDeletion(placeID: UUID, bookID: UUID) throws -> Place? {
        try context.fetch(FetchDescriptor<Place>())
            .first { $0.id == placeID && $0.bookID == bookID }
    }

    /// Resolves one marker's lower-level map. Map creation and binding share
    /// one settings-store save so a failed operation cannot leave a new map.
    func destinationMap(for place: Place, placement: MapPlacement, on source: BookMap) throws -> BookMap {
        guard place.bookID == source.bookID, placement.bookID == source.bookID,
              placement.mapID == source.id, placement.placeID == place.id,
              let sourceLevel = MapLevel(rawValue: source.levelRawValue),
              let targetLevel = sourceLevel.destinationLevel else {
            throw MapCatalogError.invalidNavigationSource
        }
        let destinationMaps = try mapsForDecision(bookID: source.bookID, level: targetLevel)
        if let targetID = placement.targetMapID,
           let boundMap = destinationMaps.first(where: { $0.id == targetID }) {
            return boundMap
        }

        let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw MapCatalogError.invalidName }
        let existing = destinationMaps.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        let destination = existing ?? BookMap(
            bookID: source.bookID,
            levelRawValue: targetLevel.rawValue,
            name: name,
            sortOrder: (destinationMaps.map(\.sortOrder).max() ?? -1) + 1
        )
        do {
            if existing == nil {
                context.insert(destination)
                context.insert(BookMapVersion(bookID: source.bookID, mapID: destination.id, name: "地圖"))
            }
            placement.targetMapID = destination.id
            try context.save(); didSave()
            return destination
        } catch {
            context.rollback()
            throw error
        }
    }

    @discardableResult
    func createVersion(for map: BookMap, name: String) throws -> BookMapVersion {
        guard MapLevel(rawValue: map.levelRawValue)?.supportsMultipleVersions == true else { throw MapCatalogError.invalidBook }
        let cleaned = try validatedVersionName(name, map: map, excluding: nil)
        let order = (try versionsForDecision(map: map).map(\.sortOrder).max() ?? -1) + 1
        let version = BookMapVersion(bookID: map.bookID, mapID: map.id, name: cleaned, sortOrder: order)
        context.insert(version); try context.save(); didSave()
        return version
    }

    func renameVersion(_ version: BookMapVersion, on map: BookMap, to name: String) throws {
        guard version.bookID == map.bookID, version.mapID == map.id else { throw MapCatalogError.invalidBook }
        version.name = try validatedVersionName(name, map: map, excluding: version.id)
        try context.save(); didSave()
    }

    func deleteVersion(_ version: BookMapVersion, from map: BookMap) throws {
        guard version.bookID == map.bookID, version.mapID == map.id else { throw MapCatalogError.invalidBook }
        let versionCount = try context.fetch(FetchDescriptor<BookMapVersion>())
            .filter { $0.bookID == map.bookID && $0.mapID == map.id }.count
        guard versionCount > 1 else { throw MapCatalogError.lastVersion }
        context.delete(version); try context.save(); didSave()
        try BookMapPDFStore.removeVersion(bookID: map.bookID, mapID: map.id, versionID: version.id)
    }

    @discardableResult
    func createMapPlace(bookID: UUID, map: BookMap, name: String, placeType: String?, coordinate: MapCoordinate) throws -> Place {
        guard map.bookID == bookID else { throw MapCatalogError.invalidBook }
        try validate(coordinate)
        let nextSortOrder = (try context.fetch(FetchDescriptor<Place>())
            .filter { $0.bookID == bookID }
            .map(\.sortOrder).max() ?? -1) + 1
        let place = Place(bookID: bookID, name: name, placeType: placeType, sortOrder: nextSortOrder)
        let placement = MapPlacement(bookID: bookID, mapID: map.id, placeID: place.id, coordinateX: coordinate.x, coordinateY: coordinate.y)
        context.insert(place); context.insert(placement); try context.save(); didSave()
        return place
    }

    func updateMapPlace(_ place: Place, placement: MapPlacement, map: BookMap, name: String, placeType: String?, coordinate: MapCoordinate) throws {
        guard place.bookID == map.bookID, placement.bookID == map.bookID,
              placement.mapID == map.id, placement.placeID == place.id else { throw MapCatalogError.invalidBook }
        try validate(coordinate)
        place.name = name; place.placeType = placeType
        placement.coordinateX = coordinate.x; placement.coordinateY = coordinate.y
        try context.save(); didSave()
    }

    func updatePlacement(_ placement: MapPlacement, for place: Place, on map: BookMap, coordinate: MapCoordinate) throws {
        guard place.bookID == map.bookID, placement.bookID == map.bookID,
              placement.mapID == map.id, placement.placeID == place.id else { throw MapCatalogError.invalidBook }
        try validate(coordinate)
        placement.coordinateX = coordinate.x; placement.coordinateY = coordinate.y
        try context.save(); didSave()
    }

    private func validatedMapName(_ name: String, bookID: UUID, level: MapLevel, excluding mapID: UUID?) throws -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw MapCatalogError.invalidName }
        guard try !mapsForDecision(bookID: bookID, level: level).contains(where: { $0.id != mapID && $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) else {
            throw MapCatalogError.duplicateMapName(cleaned)
        }
        return cleaned
    }

    private func validatedVersionName(_ name: String, map: BookMap, excluding versionID: UUID?) throws -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw MapCatalogError.invalidName }
        guard try !versionsForDecision(map: map).contains(where: { $0.id != versionID && $0.name.localizedCaseInsensitiveCompare(cleaned) == .orderedSame }) else {
            throw MapCatalogError.duplicateVersionName(cleaned)
        }
        return cleaned
    }

    private func validate(_ coordinate: MapCoordinate) throws {
        guard coordinate.x.isFinite, coordinate.y.isFinite,
              (0...MapCoordinate.maximumX).contains(coordinate.x),
              (0...MapCoordinate.maximumY).contains(coordinate.y)
        else { throw MapCatalogError.invalidCoordinate }
    }
}

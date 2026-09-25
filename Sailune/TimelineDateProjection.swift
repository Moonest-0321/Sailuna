import Foundation

// MARK: - 格子模型

enum CellKind { case year, month, day }

struct TimelineCell: Identifiable {
    let id: String
    let kind: CellKind
    let ordinal: Int
    let eraID: UUID?
    let eraHex: String
    let eraName: String
    let era: Era?
    let nodes: [Node]
    let repYear: Int
    let repMonth: Int?
    let repDay: Int?
    let events: [Event]
    let planningRecords: [PlanningRecordProjection]
    var label: String = ""

    init(
        id: String,
        kind: CellKind,
        ordinal: Int,
        eraID: UUID?,
        eraHex: String,
        eraName: String,
        era: Era?,
        nodes: [Node],
        repYear: Int,
        repMonth: Int?,
        repDay: Int?,
        events: [Event],
        planningRecords: [PlanningRecordProjection] = [],
        label: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.ordinal = ordinal
        self.eraID = eraID
        self.eraHex = eraHex
        self.eraName = eraName
        self.era = era
        self.nodes = nodes
        self.repYear = repYear
        self.repMonth = repMonth
        self.repDay = repDay
        self.events = events
        self.planningRecords = planningRecords
        self.label = label
    }
}

struct TimelineEraGroup: Identifiable {
    let id: String
    let eraID: UUID?
    let name: String
    let colorHex: String
    let era: Era?
    let cells: [TimelineCell]
}

struct TimelineSlot: Identifiable {
    let id: String
    let cell: TimelineCell
    let event: Event?
    let planningRecord: PlanningRecordProjection?
}

private final class CellAccum {
    let kind: CellKind
    var ordinal: Int
    let eraID: UUID?
    let eraHex: String
    let eraName: String
    var era: Era?
    var nodes: [Node]
    var nodeIDs: Set<UUID>
    let repYear: Int
    let repMonth: Int?
    let repDay: Int?
    var events: [Event]
    var planningRecords: [PlanningRecordProjection]
    init(kind: CellKind, ordinal: Int, eraID: UUID?, eraHex: String, eraName: String,
         era: Era?, nodes: [Node], ry: Int, rm: Int?, rd: Int?, events: [Event], planningRecords: [PlanningRecordProjection]) {
        self.kind = kind; self.ordinal = ordinal; self.eraID = eraID
        self.eraHex = eraHex; self.eraName = eraName
        self.era = era; self.nodes = nodes; self.nodeIDs = Set(nodes.map(\.id))
        self.repYear = ry; self.repMonth = rm; self.repDay = rd; self.events = events
        self.planningRecords = planningRecords
    }
}

// 寬窄版共用的唯讀日期投影，與捲動、選取及編輯狀態分離。
@MainActor
enum TimelineDateProjection {
    static func slots(cells: [TimelineCell]) -> [TimelineSlot] {
        cells.flatMap { cell in
            let orderedEvents = cell.events.sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            let orderedRecords = cell.planningRecords.sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.id < $1.id
            }
            if orderedEvents.isEmpty && orderedRecords.isEmpty {
                return [TimelineSlot(id: "\(cell.id):empty", cell: cell, event: nil, planningRecord: nil)]
            }
            return orderedEvents.map { event in
                TimelineSlot(id: "\(cell.id):event:\(event.id.uuidString)", cell: cell, event: event, planningRecord: nil)
            } + orderedRecords.map { record in
                TimelineSlot(id: "\(cell.id):record:\(record.id)", cell: cell, event: nil, planningRecord: record)
            }
        }
    }

    static func cells(
        nodes: [Node],
        events: [Event],
        planningRecords: [PlanningRecordProjection] = [],
        primary: Bool,
        granularity: SailuneTimelineGranularity
    ) -> [TimelineCell] {
        var groups: [String: CellAccum] = [:]
        var order: [String] = []

        for n in TimelineEngine.Query.sorted(nodes) where n.year != 0 && (!primary || n.isVisible) {
            let ord = n.absoluteOrdinal
            let absYear = ord / 10000
            let absMonth = ord / 100
            let eraHex = n.era?.color ?? "#888888"
            let eraName = n.era?.name ?? ""
            let eraID = n.era?.id
            let hasMonth = n.month != nil
            let hasDay = n.day != nil

            let nodeEvents = events.filter { $0.node?.id == n.id }.sorted { $0.sortOrder < $1.sortOrder }
            let evs = primary
                ? nodeEvents.filter { TimelineEngine.Visibility.isVisibleOnPrimaryAxis($0) }
                : nodeEvents
            let records = planningRecords.filter { $0.nodeID == n.id }

            var key: String
            let kind: CellKind
            if !hasMonth {
                key = "Y:\(absYear)"; kind = .year
            } else if !hasDay {
                switch granularity {
                case .year:        key = "Y:\(absYear)"; kind = .year
                case .month, .day: key = "M:\(absMonth)"; kind = .month
                }
            } else {
                switch granularity {
                case .year:  key = "Y:\(absYear)"; kind = .year
                case .month: key = "M:\(absMonth)"; kind = .month
                case .day:   key = "D:\(ord)";     kind = .day
                }
            }

            key = "\(eraID?.uuidString ?? "none"):\(key)"
            if let acc = groups[key] {
                acc.ordinal = min(acc.ordinal, ord)
                acc.events.append(contentsOf: evs)
                acc.planningRecords.append(contentsOf: records)
                if !acc.nodeIDs.contains(n.id) { acc.nodeIDs.insert(n.id); acc.nodes.append(n) }
                if acc.era == nil { acc.era = n.era }
            } else {
                groups[key] = CellAccum(kind: kind, ordinal: ord, eraID: eraID, eraHex: eraHex,
                                        eraName: eraName, era: n.era, nodes: [n],
                                        ry: n.year, rm: n.month, rd: n.day, events: evs, planningRecords: records)
                order.append(key)
            }
        }

        var cells: [TimelineCell] = order.compactMap { k in
            guard let g = groups[k] else { return nil }
            return TimelineCell(id: k, kind: g.kind, ordinal: g.ordinal, eraID: g.eraID,
                                eraHex: g.eraHex, eraName: g.eraName, era: g.era, nodes: g.nodes,
                                repYear: g.repYear, repMonth: g.repMonth, repDay: g.repDay,
                                events: g.events, planningRecords: g.planningRecords)
        }
        cells.sort { lhs, rhs in
            let lhsEra = TimelineEngine.Core.eraOrder(lhs.era?.startOrdinal)
            let rhsEra = TimelineEngine.Core.eraOrder(rhs.era?.startOrdinal)
            if lhsEra != rhsEra { return lhsEra < rhsEra }
            if lhs.ordinal != rhs.ordinal { return lhs.ordinal < rhs.ordinal }
            return lhs.id < rhs.id
        }
        assignLabels(&cells, granularity: granularity)
        return cells
    }

    static func eraGroups(cells: [TimelineCell]) -> [TimelineEraGroup] {
        var groups: [TimelineEraGroup] = []
        var indexByID: [String: Int] = [:]
        for cell in cells {
            let id = cell.eraID?.uuidString ?? "none"
            if let index = indexByID[id] {
                let existing = groups[index]
                groups[index] = TimelineEraGroup(
                    id: existing.id,
                    eraID: existing.eraID,
                    name: existing.name,
                    colorHex: existing.colorHex,
                    era: existing.era,
                    cells: existing.cells + [cell]
                )
            } else {
                indexByID[id] = groups.count
                groups.append(TimelineEraGroup(
                    id: id,
                    eraID: cell.eraID,
                    name: cell.eraName.isEmpty ? (cell.eraID == nil ? "未指定紀元" : "未命名紀元") : cell.eraName,
                    colorHex: cell.eraHex,
                    era: cell.era,
                    cells: [cell]
                ))
            }
        }
        return groups
    }

    static func eventsInDisplayOrder(cells: [TimelineCell]) -> [Event] {
        cells.flatMap { cell in
            cell.events.sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    static func relativeLabels(
        cells: [TimelineCell],
        granularity: SailuneTimelineGranularity,
        firstVisibleIndex: Int
    ) -> [String] {
        guard !cells.isEmpty else { return [] }
        let start = min(max(0, firstVisibleIndex), cells.count - 1)
        var labels = cells.map(\.label)
        var lastYear: Int?
        var lastMonth: Int?
        var lastEraID: UUID?
        for index in cells.indices {
            let cell = cells[index]
            let beginsVisibleSequence = index == start
            let eraChanged = index > start && cell.eraID != lastEraID
            if index < start { continue }
            if beginsVisibleSequence || eraChanged {
                labels[index] = fullLabel(for: cell, granularity: granularity)
                lastYear = cell.repYear
                lastMonth = cell.repMonth
                lastEraID = cell.eraID
                continue
            }
            switch granularity {
            case .year:
                labels[index] = "\(cell.repYear)年"
            case .month:
                if cell.repYear == lastYear, let month = cell.repMonth {
                    labels[index] = "\(month)月"
                } else {
                    labels[index] = fullLabel(for: cell, granularity: granularity)
                }
            case .day:
                if cell.repYear == lastYear, cell.repMonth == lastMonth, let day = cell.repDay {
                    labels[index] = "\(day)日"
                } else if cell.repYear == lastYear, let month = cell.repMonth, let day = cell.repDay {
                    labels[index] = "\(month)月\(day)日"
                } else {
                    labels[index] = fullLabel(for: cell, granularity: granularity)
                }
            }
            lastYear = cell.repYear
            lastMonth = cell.repMonth
            lastEraID = cell.eraID
        }
        return labels
    }

    static func relativeLabels(
        slots: [TimelineSlot],
        granularity: SailuneTimelineGranularity,
        firstVisibleIndex: Int
    ) -> [String] {
        relativeLabels(
            cells: slots.map(\.cell),
            granularity: granularity,
            firstVisibleIndex: firstVisibleIndex
        )
    }

    private static func fullLabel(for cell: TimelineCell, granularity: SailuneTimelineGranularity) -> String {
        switch granularity {
        case .year:
            return "\(cell.repYear)年"
        case .month:
            guard let month = cell.repMonth else { return "\(cell.repYear)年" }
            return "\(cell.repYear)年\(month)月"
        case .day:
            guard let month = cell.repMonth else { return "\(cell.repYear)年" }
            guard let day = cell.repDay else { return "\(cell.repYear)年\(month)月" }
            return "\(cell.repYear)年\(month)月\(day)日"
        }
    }

    private static func assignLabels(_ cells: inout [TimelineCell], granularity: SailuneTimelineGranularity) {
        var lastYear: Int? = nil
        var lastMonth: Int? = nil
        for i in cells.indices {
            let c = cells[i]
            if i > 0 && cells[i - 1].eraID != c.eraID {
                lastYear = nil
                lastMonth = nil
            }
            let y = c.repYear
            switch granularity {
            case .year:
                cells[i].label = "\(y)年"
                lastYear = y; lastMonth = nil
            case .month:
                switch c.kind {
                case .year:
                    cells[i].label = "\(y)年"; lastYear = y; lastMonth = nil
                case .month, .day:
                    let m = c.repMonth ?? 0
                    cells[i].label = (lastYear == y) ? "\(m)月" : "\(y)年\(m)月"
                    lastYear = y; lastMonth = m
                }
            case .day:
                switch c.kind {
                case .year:
                    cells[i].label = "\(y)年"; lastYear = y; lastMonth = nil
                case .month:
                    let m = c.repMonth ?? 0
                    cells[i].label = (lastYear == y) ? "\(m)月" : "\(y)年\(m)月"
                    lastYear = y; lastMonth = m
                case .day:
                    let m = c.repMonth ?? 0
                    let d = c.repDay ?? 0
                    if lastYear == y && lastMonth == m { cells[i].label = "\(d)" }
                    else if lastYear == y { cells[i].label = "\(m)/\(d)" }
                    else { cells[i].label = "\(y)/\(m)/\(d)" }
                    lastYear = y; lastMonth = m
                }
            }
        }
    }
}


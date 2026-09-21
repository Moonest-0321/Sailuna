import Foundation
import XCTest
@testable import Sailune

final class CharacterDetailPreviewTests: XCTestCase {
    private struct UpdatedRecord {
        let id: UUID
        let updatedAt: Date
        let name: String
    }

    private struct OrderedRecord {
        let id: UUID
        let sortOrder: Double
        let name: String
    }

    func testLatestPreviewUsesMostRecentUpdate() {
        let older = UpdatedRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            updatedAt: Date(timeIntervalSinceReferenceDate: 10),
            name: "較早"
        )
        let newer = UpdatedRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            updatedAt: Date(timeIntervalSinceReferenceDate: 20),
            name: "最新"
        )

        let result = CharacterDetailPreviewOrdering.latest(
            in: [newer, older],
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        )

        XCTAssertEqual(result?.name, "最新")
    }

    func testLatestPreviewUsesStableIDForEqualDates() {
        let date = Date(timeIntervalSinceReferenceDate: 10)
        let lowerID = UpdatedRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            updatedAt: date,
            name: "較小 UUID"
        )
        let higherID = UpdatedRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            updatedAt: date,
            name: "較大 UUID"
        )

        let result = CharacterDetailPreviewOrdering.latest(
            in: [higherID, lowerID],
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        )

        XCTAssertEqual(result?.name, "較大 UUID")
    }

    func testEventPreviewUsesLastSortOrder() {
        let first = OrderedRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sortOrder: 1,
            name: "先前事件"
        )
        let last = OrderedRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            sortOrder: 2,
            name: "最後事件"
        )

        let result = CharacterDetailPreviewOrdering.last(
            in: [last, first],
            sortOrder: { $0.sortOrder },
            id: { $0.id }
        )

        XCTAssertEqual(result?.name, "最後事件")
    }

    func testPreviewOrderingReturnsNilForEmptyInput() {
        let values: [UpdatedRecord] = []

        XCTAssertNil(CharacterDetailPreviewOrdering.latest(
            in: values,
            updatedAt: { $0.updatedAt },
            id: { $0.id }
        ))
    }

    func testCharacterTimelineIncludesAbilityHistoryWithLevelAndManualDate() {
        let characterID = UUID()
        let ability = CharacterAbility(name: "月影步")
        let level = AbilityLevel(abilityID: ability.id, name: "熟練")
        let connection = CharacterAbilityConnection(
            characterID: characterID,
            abilityID: ability.id,
            currentLevelID: level.id
        )
        let node = Node(year: 12, month: 3, day: 8)
        let history = CharacterAbilityHistory(
            connectionID: connection.id,
            content: level.id.uuidString,
            nodeID: node.id
        )

        let entries = CharacterTimelineProjectionBuilder.build(
            characterID: characterID,
            abilities: [ability],
            abilityConnections: [connection],
            abilityHistories: [history],
            abilityLevels: [level],
            nodes: [node],
            appearances: [],
            psychologies: [],
            characterItems: [],
            itemCopies: [],
            copyHoldings: [],
            copyHistories: [],
            items: [],
            relationships: [],
            events: []
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.source, "能力")
        XCTAssertEqual(entries.first?.title, "月影步・熟練")
        XCTAssertEqual(entries.first?.locationLabel, "12年3月8日")
    }
}

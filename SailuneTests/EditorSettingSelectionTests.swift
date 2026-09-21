import XCTest
@testable import Sailune

final class EditorSettingSelectionTests: XCTestCase {
    func testCharacterSearchMatchesRealNameAndAlias() {
        XCTAssertTrue(CharacterSearchMatcher.matches(query: "林遠", realName: "林遠", aliasNames: ["夜行者"]))
        XCTAssertTrue(CharacterSearchMatcher.matches(query: "夜行者", realName: "林遠", aliasNames: ["夜行者"]))
        XCTAssertTrue(CharacterSearchMatcher.matches(query: "  夜行者  ", realName: "林遠", aliasNames: ["夜行者"]))
        XCTAssertFalse(CharacterSearchMatcher.matches(query: "不存在", realName: "林遠", aliasNames: ["夜行者"]))
        XCTAssertTrue(CharacterSearchMatcher.matches(query: " \n ", realName: "林遠", aliasNames: []))
    }

    func testInspectorSectionNameMatcherUsesCompleteTrimmedName() {
        XCTAssertTrue(
            InspectorSectionNameMatcher.matches(
                name: "  Silver Key  ",
                inText: "She carried the silver key through the gate."
            )
        )
        XCTAssertFalse(InspectorSectionNameMatcher.matches(name: "Silver Key", inText: "She carried silver."))
        XCTAssertFalse(InspectorSectionNameMatcher.matches(name: "  \n ", inText: "Any text"))
    }

    func testUniqueMatchTrimsSelectionAndMatchesCharacterAlias() {
        let characterID = UUID()
        let candidate = EditorSettingsNameCandidate(
            target: .character(characterID),
            names: ["安東", "安東・舊名"]
        )

        XCTAssertEqual(
            EditorSettingsMatcher.uniqueMatch(for: "  安東・舊名\n", candidates: [candidate]),
            .character(characterID)
        )
    }

    func testUniqueMatchIsCompleteAndCaseInsensitive() {
        let itemID = UUID()
        let candidate = EditorSettingsNameCandidate(target: .item(itemID), names: ["Silver Key"])

        XCTAssertEqual(
            EditorSettingsMatcher.uniqueMatch(for: "silver key", candidates: [candidate]),
            .item(itemID)
        )
        XCTAssertNil(EditorSettingsMatcher.uniqueMatch(for: "silver", candidates: [candidate]))
        XCTAssertNil(EditorSettingsMatcher.uniqueMatch(for: "Silver Key II", candidates: [candidate]))
    }

    func testMultipleNamesForSameTargetRemainOneMatch() {
        let characterID = UUID()
        let candidates = [
            EditorSettingsNameCandidate(target: .character(characterID), names: ["林遠"]),
            EditorSettingsNameCandidate(target: .character(characterID), names: ["遠"])
        ]

        XCTAssertEqual(EditorSettingsMatcher.uniqueMatch(for: "遠", candidates: candidates), .character(characterID))
    }

    func testUniqueMatchSupportsEverySettingsCategory() {
        let candidates: [(EditorSettingsTarget, String)] = [
            (.character(UUID()), "角色"),
            (.item(UUID()), "物品"),
            (.ability(UUID()), "能力"),
            (.power(UUID()), "勢力"),
            (.place(UUID()), "地點"),
            (.worldTerm(UUID()), "世界條目")
        ]

        for (target, name) in candidates {
            XCTAssertEqual(
                EditorSettingsMatcher.uniqueMatch(
                    for: name,
                    candidates: [EditorSettingsNameCandidate(target: target, names: [name])]
                ),
                target,
                "應支援設定集分類：\(name)"
            )
        }
    }

    func testAmbiguousMatchAcrossSettingsTypesDoesNotChooseFirst() {
        let candidates = [
            EditorSettingsNameCandidate(target: .character(UUID()), names: ["晨星"]),
            EditorSettingsNameCandidate(target: .worldTerm(UUID()), names: ["晨星"])
        ]

        XCTAssertNil(EditorSettingsMatcher.uniqueMatch(for: "晨星", candidates: candidates))
    }

    func testEmptySelectionAndEmptyCandidateNamesDoNotMatch() {
        let candidate = EditorSettingsNameCandidate(target: .place(UUID()), names: ["  ", "\n"])

        XCTAssertNil(EditorSettingsMatcher.uniqueMatch(for: " \n ", candidates: [candidate]))
        XCTAssertNil(EditorSettingsMatcher.uniqueMatch(for: "有地點", candidates: [candidate]))
        XCTAssertNil(EditorSettingsMatcher.uniqueMatch(for: "無候選", candidates: []))
    }

    func testMarkerLegendMatchesTheFiveExistingMarkerKindsAndColors() {
        XCTAssertEqual(
            StoryTagMarkerDefinition.allCases.map(\.title),
            ["主軸", "支線", "伏筆", "修改", "計劃加入"]
        )
        XCTAssertEqual(
            StoryTagMarkerDefinition.allCases.map(\.colorName),
            ["systemRed", "systemBlue", "systemYellow", "systemOrange", "systemGreen"]
        )
        XCTAssertEqual(
            StoryTagMarkerDefinition.allCases.map(\.color),
            [.systemRed, .systemBlue, .systemYellow, .systemOrange, .systemGreen]
        )
        XCTAssertEqual(
            StoryTagMarkerDefinition.allCases.map(\.opacity),
            [0.58, 0.58, 0.72, 0.16, 0.14]
        )
        for kind in StoryTagMarkerDefinition.allCases.map(\.kind) {
            XCTAssertEqual(StoryTagMarkerDefinition.definition(for: kind).kind, kind)
        }
    }
}

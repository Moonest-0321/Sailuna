import Foundation
import SwiftUI

enum SectionUnitPreference {
    static let storageKey = "sailune.sectionUnit"
    static let options: [BookTextSectionMarker] = [.section, .zhang, .chapter]

    static func resolve(_ rawValue: String?) -> BookTextSectionMarker {
        guard let rawValue, let value = BookTextSectionMarker(rawValue: rawValue) else {
            return .section
        }
        return value
    }

    static var current: BookTextSectionMarker {
        resolve(UserDefaults.standard.string(forKey: storageKey))
    }
}

extension BookTextSectionMarker {
    var unitLabel: String { rawValue }

    var sectionKindLabel: String {
        switch self {
        case .section: "節次"
        case .zhang: "張次"
        case .chapter: "章節"
        }
    }

    var titleFieldLabel: String {
        "\(unitLabel)標題"
    }

    var unnamedTitle: String {
        "未命名\(unitLabel)"
    }

    var draftTitle: String {
        "新\(unitLabel)"
    }

    var firstTitle: String {
        numberedTitle(1)
    }

    func displayTitle(_ storedTitle: String) -> String {
        for previousUnit in SectionUnitPreference.options {
            if storedTitle == previousUnit.firstTitle { return firstTitle }
            if storedTitle == previousUnit.draftTitle { return draftTitle }
        }
        return storedTitle
    }

    var addActionTitle: String {
        "新增\(unitLabel)"
    }

    var addFirstActionTitle: String {
        "新增第一\(unitLabel)"
    }

    var addInVolumeAccessibilityLabel: String {
        "在此卷新增\(unitLabel)"
    }

    func numberedTitle(_ ordinal: Int) -> String {
        "第\(Self.spelledOrdinal(ordinal))\(unitLabel)"
    }

    private static func spelledOrdinal(_ ordinal: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: ordinal)) ?? "\(ordinal)"
    }
}

private struct SectionUnitEnvironmentKey: EnvironmentKey {
    static let defaultValue = SectionUnitPreference.current
}

extension EnvironmentValues {
    var sectionUnit: BookTextSectionMarker {
        get { self[SectionUnitEnvironmentKey.self] }
        set { self[SectionUnitEnvironmentKey.self] = newValue }
    }
}

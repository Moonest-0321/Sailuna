import Foundation
import SwiftData

enum SailuneAICharacterContextError: LocalizedError {
    case characterNotFound
    case ambiguousCharacter
    case characterUnavailable
    case noCategoriesSelected

    var errorDescription: String? {
        switch self {
        case .characterNotFound: "目前書籍找不到這個角色；請確認名稱或改用一般聊天。"
        case .ambiguousCharacter: "目前書籍有多位符合的角色，請在「角色資訊整理」中選擇正確角色。"
        case .characterUnavailable: "所選角色已不存在或不屬於目前書籍，請重新選擇。"
        case .noCategoriesSelected: "請至少選擇一個角色分類。"
        }
    }
}

@MainActor
enum SailuneAICharacterContextBuilder {
    static func queryAttachment(
        for prompt: String,
        bookID: UUID,
        context: ModelContext,
        abilityStore: AbilityProgressStore,
        settingsStore: V5SettingsStore
    ) throws -> SailuneAISectionAttachment? {
        guard isCharacterDataRequest(prompt) else { return nil }
        let characters = try context.fetch(FetchDescriptor<Character>()).filter { $0.book?.id == bookID }
        let aliases = try context.fetch(FetchDescriptor<CharacterAlias>()).filter { $0.character?.book?.id == bookID }
        let mentions = characters.compactMap { character -> (UUID, Int)? in
            contains(prompt, name: character.realName) ? (character.id, character.realName.count) : nil
        } + aliases.compactMap { alias -> (UUID, Int)? in
            guard let characterID = alias.character?.id, contains(prompt, name: alias.name) else { return nil }
            return (characterID, alias.name.count)
        }
        let longestMention = mentions.map(\.1).max()
        let matchedIDs = Set(mentions.filter { $0.1 == longestMention }.map(\.0))
        guard !matchedIDs.isEmpty else { throw SailuneAICharacterContextError.characterNotFound }
        guard matchedIDs.count == 1, let characterID = matchedIDs.first,
              let character = characters.first(where: { $0.id == characterID }) else {
            throw SailuneAICharacterContextError.ambiguousCharacter
        }
        let content = try snapshot(
            character: character,
            categories: Set(SailuneAICharacterCategory.allCases),
            bookID: bookID,
            context: context,
            abilityStore: abilityStore,
            settingsStore: settingsStore
        )
        return SailuneAISectionAttachment(id: character.id, title: character.realName, content: content, kind: .characterProfile)
    }

    static func templateAttachment(
        selection: SailuneAICharacterTemplateSelection,
        section: Section,
        bookID: UUID,
        context: ModelContext
    ) throws -> SailuneAISectionAttachment {
        guard !selection.categories.isEmpty else { throw SailuneAICharacterContextError.noCategoriesSelected }
        guard let character = try context.fetch(FetchDescriptor<Character>()).first(where: {
            $0.id == selection.characterID && $0.book?.id == bookID
        }) else { throw SailuneAICharacterContextError.characterUnavailable }
        let categories = selection.categories.sorted { $0.rawValue < $1.rawValue }.map(\.rawValue).joined(separator: "、")
        let volumeTitle = section.volume.map { $0.title.isEmpty ? "未命名卷" : $0.title } ?? "未命名卷"
        let sectionTitle = section.title.isEmpty ? "未命名節" : section.title
        let content = """
        目標角色：\(character.realName)
        整理分類：\(categories)

        本節原文（唯一可作為本節資訊依據的來源）：
        \(String(section.content.characters))
        """
        return SailuneAISectionAttachment(
            id: section.id,
            title: "\(character.realName)・\(volumeTitle)／\(sectionTitle)・\(categories)",
            content: content,
            kind: .characterSectionTemplate
        )
    }

    private static func isCharacterDataRequest(_ prompt: String) -> Bool {
        ["資料", "設定", "角色資訊", "人物資訊", "介紹", "角色檔案"].contains(where: prompt.contains)
    }

    private static func contains(_ text: String, name: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && text.range(of: name, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    static func snapshot(
        character: Character,
        categories: Set<SailuneAICharacterCategory>,
        bookID: UUID,
        context: ModelContext,
        abilityStore: AbilityProgressStore,
        settingsStore: V5SettingsStore
    ) throws -> String {
        let characterID = character.id
        var output: [String] = []
        let profiles = try context.fetch(FetchDescriptor<CharacterProfile>())
        let aliases = try context.fetch(FetchDescriptor<CharacterAlias>()).filter { $0.character?.id == characterID }
        let appearances = try context.fetch(FetchDescriptor<CharacterAppearance>()).filter { $0.character?.id == characterID }
        let psychologies = try context.fetch(FetchDescriptor<CharacterPsychology>()).filter { $0.character?.id == characterID }
        let abilities = try context.fetch(FetchDescriptor<CharacterAbility>()).filter { $0.character?.id == characterID }
        let items = try context.fetch(FetchDescriptor<CharacterItem>()).filter { $0.character?.id == characterID }
        let relationships = try context.fetch(FetchDescriptor<CharacterRelationship>()).filter { $0.sourceCharacter?.id == characterID }
        let kinships = try context.fetch(FetchDescriptor<KinshipRelation>()).filter { $0.sourceCharacter?.id == characterID }
        let summaries = try context.fetch(FetchDescriptor<CharacterSummary>()).filter { $0.character?.id == characterID }
        let itemsInBook = Set(try context.fetch(FetchDescriptor<Item>()).filter { $0.book?.id == bookID }.map(\.id))
        let events = try context.fetch(FetchDescriptor<Event>()).filter {
            $0.section?.volume?.book?.id == bookID && $0.characters.contains(where: { $0.id == characterID })
        }

        if categories.contains(.summary) {
            let values = summaries.map { summary in
                [summary.alias.map { "別名：\($0.name)" },
                 summary.organizationIdentity.map { "勢力身分：\($0.identity)" },
                 summary.ability.map { "能力：\($0.name)" },
                 summary.psychology.map { "心理：\($0.content)" },
                 summary.relationship.map { "關係：\($0.type)・\($0.note)" }]
                    .compactMap { $0 }.joined(separator: "；")
            }
            add("摘要", values, to: &output)
        }

        if categories.contains(.basic) {
            let profile = profiles.first { $0.character?.id == characterID }
            let birth = [character.birthYear, character.birthMonth, character.birthDay, character.birthSeason]
                .compactMap { cleaned($0) }.joined(separator: "／")
            add("基本資訊", [
                "角色：\(character.realName)", line("身分", profile?.role), line("性別", character.gender), line("出生", birth),
                line("出身", character.originBackground), line("來歷", character.originStory), line("性格", character.personality),
                line("原則", character.principles), line("小記", character.notes)
            ], to: &output)
        }
        if categories.contains(.power) {
            let powers = settingsStore.powers(for: bookID)
            let memberships = settingsStore.members(for: bookID).filter { $0.characterID == characterID }.compactMap { member -> String? in
                guard let power = powers.first(where: { $0.id == member.powerID }) else { return nil }
                let roles = settingsStore.roles(for: member, bookID: bookID).map(\.title).filter { !$0.isEmpty }
                return "\(power.name)（\(member.status.title)\(roles.isEmpty ? "" : "；職務：\(roles.joined(separator: "、"))")）"
            }
            add("所屬勢力", memberships, to: &output)
        }
        if categories.contains(.aliases) {
            add("別名", aliases.map { "\($0.name)\($0.note.isEmpty ? "" : "（\($0.note)）")" }, to: &output)
        }
        if categories.contains(.abilities) {
            let values = abilityStore.connections.filter { $0.characterID == characterID }.compactMap { connection -> String? in
                guard let ability = abilities.first(where: { $0.id == connection.abilityID }) else { return nil }
                let level = abilityStore.levels.first(where: { $0.id == connection.currentLevelID })?.name
                let history = abilityStore.histories.filter { $0.connectionID == connection.id }.sorted { $0.sortOrder < $1.sortOrder }.map(\.content)
                return [ability.name, ability.currentStage, level, ability.stageDescription, ability.summary, history.joined(separator: "；")]
                    .compactMap { cleaned($0) }.joined(separator: "｜")
            }
            add("能力", values, to: &output)
        }
        if categories.contains(.appearance) {
            add("外觀", appearances.map {
                [$0.kind == .outfit ? "服裝" : "身體特徵", $0.descriptionText, $0.usage, $0.note]
                    .compactMap { cleaned($0) }.joined(separator: "｜")
            }, to: &output)
        }
        if categories.contains(.psychology) {
            add("心理", psychologies.map {
                let kind: String
                switch $0.kind { case .personality: kind = "性格"; case .value: kind = "價值觀"; case .motivation: kind = "動機" }
                return "\(kind)：\($0.content)"
            }, to: &output)
        }
        if categories.contains(.items) {
            let history = try context.fetch(FetchDescriptor<CharacterItemHistory>())
            add("物品", items.compactMap { holding -> String? in
                guard let item = holding.item, itemsInBook.contains(item.id) else { return nil }
                let notes = history.filter { $0.characterItem?.id == holding.id }.sorted { $0.sortOrder < $1.sortOrder }.map(\.content)
                return ["\(item.name) ×\(holding.quantity)", item.itemDescription, item.category, item.appearanceAndMaterial, item.usage,
                        item.positiveAbility, item.negativeAbility, notes.joined(separator: "；")]
                    .compactMap { cleaned($0) }.joined(separator: "｜")
            }, to: &output)
        }
        if categories.contains(.relationships) {
            let values = relationships.filter { $0.targetCharacter?.book?.id == bookID }.map { relation in
                let history = relation.history.sorted { $0.sortOrder < $1.sortOrder }.map { "\($0.type)：\($0.note)" }.joined(separator: "；")
                return ["\(relation.targetCharacter?.realName ?? "未指定角色")・\(relation.type)", relation.note, history]
                    .compactMap { cleaned($0) }.joined(separator: "｜")
            } + kinships.filter { $0.targetCharacter?.book?.id == bookID }.map { "血緣：\($0.role.displayName)・\($0.targetCharacter?.realName ?? "未指定角色")" }
            add("關係", values, to: &output)
        }
        if categories.contains(.events) {
            add("事件", events.map { "\($0.title)：\($0.detail)" }, to: &output)
        }

        return output.isEmpty ? "目前角色資料的所選分類沒有已填寫內容。" : output.joined(separator: "\n\n")
    }

    private static func add(_ title: String, _ values: [String], to output: inout [String]) {
        let values = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0 != "｜" }
        guard !values.isEmpty else { return }
        output.append("【\(title)】\n" + values.map { "- \($0)" }.joined(separator: "\n"))
    }

    private static func line(_ label: String, _ value: String?) -> String {
        guard let value = cleaned(value) else { return "" }
        return "\(label)：\(value)"
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

import XCTest
import SwiftData
@testable import Sailune

@MainActor
final class CharacterLinkedCreationTests: XCTestCase {
    private func container(_ models: [any PersistentModel.Type]) throws -> ModelContainer {
        let schema = Schema(models)
        return try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    func testCreatesAndConnectsEveryCharacterDetailTarget() throws {
        let main = try container(NovelWriterSchemaV5.models)
        let ability = try AbilityProgressStore(container: container(AbilityProgressSchemaV1.models))
        let copies = try ItemCopyStore(container: container(ItemCopySchemaV1.models))
        let settings = V5SettingsStore(container: try container(V5SettingsSchemaV13.models))
        let book = Book(title: "建立連接", author: "作者")
        let source = Character(realName: "主角", book: book)
        main.mainContext.insert(book)
        main.mainContext.insert(source)
        try main.mainContext.save()

        try CharacterLinkedCreation.ability(named: "  劍術  ", for: source, book: book,
            readOnly: false, main: main.mainContext, progress: ability)
        let createdAbility = try XCTUnwrap(main.mainContext.fetch(FetchDescriptor<CharacterAbility>()).first)
        XCTAssertEqual(createdAbility.name, "劍術")
        XCTAssertTrue(ability.bookLinks.contains { $0.abilityID == createdAbility.id && $0.bookID == book.id })
        XCTAssertTrue(ability.connections.contains { $0.abilityID == createdAbility.id && $0.characterID == source.id })

        try CharacterLinkedCreation.item(named: "  長劍  ", for: source, book: book,
            readOnly: false, main: main.mainContext, copies: copies)
        let item = try XCTUnwrap(main.mainContext.fetch(FetchDescriptor<Item>()).first)
        let copy = try XCTUnwrap(copies.copies.first)
        XCTAssertEqual(item.name, "長劍")
        XCTAssertEqual(copy.itemID, item.id)
        XCTAssertEqual(copies.holdings.first?.characterID, source.id)
        XCTAssertEqual(copies.holdings.first?.copyID, copy.id)

        try CharacterLinkedCreation.power(named: "  北境  ", for: source, book: book,
            readOnly: false, settings: settings)
        let power = try XCTUnwrap(settings.powers(for: book.id).first)
        XCTAssertEqual(power.name, "北境")
        XCTAssertEqual(settings.members(for: book.id).first?.characterID, source.id)
        XCTAssertEqual(settings.members(for: book.id).first?.powerID, power.id)

        let friend = try CharacterLinkedCreation.relatedCharacter(named: "朋友", for: source,
            book: book, readOnly: false, main: main.mainContext)
        let relative = try CharacterLinkedCreation.kinshipCharacter(named: "妹妹", for: source,
            book: book, readOnly: false, role: .fatherToChild, main: main.mainContext)
        XCTAssertEqual(friend.book?.id, book.id)
        XCTAssertEqual(relative.book?.id, book.id)
        XCTAssertEqual(friend.sortOrder, source.sortOrder + 1)
        XCTAssertEqual(relative.sortOrder, friend.sortOrder + 1)
        XCTAssertTrue(try main.mainContext.fetch(FetchDescriptor<CharacterRelationship>()).contains {
            $0.sourceCharacter?.id == source.id && $0.targetCharacter?.id == friend.id
        })
        XCTAssertTrue(source.kinships.contains { $0.targetCharacter?.id == relative.id })
        XCTAssertTrue(relative.kinships.contains { $0.targetCharacter?.id == source.id })
    }

    func testRejectsBlankCrossBookAndReadOnlyWithoutCreatingRecords() throws {
        let main = try container(NovelWriterSchemaV5.models)
        let first = Book(title: "第一本", author: "作者")
        let second = Book(title: "第二本", author: "作者")
        let character = Character(realName: "主角", book: first)
        main.mainContext.insert(first)
        main.mainContext.insert(second)
        main.mainContext.insert(character)
        try main.mainContext.save()

        XCTAssertThrowsError(try CharacterLinkedCreation.relatedCharacter(named: "  ", for: character,
            book: first, readOnly: false, main: main.mainContext))
        XCTAssertThrowsError(try CharacterLinkedCreation.relatedCharacter(named: "新角色", for: character,
            book: second, readOnly: false, main: main.mainContext))
        XCTAssertThrowsError(try CharacterLinkedCreation.relatedCharacter(named: "新角色", for: character,
            book: first, readOnly: true, main: main.mainContext))
        XCTAssertEqual(try main.mainContext.fetch(FetchDescriptor<Character>()).count, 1)
        XCTAssertTrue(try main.mainContext.fetch(FetchDescriptor<CharacterRelationship>()).isEmpty)
    }

    func testNewHeldItemSurvivesReopeningBothStores() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SailuneV12LinkedCreation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let mainURL = directory.appendingPathComponent("main.store")
        let copyURL = directory.appendingPathComponent("copies.store")
        let mainSchema = Schema(versionedSchema: NovelWriterSchemaV5.self)
        let copySchema = Schema(versionedSchema: ItemCopySchemaV1.self)
        let bookID: UUID
        let characterID: UUID

        do {
            let main = try ModelContainer(for: mainSchema,
                configurations: [ModelConfiguration(schema: mainSchema, url: mainURL)])
            let copyContainer = try ModelContainer(for: copySchema,
                configurations: [ModelConfiguration(schema: copySchema, url: copyURL)])
            let copies = try ItemCopyStore(container: copyContainer)
            let book = Book(title: "重開驗證", author: "作者")
            let character = Character(realName: "持有人", book: book)
            bookID = book.id
            characterID = character.id
            main.mainContext.insert(book)
            main.mainContext.insert(character)
            try main.mainContext.save()
            try CharacterLinkedCreation.item(named: "信物", for: character, book: book,
                readOnly: false, main: main.mainContext, copies: copies)
        }

        let reopenedMain = try ModelContainer(for: mainSchema,
            configurations: [ModelConfiguration(schema: mainSchema, url: mainURL)])
        let reopenedCopy = try ModelContainer(for: copySchema,
            configurations: [ModelConfiguration(schema: copySchema, url: copyURL)])
        let item = try XCTUnwrap(reopenedMain.mainContext.fetch(FetchDescriptor<Item>()).first)
        let copy = try XCTUnwrap(reopenedCopy.mainContext.fetch(FetchDescriptor<ItemCopy>()).first)
        let holding = try XCTUnwrap(reopenedCopy.mainContext.fetch(FetchDescriptor<ItemCopyHolding>()).first)
        XCTAssertEqual(item.book?.id, bookID)
        XCTAssertEqual(copy.itemID, item.id)
        XCTAssertEqual(holding.copyID, copy.id)
        XCTAssertEqual(holding.characterID, characterID)
    }
}

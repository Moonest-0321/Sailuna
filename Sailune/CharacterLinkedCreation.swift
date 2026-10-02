import SwiftData
import SwiftUI

enum CharacterLinkedCreationError: LocalizedError {
    case emptyName
    case invalidBook
    case readOnly
    case incomplete

    var errorDescription: String? {
        switch self {
        case .emptyName: "請輸入名稱。"
        case .invalidBook: "角色與新項目必須屬於同一本書。"
        case .readOnly: "完結作品不可新增資料。"
        case .incomplete: "建立未完成，請先重新開啟作品確認資料，再重試。"
        }
    }
}

/// Owns each create-and-link operation so views never coordinate two stores.
@MainActor
enum CharacterLinkedCreation {
    private static func name(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw CharacterLinkedCreationError.emptyName }
        return value
    }

    private static func validate(_ character: Character, book: Book, readOnly: Bool) throws {
        guard !readOnly else { throw CharacterLinkedCreationError.readOnly }
        guard character.book?.id == book.id else { throw CharacterLinkedCreationError.invalidBook }
    }

    private static func nextCharacterOrder(in book: Book, main: ModelContext) throws -> Int {
        let characters = try main.fetch(FetchDescriptor<Character>())
        return (characters.filter { $0.book?.id == book.id }.map(\.sortOrder).max() ?? -1) + 1
    }

    static func ability(named raw: String, for character: Character, book: Book, readOnly: Bool,
                        main: ModelContext, progress: AbilityProgressStore) throws {
        try validate(character, book: book, readOnly: readOnly)
        let ability = CharacterAbility(name: try name(raw))
        main.insert(ability)
        do { try main.save() }
        catch { main.rollback(); throw error }
        do {
            try progress.register(abilityID: ability.id, bookID: book.id)
            try progress.connectAndSave(characterID: character.id, abilityID: ability.id)
        } catch {
            let originalError = error
            do { try progress.removeNewAbilityLinks(ability.id) }
            catch { throw CharacterLinkedCreationError.incomplete }
            main.delete(ability)
            do { try main.save() }
            catch { throw CharacterLinkedCreationError.incomplete }
            throw originalError
        }
    }

    static func item(named raw: String, for character: Character, book: Book, readOnly: Bool,
                     main: ModelContext, copies: ItemCopyStore) throws {
        try validate(character, book: book, readOnly: readOnly)
        let item = Item(name: try name(raw), book: book)
        main.insert(item)
        do { try main.save() }
        catch { main.rollback(); throw error }
        do { try copies.createHeldCopyAndSave(itemID: item.id, characterID: character.id) }
        catch {
            let originalError = error
            main.delete(item)
            do { try main.save() }
            catch { throw CharacterLinkedCreationError.incomplete }
            throw originalError
        }
    }

    static func power(named raw: String, for character: Character, book: Book, readOnly: Bool,
                      settings: V5SettingsStore) throws {
        try validate(character, book: book, readOnly: readOnly)
        let power = PowerUnit(bookID: book.id, name: try name(raw))
        settings.context.insert(power)
        do { try settings.context.save(); settings.didSave() }
        catch { settings.context.rollback(); throw error }
        do {
            try settings.addMember(characterID: character.id, characterBookID: book.id,
                                   title: "", to: power, bookID: book.id)
        } catch {
            let originalError = error
            settings.context.rollback()
            settings.context.delete(power)
            do { try settings.context.save(); settings.didSave() }
            catch { throw CharacterLinkedCreationError.incomplete }
            throw originalError
        }
    }

    @discardableResult
    static func relatedCharacter(named raw: String, for source: Character, book: Book, readOnly: Bool,
                                 main: ModelContext, relationshipType: String = "朋友",
                                 reverse: Bool = false, note: String = "", node: Node? = nil) throws -> Character {
        try validate(source, book: book, readOnly: readOnly)
        let target = Character(realName: try name(raw), book: book)
        target.sortOrder = try nextCharacterOrder(in: book, main: main)
        main.insert(target)
        let relationship = CharacterRelationship(type: relationshipType, note: note,
            sourceCharacter: reverse ? target : source,
            targetCharacter: reverse ? source : target)
        let history = RelationshipHistory(type: relationshipType, note: note, node: node, relationship: relationship)
        relationship.history.append(history)
        main.insert(relationship)
        main.insert(history)
        do { try main.save(); return target }
        catch { main.rollback(); throw error }
    }

    @discardableResult
    static func kinshipCharacter(named raw: String, for source: Character, book: Book, readOnly: Bool,
                                 role: KinshipRole, main: ModelContext) throws -> Character {
        try validate(source, book: book, readOnly: readOnly)
        let target = Character(realName: try name(raw), book: book)
        target.sortOrder = try nextCharacterOrder(in: book, main: main)
        main.insert(target)
        let forward = KinshipRelation(role: role, targetCharacter: target)
        let inverse = KinshipRelation(role: role.inverseRole, targetCharacter: source)
        source.kinships.append(forward)
        target.kinships.append(inverse)
        main.insert(forward)
        main.insert(inverse)
        do { try main.save(); return target }
        catch { main.rollback(); throw error }
    }
}

/// Presentation only. The caller supplies the persistence action.
struct CharacterLinkedNameSheet: View {
    let title: String
    let fieldTitle: String
    let onCreate: (String) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var errorMessage: String?
    @State private var needsRecovery = false

    var body: some View {
        VStack(alignment: .leading, spacing: SailuneLayout.spacingM) {
            Text(title).font(.headline)
            SailuneFormTextField(title: LocalizedStringKey(fieldTitle), text: $name)
                .onSubmit(create)
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(SailuneTheme.errorText) }
            HStack {
                Button(SailuneActionCopy.cancel) { dismiss() }
                Spacer()
                Button("建立並連接", action: create)
                    .buttonStyle(.borderedProminent)
                    .disabled(needsRecovery || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(SailuneLayout.spacingL)
        .frame(width: 320)
    }

    private func create() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do { try onCreate(name); dismiss() }
        catch {
            errorMessage = error.localizedDescription
            needsRecovery = error is CharacterLinkedCreationError &&
                (error as? CharacterLinkedCreationError) == .incomplete
        }
    }
}

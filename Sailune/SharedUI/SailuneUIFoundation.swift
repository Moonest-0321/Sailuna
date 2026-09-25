import AppKit
import SwiftUI

/// V9 新增介面的共用間距與控制項尺寸。
enum SailuneLayout {
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24

    static let regularControlHeight: CGFloat = 28
    static let iconHitSize: CGFloat = 28
}

/// 功能畫面依語意選色，不自行重建相同顏色。
enum SailuneTheme {
    private static let secondaryEightPercent = Color.secondary.opacity(0.08)

    static let appBackground = Color.appBackground
    static let panelSurface = Color.workspacePanelBackground
    static let subtleSurface = Color.secondary.opacity(0.06)
    static let controlSurface = Color(nsColor: .controlBackgroundColor)
    static let windowSurface = Color(nsColor: .windowBackgroundColor)
    static let insetRowSurface = Color.secondary.opacity(0.05)
    static let faintCardSurface = Color.secondary.opacity(0.04)
    static let characterSectionBorder = Color.secondary.opacity(0.12)
    static let outlinePlaceholderBorder = Color.secondary.opacity(0.45)
    static let searchFieldSurface = secondaryEightPercent
    static let navigationCardSurface = secondaryEightPercent
    static let storyBackgroundEditorSurface = secondaryEightPercent
    static let textEditorSurface = Color(nsColor: .textBackgroundColor).opacity(0.7)
    static let textEditorBorder = Color.secondary.opacity(0.25)
}

/// 圖標依操作命名；相似圖形仍保留不同的操作語意。
enum SailuneSymbol {
    case add
    case addCircle
    case addCircleFilled
    case addVolume
    case addCopy
    case export
    case exportText
    case exportEpub
    case importBook
    case addSection
    case storyLine
    case relationship
    case aiReadingScope
    case aiCharacterTemplate
    case ability
    case delete
    case deleteTime
    case removeAssociation
    case removeEntry
    case removeHolder
    case removeCover
    case removeRelatedCharacter
    case removeSelection
    case back
    case requirementNotice
    case warning
    case timeline
    case disclosure
    case close
    case cancel
    case edit
    case search
    case clearSearch
    case more
    case item
    case powerLevel
    case resource
    case confirm
    case selected
    case save
    case settings
    case zoomIn
    case imageAsset
    case reorderHandle
    case linkedReference
    case settingsSidebar
    case mapStack
    case government
    case belief
    case people
    case technology
    case relatedCharacters
    case rowNavigation
    case sectionDocument

    var systemName: String {
        switch self {
        case .add: "plus"
        case .addCircle: "plus.circle"
        case .addCircleFilled: "plus.circle.fill"
        case .addVolume: "folder.badge.plus"
        case .addCopy: "plus.square.on.square"
        case .export: "square.and.arrow.up"
        case .exportText: "doc.text"
        case .exportEpub: "book.closed"
        case .importBook: "square.and.arrow.down"
        case .addSection: "doc.badge.plus"
        case .storyLine: "point.topleft.down.to.point.bottomright.curvepath"
        case .relationship: "point.3.connected.trianglepath.dotted"
        case .aiReadingScope: "doc.text.magnifyingglass"
        case .aiCharacterTemplate: "person.text.rectangle"
        case .ability: "sparkles"
        case .zoomIn: "plus"
        case .delete, .removeHolder, .removeCover: "trash"
        case .deleteTime, .removeRelatedCharacter, .removeSelection: "xmark"
        case .removeAssociation, .removeEntry: "minus.circle"
        case .back: "chevron.left"
        case .requirementNotice: "exclamationmark.circle"
        case .warning: "exclamationmark.triangle.fill"
        case .timeline: "clock"
        case .disclosure: "chevron.right"
        case .close, .cancel: "xmark"
        case .edit: "pencil"
        case .search: "magnifyingglass"
        case .clearSearch: "xmark.circle.fill"
        case .more: "ellipsis.circle"
        case .item: "shippingbox"
        case .powerLevel: "list.number"
        case .resource: "shippingbox"
        case .confirm, .selected: "checkmark"
        case .save: "square.and.arrow.down"
        case .settings: "gearshape"
        case .imageAsset: "photo"
        case .reorderHandle: "line.3.horizontal"
        case .linkedReference: "link"
        case .settingsSidebar: "sidebar.right"
        case .mapStack: "square.stack.3d.up"
        case .government: "building.columns"
        case .belief: "hands.sparkles"
        case .people: "person.3"
        case .technology: "gearshape.2"
        case .relatedCharacters: "person.2"
        case .rowNavigation: "arrow.right"
        case .sectionDocument: "doc.text"
        }
    }
}

/// 通用操作文字集中管理；帶有領域對象的標籤仍須明確命名。
enum SailuneActionCopy {
    static let add = String(localized: "action.add", defaultValue: "新增")
    static let delete = String(localized: "action.delete", defaultValue: "刪除")
    static let edit = String(localized: "action.edit", defaultValue: "編輯")
    static let search = String(localized: "action.search", defaultValue: "搜尋")
    static let save = String(localized: "action.save", defaultValue: "儲存")
    static let cancel = String(localized: "action.cancel", defaultValue: "取消")
    static let close = String(localized: "action.close", defaultValue: "關閉")
    static let confirm = String(localized: "action.confirm", defaultValue: "確認")
    static let acknowledge = String(localized: "action.acknowledge", defaultValue: "好")
    static let done = String(localized: "action.done", defaultValue: "完成")
    static let exportText = String(localized: "action.exportText", defaultValue: "匯出 TXT")
    static let importBook = String(localized: "action.importBook", defaultValue: "匯入書籍")
    static let exportEpub = String(localized: "action.exportEpub", defaultValue: "匯出 EPUB")
    static let deleteAppearance = String(localized: "action.deleteAppearance", defaultValue: "刪除外觀")
    static let deleteTime = String(localized: "action.deleteTime", defaultValue: "刪除這個時間")
    static let closeStoryBackground = String(localized: "action.closeStoryBackground", defaultValue: "關閉故事背景")
    static let removeHolder = String(localized: "action.removeHolder", defaultValue: "移除持有人；副本仍保留")
    static let rename = String(localized: "action.rename", defaultValue: "重新命名")
    static let clearSelection = String(localized: "action.clearSelection", defaultValue: "不選擇")
    static let addSection = String(localized: "action.addSection", defaultValue: "新增節")
    static func selectPreset(_ title: String) -> String {
        String(localized: "action.selectPreset", defaultValue: "選擇\(title)")
    }
    static let create = String(localized: "action.create", defaultValue: "建立")
    static let addEvent = String(localized: "action.addEvent", defaultValue: "新增事件")
    static let addVolume = String(localized: "action.addVolume", defaultValue: "新增卷")
    static let addOutlineItem = String(localized: "action.addOutlineItem", defaultValue: "新增大綱項目")
    static let addRelationship = String(localized: "action.addRelationship", defaultValue: "新增關係")
    static let deleteCopy = String(localized: "action.deleteCopy", defaultValue: "刪除副本")
    static let deleteVolume = String(localized: "action.deleteVolume", defaultValue: "刪除卷")
    static let deletePlace = String(localized: "action.deletePlace", defaultValue: "刪除地點")
    static let deleteStoryLine = String(localized: "action.deleteStoryLine", defaultValue: "刪除故事線")
    static let deleteItem = String(localized: "action.deleteItem", defaultValue: "刪除物品")
    static let deleteSection = String(localized: "action.deleteSection", defaultValue: "刪除節")
    static let deleteStage = String(localized: "action.deleteStage", defaultValue: "刪除階段")
    static let restore = String(localized: "action.restore", defaultValue: "復原")
    static let addCopy = String(localized: "action.addCopy", defaultValue: "新增副本")
    static let addHistory = String(localized: "action.addHistory", defaultValue: "新增歷史")
    static let addFirstSection = String(localized: "action.addFirstSection", defaultValue: "新增第一節")
    static let addLevel = String(localized: "action.addLevel", defaultValue: "新增等級")
    static let manageLevels = String(localized: "action.manageLevels", defaultValue: "管理層級")
    static let editEra = String(localized: "action.editEra", defaultValue: "編輯紀元")
    static let back = String(localized: "action.back", defaultValue: "返回")
}

enum SailuneAccessibilityCopy {
    static let addSectionInVolume = String(localized: "accessibility.addSectionInVolume", defaultValue: "在此卷新增節")
    static let confirmEnter = String(localized: "accessibility.confirmEnter", defaultValue: "確認 (Enter)")
    static let showOnMainTimeline = String(localized: "accessibility.showOnMainTimeline", defaultValue: "顯示於主時間軸")
    static let fitWindow = String(localized: "accessibility.fitWindow", defaultValue: "符合視窗")
    static let manageLayers = String(localized: "accessibility.manageLayers", defaultValue: "管理圖層")
    static let manageMaps = String(localized: "accessibility.manageMaps", defaultValue: "管理地圖")
    static let enterCoordinates = String(localized: "accessibility.enterCoordinates", defaultValue: "輸入座標")
    static let switchConversation = String(localized: "accessibility.switchConversation", defaultValue: "切換對話")
    static let closeAIAssistant = String(localized: "accessibility.closeAIAssistant", defaultValue: "關閉 AI 助手")
    static let removeCharacterTemplate = String(localized: "accessibility.removeCharacterTemplate", defaultValue: "移除角色整理模板")
    static let removeReadingScope = String(localized: "accessibility.removeReadingScope", defaultValue: "移除閱讀範圍")
    static let sendMessage = String(localized: "accessibility.sendMessage", defaultValue: "送出訊息")
    static let addConversation = String(localized: "accessibility.addConversation", defaultValue: "新增對話")
}

/// 保留既有 28 pt 純圖標按鈕的外觀與命中框，並統一操作名稱。
struct SailuneIconButton: View {
    let symbol: SailuneSymbol
    let label: String
    let role: ButtonRole?
    let action: () -> Void

    init(symbol: SailuneSymbol, label: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.symbol = symbol
        self.label = label
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: symbol.systemName)
                .frame(width: SailuneLayout.iconHitSize, height: SailuneLayout.iconHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(Text(label))
    }
}

/// 一般設定欄位使用的既有多行編輯器；保留原本的輸入及版面行為。
struct InsetTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 90

    var body: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .font(.body)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(minHeight: minHeight)
            .background(SailuneTheme.textEditorSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(SailuneTheme.textEditorBorder))
    }
}

/// 既有設定頁使用的原生多行編輯器與邊框，不加入內距或背景。
struct SailuneBorderedTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 90

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: minHeight)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(SailuneTheme.textEditorBorder))
    }
}

/// 作者簡介在設定頁及首頁彈窗共用輸入結構，各畫面保留原高度、描邊與 placeholder。
struct SailuneAuthorBioEditor: View {
    @Binding var text: String
    let height: CGFloat
    let borderColor: Color
    var placeholder: LocalizedStringKey? = nil

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                if text.isEmpty, let placeholder {
                    Text(placeholder)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// 不含特殊提交或數值規則的一般單行表單欄位。
struct SailuneFormTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.roundedBorder)
    }
}

/// 多個功能區共用的搜尋欄位，沿用原有 placeholder、清除與排版行為。
struct SailuneSearchField: View {
    let placeholder: String
    @Binding var text: String
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: SailuneSymbol.search.systemName)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: SailuneSymbol.clearSearch.systemName)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(SailuneTheme.searchFieldSurface, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, compact ? 0 : 12)
        .padding(.top, compact ? 0 : 10)
        .padding(.bottom, compact ? 0 : 10)
    }
}

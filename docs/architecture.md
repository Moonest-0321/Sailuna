# 技術架構

> 完整架構核對基準：2026-09-22。其後 V9 專題新增的責任摘要截至 2026-09-25；這不代表所有模組均已重新核對，未完成項以 V9 交接與固定盤點為準。

## 技術組成

- macOS 原生應用；SwiftUI 負責主要畫面，AppKit `NSTextView` 負責正文編輯。
- SwiftData／`ModelContext` 持久化；正文使用 `AttributedString`。
- TXT 與 EPUB 由專案內原生程式產生，不依賴外部壓縮套件。
- 地圖模板、匯入正規化與畫面背景使用 Core Graphics／PDFKit；PDF 資產獨立於 SwiftData 座標資料。
- `SailuneTests` 使用 XCTest，測試模型、投影、遷移、錨點、刪除與編輯器橋接。
- V8 AI 助手使用 Apple Foundation Models 裝置端生成，不需要金鑰或後端；作者明確選取節次後才把該節次純文字快照加入目前對話。對話依書籍 UUID 另存 JSON，並納入完整備份。首頁 Gemini 使用入口已移除。既有 Node.js／TypeScript 本機後端保留作開發資產。

## 執行結構

```text
SailuneApp
├─ 主 store（書籍、正文、設定、世界時間）
├─ 物品副本 store
├─ 副本等級選擇 store
├─ 能力進度 store
└─ 故事規劃 store（標籤、背景、敘事大綱、事件卡 metadata）

ContentView（書櫃）
└─ BookOverviewView（書籍總覽、卷節、背景）
   └─ EditorWorkspaceView
      ├─ 正文工作區 + AI 助手側欄 + 設定集側欄
      ├─ MapWorkspaceView（平面層級、多張具體地圖、替代背景版本、map-local placement）
      └─ BookPlanningWorkspaceView
         ├─ 敘事大綱畫布
         └─ 世界時間軸
```

## 共用 UI 基礎責任

- 共用 UI foundation 集中維護可重用的按鈕、欄位、一般文字編輯器、surface／狀態色 tokens、語意圖標與通用文案資源；具體檔案／namespace 以 V9 component inventory 核定結果為準。
- 共用 UI 層只負責呈現、互動、無障礙標籤和通用視覺狀態；不依賴領域 Store，不決定角色、章節、事件或其他資料的新增／刪除規則。
- 功能畫面以語意 variant、binding、label／message 與 action 呼叫共用元件；跨 Store、持久化、檔案及資料不變條件留在對應 Store／Coordinator。
- 正文 AppKit `NSTextView`、AI composer 及其他輸入／保存行為特殊的控制項可維持專用實作，但應重用相容的 theme token 和語意資源，並記錄未共用完整控制項的理由。
- `AppTheme` 保留既有主題色，V9.1a 在 `SharedUI` 加入語意 tokens、圖標與文案資源，並把已跨畫面使用的 `InsetTextEditor`、`PlanningActionStyle` 宣告移至該處；其視覺與互動 API 仍以 V9.1 試行驗收結果調整。
- V9.1o 在共用 theme 中分開命名搜尋欄、故事背景編輯欄與導覽卡片的表面色；三者目前共用同一 `0.08` 顏色值來源，但呼叫端按用途選 token，避免未來調整其中一類時改錯其他功能。

## 主要責任

- `SailuneApp.swift`：在還原或開啟 store 前建立主資料目錄並回報目錄錯誤，建立六個 store、匯入舊 V2／V3 資料、執行回填與啟動修復、呈現啟動錯誤。
- 主資料模型：`Book`、`Volume`、`Section`、`Character`、`Item`、`Timeline`、`Node`、`Event` 等。
- `BookOutline.swift`／`StoryTag.swift`：故事規劃 schema V1–V6、文字錨點、故事線與階段、排序投影和 store 操作。
- `EditorWorkspaceView`：讓正文與寬版大綱在同一書籍視窗中保留各自生命週期；切換前提交待存正文。
- `SailuneAIChatViewModel`／`SailuneAIClient`：管理每書多段對話；選節後才加入指定節次純文字快照，處理取消與錯誤，不寫入 SwiftData。`SailuneAIConversationStore` 原子寫入每書 JSON；切換與刪除由 ViewModel 協調。Gemini 使用介面已移除；先前的 Keychain 設定與 `SailuneAIBackend` 本機開發服務不參與目前使用流程。
- `SailuneAIAnalysisContextBuilder`：組裝設定分析與角色比較附件。物品、能力、勢力快照的主 store 查詢，以及勢力附件經 `V5SettingsStore.fetchForAnalysis` 的設定 store 查詢，失敗時會沿既有送出流程回報錯誤。其他畫面與設定選取器的列表 API 仍可能把讀取錯誤折疊成空清單。
- `MapCatalog`／`MapPDFGenerator`／`BookMapPDFStore`／`MapWorkspaceView`：管理平面地圖分類、替代背景版本、map-local placement 與標記到下層地圖的 UUID 綁定，產生 4:3 模板、正規化輸入並以同一內容矩形疊加座標與標記。地圖／版本刪除先完成必要查詢，再修改設定 store；建立、改名、目的地配對、首次初始化，以及跳轉／編輯標記的來源決策查詢也會傳遞錯誤。一般畫面列表與標記刪除仍有 V9.2c 待處理的空清單折疊。
- `RichEditorView`／`EditorBridge`：文字輸入、CJK composition、選取與跨節跳轉、格式、右鍵工具、角色連結及規劃錨點協調。
- `InspectorViews`、`CharacterSectionViews`、`RelationshipWorkspace`：設定集與角色／物品／能力／勢力／關係管理；V5 勢力不與角色或正文連結。
- `UnlinkedReferenceReviewView.swift` 保管角色改名後未連結文字的使用者審核畫面；`CompositionAwareTextField.swift` 保管該角色名稱欄使用的 AppKit 組字輸入封裝。兩者的狀態與操作入口仍由 `CharacterDetailView` 持有，正文同步由 `CharacterReferenceSynchronizer` 負責。
- `KinshipGraphViews.swift` 保管角色親屬關係圖、關係列表與新增血緣關係 sheet；角色 Inspector 仍持有導覽入口，原查詢與新增關係流程不變。
- `ItemInspectorViews.swift` 保管物品清單、詳情、副本詳情與等級編輯；`InspectorRootView` 仍持有導覽入口，物品／副本 Store 與跨 Store 刪除流程不變。
- `AbilityInspectorViews.swift` 保管能力清單、詳情與能力建立補償診斷；`InspectorRootView` 仍持有導覽入口，跨 Store 建立、連結、刪除及既有錯誤出口不變。
- `CharacterInspectorViews.swift` 保管角色清單、詳情、勢力成員、正文參照與出生日期欄等畫面；`InspectorViews.swift` 保留共用連結列、route 和根導覽。角色正文同步仍由 `CharacterReferenceSynchronizer` 負責。
- `V5SettingModels.swift`：settings 歷史 schema、目前模型／遷移與一般設定 Store；`PowerHierarchyStore.swift` 保管勢力層級錯誤、層級驗證與直屬關係操作，仍由 `V5SettingsStore` 協調呼叫。`V5SettingsSearch.swift` 保管地點／世界條目純搜尋投影，`SidebarSettingCatalog.swift` 保管側邊欄預設列、排序與選取規則；搬移未改既有資料保存順序。
- `PlaceWorldTermViews.swift`：地點與世界條目各自的清單及詳情 View；原有設定 Store、搜尋、綁定與保存／刪除操作入口不變。
- `SidebarSettingsManagerView.swift`：側邊欄設定列的顯示、排序及重設入口；`PowerSettingViews.swift`：勢力清單、層級、詳情與關係編輯畫面。兩者沿用既有 `V5SettingsStore` 操作與原呼叫名稱。
- `OutlineViews`：故事背景、敘事畫布、故事線／階段／大綱項目管理，以及「由大綱加入世界時間軸」。
- `TimelineViews`／`TimelineEngine`／`TimelineDateProjection`／`TimelineCardProjection`／`TimelineOutlineSourceProjection`／`TimelineEraManagementViews`／`CharacterTimelineProjectionView`：`TimelineViews` 管理主副軸、節點與事件面板及正文跳轉；日期分組、排序、標籤與投影資料型別位於 `TimelineDateProjection.swift`，日期運算沿用 `TimelineEngine`；事件卡片來源定位與節錄位於 `TimelineCardProjection.swift`；事件新增使用的大綱來源排序與標題投影位於 `TimelineOutlineSourceProjection.swift`；年號管理、年號列、改元與年號編輯 popover 位於 `TimelineEraManagementViews.swift`，其中改元接續提示查詢失敗會記錄診斷並維持原提示結果；角色卡片時間投影與主時間軸顯示開關位於 `CharacterTimelineProjectionView.swift`。年號畫面仍依賴既有 `TimelineEngine`、`ModelContext` 與跨 Store 協調器。
- `PlanningRecordProjectionBuilder`：原 `build` 保留可拋錯的投影查詢契約；時間軸與大綱畫面共用 `buildForDisplay`，失敗時記錄來源與私有錯誤診斷，暫時維持既有空清單顯示。錯誤和真正空資料是否區分屬待核定的產品行為。
- `PersistentStoreRepair`／`CrossStoreDeletionCoordinator`：主 store 修復與 Book／Character／Item／Ability／Event／Node／Era／Timeline／Volume／Section 的跨 store 收斂。
- `SailuneBackupService`：六個 SQLite online snapshot、封面、地圖 PDF、每書 AI 對話 JSON、manifest／checksum 封裝，以及下次啟動前的驗證、現況安全備份、整組置換與失敗 rollback。
- `MigrationPlan` 與各 Backfill：歷史 schema 匯入及獨立 store 回填。

## 兩種「連動」

1. 主 store 內使用 SwiftData relationship，例如書籍—卷—節、時間軸—節點—事件、角色—設定。
2. 獨立 store 之間只用 UUID 連結。`TimelineEventCardMetadata.eventID` 指向主 store Event，可再以 `outlineItemID` 指向故事規劃中的大綱項目；這不是跨 store relationship。

敘事大綱和世界時間軸不是同一套資料。作者可由 `OutlineItem` 建立主 store `Event`，metadata 保存兩者的關聯與節錄設定；刪除大綱來源不會刪除世界事件。

## 文字位置策略

- 角色引用寫入自訂 `sailune://character/<UUID>` URL，名稱變更時可同步已連結文字；未連結同名文字只列為候選。
- 故事標籤與大綱來源保存選取文字及 UTF-16 offset，重新解析時取最接近舊位置的候選。
- 伏筆／修改錨定文字消失時刪除輕量標籤；大綱來源消失時保留項目，降級到原節開頭並轉草稿。

## 已知技術風險

- 六個 store 沒有共同交易；跨 store 寫入採主資料優先、錯誤可見及啟動冪等修復，不能提供單一 ACID transaction。
- `AttributedString`、UTF-16 offset、角色 URL 連結與規劃錨點需持續做跨模組回歸。
- 完整備份／還原已有自動測試，但正式發布前仍需人工重啟、檔案面板與故障注入冒煙。

# V9 共用規則與程式採用矩陣

> 核對日期：2026-09-24。依目前 `Sailune/**/*.swift`、V9 工作單與工程規範靜態檢查。下列數字是搜尋命中，不代表每個呼叫點具有相同語意，也不取代實際畫面或資料流程驗收。

## 目前已接入與尚待處理

| 家族 | 已接入的程式事實 | 仍待完成的 V9 工作 |
|---|---|---|
| 按鈕樣式、位置與命中 | `PlanningActionStyle` 已移到 `SharedUI`，既有 39 個呼叫維持；尺寸／間距基準已寫入 `SailuneLayout`。`SailuneIconButton` 以 28 pt frame、矩形 content shape、`.plain` style、help／accessibility label 承接書籍背景關閉及使用者核准的 `AppearanceRow` 刪除按鈕，共兩處。已從運行中的深色畫面核對外觀列排列與「刪除外觀」AX 名稱；2026-09-24 再次以執行中 App 核對既有服裝列順序及名稱，未點擊刪除。 | 全專案仍有 229 個 `.buttonStyle` 呼叫，其中原生 `.plain` 111、`.borderless` 46、`.borderedProminent` 24、`.link` 5、`.bordered` 4。共用純圖標按鈕已有兩處來源碼採用，GUI 命中與 Light 外觀仍未驗收；位置由原始截圖及接線後畫面核對。系統 Menu／Picker、整列導覽與特殊拖曳控制不可只按 style 名稱批量遷移。 |
| 單行／搜尋欄位 | 已跨三個功能檔使用的七個搜尋欄位統一為 `SailuneSearchField`；搜尋與清除圖形、底色集中。另有六個 V5 設定頁欄位、`AppearanceRow` 條件式欄位、角色／歷史區十處一般欄位、筆名／物品副本名稱／勢力職稱四處、能力詳情五處、物品相關六處、書籍與故事線五處，共三十七處已接入 `SailuneFormTextField`，保留原生圓角樣式。 | 精確 `\bTextField(` 呼叫仍有 67 處，包含共用元件內部實作、一般文字、日期數值、搜尋、改名與特殊輸入；`.roundedBorder` modifier 有 30 處，其中一處在共用元件內。一般欄位的 focus/error/disabled 狀態及逐點例外尚未核定。 |
| 多行編輯器 | `InsetTextEditor` 已移至 `SharedUI`，六個現有呼叫點沿用原 API、背景及描邊；另六個相同的設定頁原生 `TextEditor` 組合已接入 `SailuneBorderedTextEditor`，保留各自最小高度及原生輸入樣式。 | 現有精確 `\bTextEditor(` 呼叫共七處，其中兩處是共用 variant 的實作、五處留在功能 View；後五處位於章節註記、故事背景、作者簡介，含手動 placeholder overlay 與 rounded border／background。兩種共用 editor 的內距責任目前不同；V9.1x 需核對首行、圓角／描邊安全距、placeholder、捲動與 focus，且不能將目前截圖當成已證實故障。正文 AppKit `NSTextView` 必須保留專用組字、選取與 Undo 契約。
| 表面色與尺寸 | 六個功能 View 檔的 24 個相同低對比背景已引用 `SailuneTheme.subtleSurface`；搜尋欄與兩種現有編輯器亦有具名 token；另有兩個故事背景編輯欄與兩個可點擊導覽卡片依用途接入共用表面色，原值仍為 0.08。 | 目前另有 32 個 `Color.secondary.opacity(...)` 靜態命中，含 token 定義及不同用途；特別是 `0.08` 在 AI 回應、啟動錯誤資訊和登入列仍有不同用途，不能只憑色值合併。焦點、選取、錯誤、警告、成功、分隔線等 token 和 Light／Dark GUI 核對未完成。 |
| 圖標 | `SailuneSymbol` 現有 178 個呼叫點；八個返回入口、四個前置條件提示、三個警告、三個時間序、四個導覽 disclosure、三個描邊圓形新增、三個實心圓形新增、三個新增卷、兩個匯出 TXT、兩個匯出 EPUB、四個故事線、三個角色關係、四個 AI 閱讀範圍／角色整理、七個編輯、九個搜尋／設定／更多入口、五個「新增節」入口，以及十個設定領域直接呼叫點已完成語意接入。`trash`、`plus`、`plus.circle`、`plus.circle.fill`、`folder.badge.plus`、`doc.text` 匯出、`book.closed` 匯出、故事線、角色關係、`xmark`、`minus.circle`、`checkmark`、返回 `chevron.left`、前置條件 `exclamationmark.circle`、警告 `exclamationmark.triangle.fill`、時間序 `clock`、導覽 disclosure `chevron.right`、新增節 `doc.badge.plus`、能力、物品、資源與勢力層級圖標依語意集中；`AppearanceRow` 刪除按鈕接入 `.delete`。 | 仍有 104 個 `systemName`／`systemImage` 直接字串靜態命中，另有 enum 字串用途。其餘混有導覽、資料類型、狀態和操作圖標，需按實際 action 繼續分類；資料類型圖示保留具名例外。時間軸末端同字形表示延續方向，保留為獨立用途。純圖標按鈕的 tooltip 與 accessibility label 仍需逐控制核對。 |
| 通用文案 | 158 個 Button／Label 及兩個純圖標按鈕描述已引用 `SailuneActionCopy`：取消 48、儲存 10、刪除 35、新增 5、關閉 7、提示確認 32、流程完成 17、TXT 匯出 2、EPUB 匯出 2；建置產物保留原繁體中文值。三個時間格刪除按鈕的六個 help／accessibility label 亦已引用同一 `SailuneActionCopy.deleteTime`，原中文值不變。 | 帶領域對象的名稱、確認句、錯誤訊息與 tooltip 尚未逐點建立資源對照；同詞不一定同操作。需要建立操作語意 → 標題／按鈕／tooltip／accessibility label 的使用清冊與例外理由。 |
| 重複操作外殼 | 圖標、短文案及部分 style 已有集中來源；資料 action 仍由原 View／Store 呼叫。 | 目前靜態命中 `confirmationDialog` 15、`alert` 46，尚無通用確認／刪除／錯誤呈現外殼。共用外殼只能處理呈現及動作注入，不能自行刪領域模型；每一類需先比較取消、後果文字及錯誤出口。 |
| 內部程式責任 | 參照掃描、名稱比對、預覽排序、角色正文參照同步，以及未連結文字審核與組字欄封裝已從大型 `InspectorViews.swift` 移至各自責任檔；時間軸日期投影及資料型別亦從 `TimelineViews.swift` 移至 `TimelineDateProjection.swift`，350 行內容與原檔對應區塊完全一致；事件卡片呈現資料及來源節錄投影也已從 `TimelineViews.swift` 移至 `TimelineCardProjection.swift`，兩段正文與原檔相同；事件建立所用大綱來源投影位於 `TimelineOutlineSourceProjection.swift`；年號管理、年號列及改元／編輯 popover 已移至 `TimelineEraManagementViews.swift`，原 Store 依賴與操作入口不變；角色卡片時間投影與事件列已移至 `CharacterTimelineProjectionView.swift`，原顯示開關與保存流程不變；親屬關係圖及新增血緣關係 sheet 已從 `InspectorViews.swift` 移至 `KinshipGraphViews.swift`，原導覽、查詢與新增操作不變；物品清單、詳情、副本與等級編輯六個 View 已移至 `ItemInspectorViews.swift`，僅三個跨檔入口放寬可見度；能力清單、詳情與補償失敗 logger 已移至 `AbilityInspectorViews.swift`，兩個跨檔入口放寬可見度；角色清單、詳情與輔助區段九個 View 已移至 `CharacterInspectorViews.swift`，`InspectorViews.swift` 只保留共用連結列與根導覽；勢力層級錯誤、驗證與直屬關係操作已從 `V5SettingModels.swift` 移至 `PowerHierarchyStore.swift`，三段正文逐字相同；設定搜尋與側邊欄目錄也分別移至 `V5SettingsSearch.swift`、`SidebarSettingCatalog.swift`，原函式正文不變。地點與世界條目各自的清單、詳情 View 也已從 `V5SettingViews.swift` 移至 `PlaceWorldTermViews.swift`，467 行段落與搬移前工作樹一致，原綁定及操作入口不變。側邊欄管理與勢力管理 View 亦分別移至 `SidebarSettingsManagerView.swift`、`PowerSettingViews.swift`，取代原 `V5SettingViews.swift`，宣告內容及呼叫點不變。已完成歸位的 API／資料保存順序不變。勢力承接／關係建立的兩個 throwing operation 已在重複檢查讀取失敗時停止；備份匯出會在封面／地圖目錄存在但列舉失敗時回報錯誤。地點與世界條目刪除會在關聯清理查詢失敗時停止，不再繼續刪主資料；地圖與版本刪除也會先完成必要查詢，再修改設定 store；建立、改名與目的地配對的地圖／版本查詢亦會在寫入前傳遞錯誤。首次初始化會先讀完必要資料才插入 profile／地圖／版本／placement，從地圖建立標記的 Place 排序讀取也會傳遞錯誤。標記跳轉與既有標記編輯共用來源 Place／placement 查詢，會核對關聯並傳遞錯誤；編輯來源缺失不再轉成新增。啟動資料目錄建立失敗會在開啟 store 前回報。AI 設定分析快照的七處主 store 查詢及勢力附件的設定 store 查詢錯誤已傳至既有錯誤出口，不再當成空資料送出；三類 Store 七處 rollback 後重載失敗及能力補償保存、16 個設定／地圖列表 fetch fallback 及時間軸／大綱兩處規劃投影及改元接續提示兩處查詢 fallback 改以 OSLog 記錄並維持原結果；標記刪除的 Place／placement 查詢與保存錯誤均接至地圖既有 alert，確認後仍關閉編輯器，Store context rollback 未核定。 | 能力建立跨 store 補償保存失敗及 16 個地圖／設定列表查詢失敗現在會記錄 OSLog，但仍維持原始拋錯／空清單結果；地圖清單仍可能把查詢錯誤轉為空清單；設定刪除畫面仍使用原 fallback API。標記刪除來源／placement／保存錯誤由地圖既有提示呈現且編輯器仍關閉，保存失敗後 context rollback 政策另記於 `docs/work-items/v9.2t-map-marker-deletion-failure.md`。其餘地圖呼叫端、修復限制與失敗矩陣見 `docs/work-items/v9.2c-persistence-failure-paths.md`。還原 rollback 的錯誤與保留原檔問題已記入 `docs/work-items/v9.2g-backup-restore-rollback.md`；R／U／I 尚未核定。設定選取器及其他畫面仍使用可吞錯的列表 API，需另行稽核。全專案其餘 9 處 `try?` 的不同風險用途已分類於 `docs/v9-error-suppression-audit.md`；ItemCopyHistory、故事背景、三種 AI 回應 JSON 解碼與自訂封面讀取 fallback 已加 OSLog 診斷但維持既有回傳結果；不能以拆檔或命中數量當作責任整理完成證據。 |

## 已核對的語意例外

| 原字形／文字 | 語意差異 | 目前處理 |
|---|---|---|
| `trash` | 刪除資料、移除角色持有人但保留物品副本、移除自訂封面 | `.delete`、`.removeHolder`、`.removeCover` 分開命名；圖形維持原樣。`AppearanceRow` 已依批准的 U／I 接入 `.delete`。 |
| `plus` | 新增資料／內容、地圖放大 25% | `.add` 與 `.zoomIn` 分開命名。 |
| `xmark` | 關閉、取消、移除選取、解除事件角色關聯、刪除時間 | 分別使用 `.close`、`.cancel`、`.removeSelection`、`.removeRelatedCharacter`、`.deleteTime`；時間格字形保留既有規格。 |
| `minus.circle` | 解除關聯、移除獨立紀錄 | `.removeAssociation` 與 `.removeEntry` 分開命名。 |
| `checkmark` | 確認改名、目前已選取 | `.confirm` 與 `.selected` 分開命名。 |
| `pencil` | 重新命名卷、節、時間軸，以及編輯紀元、事件 | 七處均為開啟既有編輯流程，引用 `.edit`；顯示文字保留各自對象。 |
| `ellipsis.circle` | 編輯工作區「更多」與時間軸「時間軸操作」 | 兩處都是更多操作選單，`.more` 對齊現有字形後共同引用。 |
| `magnifyingglass`／`gearshape` | 搜尋入口或結果空狀態／設定入口 | 四個搜尋與兩個設定入口改引用 `.search`／`.settings`，保留原字形。`gearshape.2` 是技術階段資料圖示，未混入設定操作。 |
| `xmark.circle.fill` | 清除搜尋字詞／刪除事件卡片 | 前者引用 `.clearSearch`；事件卡片保留既有字面值，不能因字形相同當作清除搜尋。 |
| `doc.text` | 匯出 TXT／節目錄標記／未選取節時的空白狀態 | 兩個匯出 TXT 入口使用 `.exportText`；節標記與空狀態維持原字串，因用途不同不混為同一操作語意。 |
| 「編輯」 | 工作區模式名稱、實際編輯操作 | 工作區導覽 `Label("編輯"...)` 保留原名稱；不強行改用通用 `.edit` 操作文案。 |

## 完成 V9 需要的證據

1. **V9.1 代表性畫面**：已取得 `AppearanceRow` 深色局部截圖，接線後又以執行中的 Debug app 核對相同排列、相鄰控制及「刪除外觀」AX 名稱，並在 Mac 解鎖後再次核對既有服裝列；共用刪除按鈕和單行欄已按批准 U／I 接入。仍需實測命中範圍、欄位輸入、Light 及身體特徵資料類型。深色畫面證明單一服裝畫面的可見位置與 accessibility 名稱，不能證明 hit-testing、Light 或其他資料類型。
2. **共用控制項家族**：至少一個已驗收的按鈕角色／尺寸 API、一般單行欄位 API、多行編輯器 variants，以及確認／錯誤外殼；每個家族列出已轉呼叫點、未轉呼叫點和有意保留的特殊輸入或原生控制。單有 enum 或 unused component 不算採用。
3. **內部程式責任**：對高風險跨 store 與查詢錯誤候選各建立具體工作單，明確主操作、部分成功、補償／修復及使用者錯誤出口；依核准範圍實作或留下有理由的 backlog。靜態搜尋與 Debug build 不能證明失敗路徑正確。
4. **驗證與收尾**：按受影響風險完成適用的資料／UI 驗證、更新架構責任地圖與 `docs/project-status.md`，在交接中記錄未驗證區域及例外；使用者驗收 V9.1 試行與 V9 整體規則採用。產品版號與 SwiftData schema 版號分開決定。

目前第 1、2、3、4 項仍有未完成證據，因此 V9 保持 `active`。後續每批工作依 `docs/work-items/v9-code-standardization-plan.md` 的 R／U／I 和可驗收切片處理。

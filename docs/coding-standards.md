# 程式碼與技術文件規範

> 適用範圍：Sailune 目前及後續新增的 Swift、SwiftUI、SwiftData 與測試程式。
>
> 原則：新程式遵守本規範；既有程式的歷史寫法不因格式整理而大幅改寫，除非該次工作本身包含重構。

## 1. 基本原則

- 先求語意清楚，再求程式短小。
- 一個型別或檔案應有明確責任；跨模組邏輯放在服務、Store 或專用 namespace，不塞進 View。
- 新增功能要能說明「資料從哪裡來、誰負責修改、失敗如何回報」。
- 不用註解掩飾複雜度；優先拆分命名良好的函式與型別。
- 不為了迎合舊命名而新增更多縮寫；新程式採一致的完整英文命名。

## 2. 檔案與型別命名

- 檔名使用 `UpperCamelCase.swift`，通常與主要型別同名。
- `struct`、`class`、`enum`、`protocol` 使用 UpperCamelCase，例如 `EditorWorkspaceView`、`ItemCopyStore`。
- 變數、常數、函式與參數使用 lowerCamelCase，例如 `selectedSection`、`updatedAt`、`exportBookToTXT`。
- Bool 使用 `is`、`has`、`can`、`should` 開頭，例如 `isPinned`、`hasShownInlineAutosaveHint`。
- UUID 變數使用具體領域名稱加 `ID`，例如 `sectionID`、`copyID`；不可使用不明確的 `id1`、`value`。
- 集合使用複數名詞，例如 `characters`、`histories`、`sections`。
- View 以 `View` 結尾；資料模型使用領域名詞；執行操作的服務使用 `Manager`、`Store`、`Engine` 或 `Operations`，且整個模組維持同一語意。
- Schema 快照固定使用 `...SchemaV#`，產品版本與 schema 版本不可混用。

## 3. 註解規範

註解應解釋「為什麼」，而不是重述「程式正在做什麼」。

```swift
// 正確：說明限制與原因
// 副本等級選擇獨立儲存，避免改動已發布的主資料 schema。

// 避免：重述程式
// 建立一個副本
```

- 公開型別、跨 store 關聯、遷移、回填、刪除規則與非直覺演算法必須有註解。
- 技術債使用 `TODO:`，已知問題使用 `FIXME:`，並附上原因或追蹤文件；不可留下沒有上下文的註記。
- 版本相容性註解要寫明「相容哪個版本／哪個資料檔」以及不可做什麼。
- 不在註解中寫會快速過期的介面文案、個人電腦路徑或暫時測試結果。
- 註解使用繁體中文描述產品與資料語意；API、型別、方法和系統術語保留英文原名。

## 4. Swift 與 SwiftUI

- 優先使用值語意 `struct`；只有需要 SwiftData 持久化、共享可變狀態或引用身份時才使用 `class`。
- View 只負責呈現與發送使用者意圖；資料查詢、批次更新與遷移放到專用 Store／服務。
- 每個 View 的責任限制在一個可辨認的畫面區塊；重複區塊拆成具名子 View。子 View 只接收顯示所需的值、binding 與 action，不暗中查詢資料或持有跨畫面狀態。
- Store／Coordinator 的公開 action 以使用者或系統意圖命名，負責其領域內的不變條件；查詢、投影、格式轉換與寫入分開命名，不以 View modifier 或 `body` 計算承擔副作用。
- 資料責任依賴方向固定為 View → Store／Coordinator → Model／Service；共用 UI 不依賴 Store。跨功能需要資料時，由上層組合並以值或明確 action 傳遞，不讓一個 Store 直接操控另一功能的私有狀態。
- 將程式搬檔或拆型別時，保持原有操作、存取層級、狀態生命週期與呼叫順序；只在工作單明確核定行為變更時才改語意。
- `@State` 僅保存 View 私有、短期 UI 狀態；模型編輯使用 `@Bindable`；跨畫面共享狀態透過明確 environment 依賴。
- 非同步工作需標明 actor 隔離；主執行緒 UI 和 SwiftData 寫入不得被背景工作直接修改。
- 非同步 action 應集中管理載入／完成／失敗狀態，並防止過期結果覆蓋較新的選擇；可取消工作需把取消入口交給呼叫端。
- 避免在 `body` 中進行昂貴查詢、資料遷移或副作用；使用明確事件處理函式。
- View 的 modifier 依序排列：版面、互動、狀態／生命週期、輔助功能；過長 View 拆成具名子 View。
- UI 文案集中使用一致的繁體中文；快捷鍵、system image 與 accessibility label 在功能規格中有意義時一併維護。
- 除非使用者明確要求，UI 不加入多餘的說明文字；單一項目的操作優先使用簡潔圖示（例如右上角 `xmark`），必要語意放在 accessibility label、tooltip 或確認視窗，不以長文字按鈕佔用內容版面。
- 首頁的任何彈窗、浮動面板或自訂 modal 都必須提供可點擊空白處取消；若原生 sheet／popover 不支援此行為，使用半透明遮罩與明確的 dismiss callback 實作，且不讓空白點擊穿透到背景操作。
- 短輸入彈窗若只有一個主要確認動作，文字欄按 Enter 應直接送出；自訂 overlay 優先使用 `TextField.onSubmit`，避免以可能把按鈕提升至視窗工具列的 default-action shortcut 實作。
- 需要和視窗或整體版面比對位置的物件，使用父容器 `GeometryReader`／layout proposal 的可用尺寸與比例計算，並設定合理上下限；不可用固定像素 `offset` 模擬跨區定位。固定點數只保留給元件自身尺寸、間距及最小可讀邊界。

### 共用 UI 元件、語意資源與互動基準

- 共用 UI 元件集中於單一 UI foundation 區域（目前規劃為 `SharedUI/`）；設計色彩與尺寸由集中 theme／token 提供。新增控制項前先搜尋共用元件；相同語意與互動必須重用，不得在功能 View 複製 style、色彩常數或 modifier 組合。
- 共用元件呼叫端只傳入語意、內容、資料 binding 與 action；不得覆寫該元件已負責的字體、padding、背景、形狀、hover、disabled 外觀與 hit area。新的 Boolean 開關不得拼湊多種樣式，應建立有語意名稱的 variant。
- 按鈕角色使用 primary、secondary、destructive、toolbar、navigation 等語意分類。試行尺寸基準為一般按鈕高度 28 pt、純圖標工具列按鈕互動範圍至少 28 × 28 pt；命中範圍不得重疊或超出父容器。同列按鈕間距採 8 pt；標準 layout spacing 使用 4、8、12、16、24 pt。平台或既有畫面確有差異時，需說明並記錄例外。
- 一般表單底部 primary 靠 trailing 端，cancel 緊鄰其前；destructive action 獨立成組或放在被操作項目的選單，與 primary 保持至少 12 pt。相同流程只設一個 primary。位置使用父容器 layout，不用固定 offset 跨區定位。
- 單行欄位與搜尋欄使用共用欄位元件，一般多行文字使用共用編輯器元件；正文富文字、聊天輸入、數值／日期欄僅在提交、驗證、組字、選取或 Undo 行為不同時保留專用 variant。Placeholder 不取代可見 label；空間受限時仍須提供 accessibility label。
- 欄位文字的可繪製區必須完整落在描邊與圓角的安全內側；圓角只負責外觀，不能裁切文字、placeholder、游標或選取內容。單行欄位沿用平台控制項的文字 inset，不得在外層疊加會把字推入邊框的 padding／offset；多行編輯器須由共用 variant 明確負責文字容器 inset、內距與最小高度，不可讓各呼叫端猜測原生預設值。修改 inset、font、frame、clip 或 overlay 時，需檢查首行基線、首字與左／上圓角距離、捲動起點及 focus／選取狀態；不得以加大整個欄位高度掩蓋文字框位置錯誤。
- 欄位驗收至少使用貼近左上角的繁體中文首行（含高低筆畫字形）、空欄 placeholder、長文捲動起點、游標／選取、鍵盤焦點與淺／深外觀；文字不可穿過描邊、被圓角切掉、與 label 或相鄰控制重疊。發現原生 TextEditor inset 在平台／variant 間不同時，須在共用元件內統一並保留組字、選取、Undo 與捲動行為。
- 背景、surface、separator、selection、focus、destructive、warning、success 使用語意 token；功能 View 不直接建立 RGB／hex 色或用 opacity 仿製現有 token。Light／Dark 映射只在 token 定義處維護。
- 功能圖標透過集中語意表取得，不在畫面各自散寫 SF Symbol 字串。共用動作需維護「語意 key → SF Symbol → 顯示文字 key → tooltip／accessibility label」對照；例外須列出使用情境與理由。純圖標操作必須有描述動作與對象的 accessibility label。
- 共用新增列、空狀態、錯誤提示及確認框只負責呈現，接收明確標題、訊息與 closure；不得自行讀取領域 Store、推斷資料影響或接管資料操作。
- 純投影／排序／格式轉換只接受值並回傳值，不讀取 `ModelContext`、SwiftUI Environment 或全域可變狀態。View 可處理單一模型欄位的簡單同 Store 編輯；多模型不變條件、跨 Store、檔案、備份／修復與重試流程必須由單一具名 Store／Coordinator action 負責。
- `try?` 不得用於儲存、刪除、重要查詢、遷移、備份或清理。僅在失敗與「沒有值」完全等價且不影響資料正確性或使用者決策時允許，並在程式旁說明理由。
- 共用 UI foundation 不得依賴 SwiftData／領域 Store；依賴由 app 組合端流向功能與共用 UI，跨功能傳遞明確參數或值型別結果，不直接存取另一功能的私有 View 狀態。
- 跨 Store 操作需記錄主資料保存順序、附屬清理失敗時的狀態與修復／重試入口；不得宣稱獨立 store 具共同原子交易。實際使用者可見結果仍遵守已核定產品政策。
- 非同步操作需有可辨識的 action 入口；長任務說明取消方式、過期結果如何丟棄及錯誤如何回到 UI。生命週期啟動的修復／回填需可重複執行，並說明執行順序。

## 5. SwiftData 與資料模型

- 每個模型需有穩定 UUID；UUID 是識別用途，`sortOrder` 只用於排序。
- 關聯需明確指定 inverse 與 delete rule；破壞性 cascade 必須在規格和測試中記錄。
- 跨獨立 store 不使用假想的 SwiftData relationship，改用穩定 UUID 並集中管理查找與清理。
- 新增或移除欄位時，先更新 schema 快照、遷移／回填策略與舊資料測試，再修改現行模型。
- 回填必須可重複執行；不可因第二次啟動而產生重複資料。
- 可選資料需定義空值語意，例如「尚未設定」、「不適用」或「參考用時間點」，不可只依 UI 猜測。
- 模型更新時間由實際修改責任者維護；批次修改需避免遺漏父層更新時間。

## 6. 錯誤處理與資料安全

- 可預期的失敗使用 `throws` 或明確結果型別；不可用 `try?` 靜默吞掉會影響資料完整性的錯誤。
- 啟動、匯入、遷移、備份與多 store 初始化錯誤必須保留原始錯誤上下文。
- 使用者可理解的錯誤訊息與技術診斷內容分開處理。
- 刪除前確認影響範圍；刪除後驗證沒有孤立資料，並在文件中記錄正文是否保留。
- 跨 Store 寫入以主資料優先；若附屬清理失敗，保留可診斷錯誤並由明確的 deferred cleanup／啟動修復流程收斂，不向使用者呈現為完全成功。
- 通用技術建議不得自行改寫已核定的產品錯誤政策或既有操作結果。例：使用者已核定的 V9.2c「只記錄錯誤」、V9.2g「只修正錯誤文字」及 V9.2t「確認後關閉、失敗只顯示錯誤」按各工作單執行；要改變結果時須重新走需求批准流程。
- 不在程式碼中寫死個人使用者路徑、機密或測試資料；路徑由系統 API、設定或測試注入提供。

## 7. 測試與驗證

- 新增資料模型或服務時，至少測試正常、空資料、重複執行與失敗情境。
- 文字功能需測試 UTF-16 offset、中文輸入、格式保留、重複名稱與長文本。
- 遷移測試需保留代表性舊 store，驗證 UUID、數量、關聯與重新啟動結果。
- UI 測試重點放在使用者可觀察的流程；不為純版面細節建立脆弱測試。
- 每次提交前執行適用測試與 `git diff --check`；結果與未測範圍記錄在測試報告或工作狀態中。

## 8. Git 與版本

- Commit subject 使用簡短、可搜尋的動詞描述；若是產品版本，另外在 `CHANGELOG.md` 記錄。
- 不修改已發布提交來修正版本命名；在變更紀錄中註明歷史差異。
- 一次提交應聚焦一個可理解的變更；文件、測試與實作若屬同一行為可放在同一提交。
- 未完成工作不要標記為正式版本；版本號、schema 版本與測試報告日期要能互相追溯。

## 9. 文件同步規則

- 改變功能行為：更新對應 `spec-*.md` 與驗收條件。
- 改變資料關聯或遷移：更新 `data-model.md`、`backup-and-migration.md` 與一致性檢查。
- 改變技術慣例：更新本文件與 `AGENTS.md`。
- 共用元件、token、符號或文案的新增／遷移：同步列出凍結盤點 ID、實際呼叫點、例外理由與驗收狀態；不得以單一新命中自行擴大已凍結工作範圍。
- 新增待決策事項：放入對應規格的「待確認決策」，不要假裝已定案。

## 10. 文件讀取效率

- 每個對話建立一次必要上下文即可，不要求每次操作重新讀取全部文件。
- 先讀取任務直接相關的文件，再按需要補充技術文件。
- 文件未變更時，沿用本對話已確認的內容；文件變更、任務轉換模組或出現不一致時才重新讀取。
- `docs/README.md` 是索引，不是每次都必須完整載入的文件。

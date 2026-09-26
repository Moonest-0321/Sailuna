> 2026-09-26 V10.1 發布流程修訂：發布頁改列出全部書籍，新書草稿，提供草稿→發布中→完結。`BookPublicationStore` 用 `Sailune/Publication Status.json` 獨立保存，首頁書櫃同讀狀態；備份／還原包含此檔，刪書後清理。V5 主 schema 不變。無簽章 Debug build、Swift parse、diff check 通過；未執行 XCTest 或 GUI。使用者原有未提交修改保留，當輪修改限發布功能與文件。唯一下一步：用隔離資料在 GUI 驗收發布狀態即時變化、重開保留、備份還原與刪書清理。最小文件：本檔、`docs/work-items/v10.1-home-and-publishing.md`、`docs/project-status.md`。

# 當前聊天交接

## 2026-09-26 V10.1 空白頁與即時單位修正 checkpoint

- **已決定**：模板／論壇空白頁不顯示頂部新建／匯入操作；書籍操作只留首頁與尋找。章節單位切換立即套用既有書籍，但只轉換程式預設產生且可精確辨識的第一節／張／章與新節／張／章；作者自訂標題及正文不改。
- **實作**：`ContentView` 收斂頂部操作列；`BookTextSectionMarker.displayTitle` 投影舊預設名；`SectionUnitCoordinator.apply` 集中更新既有書籍的可辨識預設名並保存，成功後才變更 `UserDefaults` 偏好。總覽、編輯器及相關章節選擇介面讀取同一單位。
- **驗證**：隔離 `/private/tmp` 無簽章 Debug `xcodebuild build` 通過；尚未做 GUI 驗收或 XCTest。工作樹原有的 V10.1 與 `Localizable.xcstrings` 修改保留，V10.0 工作單未改。
- **唯一下一步**：用隔離 Debug app 確認模板／論壇沒有新建與匯入操作，並以既有預設章節名切換節／張／章檢查即時顯示、重開保存及作者自訂標題保持原文；保留 V10.0 獨立 GUI 待驗收狀態。

## 2026-09-25 V10.1 實作／驗證 checkpoint

- **已決定**：設定頁本輪只顯示目前 AI 模型與 API 設定，不顯示額度或使用帳號。章節預設單位是全 App 顯示／命名偏好，可選「節／張／章」，初始為「節」。社群新增「模板」「論壇」子項目，點擊後顯示待建置佔位頁。成就與發布資料由系統管理，作者不手動輸入；資料無法取得時只留白，不以節數或其他推算替代。未提供的平台選項與欄位名稱不自行杜撰。
- **現況**：設定頁已顯示目前 Apple 裝置端模型與外部 API 使用狀態，章節單位偏好存於 `UserDefaults`。發布／成就頁隱藏新建與匯入；成就空位、空白平台選擇器、現有書籍多選及每本書空白欄位已接入。社群模板／論壇入口導向空白頁。
- **進度**：使用者已再次回覆「R」「U」「I」，修訂版 R／U／I 均 approved，程式實作完成。全域單位已接新書初始標題、啟動補建、目錄／編輯器標題與動作、TXT 匯入預選及匯出格式；未改寫既有作者節名或正文。沒有新增資料來源或 schema。
- **待確認**：無產品決策待確認。發布平台及欄位名稱尚無資料，本工作只保留空白，不新增資料來源或自動擷取機制。
- **工作單**：V10.1 工作單為 `docs/work-items/v10.1-home-and-publishing.md`。V10.0 仍是 `docs/work-items/current.md` 所追蹤的現行工作；保留其隔離 GUI 驗收紀錄。
- **驗證**：8 個受影響 Swift 檔 frontend parse 通過，`git diff --check` 通過。使用者回報編譯錯誤後，於隔離的 `/private/tmp` 建置目錄取得實際錯誤：`EditorSidebarView` 缺少 `sectionUnit` 環境值；補齊後無簽章 Debug `xcodebuild build` 通過。未新增或執行 XCTest；尚未完成 GUI 驗收。
- **工作樹邊界**：開始實作前除 V10.1 工作單／交接文件外沒有其他使用者未提交修改；本 checkpoint 所列 Swift 與 V10.1 文件修改均屬本工作。V10.0 工作單及其 GUI 驗收狀態原樣保留。
- **唯一下一步**：在正常 GUI 使用者 session 由 Xcode Run 啟動隔離 Debug app，確認設定、單位切換及重開保留、發布／成就空白呈現、社群入口，以及匯入／匯出單位一致；不可操作正式作者資料。不要覆寫 V10.0 未完成的 GUI 驗收紀錄。

## 2026-09-25 V10.0 實作／驗證 checkpoint

- **已決定**：R／U／I 已批准。匯入 TXT 每次選定「章／張／節」一種且不得混用，卷名延續到首個節標記；匯入建立新書。卷名／節名／內文缺漏使用「無」，沒有卷標記時全部節歸入第一卷；正文採本機編輯器內文樣式，不保留來源字型、字體粗細、螢光筆等格式。TXT 匯出固定用「節」，所有 `#` 字元移除，卷名格式為「第X卷 卷名」且不重複已有卷次。
- **實作進度**：新增純值 parser、專用 ModelContext 的匯入 coordinator、書櫃匯入選檔／預覽表單；TXT 匯出直接使用「節」並開啟系統存檔面板，不再顯示標記選擇 overlay。無 SwiftData schema 改動。
- **驗證**：Swift 前端 parse 通過；V10 6 項 XCTest 全通過。序列模式完整 XCTest 214 項全通過，獨立 Debug build 通過；`git diff --check` 通過。平行測試曾遇既有案例在 macOS 27 abort／session invalidated，序列模式重跑後全數通過。
- **尚未驗收**：臨時 app 由命令列啟動會在 AppKit `RegisterApplication` 中 abort；Launch Services 對 Xcode 輸出的 bundle 回報 `kLSNoExecutableErr`，UI automation 依 bundle ID 找到的是使用者已開啟的正式 Sailune 與作者資料。未對正式資料操作，也未完成隔離 GUI 的 fileImporter、modal 與匯出手動驗收。
- **工作樹邊界**：本次功能修改集中在 `ContentView.swift`、`BookTextImport.swift`、`BookTextTransferViews.swift`、`ExportManager.swift`、`EditorWorkspaceView.swift`、`BookOverviewView.swift`、共用圖示／文案、本次測試及 V10 文件；原有 V9／其他功能責任僅保留局部接線。
- **下一步**：在正常 GUI 使用者 session 由 Xcode Run 啟動隔離 Debug app，確認匯入流程及 TXT 匯出直接打開存檔面板；勿點擊／寫入目前已開啟的正式 Sailune。之後關閉工作單。

## 2026-09-25 TXT 匯出面板時序修正

- 使用者回報點擊「繼續匯出」後沒有出現下一個視窗。
- 原因推定：同一個按鈕事件裡同步關閉自訂選項 overlay 並設定 `.fileExporter` request，SwiftUI 可能在 overlay 尚未退場時錯過系統存檔面板呈現。
- 已在 `EditorWorkspaceView` 與 `VolumeSectionTreeView` 先建立 export request、清除選項 overlay，並將 exporter request 延到下一個主執行緒事件迴圈。
- 受影響 Swift 檔 parse 通過，Debug build 通過。此主機仍無法用 Launch Services 啟動隔離 app（`kLSNoExecutableErr`），所以尚未完成 GUI 點擊驗收；不要在目前已開啟的正式 Sailune 測試匯出。
- **下一步**：於正常 Xcode GUI session 用隔離書籍確認「繼續匯出」會開系統存檔面板。

## 2026-09-25 TXT 匯出預設為「節」

- 使用者回報延後呈現仍無效，並指示先固定使用「節」輸出。
- 已移除匯出前選項 overlay；書目錄及編輯器的 TXT 匯出按鈕直接建立「節」格式 request 並交給既有 `fileExporter`。
- 「章」仍由 formatter 支援，但 UI 暫不提供選擇；EPUB 匯出未改。
- 受影響 Swift 前端 parse、Debug build 與 `git diff --check` 通過；未重跑 XCTest（本次只移除呈現步驟並固定 formatter 參數）。
- 尚需以隔離書籍確認系統存檔面板出現；不要用已開啟的正式 Sailune 測試。

## 2026-09-25 TXT 匯出文字格式更正

- 使用者更正：TXT 輸出的所有 `#` 字元都要移除，卷標題前加上「第X卷」。
- 已更新共用 formatter：整本、單卷及單節最終輸出一律移除 `#`；卷標題依排序加卷次，已帶卷次的名稱先剝除避免重複；節標題仍依預設「節」格式輸出。
- 已更新匯出規格與 V10 工作單；尚未執行最新程式修改的 build／測試。下一步是確認工作樹 diff 後依使用者授權實作完成要求處理。

## 2026-09-25 TXT 匯入空值與無卷標記

- 使用者補充：卷名、節名或內文缺漏時直接以「無」記錄；如果來源沒有卷標記，整份內容都當作第一卷。
- Parser 已接受缺少的卷名／節名／內文並填入「無」；沒有任何卷標記時建立第一卷，沒有卷名則設為「無」。第一節標記前的普通文字會保留在第一節正文開頭。
- 只更新既有結構錯誤案例的預期（沒有卷且沒有節標記時回報沒有節標記）；未執行 build／XCTest。下一步：核對 parser diff 與工作單，再依明確要求驗證。

## 2026-09-25 TXT 匯入樣式

- 使用者要求匯入文字使用本機樣式，不保留來源字型、字級、粗體、螢光筆等格式。
- `BookImportCoordinator` 現改用 `RichEditorLocalTextStyle.importedBody`，套用共用編輯器既有的內文字型、文字色與行距；來源的字元樣式不寫入模型。
- 未執行 build／XCTest。第一節標記前的普通文字仍暫定保留於第一節正文開頭。

> 整體狀態：active
>
> 目前階段：V10.0 TXT 書籍匯入與 TXT 匯出實作／驗證；R／U／I 已確認。詳見 [docs/work-items/v10-content-transfer.md](../work-items/v10-content-transfer.md)。
>
> 唯一下一步：在可用 Xcode build 環境完成 V10 指定／完整 XCTest 及 Debug build；再做隔離資料 GUI 冒煙與修正。

## 2026-09-25 V10.0 需求重整 checkpoint

- **已確認決策**：使用者回覆「是的」，確認上述解讀：匯入時可選「章／張／節」其中一種作為該次匯入的分界字，同一份來源不可混用；標題接在標記後，換行後開始正文；「第一卷」後的文字為卷名，直到第一個節分界標記；幕標題不另訂輸出處理。匯入仍建立新書，不追加或覆寫既有書。
- **目前解讀**：匯入建立新書，不追加到目前書籍、不覆寫既有書；來源使用所選分界字拆節並依原順序匯入。
- **待確認**：匯入時如何／何時選分界字；卷名標記及後續卷的具體格式；匯出時既有 `#` 是否保留；匯入預覽與新書建立時機。
- **已完成**：V10 專屬工作單已重寫為 V10.0 TXT 範圍，將舊 DOCX／Pages／字級映射方向標記為不沿用提案。未修改 Swift 程式。
- **批准狀態**：R approved；使用者回覆「U」進入 UI，之後再回覆「U」確認 UI。I proposal，待核准。功能程式未修改。
- **程式與畫面現況**：`ExportManager` 的整本與單節 TXT 目前以 `#` 輸出節標題，幕標題輸出 `##` 前綴；書櫃已有作品畫面上方有「新建書籍」，空書櫃另有「建立第一本小說」提示；新建書籍表單提供書名、作者、取消及完成。實際檢視並取消表單，未建立資料。整本匯出在書目錄列「匯出」選單，編輯器匯出在「更多」選單。
- **U 已確認**：書櫃相鄰匯入入口、TXT 單字選擇、解析預覽及整本／目前節 TXT 的章／節輸出選項；UI 現況檢視與線框記於工作單。
- **I 提案**：工作單已列純值 parser、匯入 coordinator、SwiftData 無 schema 建立、共用 TXT export 及 UI 接線，並列測試／錯誤回復計畫。
- **工作樹邊界**：目前未提交修改僅為本輪 V10 規劃文件（work item、current work item、handoff、project status）；沒有 Swift 或測試程式修改。開始實作時需保留其他工作流變更，特別 ExportManager、EditorWorkspaceView、BookOverviewView 的既有責任，按 V9 凍結清單做最小接線。
- **驗證**：目前僅規劃及文件更新，`git diff --check` 通過；尚未執行 build、XCTest 或產品程式 GUI 驗收。
- **下一步**：使用者核准或修正 I 計畫；核准前不改功能程式。

## 2026-09-23 V8.2 AI 閱讀與分析需求起點

- 使用者提出四項能力：單節／單卷／全書閱讀；對既有角色、物品、能力、勢力使用固定模板分析且不可自訂提示；對既有角色和指定正文範圍直接比對出入／矛盾且不可自訂提示；保留純聊天。
- 已查證現況：V8 使用 Apple 裝置端模型，已支援一節快照、每書對話、角色資料查詢及單節角色分類整理；尚無卷／全書上下文、物品／能力／勢力固定模板分析或角色跨範圍比較。現行超長上下文會報錯，不截短、不轉雲端。
- 已決定：指定正文範圍後可生成摘要或自由提問；純聊天不附正文。模板分析一次只選一個既有設定目標，可選多個分析維度（角色可含所屬勢力、關係等），選完直接執行。角色比較可選設定分類，正文未提及的設定不列為矛盾。內容過長時提示過長並停止，不自動分段彙整、截短或轉雲端。
- 已決定的共同邊界：僅讀目前書籍中明確選定的正文範圍與既有設定；結果留在對話，不寫回任何設定或正文。模板分析及角色比較均不提供自訂提示文字。
- 已決定：分析維度完全沿用角色、物品、能力、勢力目前既有欄位與分類，不自行增加或刪除；作者可選擇多個既有維度。
- R／U／I approved：使用者分別明確回覆「R」、「U」，並指示「開始實作」。依 I 計畫進行，不改 SwiftData schema；保留每書 AI JSON 舊格式；以 Apple Foundation Models token 計數／context size 預檢整段提示並預留回覆空間；實作含範圍及設定快照、同書 UUID 隔離、固定提示、側欄接線與既定驗證。
- U 範圍假設：全書範圍包含目前書籍所有卷內非空節次；可於 U 確認時修正。
- 被否決方案：目前無使用者否決方案。不得新增或刪除既有資料欄位維度；長文本不採自動分段彙整。
- 工作樹：`main`，起始 HEAD `1589745`；起始工作樹乾淨。此前 AI 角色整理的人工 UI 驗收仍未完成，保留為未驗收事項。
- 本輪已改：`Sailune/EditorWorkspaceView.swift`、`Sailune/SailuneAICharacterContext.swift`、`Sailune/SailuneAIChatSidebarView.swift`、`Sailune/SailuneAIChatViewModel.swift`、`Sailune/SailuneAIClient.swift`、`Sailune/SailuneAIModels.swift`，新增 `Sailune/SailuneAIAnalysisContext.swift`；文件改 `docs/spec-ai-v8.md`、`docs/project-status.md`、本工作單與交接。未改 SwiftData schema／設定欄位／測試或作者資料；起始工作樹乾淨，無使用者既有未提交程式修改需保留。
- 實作：單節／單卷／全書正文快照及摘要／範圍提問；角色、物品、能力、勢力既有維度單目標分析；角色分類比較；token 預檢與回覆空間預留；附件可檢視快照，對話 JSON 格式延用舊 Codable 形狀。
- 驗證：受影響 Swift 檔 `swiftc -frontend -parse`、`git diff --check` 與無簽章 macOS Debug build 通過。沙盒內 build 曾遇 Swift macro server malformed response；主機環境重跑後發現並修正快照作用域、字串 shadowing 與 SwiftUI 回傳值，再成功編譯連結。未新增或執行 XCTest；本 agent 未另行執行隔離 UI 冒煙，使用者已確認 V8.2 完成。
- 使用者於 2026-09-23 回覆「確認完成，唯一的問題剩下4k上下文」。依此記錄 V8.2 已由使用者確認；唯一待處理問題為本機模型上下文容量。此前角色查詢／單節整理沒有本 agent 的獨立 UI 冒煙紀錄，若要將該歷史驗收也一併關閉仍需另行確認。
- Apple Foundation Models 裝置端 context window 為 4,096 tokens；App 動態讀 `contextSize`，並預留四分之一給回覆（目前 4,096 時為 1,024），提示容量還需扣除系統指示、對話歷史與附件。這是模型上限，不能由 App 設定調高。[Apple context window 說明](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window)。
- 已決定邊界仍是超限停止，不自動分段／彙整、不轉雲端。若要突破 4,096，需重新確認需求（R）與 UI／實作計畫。未新增或執行 XCTest；未操作正式作者資料。
- 唯一下一步：確認接受現行本機上限，或重新開 R 討論分段處理／其他模型；工作單維持 active。

## 2026-09-23 設定集資料查詢與章節角色資訊整理需求起點

- 已決定：第一步以目前書籍既有角色分類查詢角色資料；第二步套用目前既有角色分類至指定節次與角色；不做一鍵寫回。線上 Apple 模型問題另行討論。「4.」未補充內容，暫無額外要求。
- 批准狀態：R／U／I 均 approved；U 線框已獲使用者「U」確認，並依先前「先把我剛剛提交的需求落實」開始實作。
- 實作：一般聊天僅在角色資料查詢時匹配本書角色本名／別名，附上已填寫的既有角色分類；未匹配或有歧義時停止並提示。角色整理模板讓使用者選節次、角色、現有分類，送出時僅加入該節純文字及模板指示。訊息可展開檢視附加資料；無資料寫回與 schema 變更。
- 工作樹邊界：本工作改動 `SailuneAICharacterContext.swift`（新增）、`SailuneAIModels.swift`、`SailuneAIClient.swift`、`SailuneAIChatSidebarView.swift`、`SailuneAIChatViewModel.swift`、`EditorWorkspaceView.swift`，以及規格／工作單／交接文件；保留其餘既有 V8 修改。未操作作者資料。
- 驗證：主機環境無簽章 Xcode Debug build、受影響 Swift frontend parse、`git diff --check` 通過。一般沙盒的 Xcode build 因 SwiftData 巨集外掛啟動限制失敗，主機環境建置成功。本輪未新增或執行 XCTest。隔離書籍資料的人工 UI 驗收尚未完成。
- 唯一下一步：以隔離書籍資料人工驗收角色資料查詢、角色整理模板與訊息附件檢視。

> 整體狀態：closed
>
> 目前階段：V8 每書 AI 對話管理完成
>
> 唯一下一步：無；新需求另開工作單。

## 2026-09-23 V8 每書 AI 對話管理

- 已決定：使用者要求切換與刪除對話，並明確選擇關閉 App 後依每本書保存。側欄清單提供新建、切換與確認刪除；第一則提問作為標題，切換或刪除目前對話會取消正在生成的回覆。
- 理由：既有對話只在工作區記憶體，離開即清空；每書獨立 JSON 可保存含節次快照的訊息，不改 SwiftData schema。檔案納入完整備份／還原與書籍刪除清理，舊備份沒有對話檔仍可還原。
- 暫時假設：對話標題以首則提問前 32 字及更新時間辨識；草稿與未送出節次在切換時清空。未要求跨裝置同步、逐則刪訊息或 AI 自動命名。
- 被否決方案：僅在記憶體切換、將大段對話及節次快照塞入 UserDefaults 或主 SwiftData schema。
- 工作樹邊界：保留先前未提交的 V8 功能與文件；本輪新建 `SailuneAIConversationStore.swift`，修改對話 ViewModel／側欄、編輯工作區、備份服務、刪書協調、AI／備份測試及相關文件。未操作正式作者資料。
- 驗證：無簽章 Debug 建置、AI 專項 14 項及備份專項 2 項 XCTest、Swift parse、`git diff --check` 通過。測試使用臨時目錄，涵蓋重開、跨書隔離、節次快照、整段對話刪除、損壞檔不覆蓋、切換取消請求、舊備份清除現有對話。隔離 App 使用 `/private/tmp/sailune-ai-conversations-ui` 建立虛構書籍，實際確認新對話空白、切回舊訊息、刪除確認視窗及取消後訊息保留。沙盒中的 SwiftData macro 服務無法啟動，主機環境建置及測試成功。
- 尚未驗證：完整 XCTest／Release 建置，以及 GUI 按下永久刪除後的結果（ViewModel 層已有資料刪除測試）。唯一下一步：無；後續新需求另開工作單。

## 2026-09-23 V8 可選節次聊天輸入

- 已決定：使用者要求移除 Gemini 使用入口；聊天輸入框左側增加「＋」以選取目前書籍的一個節次，然後用自然語言提問。未選節次維持純聊天；選中節次只在送出時擷取最新內文快照。切換目前編輯節次不會自動附加或替換快照。
- 理由：目前 App 直接走 Apple 裝置端模型；書籍、卷與節次已有排序投影。以明確選擇避免自動讀稿，並在輸入區與送出訊息顯示附加節次供作者核對。單次提問選一節是本輪暫時假設；多節選擇屬未來需求。
- 被否決方案：沿用目前編輯節次自動注入；保留 Gemini 作為首頁可選入口。舊個人 Keychain 金鑰與本機開發後端保留，無使用通路，不擅自刪除。
- 工作樹邊界：保留先前未提交 V8 功能與文件；本輪修改首頁設定、編輯工作區、聊天側欄、AI DTO／client／ViewModel、測試及 V8 文件；不改 schema、作者資料或備份。
- 驗證：AI 專項 11 項 XCTest 通過，無簽章 Debug 建置、Swift parse 與 `git diff --check` 通過。隔離 App 使用 `/private/tmp/sailune-v8-attach-ui-20260923` 獨立 store：建立兩個虛構節次，在編輯第二節時從「＋」選第一節，模型回答第一節的「藍色鑰匙」；展開對話確認第一節快照，移除另一次節次選擇後可一般聊天，首頁設定沒有 Gemini 入口。未操作正式作者資料。
- 尚未驗證：完整 XCTest 與 Release 建置未重跑；本輪核心 AI 專項與隔離 UI 流程已覆蓋。舊個人 Keychain 金鑰資料保留但無目前使用入口。

## 2026-09-23 V8 免金鑰裝置端模型

- 已決定：使用者要求接入不需金鑰、可直接使用的模型，效能非優先；隨後明確校正 Apple 模型先只做聊天，不接入節次。Apple Foundation Models 為預設純聊天通路，Gemini 個人金鑰通路保留原本節次分析。此為具體變更授權，略過重複批准關卡。
- 理由：專案最低 macOS 26.5，Foundation Models SDK 可用，無需模型服務申請或獨立後端。Mac 必須支援且啟用 Apple Intelligence；不可用時顯示裝置、啟用或準備狀態錯誤，不暗中改傳雲端。Apple 送出流程不讀取 `Section.content`、不做待存正文提交，提示只包含對話；長對話超出上下文限制時由模型錯誤回饋。
- 被否決方案：以公開無金鑰第三方接口作正式通路；此類接口不能保證穩定性或稿件隱私。登入仍暫緩。
- 工作樹邊界：保留既有未提交 V8 App／後端修改；本輪增補 provider 選擇、Apple 本機生成及文件，未操作正式作者資料。
- 驗證：本機 Apple 模型回報 available；以虛構短文已成功產生繁體中文回答。純聊天校正後無簽章 Debug 建置與 AI 專項 9 項 XCTest 通過；測試確認 Apple 提示忽略節次且純聊天請求不含 `sectionContent`，Gemini 節次請求仍通過。`swiftc -frontend -parse`、`git diff --check` 通過。隔離 App UI 冒煙尚未完成。

## 2026-09-23 V8 App 金鑰設定補正

- 已決定：使用者明確要求 App 內有地方設定金鑰；首頁設定增加 Gemini API 金鑰、模型名稱與 API 接口，Google 登入仍暫緩。此前「設定頁也暫緩」的紀錄已被最新要求取代。
- 理由：原本只依本機後端環境變數讀取金鑰，作者無法從 App 設定並直接呼叫模型。個人金鑰保存於 macOS Keychain，模型與接口保存於 UserDefaults；不改書籍資料、schema、備份。接口限 Google 官方 HTTPS Interactions 網址，避免誤送金鑰至第三方主機。
- 被否決方案：用 Google 登入代替 API key；要求作者只透過終端機設定環境變數。暫時假設：第一階段只支援 Gemini Interactions 協定，後續供應商另議。
- 工作樹邊界：保留原有未提交 V8 App／後端與文件修改；本輪新增 `SailuneAISettings.swift`，修改首頁設定、AI client、AI tests 與相關文件；未操作正式作者資料。
- 驗證：無簽章 Debug 建置及 AI 專項 8 項 XCTest 於主機環境通過，`swiftc -frontend -parse`、`git diff --check` 通過。沙盒內 Xcode 因 SwiftData macro 外掛 malformed response 無法編譯，主機環境完成驗證。沒有個人有效金鑰，真實 Google 呼叫及設定頁人工 UI 操作仍未驗證。

## 2026-09-23 V8 真實 API 呼叫補強

- 使用者校正：Google 登入不能作為 AI 服務授權，先不做登入；模型名稱與 API 接口的首頁設定也暫緩，優先接通目前 Gemini 路徑。此前提出的 V8.1 Google 登入／設定草案保留於工作單，但 R／U／I 均改為 deferred。
- 已有 App → 本機後端 → Google GenAI SDK → Gemini 的呼叫路徑；環境中 `GEMINI_API_KEY` 未設定，後端 `.env` 不存在，因此不能宣稱已對真實模型完成呼叫。
- Google 官方文件指出 Interactions API 預設保存請求；目前 App 已自行傳完整對話，無需服務端 Interaction。後端呼叫加 `store: false`，SDK 更新至 `@google/genai` 2.24.0 並採目前的 `output_text` 回應欄位；假 SDK 測試模型、JSON schema、傳入內容與 stateless 旗標。新增 `npm run smoke:live`，只傳固定虛構測試節次；缺 key 時明確失敗。`npm run typecheck` 與後端 3 項契約測試通過。
- 本輪只改後端呼叫／測試／說明與工作紀錄；既有未提交 V8 App 程式、Xcode 設定、作者資料均未更動。

## 2026-09-23 V8.1 新需求檢查點

- 使用者新增兩項要求：登入選項增加 Google；首頁設定增加使用模型名稱與 API 接口輸入。
- 已核對目前程式：首頁帳號 popover 的帳號／切換／退出是佔位互動；首頁設定頁只有開發階段資訊。V8 App endpoint 由 build 設定供應，模型由後端環境變數選擇，沒有使用者設定或正式帳號。
- 暫時假設：Google 用於帆夢帳號識別，API 接口指向帆夢後端；目前本地書籍仍可離線使用。以上並非使用者已決定，已發出釐清問題。
- 技術界線：Google 官方 macOS SDK 需要 OAuth 設定；後端需驗證 ID token 才能把登入用於服務授權。共用 Gemini key 仍留後端。若使用者要的是自備模型服務與金鑰，需改寫資料流與設定設計。
- 工作樹：上一輪 V8 第一階段的未提交 App／後端／文件修改保持原樣；本輪只新增工作單與交接紀錄，未改功能程式。

## 2026-09-23 V8 本機實作檢查點

- 已決定：第一階段只把目前 `Section.content` 的純文字及記憶體對話送到 AI 服務；點擊入口不傳資料。兩側欄順序為中央工作區、AI、設定集，各自開關；不寫入 SwiftData。理由與被否決的擴大範圍見 `docs/work-items/current.md`、`docs/spec-ai-v8.md`。
- 實作：`EditorWorkspaceView`、4 個 `SailuneAI*` Swift 檔、`Config/Sailune-Info.plist`、Xcode outgoing entitlement；後端為 `SailuneAIBackend/src/server.ts`。Debug 預設 loopback，Release URL 為空。`gemini-3.8-flash` 是後端可覆寫預設，正式選型仍可調整。
- 驗證：`npm run typecheck`、`npm test`（2 項）、`xcodebuild build` Debug／Release、AI 專項 6 項與完整 macOS XCTest 200 項通過，`git diff --check` 通過。完整套件的平行執行曾兩次在既有角色預覽測試遭 test host abort；該測試單獨通過，`-parallel-testing-enabled NO` 的完整 200 項為 0 失敗。隔離 Debug App 實測工具列入口、AI／設定集兩種開啟順序與獨立關閉、空節錯誤，以及本機 mock 回覆與逐字引文顯示。真實 Gemini 呼叫未驗證，因本次沒有 API key。
- 工作樹：起點 `main` HEAD `deeb47d` 乾淨；本輪只改 AI 相關 App、Xcode 設定、新後端／測試與文件。UI 冒煙使用 `/private/tmp` 隔離 store，未讀寫正式作者資料。
- 技術發現：Xcode `INFOPLIST_KEY_SailuneAIBaseURL` 沒有進入產出 Info.plist，已改為 `Config/Sailune-Info.plist` 並核對 Debug bundle。第一次重新啟動隔離測試 store 遇到既有主 store 的 `duplicate column name: Z16CHARACTERS` 遷移錯誤；改用全新隔離 store 完成 V8 UI 驗收。此重開問題尚未釐清，不能宣稱隔離 store 的重啟通過。
- 下一步：以取得的後端金鑰和非作者測試節次驗證真實 Gemini 回覆；若要公開使用，先設計登入、配額與隱私政策。V7.4 UI 冒煙可另行接續。

## 2026-09-23 V8 AI 助手入口方向與需求起點

- 使用者要求 V8 加入 AI 功能；可存取的其他任務紀錄提及設定集整理、文本閱讀、閱讀後建議，以及取名／修訂／資訊擷取等候選能力。這些既有討論是需求線索，不等於完整 V8 範圍已批准。
- 使用者校正範圍：目前先做「目前節次的內文」接入；不應把選取片段、卷、全書或設定集資料擴進第一階段。先前 R 草案列出多種內容範圍，是過度擴大，已更正工作單。設定集整理與更廣分析留待後續工作單。
- 使用者要求入口置於「編輯」與「大綱」按鈕之間；點擊後從 App 右側滑入聊天側欄。使用者進一步校正：若同時開啟設定集側欄，設定集必須在 AI 側欄右側。修正版順序「編輯器／大綱 → AI 助手 → 設定集」已獲使用者「是的」確認。
- 已核對目前實作：`EditorWorkspaceView` 使用編輯／大綱／地圖 segmented picker，右側設定集寬 300 pt。新增 AI 入口會涉及工具列排列調整；雙側欄需佔用可用寬度，實作時依父容器約束排版。
- 既有討論方向是 App → Sailune AI 後端 → Gemini API，避免將服務共用 API key 放入 App；付費 API 才適合作為未公開稿件的預設候選。Gemini Flash 是原型候選，並非已批准的正式模型。使用者明確要求先不使用中國大陸模型。
- 使用者於 2026-09-23 回覆「確認」，批准 R：作者送出問題／要求後，AI 閱讀目前節次完整內文，在聊天窗回覆或提出建議並附原文依據；不含設定集整理、結構化擷取、其他節／卷／全書分析，也不自動寫入資料。
- U approved：使用者確認入口／側欄位置及 AI 與設定集並存順序。工作單已記錄批准依據。
- I 提案：拆成 toolbar／雙側欄、App client／對話狀態、來源驗證、Node.js TypeScript 後端 Gemini 串接、本機啟動與驗證。Repo 目前沒有後端或網路 API；方案不部署公開服務，正式公用部署需另行設定認證、額度及隱私政策。對話保存尚未明確決定，提案採不新增 schema 的工作階段記憶體暫存。
- 使用者於 2026-09-23 回覆「確認」，批准 I 計畫並開始實作。查證 Xcode Release 設定目前禁止 outgoing network，必須在本工作開啟對外連線 entitlement，否則正式建置無法使用 AI client。
- 此節記錄批准當時的起點；目前實作與測試結果見上方 V8 本機實作檢查點。

## 2026-09-23 V7.4 跨層級跳轉需求起點

- 使用者要求：從省份以上地圖進入的地點可跳轉其城市地圖；從城市地圖進入的地點可跳轉其特寫地圖。
- 已決定：目前僅建立需求工作單並核對程式，不修改功能程式或作者資料。既有 V7.2 平面地圖分類及 map-local placement 是現況。
- 暫時假設：以來源地圖上的地點標記指定同書單一目標地圖；總體／國家／省份只連城市，城市只連特寫。尚未取得 R 批准。
- 當時待確認的配對方式已由後續使用者訊息補充；按鈕在標記表單或地點設定頁仍待確認。不能把其餘暫時假設當作已批准規格。
- 使用者隨後確認配對方向：沒有同名目標地圖就建立同名地圖；已有同名目標地圖就跳轉並綁定。工作單已更新為「首次同名配對／建立，後續使用穩定 ID」草案；綁定粒度、改名與刪除後行為及按鈕位置仍待 R 確認。
- 使用者回覆「Ｒ」批准需求。工作單已明確綁定來源地圖上的地點標記與目標地圖 ID；同名既有圖的內容不覆寫，目標改名保留綁定，刪除後重新配對。U 提案把按鈕放在既有標記編輯表單，待確認；I 尚未提出，功能程式未修改。
- 使用者回覆「U」批准標記表單按鈕與建立後直接進入流程。I 計畫已提出：settings V13 為 placement 新增可空目標 map ID；同名查找／建立與綁定單次保存；刪目標圖清除來源綁定；備份接受 V10～V12 舊 settings。I 待確認，尚未改功能程式或正式作者資料。
- 使用者回覆「I」後完成上述實作。V12→V13 輕量遷移保留舊 placement；查找或建立目標圖與寫入來源綁定在同一 settings save；刪目標圖清除指向它的綁定。沒有修改正式作者資料。
- 驗證：`xcodebuild test -project Sailune.xcodeproj -scheme Sailune -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/sailune-v74-nav-derived-host CODE_SIGNING_ALLOWED=NO` 完整 194 項通過、0 失敗；加 `-only-testing:SailuneTests/MapV7Tests` 的地圖專項 26 項通過。受影響 Swift 的 `swiftc -frontend -parse` 與 `git diff --check` 通過。沙盒內 Xcode 因 SwiftData macro 外掛 malformed response 無法編譯，改以主機環境成功驗證。最新 UI 指標操作尚未冒煙。
- 工作樹邊界：起點乾淨、HEAD `bf14ca3`；本工作修改 map catalog、標記 UI、settings schema／啟動、備份、相關測試及文件。未回復其他工作，也未操作正式作者資料。
- 工作樹起點乾淨，`main` HEAD `bf14ca3`；本輪僅修改工作單與交接。未執行測試，因尚無程式變更。下一步先完成 R。

## 2026-09-23 V7.2a 地圖工具列窄寬度圖示化

- 地圖工具列建立共用自適應標籤；目前匯入與管理地圖可在寬度不足時個別退化為純圖示。
- 層級／地圖／圖層選擇器與縮放倍率維持文字；純圖示按鈕保留 help 與 accessibility label。
- 後續重排為匯出／匯入左上、座標圖釘靠右、縮放左下、圖層切換右下；符合視窗使用等號，管理地圖與管理圖層統一使用三層正方形圖示。
- 小型明確 UI 修正，未改 schema、store、地圖流程或正式作者資料。
- Swift frontend parse、無簽章 Debug build 與 diff check 通過。

## 2026-09-23 V7.2b 地圖預設底色與浮動控制樣式

- 空白預設地圖底色改為淺灰；匯入背景與匯出「純白」模板不變。
- 「管理地圖」固定以圖示呈現並保留 accessibility label；底部縮放／圖層控制取消群組灰色底板，保留實色控制，右下圖層選擇器與管理按鈕間距縮至 3 pt。
- 小型明確 UI 修正，無 schema、資料或 store 變更。
- 後續依截圖回報將空白底色加深至 RGB 0.72（約 #B8B8B8），並將底部控制移出裁切中的地圖內容，作為根層前景覆蓋且設高 z-index，確保控制顯示於 PDF、座標刻度之上。
- 最新截圖顯示底部控制遮住下緣內容，依最新要求將縮放與圖層控制移出 4:3 畫布，放在固定 60 pt 高的底部深色區；這個區塊是畫布 GeometryReader 的同層 VStack 兄弟，因此地圖 zoom/pan 不會覆蓋它。
- 上方層級、具體地圖、管理地圖與圖釘入口形成靠右控制群。
- 最新截圖回饋層級／地圖／管理圖示三項仍分散；原因是 Picker 的 frame 會吸收剩餘寬度。現改為內容固有寬度並把群組間距縮至 2 pt，整組隨工具列 Spacer 靠右。

## 2026-09-23 V7.2 地圖分類與地圖版本規劃

- 使用者確認不建立總體／國家／省份父子階層，只保留兩個平面分類：固定層級與作者命名的具體地圖。每張具體地圖擁有自己的座標 placement。
- 所謂圖層是同一具體地圖的替代背景版本（行政區劃、地形、資源位置等），一次顯示一個；總體／國家／省份可管理多版本，城市／特寫維持單一版本。同圖版本共用 placement。
- R 已批准。U 已批准：工具列提供層級、具體地圖與條件式版本選擇器；具體地圖與版本分別以 sheet 管理；刪 map 保留 Place、刪版本保留標記。
- I 提案採 settings V12 的 `BookMap`、`BookMapVersion`、`MapPlacement`；V11 Place 舊座標遷入預設 `總體／總體地圖` placement，既有 `<bookID>.pdf` 原子搬入 map/version 子目錄並可冪等重試。
- 程式查證目前備份只掃描 Maps 第一層 PDF，還原也會壓平檔名；多版本必須同步改成遞迴保存安全相對路徑，並接受 V10／V11 settings 舊備份後升級 V12。
- I 當時尚未批准；後續使用者已回覆「I」，下列實作完成內容取代該規劃階段狀態。

### 實作完成

- 使用者回覆「I」後完成 settings V12、`MapCatalog` CRUD／回填、巢狀 `BookMapPDFStore`、地圖／版本管理 UI、map-local placement 與遞迴備份。
- `MapCatalogProfile` 記錄每本書已初始化狀態：首次建立預設總體地圖；作者刪除全部地圖後保持空狀態，不會因重開再次自動建立。
- 舊 Place 座標只作遷移來源；新地圖標記建立、表單編輯與拖曳只更新 placement。同一 Place 跨圖可有不同 X／Y。
- 最終完整 macOS XCTest 191 項通過、0 失敗／0 跳過；無簽章 Debug build通過。測試涵蓋 V11→V12 真實 store、回填冪等、刪除隔離、版本資產與巢狀備份還原。
- 正式作者資料未由測試或 UI 操作；工作樹起點只有本輪工作單／交接文件，程式、測試與其餘文件均為本輪新增修改。最新建置 UI 冒煙尚未執行。

## 2026-09-22 V7.4b 命中區裁切

- V7.4a 視覺裁切後，使用者仍重現放大地圖攔截「匯入地圖」點擊並新增 Place；確認是 SwiftUI clip 不限制 hit-testing，不是座標數學問題。
- viewport 與 GeometryReader 均加入 interaction content shape／clipping；工具列使用實色背景與 z-index 1，地圖區為 z-index 0，阻止放大 MapSurface 在工具列或 letterbox 接收點擊。
- Swift parse、無簽章 Debug build與 diff check 通過；需由最新建置確認匯入按鈕只開啟檔案選擇器。

## 2026-09-22 V7.4a 固定 viewport 修正

- 使用者回報放大後 X／Y 配置異常且 4:3 外側也顯示地圖。查明 MapSurface 自身 frame 被放大後只由整個中央區裁切，沒有固定地圖 viewport。
- `MapWorkspaceView` 現以 Fit rect 建立固定 4:3 clip，放大的 MapSurface 依 content rect offset 在其中；viewport 邊框與陰影固定，外側維持工作區背景。
- `MapViewport` 平移上限改依 Fit viewport 尺寸計算，寬／高工作區不再混入 letterbox 尺寸。新增寬工作區測試，確認 100% content 等於 viewport、200% content 仍只由固定邊界顯示。
- 18 項地圖專項、完整 186 項 macOS XCTest、無簽章 Debug build、Swift parse 與 diff check 通過。

## 2026-09-22 V7.4 標記互動

- 截圖查明點擊後名稱例外來自 `selectedPlaceID` 未隨 sheet 關閉清除；現改由 `markerDraft?.placeID` 推導選取狀態，關閉表單即恢復一般顯示。
- 圓點與名稱已整合成單一 `MapMarkerView` 互動區，hover 展開名稱後可移到文字，點擊兩者皆開啟同一表單。
- 既有 Place 可拖曳改座標：8 pt 門檻、即時 X／Y、超界貼齊、放開保存；外層畫布拖曳在標記拖曳期間停用。store 新增同書保護的座標專用更新方法。
- 既有標記表單新增「前往地點設定」，透過既有 `.place(UUID)` target 打開右側 `PlaceDetailView`；viewport 保留，表單未儲存文字不寫入。
- 完整 185 項 macOS XCTest、無簽章 Debug build、Swift parse 與 diff check 通過。最新建置 UI 手勢冒煙待確認；未改 schema、migration 或正式作者資料。

## 2026-09-22 V7.3a 小型 UI 修正

- 依使用者明確要求，標記名稱浮標改為黑字白底，修正深色模式白底白字。
- 新增僅在游標位於地圖且倍率大於 100% 時生效的滾輪監聽：觸控板二維滾動可上下左右平移，Shift＋垂直滑鼠滾輪可水平平移；離開地圖或 View 消失會停用／移除 monitor。
- 編輯／大綱／地圖 segmented control 改回書本、大綱、地圖圖示，保留可及性文字與原有互斥模式邏輯。
- 此為既有功能的小型明確修正，未重走 R／U／I；未改 schema、store 或作者資料。
- Swift parse、無簽章 Debug build、完整 183 項 macOS XCTest 與 `git diff --check` 通過。

## 2026-09-22 V7.3 工作模式切換、標記密度與地圖縮放

- 使用者詢問編輯／頁面大綱／地圖的切換邏輯，並要求縮小標記、依倍率或點擊才顯示文字，以及增加地圖縮放。
- 程式查證：大綱與地圖目前由兩個 Bool 控制；大綱按鈕會變成返回正文，地圖則同一按鈕 toggle，兩者心智模型不一致。地圖完整 fit，標記固定顯示圖釘、名稱、類型，沒有 viewport 縮放／平移。
- 建議採三個同層且互斥的工作模式 `編輯｜大綱｜地圖`，直接互切而非建立返回層級；設定集仍是獨立右欄。實作方向會以單一 enum 取代兩個 Bool。
- 使用者確認其他方向，但要求戳記更小以清楚表達位置。R 已批准；標記修訂為以座標為圓心的 5–6 pt 實心點，不使用大圖釘。hover／選取顯示名稱，選取只加 10–12 pt 細外環，`150%` 以上常駐名稱，類型不常駐。
- 縮放建議 Fit 起始、`50%...400%`、游標／手勢中心縮放、放大後平移；底圖、座標與標記共用 viewport 轉換。倍率與中心只保留本次開書期間，不改 schema。
- U 提案採主工具列 `編輯｜大綱｜地圖` 三段互斥切換，地圖工具列右側為 `－｜倍率｜＋｜符合視窗`；放大後可平移，點擊與拖曳以手勢門檻區分。使用者回覆「U」，UI 關卡通過。
- 使用者回覆「I」後完成實作：`EditorWorkspaceMode` 單一 enum 取代兩個 Bool，三段 Picker 可直接互切；切換會 flush 正文，但不強制關閉設定集。地圖 viewport state 留在書籍工作區，因此模式互切保留視野、重開書籍回到 Fit。
- `MapViewport` 集中處理 Fit、`0.5...4.0`、25% 級距、錨點縮放與平移 clamp；底圖、座標軸、標記及點擊共用同一 map rect。畫布支援 `MagnifyGesture` 與 8 pt 門檻拖曳。
- 標記改為固定 6 pt 紅點與 24 pt 命中區；選取顯示 12 pt 細環，hover／選取／`150%` 以上顯示名稱，類型移至 help 與編輯表單。
- 新增 5 項 V7.3 測試，涵蓋模式集合、倍率上下限／級距／重設、錨點座標不變、平移 clamp／座標 round-trip、語意名稱門檻。完整 183 項 macOS XCTest、無簽章 Debug build、Swift parse 與 `git diff --check` 通過；未改 schema 或正式作者資料。
- GUI 嘗試啟動最新 DerivedData build 時，系統仍綁定既有同 bundle 執行程序並顯示舊工具列，未把該畫面誤記為 V7.3 驗收；最新建置的實際互動手感仍待使用者確認。

## 2026-09-22 V7.2 地圖標記刪除與直接座標入口

- 使用者要求增加刪除按鈕、增加直接輸入 X／Y 的入口，並完成先前因使用上限中斷的工作。
- 直接座標入口暫定放在地圖工具列，不先點畫布即可開啟 X／Y 空白的新增標記表單；沿用 V7.1 驗證與 Place 建立流程。
- 使用者明確指定「直接刪除」整筆 Place，不採只清空座標；並說明標記移動與地點連接會於後續增加。這些後續能力不納入本輪，也不預先改 schema。
- R 已批准。使用者回覆「U」，確認在「匯入地圖」右側新增「輸入座標」；既有標記編輯表單左下顯示紅色「刪除地點」，按下後以系統 alert 明示會從地圖與設定集永久刪除且無法復原。
- I 計畫沿用 `MapCoordinateInput` 與 `V5SettingsStore.deletePlace`，只調整地圖 draft／表單／工具列並補刪除隔離測試；不改 schema、migration 或資產。使用者回覆「I」，實作關卡通過。
- V7.2 已完成：工具列「輸入座標」以空白 X／Y 開啟共用表單；既有標記表單顯示「刪除地點」並先要求永久刪除確認。刪除時重新按目前書籍與 UUID 查找 Place，再沿用既有 store 刪除。
- 驗證：10 項地圖專項、完整 178 項 macOS XCTest、Swift parse、無簽章 Debug build與 `git diff --check` 通過。隔離 UI 建立 `(1000,2000)` 標記，檢查刪除 alert 並取消，標記保持存在；永久刪除資料行為由隔離自動測試覆蓋。正式作者資料未使用。

## 2026-09-22 V7.1 自選座標與圖片匯入

- 使用者追加兩項需求：地圖標記提供自選座標，地圖背景兼容 PNG、JPEG 與 JPG。
- 程式查證：`MapMarkerEditorView` 目前只顯示唯讀座標；`fileImporter` 只允許 `.pdf`；既有背景儲存與備份均以每書一份正規化 PDF 運作。
- 暫時假設「自選座標」是新增／編輯標記時可直接輸入 X、Y，合法範圍維持 X `0...4000`、Y `0...3000`；超界或非數字不允許儲存，不自動截斷。
- 圖片匯入提案沿用既有安全規則：依圖片像素尺寸等比例置中至白色 4:3 畫布，不裁切、不拉伸；透明 PNG 合成白底；完成後仍轉成單頁 PDF 保存，因此不改 schema、備份資產格式或更換底圖不動座標的行為。
- 使用者回覆「Ｒ」，需求關卡通過。U 提案保留單一匯入入口並改名為「匯入地圖」，系統選擇器接受 PDF／PNG／JPEG／JPG；標記表單提供並排 X／Y 整數欄、範圍提示與行內錯誤，無效時停用儲存。
- 使用者回覆「Ｕ」，UI 關卡通過。I 計畫集中修改 `MapPDFGenerator`、`MapViews`、必要的地圖 store 入口與 `MapV7Tests`：圖片正規化後仍存單頁 PDF；座標文字解析採可測試純邏輯；不改 schema、migration、備份格式或其他地圖 UI。
- 使用者回覆「Ｉ」，實作關卡通過。已新增 PNG／JPEG 正規化、單一圖片／PDF 匯入入口、X／Y 整數欄與驗證；不改 schema、migration 或備份格式。
- Swift parse、`git diff --check`、9 項 `MapV7Tests`、完整 177 項 macOS XCTest與無簽章 Debug build通過；沙盒內 Xcode 因 SwiftData／SwiftUI macro plugin 權限失敗，主機環境重跑成功。
- 隔離 UI 確認 X／Y 輸入、超界錯誤、`(100,200)` 標記與非 4:3 PNG 補白。第二次 GUI 選檔因相同 bundle 視窗重新綁定中止；JPEG 替換與座標保持由專項測試補驗證。正式作者資料未使用。

## 2026-09-22 V7 地圖匯入／匯出需求整理

- 使用者提出 V7 地圖方向：提供可下載的 4:3 全白或網格 PDF；使用者可將外部完成的地圖 PDF 匯入，並在其上疊加左下角原點、範圍 `4000 × 3000` 的平面座標系，點選位置建立城市等標記。
- 使用者已確認第一階段暫時只製作單張地圖；不預設多張地圖 UI，未來增加時另立工作單。
- 已決定的核心語意：PDF 是可替換背景，座標系統與標記資料獨立；更換 PDF 不影響既有座標。
- R 確認前未修改程式、schema、store、正式資料或規格；目前 V6.4 的唯一下一步仍是隔離資料確認紀元刪除 alert 後取消。
- 使用者後續已回覆「R」，V7 需求關卡通過；目前進入 U，待確認單張地圖工作區的操作流程與文字線框。尚未修改功能程式、schema、store 或正式資料。
- 使用者後續已回覆「U」，V7 UI 關卡通過；I 計畫沿用 `Place` 保存可選座標、settings 升級 V11、外部 PDF 以書籍 UUID 保存並納入備份、地圖畫布使用固定 4:3 與 `(4000,3000)` 轉換。
- 使用者確認採用較安全的 PDF 正規化方案：匯入時完整保留單頁 PDF 內容，以等比例縮放並用白邊補成 4:3；不自動裁剪、不變形。白邊屬於正規化後的 `4000 × 3000` 座標平面，替換背景仍不改動既有座標。此決策已回寫 V7 工作單。
- 使用者於 2026-09-22 回覆「I」，V7 實作關卡通過；開始依工作單實作 schema V11、地圖 PDF 資產、中央畫布、點位、備份／刪除整合與測試，不操作正式作者資料。
- V7 第一階段已完成：新增 settings V11 Place 可空座標、每書單張 PDF 資產、純白／網格模板、單頁補白匯入、固定座標與點位、完整備份／V10 備份相容及刪書清理。正式規格為 `docs/spec-map-v7.md`。
- 驗證：完整 173 項 macOS XCTest 與無簽章 Debug build 通過；PDF 實際渲染為單頁 1200×900，2:1 寬圖上下補白且左右內容保留。隔離 UI 建立「中央城」後替換為寬圖，座標保持約 `(1995,1499)`；深色模式座標標籤已修正為黑字白底。正式作者資料未使用。

### V7 狀態

第一階段完成，無未完成的 V7 必要工作；多張地圖、路徑、區域、備註與自訂標記樣式留待後續新工作單。整體專案唯一下一步仍為 V6.4 隔離資料紀元刪除 alert 的取消驗收，不執行刪除。

## 2026-09-22 能力時間序列標記精簡

- 使用者明確確認不需要記住角色詳情項目的展開狀態；本次未加入任何展開狀態保存。
- 能力時間序列不再於首筆或尚未選擇等級時顯示「設定／未設定」；既有「上升／下降／維持」比較結果保留。
- 「敘事版本」與「時間序版本」列內按鈕分別改為書頁與時鐘小圖示，保留 tooltip 與 accessibility label；兩個既有編輯彈窗及資料行為不變。
- 使用者截圖回報時間軸日期卡的 `xmark` 在游標停留時呈現灰色圓底並被游標遮住。三種日期版面的刪除入口已移除按鈕本身的 destructive role，固定為透明 24×24 圖示命中區；破壞性語意與實際刪除仍由後續確認視窗處理。

## V6.4 紀元管理增加刪除按鈕（R／U／I approved；實作與自動驗證完成）

- 使用者提出：「紀元管理增加刪除按鈕」。
- 已讀取 `docs/spec-timeline.md`、`Sailune/Era.swift`、`Sailune/TimelineEngine.swift` 與 `Sailune/TimelineViews.swift` 的紀元管理區段，並查閱刪除資料安全規範。
- 使用者澄清：需要保留的時間點先移出紀元；刪除紀元時連同仍掛在該紀元的時間點一起刪除，不保留成未指定紀元。R 已 approved。
- 核對 `PersistentModelDeletion.deleteNodes`／`CrossStoreDeletionCoordinator.deleteNodes`：Node 刪除會級聯刪除 Event，清理規劃 metadata 與跨 store 時間定位；角色／能力／物品／關係等來源歷史本身保留但失去 Node 定位；正文與敘事大綱內容保留。紀元只屬目前 Book，刪除範圍是該書所有主／副 Timeline。
- 若被刪 Era 是某本書 `currentEra`，關聯解除；既有 bootstrap 之後會建立空白預設 Era。這是已存在的系統行為，本輪不指定其他 Era 接任。
- U 已 approved：每個紀元名稱欄右側放「刪除」破壞性按鈕；系統 alert 顯示 Era 名稱及節點／事件刪除、歷史定位失效、正文與敘事大綱保留，以及目前紀元會在之後 bootstrap 成空白預設紀元的影響；取消不變，確認才透過既有 coordinator 刪除。
- I 已 approved：使用者回覆「I」。開始依工作單計畫實作與驗證。
- 開始本工作時工作樹乾淨；本工作修改 `Sailune/PersistentStoreRepair.swift`、`Sailune/TimelineViews.swift`、`SailuneTests/ItemV3Tests.swift` 及時間軸、資料模型、架構、一致性、狀態與工作交接文件。未改 schema、migration 或正式作者資料。
- `swiftc -parse` 與 `git diff --check` 通過；新增同一本書跨主／副 Timeline、另一書資料保留的紀元刪除整合測試通過；單項與完整 macOS XCTest 以主機環境執行通過。沙盒內 test runner 曾因分散式通知權限 exit 133，非程式測試失敗。
- 以獨立 `/private/tmp/sailune-v64-era-ui/Sailune-v5.store` 啟動 Debug App 並確認空書櫃畫面；尚未建立測試書進入紀元管理，所以刪除按鈕／alert 的人工 UI 確認待完成。隔離資料未執行刪除。
- 使用者追加要求提供刪除特定時間的按鈕；依後續 UI 修正，寬版與窄版時間軸每個日期項目右上角使用 `xmark` 圖示，仍呼叫同一個確認視窗與 `CrossStoreDeletionCoordinator.deleteNodes`，只處理該日期項目的 Node／Event。除必要 accessibility label／tooltip 外，不放多餘說明文字。
- 追加位置修正：橫向時間格的 `xmark` 已移入內容方塊右上角；「尚無事件」方塊也直接在方塊內顯示，避免跟隨紀元名稱長度移動。
- 本次驗證：`swiftc -frontend -parse Sailune/TimelineViews.swift`、`git diff --check` 通過；主機環境完整 macOS XCTest 通過（`xcodebuild test ... -derivedDataPath /private/tmp/sailune-v64-specific-time-derived-host`）。沙盒測試另受 SwiftData／SwiftUI macro plugin sandbox 限制失敗，不代表程式測試失敗。
- V6.3 的自動驗證已完成；其先前 UI 驗收狀態不受本次 V6.4 工作影響。

## 第一個下一步

使用者已確認：前一紀元最後一次紀錄的年份就是最後一年，各紀元從元年元月一日開始；紀元與設定只屬單一本書，不存在跨書共享。現行改元看觸發改元之書籍的所有時間軸。後續依此補測試／文件，並回到隔離 store 驗收紀元刪除 alert、按取消；不執行刪除。

- 追加完成：時間軸節點與日期格先按紀元順序，再按紀元內年月日、同日 `sortOrder` 與 UUID；角色時間定位、物品副本歷史同步使用此排序，未指定紀元排在最後。單項與完整 macOS XCTest 已通過。

## 2026-09-21 V6.3 角色所屬勢力（R／U／I approved；實作與自動驗證完成）

- 使用者要求角色增加「所屬勢力」。現有正式資料來源是 V5 settings store 的 `PowerMember`／`PowerUnit`，已支援一角多勢力，角色頁目前未提供入口。
- 使用者確認允許多個；每筆只需要勢力名稱與單一職稱，先不加入時間序，也不呈現狀態或多職務歷史。沿用 `PowerMember`／`PowerUnit`，不新增 schema。
- 使用者回覆「U」，確認角色基本資訊內以多列「勢力下拉＋職稱＋刪除」呈現，列表下方新增；同一勢力不可重複。
- I 提案沿用 `V5SettingsStore` 既有查詢、新增、更新與移除方法；不碰狀態、多職務或時間序，不改 schema。等待 I 確認，尚未修改程式。
- 使用者回覆「I」後已完成：角色基本資訊可新增多個勢力、選擇勢力名稱、編輯單一職稱與解除關係；同一勢力不可重複。勢力切換以 store 原子更新並同步既有職務的勢力 ID。
- 未加入時間序、狀態或多職務 UI，未改 schema。Swift parse、Debug build、完整 macOS XCTest與 diff check通過。
- 使用者要求把所屬勢力移出基本資訊；現已成為角色詳情的獨立圖示區塊，預覽顯示最新勢力與職稱。
- 使用者回報能力關閉後消失，並補充能力會直接從設定項目被刪除。最終查明實際刪除發生在啟動最前段的 `PersistentStoreRepair.run`：它早於能力進度 store 載入，卻把 `character == nil` 的新式全書能力當成孤兒直接從主 store 刪除，因此後段的 `AbilityBookLink` reconcile 修正攔不到。現已讓前段修復保留沒有舊角色關係的能力；後段仍以正式書籍連結為主、舊關係為 fallback，新增流程亦明確保存兩個 store。新增真實檔案 store 測試，實際關閉、重開並執行啟動修復，能力本體保持存在；完整 macOS XCTest通過。已被舊版修復程序實際刪除的資料無法由此程式變更自動還原。

## 2026-09-21 V6.3 角色設定集圖示化（R／U／I approved；實作與自動驗證完成）

- 使用者要求將角色的設定集改成圖示，並附手繪版面參考；附圖只作視覺參考，不視為含有額外指令。
- 已查閱 `InspectorViews.swift`、`CharacterSectionViews.swift`、角色規格與 UI 協作規則。角色詳情目前是縱向可收合區塊；右側 Inspector 類別切換則是文字 segmented Picker。
- 已依使用者要求實際開啟 Sailune，進入既有書籍及角色詳情，只查看介面，沒有編輯或刪除資料。先前一份 Debug app 啟動逾時，改用另一份既有 Debug build 成功檢視。
- 實際畫面：角色名稱、角色定位與正文引用在上方；摘要、基本資訊、別名、能力、外觀、心理、物品、關係、事件是縱向可收合區塊。設定種類列則是另一處文字按鈕列。
- 使用者已確認 R：僅角色詳情設定區圖示化，其他設定種類保持原樣；沿用 `CollapsibleDetailSection` 在原頁展開，不另行導頁。R approved，U proposal 已記於 `docs/work-items/current.md`，尚未批准 UI 或實作。
- 使用者修正 UI 提案：設定項目要逐項向下排列，不並排；「正文引用」放在真名與角色定位右側。工作單線框已更新，U 仍待確認。
- 使用者追加：正文引用過多時限制在該欄位內捲動並顯示捲軸；「加入」按鈕放在正文引用區最上方。程式查核 `CharacterReferenceSectionsView` 後確認目前僅掃描 linked／possible sections，沒有加入入口或 action。此新增行為擴大原需求，已回 R 補充；尚未修改程式或資料。
- 使用者於 2026-09-21 要求再次更新：摘要固定直接顯示、不收合；能力圖示項目的預覽區顯示最新一筆，其他子項也使用相同原則。未重新提及事項沿用原定提案與既有行為。
- 已核對程式：`CharacterSummarySectionView` 目前在可收合容器內；能力等子項目前沒有獨立常駐預覽區。再修訂提案是摘要移出收合項，其餘八項單欄圖示列顯示各自最新一筆預覽，點擊仍在原頁展開現有編輯內容。
- 使用者立即糾正：「重新開始 V6.3」表示不得把上一輪未定案的正文引用右移、欄內捲動或「加入」按鈕帶入本輪。正文引用應維持目前程式中姓名／定位下方的原位置與原行為。先前延續舊提案是助手誤解，不是技術阻礙。
- 使用者回覆「繼續」，U 已批准。I 提案只改角色詳情組合與預覽邏輯：摘要固定顯示，八個單欄圖示列常駐顯示最新預覽；有 `updatedAt` 的資料以更新時間判定，事件沿用 `sortOrder` 最後一筆。不改 schema、store、CRUD 或正文引用。
- 使用者回覆「I」後已實作。`InspectorViews.swift` 現將摘要固定顯示，其餘八項為整列可點擊的單欄圖示列，最新預覽常駐可見；正文引用組合順序與行為未修改。
- 新增 `CharacterDetailPreviewOrdering` 與四項 `CharacterDetailPreviewTests`，覆蓋最新更新時間、UUID 平手、事件 `sortOrder` 與空資料。Swift parse、diff check、主機無簽章 Debug build 及完整 macOS XCTest 通過。沙盒 build 僅受既有 SwiftData macro plugin malformed response 阻擋。
- 使用者追加三項需求：時間序改手填並將選擇部分改為「敘事版本」；角色事件改為該角色全部時間序；能力預覽加入等級。
- 已查核 `CharacterNodePicker`、`CharacterTimestampEditorSheet`、`PlanningRecordProjectionBuilder` 與時間軸／敘事規格。現況是下拉選既有 `Node`，另一個編輯器手填年月日並可選節次、故事線與階段；專案沒有「敘事版本」正式名詞或模型。此語意會決定是否需要 schema／遷移，因此回 R 釐清，未修改程式。
- 已確認可沿用的資料：角色全時間序可由現有能力、外觀、心理、物品、關係投影彙整；能力預覽等級可使用 `currentLevelID` 查找 `AbilityLevel`，不需新欄位。
- 使用者已釐清：時間序的日期僅保留手填；原時間點下拉選單改為選擇卷、節（敘事），不是故事線或新版本模型。R approved。
- U 提案：角色相關時間序列直接呈現年／月／日手填與「卷 → 節」選擇；沿用 `Node` 及舊值，不新增 schema。角色事件彙整能力、外觀、心理、物品、關係與直接事件；能力預覽顯示名稱與目前等級。U 待確認，未修改程式。
- 使用者回覆「U」後，提出 I 提案：新增角色時間序專用行內編輯器；新紀錄使用專用 Node，既有共用 Node 首次編輯時複製以避免連動；以可測試投影器彙整全時間序；直接事件保留編輯，其他來源唯讀；能力預覽查找現有等級。不改 schema；當時尚待 I 確認。
- 使用者回覆「I」後追加實作；隨後明確校正為兩個按鈕、兩個彈窗：「敘事版本」只選卷／節，「時間序版本」只選紀元／年／月／日。現已依此修正；首次儲存修改既有 Node 時複製定位，避免共用資料被連動修改。
- 角色事件現在彙整能力、外觀、心理、物品、關係及直接事件，事件圖示預覽亦取全時間序最後一筆；直接事件 CRUD 保留。能力圖示預覽增加目前等級。
- 使用者追加指定事件僅在被賦予時間序後顯示；投影與直接事件列已過濾無 Node 紀錄，新增直接事件會同步建立專用 Node。Debug build 與 parse 通過。
- 新增投影器回歸測試；受影響 Swift parse、主機無簽章 Debug build與完整 macOS XCTest通過。未改 schema、migration、正文引用位置或角色以外時間軸 UI。隔離資料 UI 驗收待完成。
- 工作樹邊界：目前另有 `Sailune/EditorWorkspaceView.swift` 未提交修改，內容涉及卷／節重新命名、列點擊範圍及標題寬度；與 V6.3 無關，本工作未修改，視為使用者既有變更並保留。
- 使用者於 2026-09-21 明確表示 V6.2 已完成；此確認取代此前工作紀錄內尚待 UI 驗收的狀態。V6.2 不再列為下一步。
- 第一個下一步：以隔離資料驗收行內日期、卷／節、全時間序及能力等級預覽；新聊天最小讀取集合為 `docs/work-items/current.md`、`docs/handoffs/current.md`、`docs/project-status.md` 與 `docs/spec-character.md`。

## 2026-09-21 V6.2.2 右側設定集欄重設計（R／U／I approved；自動驗證完成，待 UI 驗收）

- 使用者要求依草圖實作右側邊欄，並澄清搜尋欄位置在設定種類列下方：`[角色｜物品｜能力｜勢力｜…]` 後接 `[🔍 搜尋＿＿＿＿＿＿＿＿]`。
- 已確認角色列右側使用既有「角色定位」；底部新增與列表刪除操作留在原位。
- 明確限制：不得自行加入任何提示語、標題、說明、空狀態文案、導覽文字或其他未被使用者指定的 UI。只可呈現使用者指定控制項與既有資料。
- 已確認本節引用角色（例如「小明、大明」）的橫向列置於搜尋欄上方；「只顯示本節相關角色」開關保留在搜尋欄下方。本節引用不是建議列，也不取代開關；不新增提示文案。
- 已以實際 App 檢視現況：右欄已有設定種類列、搜尋欄、角色本節開關、角色清單及新增按鈕。R 需求已可整理為 UI 提案。
- 使用者回覆「U」，確認目前線框與「不加自行提示語」限制；再回覆「I」，批准實作與測試。
- 已移除設定種類列上方的全域本節引用摘要；角色種類內改為在搜尋欄上方顯示僅含實際引用角色的橫向列，接著為搜尋欄與既有開關。角色列右側改為既有角色定位，UID 移除；空資料不加替代文案。新增與刪除維持原位。
- 未改 schema、資料或正文。受影響 Swift parse、完整 macOS XCTest、無簽章 Debug build 與 diff check 通過。新建置實際開啟未修改的驗收書籍，確認順序、角色定位及未出現額外提示文案；本小項完成。
- 使用者追加指定本節引用橫列最前方顯示連結符號及「本節連結角色」，後接實際角色按鈕；已實作。受影響 Swift parse、diff check 與無簽章 Debug build 通過；未重啟已開啟的驗收 App，追加標籤的實際畫面待下次新建置啟動時確認。
- 使用者追加指定每個角色列最右側、角色定位之後顯示「刪除」按鈕；沿用既有確認與刪除流程。已實作；受影響 Swift parse、diff check 與無簽章 Debug build 通過。未重啟驗收 App，畫面驗收待下次新建置啟動時確認。
- 使用者追加要求「全部項目都使用與角色相同的邏輯」。查證後，物品已有本節引用掃描、標籤有節次；勢力、能力、地點與世界條目沒有正式正文引用／節次連結，若全面套用需新增名稱掃描或新的連結規則。簡易版大綱也不是同構 CRUD 列表。追加需求回到 R，尚未修改這些種類。
- 使用者回覆「是的」，R approved：七個設定種類統一角色版排列與操作；無正式節次連結者以名稱精確掃描正文；摘要映射依工作單；簡易版大綱排除。現在進入 U，尚未修改追加範圍程式。
- 使用者回覆「U」後再回覆「I」，全部種類共用 UI 與實作計畫均已批准。
- 角色、物品、能力、勢力、世界條目、標籤與地點現均採相同順序：有命中才顯示的「連結符號＋本節連結〈種類〉」橫列、搜尋、本節篩選、名稱／批准摘要／文字「刪除」按鈕。物品與能力摘要留白；簡易版大綱不變；未新增任何提示或空狀態文案。
- 標籤以既有 `sectionID` 判定；其餘無正式節次連結的種類使用完整項目名稱掃描目前節正文，不新增 schema 或正文錨點。所有刪除沿用原有確認及 store／coordinator，新增入口留在原位置，標籤未新增不存在的建立入口。
- Swift frontend parse、`git diff --check`、完整 macOS XCTest 與無簽章 Debug build 通過；新增完整名稱掃描測試。驗證產物位於 `/private/tmp/sailune-v622-all-inspector`。最新七類畫面尚未逐類 UI 冒煙；下一步與既有 V6.2 UI 項目一併驗收。
- 使用者追加指定新增入口一律位於下方，且能力／標籤的背景畫面與初始空列表設置需和其他種類一致。勢力、地點、世界條目的新增入口已移至清單底部；角色、物品、能力原本已在底部。能力與標籤現採常駐純列表、隱藏系統捲動背景及右欄背景，不加空狀態文案。Swift parse、diff check 與 Debug build 通過。

## 2026-09-21 左側目錄點擊與改名

- 使用者要求左側目錄改為右鍵改名、其他點擊進入章節，並完整顯示章節文字。
- `EditorSidebarView` 章節列現在由整列一般點擊選取章節；改名留在右鍵選單。使用者補充標題需單行顯示，已取消換行並讓標題按完整單行寬度排版。卷名也由右鍵改名，避免左鍵直接進入改名。
- `swiftc -frontend -parse Sailune/EditorWorkspaceView.swift` 與 `git diff --check` 通過；尚未執行 build 或 UI 冒煙。下一步以窄版側欄確認長章名完整顯示、一般點擊進入及右鍵改名。
- 使用者提供截圖指出改名文字欄只依原標題取寬，要求編輯區拉滿；已讓 TextField 與改名容器取得可用列寬並提高排版優先權。待 parse／diff check 與 UI 驗收確認欄位填滿側欄。
- 後續截圖顯示章節序號分隔符「｜」因窄列換行而落到下一行；序號與分隔符現在使用固定單行寬度，避免字元拆行。

## 2026-09-21 V6.2.2 角色搜尋支援本名與別名

- 使用者明確要求「搜尋欄可以搜尋本名與別名」，截圖作為搜尋欄參考；沒有要求其他視覺或互動變更。
- 查證：設定集角色列表原已支援本名、小記及別名；關係網／關係列表上方共用的角色搜尋欄僅比對對象本名，定位為本次修正範圍。
- 已修改 `RelationshipWorkspaceViews.swift`、`InspectorViews.swift`：共用 matcher 以修剪後查詢比對對象本名與別名，並用於關係網及列表。未更動關係資料或 schema。
- 更新 `docs/spec-character.md`，新增關係搜尋行為規格；新增 matcher 測試涵蓋本名、別名、首尾空白、無命中及空白查詢。
- 工作樹原先乾淨；本工作修改邊界為上述兩個 Swift 檔、`SailuneTests/EditorSettingSelectionTests.swift`、角色規格及 current 工作單／交接／專案狀態。
- 驗證：受影響 Swift frontend parse、`EditorSettingSelectionTests` 專項及完整 macOS XCTest 通過；`git diff --check` 通過。首次 sandbox 內測試因 SwiftData macro plugin 權限失敗，sandbox 外重跑成功。無 schema／store／關係資料變更，畫面配置未改。
- 此小型工作單元已完成；整體 V6.2 工作仍 active。下一步沿用本文件頂端既有項目：隔離書籍原生注音輸入驗收，並驗收右側分類列與頁面地圖。

## 2026-09-21 V6.2 頁面地圖空白入口（R／U／I approved；實作完成，待 UI 驗收）

- 使用者要求在「大綱」與「設定集」按鈕之間新增「頁面地圖」，點擊後進入暫不顯示其他內容的空白頁；之後確認該頁只取代中央正文區，既有側欄及工具列保留。R approved。
- 程式確認目前「大綱」進入規劃工作區時會隱藏左目錄與設定集右欄；不假定新頁面必須沿用該行為。
- 使用者回覆「U」，批准按鈕位置、中央純空白、側欄／工具列保留，以及同一按鈕再次點擊返回正文；再回覆「I」，批准 workspace 顯示狀態、穩定 toolbar 容器及進入前 flush 待儲存正文的實作計畫，不新增資料或其他 UI。
- `Sailune/EditorWorkspaceView.swift` 已新增指定位置的頁面地圖按鈕與空白中央狀態；同一按鈕返回正文，切入前 flush 正文待存內容，工具列 modifier 留在 detail 共用容器。
- 受影響 Swift frontend parse、`git diff --check` 及 macOS Debug build 均通過；build 使用 `/private/tmp/sailune-v62-toolbar-build`。
- 隔離資料 UI 冒煙尚未執行；未人工確認空白中央區、工具列／左右欄保留及正文返回。沒有修改 schema 或 store。
- 下一步：以隔離書籍實際操作新按鈕，確認進入與返回及保存狀態。

## 2026-09-21 V6.2 右側設定種類列 UI 精簡（實作完成，待 UI 驗收）

- 使用者明確要求將「簡易版大綱」移入設定種類、移除「設定集／大綱」橫欄，並移除「設定種類」字樣。
- 這是具體、小型的現有 UI 結構調整，依 AGENTS.md 的明確修正例外略過 R／U／I；只重排既有右側入口，未新增資料或其他視覺調整。
- `WorkspaceInspectorView` 不再呈現外層「設定集／大綱」分段列；原簡易大綱現為設定種類 Picker 的「簡易版大綱」選項，原敘事大綱／時間軸內容與點選項目正文跳轉保留。Picker 不再帶「設定種類」標籤。
- `InspectorViews.swift`／`TimelineViews.swift` frontend parse、`git diff --check` 與 macOS Debug build（`/private/tmp/sailune-v62-settings-outline-build`）通過。
- 隔離資料 UI 冒煙待完成；未修改 schema 或 store。下一步與頁面地圖一併驗收右側分類列及進入／返回。

## 2026-09-21 V6.2 正文中文輸入法組字底線（程式修改完成，待 UI 驗收）

- 使用者要求正文中文編輯依 Apple 原生輸入方式，按 Enter 確認候選字後不殘留組字底線。
- 根因位於正文專用組字覆寫：刪除輸入法 marked text 的原生 underline 屬性，再由自訂 layout manager 依標記範圍手動畫線。正文現改用標準 `NSTextView`／`NSLayoutManager` 流程，角色連結、選字及焦點覆寫保留；Inspector 短文字欄位原樣保留。
- 更新 `docs/spec-editor.md` 記錄組字底線只在組字期間顯示，Enter 確認後解除標記。
- 受影響 frontend parse、`git diff --check` 與完整 macOS XCTest 通過（`/private/tmp/sailune-ime-test`）。
- 探索性無視窗 XCTest 未能建立 AppKit 的 marked-text 狀態，已移除，不當作通過；須使用真正的 macOS 注音輸入法做 UI 驗收。
- 下一步：以隔離書籍確認注音組字與 Enter 確認；並合併驗收本次右欄分類列及頁面地圖。

## 2026-09-20 V6.2 編輯頁面 UI 更新

- 使用者已確認兩項需求：設定集項目反白時右欄直接導向；同一工具列橫列顯示標籤顏色含義。
- 使用者要求調換圖例與開關位置；目前 UI 提案順序已改為先顯示五色圖例，再顯示「反白顯示設定集」開關。
- 使用者回覆「U」，UI 關卡已批准。
- 使用者回覆「I」，實作與測試計畫已批准，開始功能實作。
- 已檢視實際 Sailune 編輯器含正文及右側角色詳情畫面。現有中央工具列是「反白角色時顯示資訊」開關；角色資訊列需要再按按鈕才導向右欄。
- 已在 `docs/work-items/current.md` 記錄 R／U approved 與 I 計畫。程式查證發現角色／物品／能力／勢力已有 Inspector 詳情 route；地點與世界條目目前以 modal 編輯，需新增右欄 route 並讓詳情可在 300 pt 寬度使用。
- I 計畫要求採全書唯一匹配、同名歧義不跳轉、隱藏分類不改持久偏好、保留既有 AppStorage 鍵與標記色彩來源，並測試 AppKit route 切換時的正文選取／繼續輸入安全。
- 已完成唯一匹配與直接導向、一次性請求消耗、五色圖例共用標記色彩定義，以及地點／世界條目的 inline Inspector route；保留清單原 modal 編輯流程及既有偏好鍵。
- matcher／圖例 7 項專項 XCTest、完整 XCTest（結束碼 0）、受影響 Swift parse、`git diff --check` 均通過；完整 XCTest 使用 `/private/tmp/sailune-v62-derived-host`。
- 六個 production store 僅以 SQLite backup 複製到 `/private/tmp/sailune-v62-ui.x3WAcD`，供隔離啟動使用。測試 app 直接啟動於 AppKit 註冊階段中止，而 LaunchServices 無法開啟 Xcode 產物（`kLSNoExecutableErr`）；正式 app 未啟動、正式 store 未寫入，人工 UI 冒煙仍待完成。
- 本工作修改邊界：`Sailune/EditorSettingSelection.swift`（新增）、`SailuneTests/EditorSettingSelectionTests.swift`（新增）、`Sailune/EditorWorkspaceView.swift`、`Sailune/InspectorViews.swift`、`Sailune/RichEditorView.swift`、`Sailune/TimelineViews.swift`、`Sailune/V5SettingViews.swift` 及本工作單、交接、專案狀態文件。未修改 schema、正式 store、正文或標籤資料。
- 單一下一步：以可正常啟動的新建置和隔離書籍驗收六類反白跳轉與右欄詳情；新聊天最小讀取集合為本文件、`docs/work-items/current.md`、`docs/project-status.md` 與上述功能檔。

## 2026-09-21 V6.2 角色名稱選取粒度修正

- 使用者澄清主要問題不是跳轉，而是拖曳經過連接角色名稱時會直接整名反白。
- 已在 `SailuneTextView.mouseDown` 與 `mouseDragged` 強制 `selectionGranularity = .selectByCharacter`，修正 AppKit 在 word／paragraph 粒度下延伸拖曳選取的情況；並保留手勢期間暫緩 Inspector 導向作為版面穩定保護。沒有程式化設定選取範圍。
- 受影響 Swift parse、完整 macOS XCTest（結束碼 0）與 `git diff --check` 均通過。人工 UI 冒煙仍待可正常啟動的新建置；先前測試產物無法由 LaunchServices 啟動，正式 store 未寫入。
- 唯一下一步：以新建置／隔離書籍確認連接角色名稱拖曳時逐字元選取、放開後設定集導向正常。

## 2026-09-21 V6.2 編輯器工具列微調

- 使用者要求移除獨立的「指令」按鈕，只留「更多」裡的「指令面板」；⌘K 快捷鍵保留在該選單項目。
- 最新確認：「內文／幕標題」狀態貼左；標題尺寸圖示／切換、註記及圖例共置於緊鄰「反白顯示設定集」左側的水平捲動帶，開關固定最右。
- 截圖驗收補正：左側標籤文字被右側彈性視圖擠壓，故固定標籤自然寬度以完整顯示「內文」；工具列維持開關自然列高並採垂直置中，捲動帶內容以同一視窗高度置中對齊開關。移除會讓開關無限伸展、可能撐高整列的 max-height 設定。
- 僅修改 `Sailune/EditorWorkspaceView.swift` 相關工具列排版；沒有更動其它工作樹改動或資料。工作單與專案狀態文件記錄此次追加範圍。
- 受影響 Swift parse、`git diff --check` 與 macOS Debug build（`/private/tmp/sailune-v62-toolbar-build`）通過；首次受沙盒限制的 build 失敗後，同一命令以核准的建置權限重跑成功。
- 尚未完成實際 UI 驗收。第一步：用可啟動建置／隔離書籍確認窄版圖例捲動時開關仍貼齊右側、「更多」內指令面板及 ⌘K 正常，並接續驗收逐字元拖曳與設定集導向。

## 2026-09-21 V6.2 設定集側欄滑動開合

- 使用者明確要求右側設定集側欄改以滑動打開；同一側欄關閉時滑回收起。僅改顯示過渡，不改欄寬或內容。
- `EditorWorkspaceView` 將右欄與分隔線包為單一 trailing-edge move transition，並在開合狀態變更時啟用動畫；仍先結束 NSTextView 第一響應者。
- 尚待 parse、diff check、macOS Debug build 及隔離 UI 冒煙確認滑入／滑出與正文版面穩定。

## 2026-09-20 書籍目錄拖曳重排

- 使用者直接要求讓拖曳順暢且不要卡住；程式搜尋確認拖曳入口是書籍總覽目錄和編輯器側欄節次排序。
- 根因風險：dragging state 會在 `List` 中條件式新增末尾 drop rows；`performDrop` 直接在原生拖曳回呼內同步更新一批 SwiftData sortOrder，造成清單正在拖曳時改變結構／重排。
- 第一版曾使用含 hover indicator 的 `OutlineRowDropModifier`，後因使用者實測藍線殘留而被最終型別化拖放實作取代；List rows 始終不在拖曳期間新增／刪除。
- 拖曳識別資料改隨 `NSItemProvider` 傳遞，取消拖曳不會留下父層 drag state；取得 payload 後才在主執行緒套用排序，且只更新實際位移項目。
- 「完全不能拖曳」的直接原因已定位：drop surface 被改成透明 overlay 後覆蓋拖曳把手，來源 `onDrag` 無法開始。現已移回背景層，payload 改用原生 `NSString` item provider，接收端以 `loadObject` 讀取。
- 後續「放開後卡頓」定位為 drop 結束狀態和 SwiftData 排序在同一個主執行緒 pass 內競爭：現先清除列內插入狀態，下一個 pass 才在停用動畫的 transaction 內重排，避免 `List` 在 AppKit 結束 drag session 前重建列。
- 使用者實測藍色線持續亮著且全介面無法操作，確認自訂 delegate 本身仍卡在 hover 狀態。最終修正已刪除整套 `DropDelegate`／hover binding／藍線，來源與接收改用 SwiftUI `String` 型別化 `.draggable`／`.dropDestination`，drop closure 返回後再排程無動畫資料更新。
- 型別化原生拖放仍被使用者確認會短暫鎖住，因此上述方案也已被取代。現行最終實作不進入原生 drag session：把手是 `DragGesture`，列 frame 經 preference 收集，目標上／下半顯示自訂藍線；手勢結束先清狀態，下一個 pass 才重排。程式內已無任何原生 drag/drop API。
- 純手勢第一版被使用者回報完全無法拖曳；原因風險是 `List` 列選取攔截一般 gesture，且 hosting row 可能隔離 preference。已改為把手 `highPriorityGesture(minimumDistance: 1)`，並以每列 `onGeometryChange` 直接寫入 frame map，不再依賴跨 List row 的 PreferenceKey。
- 使用者確認第二卷多個節也無法拖曳，因此排除同卷目標不足。確定的實作缺口是 macOS `List` 的 AppKit `NSTableView`／獨立 hosting row 仍會攔截列內 `DragGesture`，而 `highPriorityGesture` 無法跨 AppKit 事件邊界解決；named coordinate space 也不應跨 hosting rows 做命中。
- 最終修正將書籍總覽與編輯器側欄的目錄改為 `ScrollView`＋`LazyVStack`，使拖曳把手、列 frame 與命中座標都在同一 SwiftUI 視圖樹。只允許同卷排序的規則維持不變。
- 驗證：Swift parse、主機 Debug build、完整 145 項 XCTest 與 `git diff --check` 通過。另以 SQLite `.backup` 建立 `/private/tmp/sailune-drag-ui-smoke.*` 隔離快照啟動新建置；編輯器側欄與書籍總覽均實際完成同卷前移，總覽亦驗證末列下半放置。正式 store 未被寫入。
- 本次只修改 `Sailune/BookOverviewView.swift`、`Sailune/EditorWorkspaceView.swift` 及工作文件；未改 schema、封面、正文或正式使用者 store。
>
> 2026-09-18 V5.6 實作：已修正固定匯出路徑、加入六 store／封面完整備份與啟動前安全還原、補齊 AbilityProgress／ItemCopy／V5 settings reconcile、集中產品刪除入口，並讓關鍵儲存失敗可見且 rollback／reload。
>
> 資料策略：六個 store 以 SQLite snapshot 封裝成具 manifest／checksum 的 `.sailunebackup`；還原先驗證，強制備份現況，再於下次啟動、container 開啟前整組置換，失敗自動 rollback。其餘跨 store 資料以主 store UUID／book 對照做可證明、冪等的清理，不猜測內容。
>
> 驗證：無簽章 Debug／Release build 與完整 140 項 XCTest 通過；備份測試使用 `/private/tmp` 隔離資料並驗證六個 store、封面、安全備份及 pending 清除。人工 UI／故障注入尚待完成。
>
> 2026-09-18 20:34 啟動崩潰診斷：crash report 的第一個 Sailune frame 是舊 binary 的 `sharedModelContainer`，統一日誌顯示它嘗試以已不相容的即時模型開啟 `Sailune-v4.store`，得到 Core Data 134130（missing source managed object model）後 `fatalError`。該產物位於舊的 `DerivedData/DreaMoon-*`，編譯日期為 2026-08-08；目前工作樹沒有這段啟動碼。已重建 `Sailune.xcodeproj` 的 Debug 產物至 `DerivedData/Sailune-*`，並以 `/private/tmp/sailune-v56-crash-smoke` 隔離資料成功啟動六 store，未再崩潰；正式作者資料未用於驗證。
>
> 2026-09-18 23:04 編輯器崩潰修正：目前 binary 可在開啟右側「設定集」時重現 AppKit `Update Constraints in Window` 無限重排，最後由 `NSApplication _crashOnException` 形成 `EXC_BREAKPOINT`；不是 store 或作者資料錯誤。已停用系統 `.inspector`，改為工作區內固定 300pt 的第三欄，並為中央編輯區、工作區與設定種類 segmented picker 加入可收斂的尺寸／水平捲動約束。Xcode Debug build 成功，實際作者介面已完成開啟、關閉、再次開啟設定集的冒煙驗證，未再崩潰且未修改作者資料。
>
> 2026-09-18 文件整理：新增 `docs/spec-power-v5.5.md`，並同步資料模型、功能盤點、測試基線及 settings V10 遷移說明。V5.0「不連接角色／物品／能力等」保留為第一版歷史邊界，後續 V5.2～V5.6 增量能力分開描述。

## V6.1 EPUB 自訂封面（需求確認中）

- 使用者要求 EPUB 匯出套用書籍目前使用的封面。現況是 `BookCoverStore` 保存 UUID 對應 PNG，但 EPUB 只建立書名／作者文字封面且未宣告 OPF `cover-image`。
- 建議有自訂封面時嵌入 `OEBPS/cover.png`、在 manifest 宣告 `properties="cover-image"`，並由 `cover.xhtml` 等比例完整顯示；沒有或無法讀取圖片時保留文字封面，不能因此阻止正文匯出。
- 使用者於 2026-09-20 回覆「是的」，R 已批准。UI 提案為：有圖片時封面頁只顯示等比例置中的同一張 PNG，並由 OPF 封面縮圖引用；沒有圖片時維持書名／作者文字封面，目錄結構不變。U 等待批准，尚未修改功能程式、EPUB 格式或作者資料。
- 使用者回覆「繼續」，U 已批准。I 提案為：`BookCoverStore` 提供最新 PNG data；`EpubExporter` 有圖時加入 `cover.png`、OPF `cover-image` 與圖片 XHTML，無圖時維持文字 fallback；以隔離封面驗證新增、更換、移除及 EPUB ZIP／manifest。等待批准，尚未修改功能程式。
- 使用者回覆「確認」，I 已批准並完成。`BookCoverStore` 現直接提供經驗證的最新 PNG data；EPUB 有圖時加入 `OEBPS/cover.png`、OPF `cover-image`／相容 metadata 與等比例圖片封面頁，無圖或移除後維持文字封面。
- 新增隔離 EPUB 封面測試，覆蓋無封面、首次設定、更換與移除，並確認更換後只嵌入最新 PNG。frontend parse、diff check、專項與完整 145 項 XCTest 通過；未使用正式作者資料。
- 使用者回報實際閱讀器仍未成功顯示封面，因此上述自動測試不足以證明產品結果，工作重新進入實檔驗證。W3C EPUB 3.3 規格確認 `properties="cover-image"` 是正式封面識別方式；下一步必須檢查使用者實際輸出的 EPUB，並區分檔案未嵌入與閱讀器對固定 `dc:identifier` 的舊封面快取，未取得證據前不再宣稱完成。
- 使用者提供 `/Users/hsuchengyu/Downloads/孤鷹群舞.epub` 後已解包證實檔內沒有 `cover.png` 或 `cover-image`；書籍 UUID `58D81B57-3063-4803-8E54-A37220B423C1` 在 Covers 目錄也沒有自訂 PNG。畫面使用的是程式依書名產生的首字預設封面，而先前匯出只涵蓋自訂圖片，這是實際根因。
- 已新增畫面封面 PNG 輸出：有自訂圖片時直接使用最新 PNG，否則以和 `BookCoverArtwork` 共用的書名雜湊色彩產生 1200 × 1800 首字封面；EPUB 兩者都寫入 `OEBPS/cover.png` 並宣告 OPF `cover-image`。移除自訂圖片後回復預設封面。frontend parse、diff check、主機 EPUB 專項測試通過；下一步只需使用者用新建置重新輸出《孤鷹群舞》作實檔驗收。

## V6.1 書籍總覽介面更新（已完成；追加修正需求確認中）

### 第二輪校正（需求確認中，尚未實作）

- 使用者澄清書名／作者不應套用刻意的短欄寬；欄位應從封面右側一路使用至左側資訊面板分割線前的可用空間。目前程式仍有 180 pt 最大寬度，預計在批准後移除並改為剩餘空間響應式排版。
- 使用者要求「故事背景」改成目前總覽上方的畫面中央彈窗，不再以整頁內容取代總覽。提案會沿用既有 `BookBackgroundView` 與儲存流程，並納入空白遮罩取消及點擊攔截。
- 使用者第一張 Xcode 截圖顯示同步建立 `NSSavePanel()` 時觸發 `AppKitBreakInDebugger / EXC_BREAKPOINT`；初步判定與 SwiftUI Menu 事件重入有關。後續第二張截圖證實延後至下一個主事件週期仍在 `NSSavePanel()` 初始化崩潰，因此該判斷不足，不能只改呼叫時機。
- 使用者於 2026-09-20 回覆「繼續」，R 已批准。UI 提案為：書名／作者直接取得封面右側全部剩餘寬度；故事背景以有遮罩、可外點關閉、內容可捲動的中央 overlay 呈現；匯出選單外觀不變，選定格式並結束選單事件後才顯示原生存檔面板。U 等待批准，功能程式尚未修改。
- 使用者再次回覆「繼續」，U 已批准。I 提案限於：移除欄位 180 pt 上限與推離 Spacer、以父容器尺寸約束的中央 overlay 取代整頁故事背景、由共用 `ExportManager` 延後至下一個主事件週期才建立 `NSSavePanel`。預計執行 parse、專項／完整 XCTest、diff check、Debug build及隔離 UI 冒煙；等待批准，尚未修改功能程式。
- 使用者第三次回覆「繼續」後曾完成延後 `NSSavePanel` 的版本，但使用者實際在 Xcode 偵錯執行仍重現同一 breakpoint；此版本不再視為完成。
- 最終已移除產品 TXT／EPUB 匯出的 `NSSavePanel`／`runModal` 路徑，改為共用 `SailuneExportDocument`、`SailuneExportRequest` 與 SwiftUI `fileExporter` modifier；書籍總覽與編輯器的 TXT／EPUB 入口均已切換。
- frontend parse、diff check、新增 request payload／檔名／UTType 與 entitlement 專項測試，以及主機環境完整 144 項 XCTest 通過。以 `/private/tmp/sailune-v61-fileexporter-smoke` 隔離 store 實際確認總覽 TXT、編輯器 TXT 及編輯器 EPUB 系統輸出面板可開啟／取消，副檔名正確。正式作者資料未使用。
- 使用者提供完整 `bt` 後，根因確定為 `REPORT_APP_ENTITLEMENTS_INSUFFICIENT`：Debug target 的 `ENABLE_USER_SELECTED_FILES` 是 `readonly`，而 Release 已是 `readwrite`。已把 Debug 改為 `readwrite` 並新增 Debug／Release 專案設定回歸測試。`xcodebuild -showBuildSettings` 與實際簽署 Debug App 的 codesign entitlements 均確認 `com.apple.security.files.user-selected.read-write = true`。
- 本輪 R／U／I 均已批准並完成；作者資料未修改。

- 使用者已確認需求：把書籍總覽左側面板的封面移到左上角；在封面按右鍵更換圖片；成功更換需立即同步顯示於目前總覽與開始頁書櫃；書名／作者右移並縮短欄寬；簡介與故事背景上移。
- 已讀取 `BookOverviewView`、`ContentView` 與 `BookCoverStore`。封面目前由獨立 `BookCoverStore` 以書籍 UUID 存檔，總覽與書櫃均經 `BookCoverArtwork` 讀取，預期不用 schema 或儲存格式變更即可共用新封面。
- 已以實際 App 檢視目前總覽：左側 450 pt 面板依序呈現書名／作者、封面與常駐按鈕、簡介、故事背景、統計。UI 提案將封面與書名／作者併為頂部列，封面右鍵選單保留「更換封面…」及已有自訂封面時的「移除封面」；使用者已確認。
- 實作計畫：只修改 `BookOverviewView.swift` 的資訊面板與封面操作／錯誤呈現，沿用 `BookCoverStore` 格式；補上隔離暫存目錄的替換／快取／移除回歸測試，並執行 parse、專項／完整 XCTest、diff check、Debug build 與隔離資料人工冒煙。無 schema、遷移、備份格式、書櫃卡版面或 EPUB 封面改動。
- 已完成 `BookOverviewView` 頂部封面／書名作者列、封面右鍵更換／移除及可見錯誤提示；簡介與故事背景上移。封面覆蓋後藉 `book.updatedAt` 使總覽與書櫃使用相同的新快取圖。
- 新增隔離目錄封面回歸測試，確認覆蓋會立即替換快取、移除回到預設；三檔 frontend parse、diff check、封面專項與完整 142 項 XCTest、無簽章 Debug build 通過。
- 以 `/private/tmp` 最新 build 實際確認一般與 300 pt 最小資訊面板的版面，以及預設封面右鍵「更換封面…」選單；未選圖片、覆蓋或移除作者資料。

### 追加修正（尚未實作）

- 使用者回報更換／刪除封面後，書櫃未即時同步；查核確認 `BookCoverArtwork` 沒有訂閱明確封面變更狀態，可能持有舊快取直到 View 重建。追加範圍會建立可觀測的封面 revision，讓總覽與書櫃同步更新。
- 同時要求放大總覽封面、書名／作者欄靠近資訊面板右側分割線、主視窗有更大初始尺寸，並將總覽目錄的 TXT／EPUB 兩個按鈕收斂為單一「匯出」選單後再選格式與自選輸出位置。
- 使用者已確認採用封面 112 × 158 pt、視窗 1,280 × 820，且匯出整合只限書籍總覽；編輯器現有「更多」選單維持。
- UI 提案：封面仍在左上，書名／作者欄靠右側分割線；右鍵更換／移除後總覽與書櫃同步重繪；目錄工具列採單一「匯出」選單，選 TXT 或 EPUB 後以原生存檔面板自選檔名與目的地。尚未修改程式、作者資料或封面。
- 使用者已確認 UI。實作計畫是：在封面儲存層於成功寫入／移除後發送 UUID 變更通知，所有 `BookCoverArtwork` 訂閱後立即重繪；放大封面並右對齊資訊欄；`WindowGroup.defaultSize(1280×820)`；總覽兩個匯出按鈕改一個 `Menu`。新增通知回歸測試與隔離 UI 冒煙。尚未修改程式、作者資料或封面。

## 書籍刪除後重開復現（診斷完成，未實作修正）

- 已確認首頁刪除會經 `CrossStoreDeletionCoordinator` 明確刪除主 store 書籍與相關模型，並同步 `context.save()`；不是單純從 `@Query` 畫面移除。
- 實機有兩套不同的 `Sailune-v5.store`：App Sandbox container 現有 3 本，非沙盒 Application Support 舊位置現有 1 本。交替啟動不同簽章／沙盒狀態的建置會切換書庫，形成「刪除後復現」的主要風險。
- 兩個位置都沒有 pending restore，可排除本次由排程備份還原覆蓋刪除。
- 現有測試只在同一個 in-memory container 驗證刪除，沒有以檔案 store 釋放／重開驗證。
- 另有舊 V2／V3 import 邊界：只要舊 store 存在且目標書庫為空，下次啟動可再匯入整批舊書。本機實際位置目前只見舊 V4，不是此次直接來源，但實作時應一併修正。
- 本輪僅唯讀檢查程式、測試與本機 store 位置；沒有修改、刪除或搬移任何作者資料。

## V6 首頁響應式搜尋修正（完成）

- 根因是搜尋框已佔用 `HStack` 寬度，新建按鈕又施加同段固定像素位移，視窗尺寸改變後形成重複位移。
- `Sailune/ContentView.swift` 現依內容區可用寬度的 38% 計算搜尋框，保留按鈕比例空間並加入上下限；新建按鈕移除額外 `offset`，改用容器自然排版。
- 長期規則已加入 `AGENTS.md` 與 `docs/coding-standards.md`：與視窗或整體版面比對位置的物件，必須根據父容器可用尺寸、比例與上下限約束計算，不得以固定像素 offset 模擬跨區位移。
- 驗證：Swift frontend parse、`git diff --check`、無簽章 Debug build 通過；隔離 V5 store UI 冒煙中，一般與最大化視窗切換後重新點擊尋找，搜尋框與新建按鈕位置正常、無重疊或越界。
- 本輪只修改首頁排版與協作規範，沒有修改 schema、migration、搜尋條件或正式作者資料。

## V6.0a 開始介面（實作完成，待 UI 驗收）

- 使用者已確認 V6.0a 只更新開始／書櫃介面：標題改為「帆夢 Sailune」、暫時不呈現作者介紹卡、加入約 210–230 pt 且不可收合的固定左側欄。
- 側欄依 Apple Music 式低密度系統導覽呈現：作品／首頁、尋找、發布；作者／成就、關於我。首頁為預設選取並顯示現有作品區；其餘四個按鈕目前只保留外觀，不建立內容或改變既有搜尋。
- 作品區的卡片、搜尋、新建、刪除、空狀態和資料語意均維持不變；作者資料也不刪除，只是不在書櫃呈現。
- R、U 與 I 已批准；`ContentView` 已完成固定窄側欄、品牌標題與作者卡移除。V5.6 人工資料安全驗收仍是獨立未完成工作，不與此 UI 工作混合。
- 驗證：`swiftc -frontend -parse Sailune/ContentView.swift`、`git diff --check`、主機環境隔離 Debug build 與 `xcodebuild test -only-testing:SailuneTests` 均通過。唯一下一步是實機 UI 冒煙；沙盒宏 plugin 錯誤已由主機建置環境排除。

## V6.0b 開始介面互動（實作完成，待 UI 驗收）

- 使用者提出：移除頂欄「帆夢 Sailune」、尋找按鈕觸發搜尋框與新建按鈕的邊界滑動、首頁返回最初畫面、發布／成就／關於我暫留空白，以及左下角圓形使用者頭像。
- 目前提案沿用側欄品牌文字，頭像優先取既有 `AuthorProfile.avatarData`，無資料時使用系統人物圖示；不新增作者欄位或內容頁。
- 架構已確認：進入作品總覽／編輯器後開始介面側欄消失；「首頁」只在開始介面內返回最初書櫃，維持現有 `NavigationStack` 外框。
- R、U 與 I 已完成批准；使用者於 2026-09-19 回覆「正確」後，已完成開始頁頂欄／搜尋滑動、首頁重設、三個空白入口與左下角圓形頭像。進入作品後仍由既有 `NavigationStack` 路由取代開始頁，因此側欄消失。
- 側欄五個選單按鈕現為整列可點擊，非僅限文字／圖示範圍；每列維持 38 pt 最小高度與選取背景。
- 品牌文字已放大；左下角頭像改為可點擊的「登入」整列按鈕，從底部向上開啟帳號面板，五個帳號／方案／設定入口目前僅保留 UI。
- 帳號面板已收斂為原生背景；方案提供三種選單，Sign in with Apple 曾嘗試但現已暫停。關於我改為作者資料彈窗，顯示筆名、簡介與筆名首字預設頭像。
- 帳號面板後續改為 220 pt 側欄同寬、無箭頭圓角面板，從登入區上方浮出；方案名稱會顯示在方案列尾端。Apple ID 最後一次模板嘗試仍失敗，現改為顯示暫停提示；關於我可加入 PNG 頭像。
- 已移除方案列重複的自訂箭頭；關於我不再選取空白內容狀態，只保留目前頁面並開啟作者彈窗。
- `ContentView` parse、`git diff --check`、主機隔離 Debug build 與 `xcodebuild test -only-testing:SailuneTests` 均通過；唯一下一步是人工 UI 冒煙，確認一般／窄視窗搜尋邊界、選單狀態、空白內容、頭像及作品路由。
- 本次增量重新建置受既有 Swift macro plugin server malformed response 阻斷；篩選輸出未見 `AccountPopoverView` 或本次 popover 相關專屬錯誤。

## V6.0c 首頁彈窗規則與書籍狀態（實作完成，待 UI 驗收）

- 已將「首頁任何彈窗、浮動面板或自訂 modal 都可點擊空白處取消」加入 `docs/coding-standards.md`，並套用新建書籍、關於我與登入面板；遮罩會攔截點擊，不穿透背景。
- `Book` 新增 `BookStatus`（連載／完結／草稿），但持久化欄位曾造成 `Sailune-v5.store` 模型不相容，現已撤回；目前使用 `@Transient`、預設草稿，未新增連載／完結入口，也未動正式資料。
- `ContentView`／`Book` parse、狀態單元測試與主機環境無簽章 Debug build 通過。
- 已將正式 V5 store 的 `.store`／WAL／SHM 複製到 `/private/tmp` 隔離目錄，用修正版 App 成功開啟副本並在書櫃看見既有作品；沒有再出現 V5 主資料庫載入失敗，正式資料未被修改。
- 唯一下一步：人工確認三個首頁彈窗的空白取消、圓角尺寸與草稿預設顯示，並沿用 V6.0b 的側欄與路由冒煙。

## V6.0d 書櫃狀態分區與設定頁（實作完成，待最終 UI 複核）

- 書籍卡資料區顯示草稿／連載／完結狀態，卡片高度調整為 310 pt；書櫃依連載、草稿、完結三區排列並以低對比線分隔，空分類保留提示。
- 登入面板改由首頁全頁遮罩處理，已人工確認點擊右側書架空白可取消且不穿透；「設定」會關閉面板並顯示暫時空白頁，第一列為「開發階段 V6.0d」。
- 正式 V5 store 的隔離副本可正常開啟，既有作品出現在草稿區，沒有修改正式資料；frontend parse、狀態專項 XCTest、無簽章 Debug build 與 diff check 通過。
- 書籍狀態仍為 `@Transient`；本輪只呈現 UI，不宣稱重啟後保留連載／完結，正式持久化等待相容的 V6 schema migration。

## V6.0e 首頁收尾（完成）

- 側欄已在作者分組上方新增只有標題與分隔線的「社群」分類；未建立額外按鈕或內容。
- Apple ID 已完成最後一次官方流程嘗試：程式、官方按鈕與 entitlement 可無簽章編譯，但 Xcode 實際簽章回報目前 Personal Team 不支援 Sign in with Apple，無法建立 `com.MooNest.Sailune` 的 provisioning profile。
- 為保持專案可建置，已撤回無法簽署的 capability／entitlement；帳號列顯示需要付費 Apple Developer Program 的明確原因。最終 Debug build、parse、pbxproj lint、diff check 與隔離 V5 store UI 冒煙通過。
- 使用者指定此項完成後結束首頁開發；下一項產品功能應另建工作單。書籍狀態持久化仍是未來 V6 schema migration，不屬於已完成首頁 UI。

## V6.0f 新建書籍流程修正（完成）

- 已重現取消／儲存跑到主視窗工具列，以及完成後沒有進入編輯器。根因是自訂 overlay 誤用 environment `dismiss()`／系統 action 快捷語意，且 `onCreated` 被改成清空導覽回首頁；不是資料庫或卷節 schema 損壞。
- 取消／完成現在固定在圓角彈窗內；建立成功後以新書 UUID 直接開啟第一卷第一節編輯器。
- 隔離 V5 store 實際建書 UI 冒煙通過，未見黃色警告；parse、Debug build 與 diff check 通過，正式作者資料未修改。V6 首頁工作再次標記完成。
- 追加全域首頁規則：只有一個主要確認動作的短輸入彈窗，文字欄按 Enter 直接確認並關閉；規則已同步至 `AGENTS.md` 與 `docs/coding-standards.md`。新建書籍的書名與作者欄已使用 `onSubmit` 套用。

## V5.6 勢力非隸屬關係（完成）

- settings store 升級至 V10，新增 `PowerRelation`；同盟、敵對、競爭、貿易與臨時合作為對稱關係，宗主／附庸以宗主→附庸保存，不含時間序。
- UI 沒有採用探索 mockup 的視覺；正式畫面依現有 `PowerDetailView` 的灰底區塊、caption、borderless 按鈕、plain 移除圖示、原生 sheet 與 alert 適配。既有 `relationshipNotes` 原文保留。
- Store 阻止跨書、自連結與同類型重複；刪除勢力／整書與 reconcile 清理非法關係，不改變直屬隸屬或前身／後繼。
- V9→V10 檔案型遷移測試確認勢力 UUID 與自由文字保留、新關係初始為空；V5SettingsTests 45 項通過，完整回歸 135 項通過。
- 唯一下一步：以實際 App 人工驗收勢力詳情的新增關係 sheet、宗主／附庸視角及小視窗排版。

## V5.5 勢力生命週期與成員時間序（完成）

- 勢力詳細頁新增存在狀態、生命週期事件、前身／後繼承接；事件與承接均可沿用共用時間定位選擇器設定世界日期與節次。
- 成員新增現任／前任、加入／離開定位；每位成員可有多筆職務，每筆可標示領導職位、任職／卸任定位及現任／前任／代理／繼任／遭罷免。
- settings store 新增 `PowerLifecycleEvent`、`PowerSuccessionLink`、`PowerMemberRole`，正式升級為 V9。V8 snapshot 保持 V5.4 原結構，V8→V9 自訂遷移會把舊單一職稱回填為第一筆職務。
- 已修正真實 V8 store 載入失敗：根因是 V5.5 曾在同一 V8 版本號下改動 schema。新增檔案型 V8→V9 測試，驗證勢力、舊稱、成員與職稱均保留。
- 刪除勢力、成員或整書會清理附屬資料；啟動修復會清除已不存在 Node 的 UUID 定位但保留原始內容。
- 驗證：V5SettingsTests 43 項與完整 macOS XCTest 132 項通過；frontend parse 與 `git diff --check` 通過。

## V5.4 勢力別名與資源／能力識別（實作與驗證中）

- 已新增 V5SettingsSchemaV8：PowerUnit 保存 `formerNames`、`foreignNames`、`shortName`；PowerAssetLink 以 UUID 連接資源、技術、物品或能力；PowerAdvantage 保存軍事／經濟優勢的名稱與說明。
- 資源／技術必須為同書且正確 WorldTerm 分類；物品／能力候選由 UI 限定同書，啟動修復以主 store 現存 UUID 清掉已刪來源。刪除世界條目、勢力與整書同時清理附屬資料。
- 詳細頁已加入識別、掌握的資源與能力、軍事與經濟優勢區塊。沒有獨立軍經模型，因此優勢是作者命名記錄，沒有假裝成跨模組連結。
- 已新增 Store 回歸測試；frontend parse 與 `git diff --check` 通過。改在主機環境使用隔離 DerivedData 後，V5SettingsTests 40 項與完整 macOS XCTest 129 項全數通過。
- 本工作單自動驗證完成；人工 UI 冒煙可與既有 V5 預設驗收一併進行，範圍是四類連接、別名與兩類優勢的新增／刪除／重開。

## V5.2 追加修正：勢力條目連接限制（實作完成，待人工 UI 冒煙）

- 使用者校正「權力」為誤植，正確欄位是「核心」；核心是勢力實際控管的核心區域，範圍是輻射區域，未來改連接地點／地圖。
- 目前只有宗教與政體連接 WorldTerm，且宗教只接受「信仰」、政體只接受「制度」；核心／範圍不提供世界條目選擇。
- 既有 `powerWorldTermID`／`scopeWorldTermID` 欄位保留作相容性，未做 schema migration；V5SettingsTests 38 項與完整 127 項 XCTest 通過，仍待人工 UI 驗證後關閉本追加修正。

## V5.3.4 世界條目預設：族群／種族與移除獨立語言分類（實作完成，待人工 UI 冒煙）

- 使用者改變方向：V5.3.4 不再建立獨立的「語言」預設，而改為「族群／種族」；語言只作為共同模板的其中一段，並從新建分類選項移除，以減少語言專屬細項。
- 使用者希望減少虛構項目、增加現實族群；草案目前建議 12 套現實族群／文化群體（漢人、大和／和人、斯拉夫、日耳曼、蒙古、印度次大陸、阿拉伯、波斯、突厥語族、西非曼德、東非斯瓦希里、南島海洋）與 6 套虛構種族（精靈、矮人、獸人、龍裔、海族、亡靈族）。
- 共同模板改為族群定位、身體與生命週期、棲地與適應、成員延續、社會與文化、語言溝通、技術資源、跨族群關係等十二段；不把語言細分成獨立音系／詞典／文法模板。
- 現實預設描述歷史形成、文化實踐與內部差異，不把民族、國籍、語言或外貌硬套成生物本質；虛構預設只提供原創類型骨架。模板不假設作者劇情，也不替作者決定角色衝突。
- R 已批准：使用者於 2026-09-17 回覆「可」，確認 12 套現實族群／文化群體、6 套虛構種族與十二段共同模板。
- U 已批准：使用者於 2026-09-17 回覆「U」，確認沿用資源／技術的可關閉雙欄選擇器，左欄分現實／虛構，右欄預覽 12 段內容；套用後唯讀，普通條目仍可編輯。
- I 已批准：使用者於 2026-09-17 回覆「I」，同意新增 12 套現實族群／文化群體與 6 套虛構種族、分類入口、穩定目錄 ID／既有文字欄位映射、測試與隔離資料 UI 冒煙；後續確認移除獨立語言分類，但保留既有語言字串作舊自由分類。
- 已完成 `PeoplePreset`、族群／種族分類入口、現實／虛構雙欄選擇器、套用／唯讀分流與 3 項回歸測試；未修改 schema、migration 或正式作者資料。
- 驗證結果：移除語言分類後重新完成 frontend parse、`git diff --check`、V5SettingsTests 38 項與完整 127 項 macOS XCTest；人工 UI 冒煙尚待執行（本次 AX 讀取逾時，尚未取得可靠畫面驗證）。
- 唯一下一步：以隔離資料驗收族群／種族分組瀏覽、關閉、套用、重開唯讀，以及普通條目仍可編輯。

## V5.3.3 世界條目預設：資源（實作完成，待人工 UI 冒煙）

- 使用者指定下一版加入主要金屬礦物、非金屬礦物、農林漁牧產、人口與合成物。
- 使用者已補充：每一個選定資源項目都要各自套用完整模板；已整理 39 套代表項目，依主要金屬礦物、主要非金屬礦物、農林漁牧產、人口、合成物五類分組。
- 人口模板以人口結構、勞動、知識、消費、照護與遷徙能力描述，不把人當作商品或可買賣資源。
- R／U／I 均已批准：使用者回覆「繼續」，同意 39 項依五類分組的雙欄選擇器與獨立模板實作；煤炭、石油與天然氣暫留待未來能源類別。
- 已完成 `ResourcePreset`、資源分類入口、唯讀比對與 39 項目錄／保存測試；不修改 schema、migration 或作者資料。
- 驗證結果：frontend parse、`git diff --check`、V5SettingsTests 34 項與完整 124 項 macOS XCTest 通過；測試使用無簽章 Debug 設定及隔離 DerivedData。
- 唯一下一步：以隔離資料人工驗收五類分組瀏覽、選擇、重開唯讀與普通資源條目編輯。

## V5.3.2 追加需求：人類現實社會的技術階段（實作中）

- 使用者要求在既有五套虛構技術階段之外，加入人類現實社會的主要技術階段。
- 已建立需求草案：狩獵採集、農業新石器、青銅、鐵器、前工業、工業、電氣化與大量生產、資訊與網路、智慧科技九套獨立唯讀模板。
- 草案明確避免線性進步論；每套以代表性案例、年代與地域作固定參考，沿用技術預設的十二段內容與同一選擇器。
- 使用者回覆「去吧」，R／U／I 均批准：採用九套清單，智慧科技獨立，並在既有選擇器中分成現實歷史／虛構兩組。
- 實作範圍：擴充 `TechnologyPreset` 至十四套、更新技術目錄分組、保留既有欄位映射與普通技術條目編輯行為；不修改 schema、migration 或正式作者資料。
- 已完成九套現實歷史模板、兩組選擇器分組與測試；不修改 schema、migration 或正式作者資料。
- 驗證結果：frontend parse、`git diff --check`、V5SettingsTests 32 項與完整 122 項 macOS XCTest 通過；測試使用無簽章 Debug 設定及隔離 DerivedData。
- 唯一下一步：以隔離資料人工驗收現實／虛構兩組瀏覽、套用、重開唯讀與普通技術條目編輯。

## V5.3.2 世界條目預設：虛構技術階段（實作完成，待人工 UI 冒煙）

- 使用者指定 V5.3.2，要求在「技術」分類新增蒸汽朋克、鋼鐵朋克、廢土、太空時代與修仙五套內建唯讀預設，且互動／資料邏輯與政體、信仰一致。
- 使用者明確指定五套皆為虛構類型，可參考主流小說建立。內容應為原創的類型骨架，不重製來源小說的角色、地名、情節、台詞或段落。
- 使用者已回覆「可」，R 已批准：固定參考為《差分機》、《移動城市》、《長路》、《蒼穹浩瀚：利維坦覺醒》與《凡人修仙傳》；鋼鐵朋克定義為重工業鋼鐵機械類型，並與其他四項一律歸入既有技術分類。
- 使用者已回覆「繼續」，U 已批准：技術分類出現「選擇並套用技術階段」，以既有可關閉雙欄目錄瀏覽五項並套用；套用後唯讀，其他分類與普通技術條目不變。
- 使用者再回覆「繼續」，I 已批准。已完成 `TechnologyPreset` 目錄與視圖、技術分類入口、五套目錄／套用／唯讀與普通技術條目可編輯測試；不新增 schema、migration 或資料關係。
- 已修改 `Sailune/TechnologyPresets.swift`、`Sailune/V5SettingViews.swift` 與 `SailuneTests/V5SettingsTests.swift`；正式作者資料未使用。
- 驗證結果：frontend parse、`git diff --check`、V5SettingsTests 31 項與完整 121 項 macOS XCTest 通過；無簽章 Debug 測試建置使用隔離的 `/private/tmp/sailune-v532-technology-tests` DerivedData。
- 唯一下一步：以隔離資料人工驗收技術選擇器的五項瀏覽、關閉、套用、重開唯讀，以及普通技術條目仍可編輯；同時回看 V5.3.1 的既有人工冒煙待辦。

## V5.3.1 世界條目預設：信仰

- 使用者要求新增內建信仰預設：基督教、猶太教、伊斯蘭教、道教、佛教、祆教、科學，以及兩套「邪教」方向的預設。
- 使用者已確認：科學屬於信仰（人所相信、寄託的事物），維持「科學」名稱並放在世界條目的信仰分類；整體完全沿用 V5.3 政體的固定真實案例、固定年代、作者只選擇／套用、套用後完全唯讀的模式。
- 使用者已同意兩個原稱「邪教」的方向採描述性名稱「高控制團體」與「末世型新興宗教運動」；兩者是不同敘事模型，不作為其他少數信仰的籠統稱呼。
- 使用者已確認九套固定案例／年代、12 段共同資料骨架，以及勢力直接沿用既有「宗教」世界條目連接欄。
- R／U／I 均已批准並完成實作。UI 與制度政體一致：選擇「信仰」後出現套用入口、雙欄目錄可關閉、套用後唯讀；未套用的普通信仰世界條目仍使用既有編輯頁。
- 新增 `Sailune/BeliefPresets.swift`：九套固定目錄、穩定 UUID、12 段內容、套用／比對與選擇器／詳情；`V5SettingViews.swift` 新增信仰入口及唯讀分流；`V5SettingsTests.swift` 新增目錄、科學不適用段落、勢力宗教連接與刪除清理測試。
- 沒有 schema、migration 或資料關係修改；正式作者資料未用於測試。
- 驗證：Swift frontend parse、`git diff --check`、V5SettingsTests 29 項及完整 119 項 macOS XCTest 通過；測試使用無簽章 Debug 設定與 `/private/tmp` 隔離 DerivedData。沙盒內 Xcode macro service 失敗，已在主機環境重跑通過。
- 唯一下一步：以隔離書籍人工驗收信仰選擇器的關閉、九項瀏覽、套用、重開唯讀、勢力宗教選擇與清除；驗收通過後關閉 V5.3.1。

## V5.3 世界條目預設：政體需求草案

- 使用者要求從政體開始建立世界條目預設，首批為民主、共產、威權、法西斯、帝制、聯邦制、共和制、殖民，並要求依現實提供模板選擇。
- 已建立 R 草案，尚未批准，未修改功能程式。
- 現實分類校正：八項並非互斥維度；第一版建議作為可獨立建立、可並存的起始模板，例如同一世界可同時建立民主、共和制與聯邦制條目。
- 「殖民」建議顯示為「殖民統治」；「共產」以共產主義國家／黨國制度的歷史實務作為內容參考，但不把政治理念直接等同唯一制度形式。
- 建議所有模板建立為一般「制度」類 WorldTerm，只預填可編輯的中性內容骨架，不綁定真實國家、不修改既有條目，也不新增 schema。
- 待確認：殖民模板名稱、採完整示例或問題骨架、以及接受八類可並存的產品語意。
- 唯一下一步：由使用者確認或修正 V5.3 R 草案；R 未批准前不進入 UI 或實作。
- 使用者進一步校正：政體模板需要先統一現實政體的最大公因數項目，例如最高領導人、最高行政機關與最高立法機關，再由各模板把答案預填進世界條目。
- 已依現實憲政結構整理六組共 31 項資料字典：基本定位與正當性、最高領導職位、中央國家機關、權力運作規則、領土與被統治者、寫作運用。
- 建議第一版不要新增 31 個 schema 欄位，而是將固定小標題映射到既有簡介、核心定義、運作與表現、限制／差異／例外、世界影響、使用範例及作者備註；個別模板提供典型答案與可替換提示。
- 使用者決定 V5.3 先不提供使用者自設模板，只能使用系統內建模板，以節省畫面與資料設計空間；自訂模板待未來有更好的設計後另行加入。
- 使用者再次校正：不只模板定義不可修改，也不建立可自由修改的世界條目副本。V5.3 使用者只選政體，所有共同條目、典型內容與政體特色皆由系統預設並唯讀顯示。
- 需求方向已改為「內建政體目錄」：使用者資料只保存穩定政體 ID；每個政體依同一組最大公因數項目顯示，最下方再補該政體專屬特色。自訂政體與作者補充留待未來版本。
- 使用者要求每個政體選定一個最經典的真實國家案例，不呈現模糊地帶。已提出固定案例與年代：民主＝英國西敏制（2011 內閣手冊基線）、共產＝1977 蘇聯、威權＝1967 後佛朗哥西班牙、法西斯＝1939～1943 墨索里尼義大利、帝制＝乾隆清帝國、聯邦制＝1992 後美國憲政架構、共和制＝1962 後法蘭西第五共和、殖民統治＝1935～1947 英屬印度。
- 每套模板只依單一案例填滿共同項目，不列其他常見形式；顯示參考國家與制度年代，但不保存當時個人姓名。
- 使用者明確要求「進入實作」後，已新增八套固定 UUID 的唯讀政體目錄；每套含參考案例、年代、摘要與 16 個同序制度區段。
- 使用者校正流程：選擇器需可關閉、世界條目仍可新增，且新增條目選擇「制度」後才顯示政體選擇與套用。已移除獨立瀏覽入口與勢力直接選內建政體流程。
- 套用把固定內容保存至該 WorldTerm，匹配內建內容時改用唯讀詳情；勢力維持既有 WorldTerm 連接。選擇器新增「關閉」。
- 兩項測試覆蓋八套內容完整性及套用後保存／勢力連接；修正後 V5SettingsTests 27 項通過。
- `git diff --check` 與四個受影響 Swift 檔案的 frontend parse 通過。
- 唯一下一步：人工驗收世界條目的政體目錄，以及勢力政體選擇、保存重開與清除流程。

## V5.2.2 世界條目內容結構規劃

- 使用者要求接續規劃世界條目內容，並校正「制度」應指政體等制度性架構，通常不會具體為法令。
- R 已確認：現有詳細說明沿用為核心定義，新增運作與表現、限制／差異／例外、世界影響三個可空欄位；七項分類只提供不同引導，不強迫全部填寫。
- 具體法令原則上放在制度內容；只有具獨立名稱、反覆出現或需單獨引用時才另建條目。
- U 已確認：沿用目前單欄可捲動 sheet，順序為辨識資料、核心定義、運作、限制／差異／例外、世界影響、使用範例、作者備註；分類只切換說明文字，不切換欄位或內容。
- I 已由使用者於 2026-09-17 回覆「繼續」批准；`V5SettingsSchemaV7`、三個可空 WorldTerm 欄位、分類提示、名稱焦點及保存成功才關閉的流程均已完成。
- V6→V7 採 lightweight migration；既有 `detailedDescription` 完整保留為核心定義，不拆分或猜測作者內容，三個新欄位初始為空。
- 驗證：V5SettingsTests 25 項及完整 115 項 XCTest、無簽章 Debug build、frontend parse 與 `git diff --check` 通過。畫面擷取工具曾逾時，尚待使用者以最新建置人工確認新增、提示切換、保存重開與小視窗捲動。
- 唯一下一步：人工驗收 V5.2.2 世界條目編輯 sheet；若通過，關閉 V5.2.1／V5.2.2 工作單與交接。

## V5.2.1 世界條目預設入口

- 2026-09-17 使用者要求先準備世界條目，最低範圍是讓入口出現。
- 已核對目前程式：世界條目清單、搜尋、七項分類、新增與詳細編輯均已存在；入口由每書 `BookSidebarSetting` 控制，但 `.worldTerm` 在 V5.2 是預設隱藏的可選項目。
- 使用者已確認 R／U：世界條目改為預設顯示，排列於勢力與物品之間；新書直接顯示，既有書籍升級時顯示一次，之後作者仍可再次隱藏；地點維持預設隱藏。
- 本輪不新增欄位、分類、條目內容、關聯或正文連結，也不建立示例資料。
- 使用者已批准 I，並確認以 settings schema V6 保存每書側邊欄目錄版本。
- 已完成：世界條目改為預設顯示並排列於勢力與物品之間；地點維持預設隱藏；管理設定集文案與重設預設順序同步更新。
- 使用者指出實際畫面無法加入條目；查證新增動作原本只放在巢狀 `WorldTermListView` 的 `.toolbar`，該容器不保證顯示工具列項目。已改為在分類篩選旁固定顯示「新增條目」，空狀態文案也指向同一入口。
- `V5SettingsSchemaV6` 只在 `BookSidebarSetting` 新增 `catalogRevision`。V5→V6 lightweight migration 後，舊配置只顯示世界條目一次並寫入版本；作者再次隱藏後不會反覆打開，WorldTerm 資料不修改。
- 驗證：2026-09-17 V5SettingsTests 22 項及完整 112 項 XCTest 通過，包含檔案型 V5→V6 遷移、一次性顯示、再次隱藏與 WorldTerm UUID 保留；無簽章 Debug build、frontend parse、`git diff --check` 通過。
- 人工 UI 冒煙尚未執行；正式作者資料未用於測試。
- 唯一下一步：由使用者以最新建置確認設定集顯示「角色、勢力、世界條目、物品、能力、標籤」，並測試隱藏世界條目後重新開啟仍保持隱藏。

## V5.2 下一工作單需求草案

- 2026-09-16 使用者逐項完成 V5.2 R 需求確認，並兩次以「繼續」分別批准修正後的 U 與 I；settings schema V5、世界條目 UUID、角色成員跨 store 清理與 UI 已進入實作與驗證。
- 已確認唯一新增關係流程為：先指定層級，再由獨立的「選擇直屬上級」入口新增；現行上／下級列表改為查詢用途，不提供新增下級。
- 已確認解除直屬關係的入口放在上級列表，只移除對應連線。
- 已確認宗教、政體、權力與範圍各直接連接一筆世界條目；勢力沒有「分類」欄位，也不另建勢力分類選項。
- 已確認成員連接既有角色、職稱由作者自由輸入；同一角色在同一勢力先只保存一筆成員資料。刪除角色或世界條目時解除連接，不刪除勢力。
- 已確認上／下級列表只查詢直接關係。
- 參考手繪圖只用來說明勢力候選篩選時的呈現概念，不實作關係圖、表格或自由畫布。
- 完整範圍、非目標、驗收條件與待確認事項見 `docs/spec-power-v5.2.md`；V5.1 仍維持原驗證狀態。
- V5.2 已新增 settings schema V5、四個世界條目 UUID 欄位、目的文字與 `PowerMember`；勢力頁只保留「選擇直屬上級」作為新增關係入口，下級列表唯讀，上級逐筆解除。
- 角色刪除已納入跨 store 成員清理，啟動時會修復孤立或跨書連結；既有自由文字欄位未轉換或覆蓋。
- 2026-09-16 驗證：frontend parse、`git diff --check`、無簽章 Debug build 通過；V5SettingsTests 21 項全部通過。

> 狀態：historical_checkpoint
>
> 更新日期：2026-09-15
>
> 工作單元：V5.1 地點與世界條目第一階段完善
>
> 目前階段：implementation／verification

## 本輪進度

- V5.1 階段 A 已完成：設定集 schema 從 V3 升級至 V4，Place／WorldTerm 保留既有 UUID、`bookID`、名稱、簡介與排序，新增其他名稱、類型／分類、詳細內容、使用範例與備註欄位。
- 地點與世界條目清單已改為搜尋／列表 → 詳細編輯頁；支援新增、編輯、刪除、搜尋與每書隔離，沒有加入階層、互聯或跨模組連結。
- 已新增 V3→V4 檔案型遷移測試與欄位／搜尋／刪除／每書隔離測試；原始碼目前共有 106 個 XCTest 方法。
- 外部 Xcode 驗證：完整 Debug `xcodebuild test` 通過；無簽章 Release `xcodebuild build` 通過。沙盒內的早期測試曾受 Swift macro plugin 與 CoreSimulator 權限限制，並非程式錯誤。
- 最後一輪另以檔案型 settings store 重開後驗證 16 項 V5 settings tests；最新 Release build 使用同一份修正版 source 成功。

- 已閱讀專案協作規則、目前狀態、工作單、既有交接、資料模型、設定集程式與目前側邊欄畫面。
- 確認現行設定集畫面固定顯示「角色／能力／物品／標籤」；組織目前不是獨立設定集分頁，而是角色詳情內的組織區塊。
- 使用者確認 V5 納入勢力與其他設定集，並新增每本書可自選側邊欄設定項目的需求。
- 使用者進一步確認組織與陣營要整合、分類為同一個「勢力」上層設定集；標籤也納入同一套可自由選擇的顯示配置。
- 先前曾誤把使用者的「可」解讀為 UI 確認；經重新確認細節後，使用者已明確確認 UI，並於 2026-09-14 回覆「計劃正確」，I 已批准開始實作。
- 已將需求整理到 `docs/work-items/current.md`，並完成 V5 功能程式、schema、清理、測試與相關規格更新。
- 使用者追加並確認：層級由每本書自訂名稱與順序；勢力必須先指定具體層級，才能選擇上／下級；允許跨級直接隸屬；修改勢力層級若會使既有關係失效，必須阻止而不能自動刪除。
- 使用者在新版層級 UI 提案後回覆「繼續」批准 U，並在修訂版 I 計畫後再次回覆「繼續」批准實作。
- 第一輪先完成 `V5SettingsSchemaV2`、V1→V2 遷移、自訂層級規則與先分級再建立關係的 UI；收到需求校正後再升級 V3，保留 V2 作為遷移快照。
- 使用者指出兩項需求落差：應預設兩個層級，且勢力原始項目不可被收斂刪除。已新增 settings schema V3：首次配置建立「層級 1／層級 2」，並恢復高層管理員、其他名單（職稱／人名）、勢力關係、政治、宗教自由文字；簡介與上下隸屬維持。
- V1→V3 與 V2→V3 檔案型遷移測試已通過：既有自訂層級不被覆寫，新增欄位可保存。
- 已依使用者要求建立 `docs/spec-places-world-terms.md`，保存地點與世界條目的後續專案討論；本輪只完成已批准的階段 A，階段 B～D 仍標為建議或待確認。
- 隔離 UI 冒煙曾發現層級衝突同時出現局部與全域兩個警示；已改為由當前操作畫面呈現領域錯誤，並新增回歸測試確認不設定全域 persistence error。

## 世界條目內容查核

- 已重新搜尋專案文件、測試、Git 歷史與 `DatabaseBackups`；目前沒有可確認的正式小說世界觀條目來源。
- 舊版 V4／V5 settings store 沒有 `Place` 或 `WorldTerm` 資料表；可查到的敘事與設定資料也只有空白／佔位資料，不能直接轉寫成世界條目。
- 另查目前 macOS 上的 `Sailune-v5.store`：只有一筆「角色詳情修正驗證」測試書資料，主 store 沒有 `WorldTerm` 表；新版獨立 settings store 目前尚未產生。
- `docs/prd-v4.2-outline.md` 裡的「魔法世界、巫師、黑魔王」是產品示例；測試裡的「月曆／一年十三月」是測試 fixture，均暫不視為正史。
- 本輪沒有新增或改寫任何作者設定資料，也沒有把上述示例寫入世界條目。

## 世界條目分類追加需求

- 使用者已提供並確認世界條目優先方向：WorldTerm 不做無限制 OtherSetting，分類限定為「制度、信仰、技術、資源、語言、文化習俗、專有名詞」。
- 「種族／血統」保留為未來每本書可選的獨立模組；完整地圖、宗教系統、貨幣與經濟系統、語言系統、科技樹及泛用設定模型暫緩。
- 已將 `WorldTermCategory` 加入程式，編輯 UI 改用有限分類選單，列表加入分類篩選；V4 既有自由文字分類仍以原字串保留，未對應值顯示為「既有分類」，不執行猜測式遷移。
- 已同步更新世界條目規格、資料模型、遷移說明、功能清單、一致性稽核、變更紀錄與工作單；本輪新增有限分類與舊分類不猜測測試，目前 V5SettingsTests 共 18 項。

## 已決定

- 側邊欄配置以每本書為單位，不同作品可有不同設定集組合。
- 預設顯示是新書的初始配置，作者可以移除預設項目。
- 隱藏設定只改變導航顯示，不刪除設定資料，也不應破壞正文右鍵導覽。
- 組織與陣營在側邊欄採「勢力」上層分類；標籤納入可加入、移除與排序的設定集項目。
- 使用者確認 V5 第一版界線：可配置設定集、單一勢力系統、標籤配置，以及地點／世界條目的基礎設定；地圖與專門世界系統延後。
- 使用者釐清勢力模型：第一版以單一勢力節點取代陣營／組織；等級只表示上下隸屬方向，不代表數值或重要性。
- 勢力可有多個上層與下層，隸屬以直接連線保存；聯盟先作為上層勢力節點，不另建同盟關係型別。
- 每本書擁有自己的具名有序層級；每個勢力先指定一個層級，才可建立關係。
- 允許跨級直接隸屬，不要求上下層相鄰；上級層級只需高於下級。
- 修改勢力層級若造成既有關係不合法，阻止修改並保留全部關係。
- 既有 Organization、角色—組織關聯與組織身分歷史不遷移；V5 實作時完整清除舊資料與關聯，保留角色、正文與共用 Node。
- 使用者確認 V5 第一版完全不連結角色、物品、能力、地點、事件或正文。
- 使用者確認 V5 第一版不保存勢力改變上層的歷史，只保存目前直接隸屬結構。
- 政治、宗教等分類先不固定。
- 本工作版本為 V5，不是 V6。
- 本輪 U 草案改為單一勢力入口：列表與詳情只處理名稱、簡介、直屬上層與直屬下層；不顯示組織／陣營子分類，也不顯示外部連結。
- 原版與新增層級流程的 R／U／I 均已確認並完成實作；目前只待使用者以最新建置做最終 UI 驗收。

## 暫時假設

- 建議新書預設顯示角色、勢力、物品、能力、標籤。
- 建議地點、世界條目／專有名詞先列為可自選添加；種族／血統及其他專門模型待具體需求。
- 標籤雖保留寫作／規劃用途，但納入同一套側邊欄顯示配置。
- V5 不包含地圖、宗教、經濟、語言、科技樹、種族／血統完整系統、泛用其他設定模型或完整正文穩定連結。
- 配置可由主 store 的獨立書籍配置模型保存，設定項目使用穩定識別碼，不依顯示名稱或排序位置識別。
- schema、模型、刪除規則與實作方向已依 I 計畫完成，並以測試驗證資料安全性。
- 層級管理由高至低排序；已使用層級不可刪除，重新排序若會使既有隸屬失效則阻止。新版 UI 已確認。
- 已修正採用：新書預設兩個中性名稱「層級 1／層級 2」，不預設聯盟／國家等世界觀名稱；同一本書層級名稱不可空白或不分大小寫重複。

## 待確認

- 功能與自動驗證已完成；待使用者最終 UI 驗收。

## 工作樹邊界

- 本輪層級增補只修改 V5 settings schema、勢力模型／UI、測試及相關文件；工作樹中其他既有修改均保留。
- 工作樹原有的時間序投影實作、測試與文件修改均屬前一工作及既有工作，不在本輪回復或重做。

## 驗證

- 2026-09-14 啟動故障追查：正式 `Sailune-v5-settings.store` 是先前多 configuration 實驗留下的 32 entity 空庫；逐表查詢確認所有使用者資料為 0。已將該檔及 WAL／SHM 完整移至同目錄 `V5SettingsEmptyBackup-20260914`，沒有刪除其他 store。下次正式啟動會建立正確 5 entity settings store；實際重啟尚待確認。
- `SailuneApp.storeURL` 已隔離 hosted XCTest 的 App.init，避免測試啟動讀寫正式資料。

- 已用程式與實際 Sailune 畫面核對目前設定集入口及側邊欄狀態。
- 主 store 維持 `NovelWriterSchemaV5`；設定集／勢力／地點／世界條目使用獨立 `V5SettingsSchemaV4` store 與 V1→V2→V3→V4 migration plan。檔案型測試驗證舊設定保留、V3→V4 新欄位安全加入，並驗證舊主 store 重開後核心 UUID 與正文內容不變。
- 已修正勢力清單刪除遺留隸屬連線，以及隱藏目前選中設定集後仍顯示原內容的問題；舊組織編輯 UI 與未使用查詢已移除。
- 隔離 UI 書籍已驗證：建立「聯盟／國家／地方組織」層級、未分級提示、方向候選、跨級「地方組織 → 聯盟」與衝突改層阻止。正式作者資料未用於測試。
- 修正版隔離 UI 再驗證：新書顯示角色、勢力、物品、能力、標籤；層級管理立即有「層級 1／層級 2」；新勢力詳情可見簡介、高層管理員、其他名單、勢力關係、政治、宗教、層級與隸屬流程。
- 修正後 V5 settings 專項 16 項、完整 XCTest 106 項全數通過，最新無簽章 Release build 成功。
- 收尾檢查：四個受影響 Swift 檔案 frontend parse 通過，`git diff --check` 通過；正式作者資料未用於測試。

## 唯一下一步

完成本輪有限分類測試與建置驗證，再由使用者驗收世界條目分類選單；不寫入杜撰的作者世界觀內容。

## 本輪驗證

- `swiftc -frontend -parse` 已通過 `V5SettingModels.swift`、`V5SettingViews.swift`、`V5SettingsTests.swift`；`git diff --check` 通過。
- Debug `xcodebuild test` 與 Release `xcodebuild build` 均受 Xcode 的 SwiftData／Observation macro plugin malformed response 影響，未完成模組編譯；尚不能宣稱本輪測試或建置通過。

## 前一工作單元（已關閉）

## 已決定

- 人物等時間序資料有時間戳記時，依時間戳記出現在世界時間軸。
- 有具體正文位置時，依節次出現在敘事大綱。
- 兩種定位都有時，同一來源同時出現在兩個視圖。
- 產品流程保證至少有一種定位，本工作忽略兩者皆無。
- 世界實際時間與正文揭露位置維持不同投影，不互相推算。
- 人物等原始時間序資料是唯一內容來源；時間軸與敘事大綱只保存必要投影／關聯，內容與定位自動同步，不建立可分歧副本。
- 設定具體正文位置時由作者選擇故事線，不由系統猜測；主線可選階段，未選則進入「未分階段」。節次決定橫向位置，故事線／階段決定泳道。
- 第一版涵蓋現有所有時間序來源；投影卡片顯示類型、相關名稱與原始內容摘要，編輯時回到原設定。
- 具體正文位置不是必填；沒有位置時不加入敘事大綱，也不因此刪除原始時間序資料。若另有時間戳記，仍可只出現在世界時間軸。
- 敘事大綱只依有效節次投影，不使用節內文字錨點、offset、草稿降級或待安置。
- 移除日期／節次只移除對應投影，來源與另一種投影保留；刪除來源才讓所有投影消失。
- Node 現有的「顯示於時間軸」開關改視為規劃投影總開關；關閉後世界時間軸與敘事大綱都不映射，來源與定位保留，重新開啟後依當前定位恢復。

## 已查證

- `Node` 是多種人物／設定歷史共用的時間定位，包含世界日期並可關聯 `Section`。
- 世界時間軸目前以 `Event` 為主要內容；敘事大綱位於獨立 store，以 `OutlineItem` 為內容。
- `TimelineEventCardMetadata` 已能以 UUID 連結 Event 與單一 OutlineItem，但未涵蓋人物等時間序來源，也未定義完整同步語意。
- `CharacterNodePicker` 編輯的是共用 Node：世界日期與節次可獨立留白，主 store 來源直接關聯 Node，AbilityProgress／ItemCopy 等獨立 store 保存 `nodeID`。
- 同一 Node 可供多筆來源使用，因此故事線／階段歸屬必須記在來源層級，不能放在 Node。

## 已決定（續）

- 節次暫時移除時保留來源層級的故事線／階段歸屬，重新指定節次後回到原泳道。
- 刪除與設定編輯沿用現有行為，不在本工作新增跨 store 全域 Undo／Redo。
- R 已於 2026-09-14 由使用者確認。
- U 已於 2026-09-14 由使用者確認。
- I 已於 2026-09-14 由使用者回覆「確認」批准；可開始功能、schema 與測試修改。

## 待確認

- 無產品決策待確認；實作若發現需改變既定需求或 UI，應停止並退回相應關卡。

## 工作樹邊界

- 接手時 `main`、HEAD `4ed99bf`；工作樹已有前一輪全專案文件稽核留下的多份 `docs/` 修改，均保留。
- 本工作新增 `PlanningRecordProjection.swift`，並修改 StoryPlanning schema/store、定位 UI、兩個規劃視圖、來源導覽與測試；先前文件稽核修改仍保留且未回復。V5 另新增設定集／勢力模型、UI、清理流程與測試。
- 實作過程只唯讀檢視作者現有資料；未建立、刪除或改寫作者資料。

## 驗證

- 已唯讀核對 Event、Node、人物／設定歷史模型、世界時間軸與敘事大綱規格。
- 已實際檢視目前角色設定、敘事大綱及世界時間軸；只做導覽，未修改使用者資料。
- 完整 macOS XCTest：90 項通過。
- `V42OutlineTests`：51 項通過，包含 V6→V7 遷移、metadata 冪等／清理及日期／節次／總開關投影矩陣。
- Debug build 與無簽章 Release build 均成功；`git diff --check` 通過。
- 已以 `/tmp` 隔離測試資料完成代表性人物外觀紀錄的人工 UI 冒煙：定位表單會依欄位顯示投影結果，日期＋節次可同時投影至世界時間軸與敘事大綱，兩種卡片均顯示來源摘要。
- 已人工確認投影卡片可返回原角色的外觀設定；關閉「顯示於規劃視圖」後，世界時間軸與敘事大綱的投影同時消失，來源資料、日期與節次定位仍保留。
- 所有來源類型的投影組裝與導覽目標由自動測試覆蓋；人工冒煙採代表性來源，不逐一建立八類測試資料。

## 唯一下一步

V4.4.81 無待辦；下一個工作單可處理專案狀態列出的 V4.4.9 右鍵選單冒煙或後續產品項目。

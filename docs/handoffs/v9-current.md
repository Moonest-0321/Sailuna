# V9 工程規則化交接

## 2026-09-25 文件規則整理檢查點

- 已完成純文件工作單 `docs/work-items/code-rules-operational-docs-2026-09-25.md`。
- 程式規範補上 View／Store／Coordinator 邊界、非同步 action、已核定產品錯誤政策優先及固定盤點範圍規則；開發流程新增階段 4a 的搜尋、契約、行為保留、例外紀錄與驗收步驟。
- `AGENTS.md` 加上重用檢索及責任邊界入口；`docs/testing.md` 說明 Store action 驗收與純文件工作的驗證範圍。
- V9 仍依使用者指示暫停；此文件更新未修改產品程式、ledger、快照或 V10 的 current work item／handoff，未執行 build／XCTest。
- 文件檢查：`git diff --check` 通過。
- 下一步：無此文件工作待辦；恢復 V9 時依 `docs/handoffs/v9-pause-checkpoint-2026-09-25.md` 的單一續接點繼續，除非使用者另行安排功能工作。

> 狀態：paused（使用者優先投入功能增加與穩固；V9 清單和未提交工作樹保留）
>
> 暫緩前 V9 續接起點：見 `docs/handoffs/v9-pause-checkpoint-2026-09-25.md`。恢復後先核對五個 help ActionCopy 改動並建置，再按凍結清單完成剩餘項目。

## 已決定

- V9 涵蓋內部程式責任與可維護性、UI 控制與互動規則、按鈕／欄位／編輯器／色彩共用、相同操作的圖標和文字資源。
- 使用者同意以 `AppearanceRow` 作 V9.1 第一個可見畫面試行；深色截圖已完成現況核對，R／U／I 均已批准。刪除圖標緊鄰 Picker、原文字與資料綁定維持，共用刪除控制採 28 × 28 pt 並提供「刪除外觀」提示；只批准此列的接線。
- V9.1a 為不接入畫面的共用基礎工作：語意圖標、通用文案鍵、尺寸／色彩 tokens，以及 `InsetTextEditor`／`PlanningActionStyle` 宣告歸位。這批不更動原有 View 呼叫點或資料流程。
- V9.1b 已把六個功能 View 檔的 24 處相同低對比背景色集中為 `SailuneTheme.subtleSurface`，保持原有色值、形狀與操作。
- V9.1c 已將跨功能使用的搜尋欄位從 `InspectorViews.swift` 移入 `SharedUI`，七個呼叫點統一改用 `SailuneSearchField`；圖標與底色改由集中語意資源提供，原值不變。
- V9.1d 已讓 33 個資料刪除、1 個移除持有人及 1 個移除封面的既有圖標呼叫集中使用 `SailuneSymbol`；其後 `AppearanceRow` 的刪除圖標也依批准的試行接入 `.delete`，原圖形均未改。
- V9.1e 已讓 48 個取消、10 個儲存按鈕引用 `SailuneActionCopy`；兩個原帶儲存圖標的按鈕改用 `.save` 語意 key，原圖形與中文值不變。
- V9.1f 已讓 47 個刪除／新增／關閉 Button 或 Label 呼叫點引用 `SailuneActionCopy`；三個既有圖標改由語意表提供，原值不變。
- V9.1g 已讓 33 個新增圖標與 1 個地圖放大圖標分別引用 `.add`／`.zoomIn`；原 `plus` 字形不變。
- V9.1h 已讓 12 個 `xmark` 圖標呼叫點依關閉、取消、移除 AI 選取、解除事件角色關聯及刪除時間接入具名資源；原字形不變。
- V9.1i 已讓八個 `minus.circle`、四個 `checkmark` 依解除關聯／移除紀錄和確認／選取狀態引用語意表；原字形不變。
- V9.1j 已讓七個卷／節／時間軸重新命名及紀元／事件編輯的 `pencil` 圖標引用 `.edit`；原字形、文字和 action 不變，主機 Debug build 通過。
- V9.1k 已讓九個搜尋／清除搜尋／設定／更多入口引用語意表，並把未被使用的 `.more` 定義對齊畫面既有的 `ellipsis.circle`；事件卡片刪除雖也用 `xmark.circle.fill`，保留獨立語意，主機 Debug build 通過。
- V9.1l 已讓六個相同的 V5 設定頁邊框多行編輯器引用 `SailuneBorderedTextEditor`；保持原生 TextEditor、frame 與 overlay 順序、Binding、最小高度和色值，主機 Debug build 通過。
- V9.1m 已讓六個簡單 V5 設定頁文字欄位引用 `SailuneFormTextField`；有 focus 與容器樣式的欄位保持原處，主機 Debug build 通過。
- V9.1n 已讓書籍背景彈窗既有 28 pt 關閉圖標按鈕引用 `SailuneIconButton`；共用元件保留原 frame、content shape、style、help、accessibility label 與 action。其後 `AppearanceRow` 也接入此元件，目前共兩處。
- V9.1o 已讓故事背景兩個編輯欄與兩個可點擊導覽卡片分別引用語意表面色；三個同色用途在 theme 內共用一個色值來源，原視覺值與互動不變。
- V9.1p 已讓 32 個既有提示確認「好」按鈕引用 `SailuneActionCopy.acknowledge`；繁體中文仍是「好」，原 action、role、位置及快捷鍵不變。
- V9.1q 已讓 17 個既有流程結束「完成」按鈕引用 `SailuneActionCopy.done`；繁體中文仍是「完成」，各自儲存與關閉順序不變。
- V9.1r 已將角色別名備註、心理內容、關係類型／備註及事件標題五個一般單行欄位接入 `SailuneFormTextField`；原 title、Binding、樣式與次序保留。別名名稱欄具 `FocusState` rename 副作用，事件摘要為垂直多行，因此保留專用實作。主機 Debug build 與 `git diff --check` 通過。
- V9.1s 已將角色能力階段歷史、物品歷史與關係歷史五個一般文字欄位接入 `SailuneFormTextField`；數值欄仍保留數字過濾與尺寸。主機 Debug build 與 `git diff --check` 通過。共用一般單行欄位來源碼採用數現為 17。
- V9.1t 已將書櫃及編輯工作區五個「新增節」入口改用 `SailuneSymbol.addSection` 集中取得原 `doc.badge.plus`；action、可見標籤與位置不變，其他相同字形但不同用途仍保留。五個呼叫點已核對，`doc.badge.plus` 原始字串只留在語意表。
- V9.1u 已將 Inspector 與 V5 設定畫面八個返回入口改用 `SailuneSymbol.back`；文案、action、style 與版位不變，`.previousSection` 保留獨立語意。
- V9.1v 已將物品名稱、能力等級名稱、歷史描述和故事線前置條件的四個提示統一使用 `SailuneSymbol.requirementNotice`；原圖形、文案與顯示條件不變。
- V9.1w 已為能力、物品、資源與勢力層級集中設定領域圖標，改接 Sidebar、Inspector、層級選取／管理及資源選擇中的十個直接呼叫；兩個 Sidebar 分類也改讀相同語意 key。AI 助手的 `sparkles` 保持獨立用途。
- V9.1y 已將三個警告狀態圖標呼叫接入 `SailuneSymbol.warning`；原字形、文案、顏色及條件不變。靜態引用數為 147，直接系統圖標字串為 135。
- V9.1z 已將角色歷史的時間序入口與兩種時間軸空狀態共三處 `clock` 呼叫接入 `SailuneSymbol.timeline`；原字形、accessibility label、文案與操作不變。靜態引用數為 150，直接系統圖標字串為 132。
- V9.1aa 已將四個列／卡片導覽指示接入 `SailuneSymbol.disclosure`；時間軸末端相同 `chevron.right` 表示延續方向，保留為獨立例外。靜態引用數為 154，直接系統圖標字串為 128。
- V9.1ab 已將六個圓形新增入口依實心／描邊兩種原有字形接入 `SailuneSymbol.addCircleFilled`／`.addCircle`；按鈕、選單與 action 不變。靜態引用數為 160，直接系統圖標字串為 122。
- V9.1ac 已將三個新增卷入口接入 `SailuneSymbol.addVolume`；總覽、context menu 與工作區控制均保留原文案、action 與呈現。靜態引用數為 163，直接系統圖標字串為 119。`doc.text` 的五處重複中，已記錄匯出、節標記和空狀態三種語意差異。
- V9.1ad 已將兩個「匯出 TXT」圖標接入 `SailuneSymbol.exportText`；同字形的節標記與空白狀態保留。靜態引用數為 165，直接系統圖標字串為 117。
- V9.1ae 已將故事線四處、關係三處、EPUB 匯出兩處圖標接入 `SailuneSymbol`；兩種匯出文案各兩處改用 `SailuneActionCopy`，字形與繁體中文值不變。`book.closed` 缺書空狀態保留獨立用途。
- V9.2w 已將 `TimelineOutlineSourceProjection` 從 `TimelineViews.swift` 移到獨立檔案；搬移宣告與 HEAD 原文逐字一致，來源檔無重複型別，`TimelineEventCreatePopover` 與 `V42OutlineTests` 的 API／呼叫名稱保留，主機 Debug build 通過。
- V9.2x 已將年號管理、年號列、改元及年號編輯 popover 移至 `TimelineEraManagementViews.swift`；`TimelineViews.swift` 不再重複宣告，原 Store 依賴、呼叫點與操作流程保留，主機 Debug build 通過。
- V9.2aa 已將角色卡片時間投影及事件列移至 `CharacterTimelineProjectionView.swift`；搬移的 208 行宣告逐字保留，顯示名稱輔助函式只從 file-private 調整為 module internal，主機 Debug build 通過。
- V9.2ab 已讓時間軸與大綱顯示共用 `PlanningRecordProjectionBuilder.buildForDisplay`，失敗以來源分類記入 OSLog 並保留空清單；原 throwing `build` 與其測試呼叫維持。
- V9.2ac 已將地點及世界條目各自的清單與詳情 View 原樣移至 `PlaceWorldTermViews.swift`；綁定、Store 操作與畫面未改。
- V9.2ad 已將側邊欄管理與勢力管理畫面移至各自具名檔；`V5SettingViews.swift` 已由 `SidebarSettingsManagerView.swift`、`PowerSettingViews.swift` 取代，原資料與互動入口不變。
- V9.2ae 已為改元接續提示的最後紀元／年份查詢失敗加入 private OSLog；原空提示與預設第 1 年的結果不變。
- V9.1af 已提出四組上下移動控制統一為 `arrow.up`／`arrow.down` 及補足 help／accessibility 名稱的 UI 提案，U 待使用者核定；目前未修改控制圖形。
- V9.1ag 已讓兩個筆名、物品副本名稱及角色勢力職稱欄位接入 `SailuneFormTextField`；原外層字體和保存觸發保留，共用一般單行欄位目前 21 處。
- V9.2af 已將親屬關係圖與新增血緣關係 sheet 歸入 `KinshipGraphViews.swift`；角色 Inspector 仍以原入口導覽，資料查詢與新增操作不變。
- V9.2ag 已將物品清單、詳情、副本詳情與等級編輯六個 View 歸入 `ItemInspectorViews.swift`；只放寬三個供根導覽跨檔使用的入口可見度，原物品操作不變。
- V9.2ah 已將能力清單、詳情和能力建立補償診斷 logger 歸入 `AbilityInspectorViews.swift`；兩個根導覽入口保持原名，能力資料操作與錯誤政策不變。
- V9.2ai 已將角色清單、詳情、勢力成員與參照區段等九個 View 歸入 `CharacterInspectorViews.swift`；`InspectorViews.swift` 保留共用連結列、route 和根導覽。
- V9.1ah 已讓三個時間格刪除按鈕的 help／accessibility label 共用 `SailuneActionCopy.deleteTime`；字形、文案值與刪除 action 不變。
- Mac 解鎖後已在運行中的 Sailune 核對既有「安東」服裝外觀列：Picker 緊鄰 trash、描述／場景用途／時間定位順序符合深色基線，AX 名稱為「刪除外觀」；未操作正式資料，檢查後回到書籍總覽。28 pt 實際命中、Light、身體特徵及輸入仍未驗收。
- 使用者新增要求欄位首行文字不得因圓角或其他樣式而穿模／裁切。已在 coding standards 與 UX principles 加入文字安全內距規則，建立 V9.1x 工作單；目前只確認 `InsetTextEditor` 明確 padding 與 `SailuneBorderedTextEditor` 沿用原生 inset 的結構差異，未確認具體故障畫面，因此沒有擅自改變欄位尺寸或 inset。
- V9.1x 已在執行中的書籍總覽「故事背景」彈窗，以未保存的繁體中文首行檢查「世界／時代背景」欄；深色模式沒有重現穿模，關閉後背景仍未設定。其他欄位與 Light／focus／捲動尚未核對，受影響欄位仍需定位。
- `docs/v9-adoption-matrix.md` 已依目前程式列出各家族接入證據、剩餘工作、語意例外與 V9 完成門檻；不能以既有 tokens／圖標／文案採用數量推論共用控制項全面完成。
- V9.2a 已將參照掃描、欄位名稱比對與預覽排序三個投影型別從 `InspectorViews.swift` 移出，原 API 與呼叫點不變。
- V9.2b 已將角色正文參照同步流程及候選資料移到 `CharacterReferenceSynchronizer.swift`；審核 View 仍在 `InspectorViews.swift`。原同步內容、保存與通知順序不變。
- 內部程式第二輪靜態稽核發現兩個後續候選：能力建立的跨 store 補償保存使用 `try?`，以及地圖清單查詢把 fetch 失敗折疊為空陣列；具體證據與工作邊界已記入 V9 整體規劃，尚未變更資料流程。
- V9.2c 使用者核定先只記錄錯誤，不改操作結果：能力補償保存及 13 個 V5 設定／3 個 MapCatalog 列表 fetch 失敗均寫 OSLog，空陣列 fallback 與主要錯誤出口保留。完整部分成功與空集合操作政策仍待核定；主機 Debug build 通過。
- V9.2d 已把時間軸日期投影與資料型別移至 `TimelineDateProjection.swift`，350 行宣告內容與原檔對應區塊完全一致，原 API／呼叫點不變，主機 Debug build 通過。
- V9.2u 已把事件卡片呈現資料與來源節錄投影移至 `TimelineCardProjection.swift`，兩段宣告共 81 行與原檔逐字相同，卡片與面板呼叫點不變，主機 Debug build 通過。
- V9.2v 已將能力進度、物品副本與故事規劃 Store 共七處 rollback 後 reload／refresh 失敗改成 OSLog 診斷，保留主要錯誤呈現／拋出；三檔此類 `try?` 已清零，主機 Debug build 通過。全專案 `try?` 由 45 降至 38。
- V9.2e 已把勢力承接及關係建立兩個重複檢查的 `try? fetch ?? []` 改由既有 throwing API 傳遞查詢錯誤；現有 View catch 顯示錯誤，正常資料路徑不變，主機 Debug build 通過。
- V9.2f 已讓完整備份中的封面／地圖資產目錄在存在但列舉失敗時回報錯誤，不再產生漏資產但看似成功的備份；目錄不存在的正常空狀態保留，主機 Debug build 通過。
- `docs/v9-error-suppression-audit.md` 初始將 45 處 `try?` 按資料正確性、資訊完整性與可容忍 fallback 分組；V9.2v 後 38 處，V9.2c 診斷批次後 21 處，V9.2y 診斷 ItemCopyHistory 編解碼後 19 處，V9.2z 診斷故事背景編解碼後 17 處，V9.2ab 集中規劃投影診斷後 15 處，V9.2ae 加入改元提示查詢診斷後為 13 處，V9.2aj 加入 AI 回應解碼診斷後為 10 處，V9.2ak 加入封面讀取診斷後目前 9 處。這是靜態風險導航，不是已重現缺陷或全數必改清單。
- V9.2g 使用者核定只修正錯誤文字；啟動訊息現在說「備份還原失敗，原資料回復狀態未確認」。rollback 保留、清理及再次啟動政策未改，另待決定。
- V9.2h 已把 AI 設定分析快照的七個主 store fetch 改為錯誤傳遞；設定分析的既有 View catch 會拒絕送出附件。
- V9.2i 已讓同一附件的勢力設定查詢使用 `V5SettingsStore.fetchForAnalysis`，保留原有篩選與排序；設定選取器及其他畫面仍使用原列表 API，可能將讀取錯誤視為空資料。
- V9.2j 已讓刪除地點及世界條目在必要關聯查詢失敗時記錄錯誤並於修改模型前停止；既有保存與畫面退出流程未改，保存失敗提示仍需獨立處理。
- V9.2k 已將資料目錄建立移入 `makeModelContainer()` 的錯誤鏈，在還原與開啟 store 前回報；正式與 DEBUG 路徑選擇不變。
- V9.2l 已將勢力階層錯誤、驗證及直屬關係操作三個宣告移入 `PowerHierarchyStore.swift`，沒有修改 `V5SettingsStore`／View 呼叫點或 schema。
- V9.2m 已將地點／世界條目搜尋與側邊欄目錄兩組宣告分別移入 `V5SettingsSearch.swift`、`SidebarSettingCatalog.swift`；呼叫點、schema 與保存行為不變。
- V9.2n 已將角色未連結文字審核與 AppKit 組字文字欄封裝移出 `InspectorViews.swift`，原 `CharacterDetailView` 的綁定、狀態與 action 入口不變。
- V9.2o 已讓地圖刪除先讀完版本及同書 placement，再開始刪除與解除綁定；版本刪除也改以可拋錯查詢核對數量。兩個既有管理畫面 catch 不變，其他地圖讀取仍待 V9.2c。
- V9.2p 已讓地圖／版本建立與改名、標記目的地配對走私有可拋錯查詢，避免讀取失敗被當成無重名或無目的地後繼續寫入；首次初始化、來源標記與畫面列表仍待 V9.2c。
- V9.2q 已讓預設地圖初始化先完成所有必要讀取，再插入初始資料；地圖新增標記的 Place 排序讀取亦可拋錯。跳轉前來源標記與畫面列表仍待 V9.2c。
- V9.2r 已讓標記跳轉前的 Place／placement 來源查詢可拋錯且核對關聯；標記編輯和畫面列表仍待 V9.2c。
- V9.2s 已讓編輯既有標記時重用同一來源查詢；缺失來源或讀取失敗不再轉成新增，原資料缺失時由既有 alert 顯示具體錯誤。標記刪除與畫面列表仍待 V9.2c。
- V9.2t 標記刪除的 Place／placement 查詢與保存錯誤均接至地圖既有提示；依使用者核定，確認後仍關閉編輯器。保存失敗後 context rollback 策略待另議，不得默認擴寫。
- V8.2 的 `docs/work-items/current.md` 與 `docs/handoffs/current.md` 保持原工作狀態；V9 使用獨立工作單與本交接檔。

## 暫時假設與待確認

- 28 pt 一般控制高度、28 × 28 pt 純圖標 hit area 與 4／8／12／16／24 pt spacing 是 V9 試行基準；實際 App 畫面核對後才能確認是否適用於 `AppearanceRow`。
- 先前 `cua.getApp("Sailune")` 多次逾時；使用者於 2026-09-24 提供 556 × 828 像素的深色局部截圖，已保存至 `docs/assets/v9-appearance-row-dark-2026-09-24.png`。畫面確認 Picker 後緊鄰刪除圖標，沒有靠右；描述、場景／用途、時間定位順序與來源碼相符。截圖下方開著「新增外觀」選單。
- `AppearanceRow` 接線後已於運行中的深色 Debug app 核對服裝列排列及「刪除外觀」AX 名稱；本次未觸發刪除或編輯資料。Light、身體特徵、hover／focus、實際 hit area 仍未觀察，截圖不能當作互動命中驗收。

## 進度與驗證

- V9.0b 規則已寫入 `docs/coding-standards.md`、`docs/ux-principles.md`、`docs/architecture.md`、`docs/testing.md`、`AGENTS.md`；第一輪元件／呼叫點 inventory 在 `docs/work-items/v9-code-standardization-plan.md`。
- V9.1a 新增 `Sailune/SharedUI/SailuneUIFoundation.swift` 和 `Sailune/Localizable.xcstrings`；把 `InsetTextEditor` 從 `CharacterSectionViews.swift` 移入 foundation，把 `PlanningActionStyle` 從 `OutlineViews.swift` 移入 `SharedUI/PlanningActionStyle.swift`。原呼叫點未修改。
- V9.1b 新增 `SailuneTheme.subtleSurface` 並替換 24 個原色值呼叫點；原字面值只留在 token 定義。`git diff --check` 通過，沒有執行程式測試或 GUI 驗收。
- V9.1c 主機環境無簽章 Debug build 通過；七個搜尋欄位呼叫點和舊型別移除已做靜態核對，未執行程式測試或 GUI 驗收。
- V9.1d `git diff --check` 與主機環境無簽章 Debug build 通過；其後 `AppearanceRow` 也已接入共用 `.delete` 圖標。未執行程式測試或 GUI 驗收。
- V9.1e `git diff --check` 與主機環境無簽章 Debug build 通過；建置產物確認 `action.cancel`／`action.save` 仍為「取消」／「儲存」。未執行程式測試或 GUI 驗收。
- V9.1f `git diff --check` 與主機環境無簽章 Debug build 通過；建置產物確認 `action.delete`／`action.add`／`action.close` 的原中文值不變。未執行程式測試或 GUI 驗收。
- V9.1g `git diff --check` 與主機環境無簽章 Debug build 通過；raw `"plus"` 只剩語意表定義。未執行程式測試或 GUI 驗收。
- V9.1h `git diff --check` 與主機環境無簽章 Debug build 通過；raw `"xmark"` 只剩語意表定義。未執行程式測試或 GUI 驗收。
- V9.1i `git diff --check` 與主機環境無簽章 Debug build 通過；raw `"minus.circle"`／`"checkmark"` 只剩語意表定義。未執行程式測試或 GUI 驗收。
- V9.1j `git diff --check` 與主機環境無簽章 Debug build 通過；raw `"pencil"` 只剩語意表定義。未執行程式測試或 GUI 驗收。
- V9.1k `git diff --check` 與主機環境無簽章 Debug build 通過；`SailuneSymbol` 使用點 116、直接 `systemName`／`systemImage` 字串 166（靜態命中，非語意驗收）。未執行程式測試或 GUI 驗收。
- V9.1l `git diff --check` 與主機環境無簽章 Debug build 通過；六個 V5 設定頁呼叫點均引用共用 variant。精確原生 `\bTextEditor(` 目前七處，兩處在 SharedUI，五處留在功能 View；先前粗略搜尋把 `InsetTextEditor(` 也計入，矩陣已修正。未執行程式測試或 GUI 驗收。
- V9.1m `git diff --check` 與主機環境無簽章 Debug build 通過；六個 V5 設定頁單行欄位引用共用元件。精確原生 `\bTextField(` 98 處，`.roundedBorder` modifier 61 處（含共用元件），矩陣已更新；未執行程式測試或 GUI 驗收。
- V9.1n `git diff --check`、String Catalog JSON 語法檢查及主機無簽章 Debug build 通過；共用純圖標按鈕現只有一處採用，GUI 命中與 Light／Dark 未驗收。
- V9.1o `git diff --check` 與主機無簽章 Debug build 通過；四個背景呼叫點靜態核對完成，未執行 Light／Dark GUI 驗收。`Color.secondary.opacity(...)` 靜態命中由 36 降至 32 處。
- V9.1p String Catalog JSON 語法檢查、`git diff --check` 與主機無簽章 Debug build 通過；原 `Button("好"...)` 32 處均改由通用文案取得，未執行程式測試、GUI 或 VoiceOver 驗收。
- V9.1q String Catalog JSON 語法檢查、`git diff --check` 與主機無簽章 Debug build 通過；原 `Button("完成"...)` 17 處均改由通用文案取得，未執行程式測試或 GUI 驗收。
- V9.1 試行已保存使用者的深色畫面作 U 基線，R／U／I 均已批准。`AppearanceRow` 的刪除按鈕接入 `SailuneIconButton`，條件式單行欄接入 `SailuneFormTextField`；原 Picker、描述編輯器、時間定位與 Binding 保留。已以運行中 Debug app 核對深色畫面排列與 AX 名稱；實際 hit area、Light、身體特徵、焦點及輸入仍待 GUI 驗收。
- V9 採用盤點為唯讀程式與文件工作；矩陣搜尋數字已與目前原始碼核對，未執行程式測試或 GUI 驗收。
- V9.2a 新增 `WritingReferenceScanner.swift`、`CharacterDetailPreviewOrdering.swift`；首次建置發現新檔需明確引入 `AppKit`，補正後主機環境無簽章 Debug build 通過。未執行程式測試或 GUI 驗收。
- V9.2b 新增 `CharacterReferenceSynchronizer.swift`；`git diff --check` 與主機環境無簽章 Debug build 通過，未執行程式測試或 GUI 驗收。
- V9.2d 新增 `TimelineDateProjection.swift`；從 `HEAD:TimelineViews.swift` 擷取的三段宣告與新檔正文逐字相同，原檔無重複型別，`git diff --check` 與主機無簽章 Debug build 通過。未執行程式測試或 GUI 驗收。
- V9.2u 新增 `TimelineCardProjection.swift`；原檔的兩段宣告逐字搬移，來源檔無重複型別，`git diff --check` 與主機無簽章 Debug build 通過。未執行程式測試或 GUI 驗收。
- V9.2v `git diff --check` 與主機無簽章 Debug build 通過；沒有新增程式測試，沒有故障注入驗證。
- V9.2e `git diff --check` 與主機無簽章 Debug build 通過；兩個重複檢查的查詢錯誤不再吞掉。未執行程式測試、故障注入或 GUI 驗收。
- V9.2f `git diff --check` 與主機無簽章 Debug build 通過；備份資產目錄的兩處 `try?` 已移除。未執行程式測試、故障注入、備份／還原或 GUI 驗收；還原 rollback 未修改。
- V9 `try?` 稽核為唯讀程式與文件工作；48 處靜態命中已逐群記錄於專用稽核文件，未執行程式測試或 GUI 驗收。
- V9.2g 只改啟動錯誤字句；尚未執行故障注入或實際還原，rollback 程式未改。
- V9.2h `git diff --check` 與主機無簽章 Debug build 通過；七處 `try? context.fetch` 已移除，成功資料映射保留。未執行程式測試、故障注入或 GUI 驗收。
- V9.2i `git diff --check` 與主機無簽章 Debug build 通過；勢力附件的 13 處設定 store 呼叫均走可拋錯入口。未執行程式測試、故障注入或 GUI 驗收；`try?` 靜態命中仍為 48 處。
- V9.2j `git diff --check` 與主機無簽章 Debug build 通過；兩個刪除前 `try?` 已移除，靜態命中目前 46 處。未執行程式測試、故障注入或 GUI 驗收。
- V9.2k `git diff --check` 與主機無簽章 Debug build 通過；啟動目錄的 `try?` 已移除，靜態命中目前 45 處。未執行程式測試或故障注入。
- V9.2l 從 `HEAD:V5SettingModels.swift` 比對新檔的三段宣告正文逐字相同，原檔無重複宣告；`git diff --check` 與主機無簽章 Debug build 通過。未執行程式測試或 GUI 驗收。
- V9.2m 從 `HEAD:V5SettingModels.swift` 比對搜尋與側邊欄目錄兩段正文逐字相同，原檔無重複型別；`git diff --check` 與主機無簽章 Debug build 通過。未執行程式測試或 GUI 驗收。
- V9.2n 已核對組字欄本文與 `HEAD:InspectorViews.swift` 相同，審核 View 除先前 V9 的同字形取消圖標 key 外相同；`git diff --check` 與主機無簽章 Debug build 通過。未執行 CJK、焦點、VoiceOver 或 GUI 驗收。
- V9.2o `git diff --check` 與主機無簽章 Debug build 通過；地圖／版本刪除的必要查詢失敗會在修改模型前拋錯。未執行程式測試、故障注入、實際地圖刪除或 GUI 驗收；`try?` 靜態命中仍為 45 處。
- V9.2p `git diff --check` 與主機無簽章 Debug build 通過；建立／改名／目的地配對的地圖／版本必要查詢失敗會在寫入前拋錯。未執行程式測試、故障注入、實際地圖操作或 GUI 驗收；`try?` 靜態命中仍為 45 處。
- V9.2q 主機無簽章 Debug build 通過；預設地圖初始化及地圖新增標記的必要查詢失敗會在任何相關插入前拋錯。未執行程式測試、故障注入、實際初始化或 GUI 驗收；`try?` 靜態命中仍為 45 處。
- V9.2r 主機無簽章 Debug build 通過；標記跳轉讀取失敗會在目的地建立與綁定前拋錯。未執行程式測試、故障注入、實際跳轉或 GUI 驗收；`try?` 靜態命中仍為 45 處。
- V9.2s 主機無簽章 Debug build 通過；既有標記來源不完整或無法查詢時會停止保存，不建立另一筆 Place。未執行程式測試、故障注入、實際編輯或 GUI 驗收；`try?` 靜態命中仍為 45 處。
- V9.2t 已完成可拋錯來源、placement 與保存入口，三種錯誤均由地圖既有 alert 顯示；依使用者核定，編輯器仍在確認後關閉。Store context rollback 的進一步政策待另議。
- 2026-09-24：V9.1t／u／v／w 與 V9.2t 變更後，`git diff --check` 與主機無簽章 macOS Debug build 通過。沙盒 build 曾因 SwiftData macro plugin malformed response 失敗，主機環境重跑成功。`SailuneSymbol` 靜態呼叫點為 144；直接 `systemName`／`systemImage` 字串為 138，設定領域 12 個 key 引用、10 個 UI 呼叫點已核對。
- 2026-09-24：V9.1y 警告圖標接線後主機無簽章 macOS Debug build 通過；`SailuneSymbol` 靜態呼叫點為 147，直接系統圖標字串為 135。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.1z／1aa 時間序及導覽圖標接線後，`git diff --check` 與主機無簽章 macOS Debug build 通過；目前 `SailuneSymbol` 靜態呼叫點為 154，直接 `systemName`／`systemImage` 字串為 128。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.1ab 圓形新增圖標接線後，`git diff --check` 與主機無簽章 macOS Debug build 通過；目前 `SailuneSymbol` 靜態呼叫點為 160，直接 `systemName`／`systemImage` 字串為 122。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2w 投影責任搬移後，宣告與 HEAD 原文逐字一致，`git diff --check` 與主機無簽章 macOS Debug build 通過；未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2x 年號 View 搬移後，四個 View／色票只在新檔宣告，三個跨檔 popover 建置解析成功；`git diff --check` 與主機無簽章 macOS Debug build 通過。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.1ac／1ad 新增卷及 TXT 匯出圖標接線後，`git diff --check` 與主機無簽章 macOS Debug build 通過；目前 `SailuneSymbol` 靜態呼叫點為 165，直接 `systemName`／`systemImage` 字串為 117。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2y／2z 已為 ItemCopyHistory 及故事背景 JSON 編解碼 fallback 加入 private OSLog；舊文字相容與現有回傳結果維持不變。`git diff --check`、主機無簽章 macOS Debug build 通過，`try?` 目前 17 處；未執行 XCTest 或故障注入。
- 2026-09-24：V9.2aa 角色時間投影 208 行宣告從目前工作樹逐字搬移，SHA-256 `079170bdb58c2a5f13ba7d069129286e0556b1b8e3ede5b61db33d99419f6c48`；兩個 View 各只宣告一次，主機無簽章 Debug build 與 `git diff --check` 通過。未執行 XCTest 或該 View 的 GUI 驗收。
- 2026-09-24：V9.1ae String Catalog JSON 語法、`git diff --check` 與主機無簽章 Debug build 通過；`SailuneSymbol` 引用數 174，直接系統圖標參數 108。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2ab 兩處規劃投影顯示 fallback 已改用同一個診斷入口；`git diff --check` 與主機無簽章 Debug build 通過，`try?` 靜態命中目前 15 處。未執行 XCTest、故障注入或 GUI 驗收。
- 2026-09-24：V9.2ac 從目前工作樹逐字搬移 467 行，段落 SHA-256 `141bca3c7415eaf54a0bf5716e4a730d425d92aecc971cf269749363db4a48e4`；四個 View 均只在新檔宣告，`git diff --check` 與主機無簽章 Debug build 通過。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2ad 將 78 行側邊欄管理與 910 行勢力畫面宣告分別移至專責檔，五個 View 各只宣告一次；`git diff --check` 與主機無簽章 Debug build 通過。第一次沙箱內建置遇 Xcode SwiftData macro 外掛啟動限制，允許外掛運作後重跑通過。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2ae 改元接續提示的兩處查詢 fallback 已加入 private OSLog，`try?` 靜態命中由 15 降為 13 處；`git diff --check` 與主機無簽章 Debug build 通過。未執行 XCTest、故障注入或 GUI 驗收。
- 2026-09-24：V9.1ag 四個簡單單行欄位接線後，`SailuneFormTextField` 呼叫點 21 處、原生 `TextField(` 83 處、`.roundedBorder` modifier 46 處；`git diff --check` 與主機無簽章 Debug build 通過。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2af 親屬關係圖及新增關係 sheet 284 行宣告從目前工作樹逐字搬移，SHA-256 `9f3a2ea859d390b6d8d1da88ec5d1ce9ed56270fdc507ae0d3bee100db3a2ef6`；兩個 View 只在新檔宣告，`git diff --check` 與主機無簽章 Debug build 通過。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2ag 物品群組 647 行宣告搬移後，還原三個跨檔入口的 `private` 即與搬移前工作樹 SHA-256 `792ddf4ae401b19acd3dd8f900a7c485a9feb2738b5dd21b2f62f59139b024d2` 一致；六個 View 各宣告一次，`git diff --check` 與主機無簽章 Debug build 通過。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.2ah 能力兩個 View 的 236 行宣告搬移後，還原兩個跨檔入口的 `private` 即與搬移前工作樹 SHA-256 `cbefc1d9a6337d5edee08e371656a6d5ef0329553af64dd743fef6a7a511737d` 一致；補償診斷 logger 原樣移入，`git diff --check` 與主機無簽章 Debug build 通過。未執行 XCTest、故障注入或 GUI 驗收。
- 2026-09-24：V9.2ai 角色區九個 View 的 1021 行宣告從目前工作樹逐字搬移，SHA-256 `5e472765b2e7efaee608c80d9c12e778c734397b0a19c0628458db842a14bee2`；各 View 只在新檔宣告，`InspectorViews.swift` 現為 422 行，`git diff --check` 與主機無簽章 Debug build 通過。未執行 XCTest 或 GUI 驗收。
- 2026-09-24：V9.1ah 六個相同的時間格刪除描述參數改讀既有共用 key；String Catalog 原值、`git diff --check` 與主機無簽章 Debug build 通過。未實測刪除控制命中。
- 2026-09-24：V9.1ai 能力詳情五個圓角單行欄已接入共用欄位；初次建置因缺少 `title:` 標籤失敗，補正後主機無簽章 Debug build 與 `git diff --check` 通過。原 Binding 與更新時間處理保留；未執行 XCTest 或 GUI 驗收。共用欄位採用 26 處，原生 `TextField(` 78 處，`.roundedBorder` 41 處。
- 2026-09-24：Mac 解鎖後在執行中 Sailune 的既有角色頁唯讀核對服裝外觀列：AX 顯示類型為「服裝」、刪除控制描述為「刪除外觀」、下方仍是「外觀描述」及「場景／用途」欄；深色畫面可見刪除圖標位於類型選單右側。未點擊刪除或修改作者資料；此觀察無法證明 28 pt 實際 hit-test、Light、身體特徵與輸入首行。
- 2026-09-24：V9.1aj 物品相關六個圓角單行欄接入共用欄位，原驗證與資料動作保留；主機無簽章 Debug build 及 `git diff --check` 通過。共用欄位採用 32 處，原生 `TextField(` 72 處，`.roundedBorder` 35 處；未執行 XCTest 或 GUI 輸入驗收。
- 2026-09-24：V9.1ak 書籍建立／總覽及故事線五個圓角單行欄接入共用欄位，原提交、更新時間與字級保留；主機無簽章 Debug build 及 `git diff --check` 通過。共用欄位採用 37 處，原生 `TextField(` 67 處，`.roundedBorder` 30 處；未執行 XCTest 或 GUI 輸入驗收。
- 2026-09-25：V9.2aj AI 回應三處解碼失敗加入分支明確、private 的 OSLog，保留原回傳與使用者錯誤；主機無簽章 Debug build 及 `git diff --check` 通過。目前 `try?` 靜態命中 10 處；未執行 XCTest、故障注入或實際服務呼叫。
- 2026-09-25：V9.2ak 自訂封面讀取只在檔案存在但失敗時記 private OSLog，原 `nil`／預設封面 fallback 不變；主機無簽章 Debug build 及 `git diff --check` 通過。目前 `try?` 靜態命中 9 處；未執行 XCTest、故障注入或實際匯出。
- 2026-09-25：V9.1al AI 側欄閱讀範圍及角色整理兩組入口／摘要共四處接入語意圖標；原字形、文案、操作不變。主機無簽章 Debug build 與 `git diff --check` 通過；`SailuneSymbol` 靜態呼叫點 178，直接系統圖標字串 104。
- 2026-09-25：使用者提供地點「簡介」首行幾乎貼圓角上框的截圖，已保存為 `docs/assets/v9-place-intro-first-line-clipping-2026-09-25.png`。來源定位到 `PlaceDetailView.settingTextArea` 與無明確內距的 `SailuneBorderedTextEditor`；V9.1am 已提出 9 pt 水平、8 pt 垂直安全內距及共用採用範圍，U 核定待回覆，未先修改 UI。
- 2026-09-25：V9.1an 兩個匯出選單接入 `.export`，原字形與流程不變；主機 Debug build 與 `git diff --check` 通過。`SailuneSymbol` 靜態呼叫點 180，直接系統圖標字串 102。使用者隨後要求凍結 V9 逐項清單，停止新增單點切片；下一步先建立可核對的固定盤點基準與每點三態分類。
- 2026-09-25：依使用者新指示凍結 93 個 Swift 檔雜湊、2,256 筆固定搜尋命中及 93 筆模組責任列於 `docs/v9-freeze/`；每筆有 ID／三態／來源理由，初始分類仍需逐項人工複核。凍結後只在發現漏整個需求類別或分類錯誤時提出範圍變更；單一新命中點不再自動擴張 V9。
- 2026-09-25：獨立讀取比對確認 93 個原始碼 SHA-256、2,256 個固定 regex 命中與行列／程式片段、93 個模組 hash 均吻合，ID 無重複。`resolution-ledger.csv` 首次對全部 2,256 個 ID 建立來源初審列時，暫列已共用 555、待共用 1,083、合理例外 618；`module-resolution-ledger.csv` 涵蓋全部 93 檔（2／11／80）。這是凍結時來源初審，不是逐項決策、畫面或資料驗收；當時尚無凍結後的 Swift 程式修改。
- 2026-09-25：固定表中 185 個 failure_path ID 已依同一來源分支的明確錯誤顯示／拋出／記錄，以及使用者對 V9.2g 只改文字的決定，從待共用修訂為暫列合理例外；故障注入仍未驗收。`dialog-groups.csv` 另列 4 組同標題、9 個 ID 作外殼核對線索，沒有因相同字面值改動 UI。
- 2026-09-25：原 V9 規劃包含非 Button 整列命中、遮罩與手勢競爭，固定十家族未收錄；同一批凍結產品檔唯讀查到 14 檔 115 個修飾器命中，已依整個類別漏項門檻提出 `scope-change-proposal-hit-testing.md`，待使用者決定。原 2,256 筆與三個快照 hash 均未改；`check_inventory.py --source-frozen` 通過，沒有在凍結後修改 Swift 原始碼。原清單的逐項核定與 GUI／資料驗收繼續進行。
- 2026-09-25：171 個原生文字 Button 依凍結來源、非 iconOnly、非破壞性角色分類為暫列合理例外；`SailuneActionCopy` 或領域標題仍由 copy 家族核對，同位置的 style 由 button_style 家族核對，實際命中與鍵盤／Light／Dark 未驗收。185 個圖標／破壞性／整列 Button 待按畫面判定。此時共用化暫列 555 已共用、712 待共用、989 合理例外；分類階段未修改 Swift 程式。
- 2026-09-25：V9.1ao 依凍結 `copy-groups.csv` 將 24 組、65 個固定操作文字 ID 接入 `SailuneActionCopy`，19 個功能檔保留原文、closure、role、style 與圖標；String Catalog 新增相同繁體中文值。65 個原 ID 的現行來源、JSON、`git diff --check` 與主機無簽章 macOS Debug build 通過；GUI／VoiceOver 未驗收。「新增副本」圖標差異保留由 symbol／button 固定 ID 另審。接線後共用化暫列 620／647／989（已共用／待共用／合理例外）。
- 2026-09-25：V9.2al 三個固定靜默 catch（V9-0686、V9-0737、V9-1058）已加 private OSLog，原結果分支不變，主機無簽章 Debug build 通過；隔離故障注入未做。`failure_path` 219 筆現在來源分類全為合理例外，其中 V9.2g rollback／清理政策仍依使用者決定留待另議。固定清單當前 620／644／992。
- 2026-09-25：V9.1ap 五個顯式圓角單行欄位固定 ID 已接入 `SailuneFormTextField`，原 Binding、字級及事件保留；主機無簽章 Debug build 與 `git diff --check` 通過。CJK／focus／首行未經 GUI 驗收；固定清單當前 625／639／992。
- 2026-09-25：V9.1aq 八個勢力區塊圓角文字欄接入 `SailuneFormTextField`，主機無簽章 Debug build 與 `git diff --check` 通過；另依父容器契約將 21 個原生 alert／Form、focus／提交及列內欄分類為合理例外。`field` 只剩固定 ID V9-0897 親屬圖搜尋欄待 compact variant 的 U／I 核定，見 `v9.1ar-kinship-search-field.md`。目前固定清單 633／610／1,013；GUI／CJK／首行仍待驗收。
- 2026-09-25：V9.1as 將固定 18 個相同語意／領域圖標接入九個 `SailuneSymbol` key，原 SF Symbol 字形、文字及 action 不變；逐 ID 核對與主機無簽章 macOS Debug build、`git diff --check` 通過。上下移動及「新增副本」不同字形仍待獨立 U 決策；目前固定清單 651／592／1,013。
- 2026-09-25：V9.1as 再將固定 5 個關聯角色／列導覽及 3 個節文件圖標接入同字形 key，逐 ID 與主機無簽章 Debug build 通過；29 個單一語意圖標已逐項列保留理由。`symbol` 只剩 10 個 U／I 待核定 ID：8 個上下移動屬 V9.1af，新增副本及刪除事件卡片兩種同功能不同字形屬新具體提案 V9.1at。固定清單當前 659／555／1,042；實際圖標、hover／VoiceOver 尚未驗收。
- 2026-09-25：V9.1au 將作者設定與首頁作者彈窗的兩個簡介 editor 封入 `SailuneAuthorBioEditor`，100／110 pt、原描邊／placeholder／Binding 保留；主機無簽章 Debug build 與 `git diff --check` 通過。`editor` 家族的固定 19 ID 現為 16 已共用、0 待共用、3 專用例外；V9.1am 的地點首行安全內距仍待 U 核定，實際 GUI 首行未驗收。固定清單當前 661／553／1,042。
- 2026-09-25：V9.1av 在固定 surface 清單中將 10 個 controlBackground、8 個 windowBackground 與 6 個 0.05 次要色 regex ID（共 21 個色值位置）接入同值 token，原 shape／opacity 不變；主機無簽章 Debug build 與 `git diff --check` 通過。Light／Dark／hover 未驗收，非固定搜尋規則捕捉的其他單點不自動擴入 V9。固定清單當前 685／529／1,042。
- 2026-09-25：V9.1av 再將 10 個角色詳情／大綱重複邊框與 0.04 卡片固定 ID 接入同值 token，主機無簽章 Debug build 通過；其餘 43 個 surface ID 已逐項列出狀態色、材質、地圖標籤、hover、診斷等用途理由，暫列合理例外。`surface` 全 193 筆目前為 131 已共用、0 待共用、62 例外；Light／Dark／hover 仍未驗收。固定清單當前 695／476／1,085。
- 尚未執行程式 XCTest；V9.1 `AppearanceRow` 已有深色運行畫面檢查，但命中、Light、身體特徵、focus／CJK 輸入仍待 GUI 驗收。其他控制家族及內部責任也仍有未完成採用範圍。

## 工作樹邊界

- 起點已有未提交的 V8.2 文件修改：`docs/work-items/current.md`、`docs/handoffs/current.md`、`docs/spec-ai-v8.md`、`docs/project-status.md`。本 V9 工作不回復 V8.2 修改，也未修改前面三份。
- V9 新增：專用工作單與交接、採用／失敗路徑稽核文件、使用者提供的 `docs/assets/v9-appearance-row-dark-2026-09-24.png`、`Sailune/SharedUI`、`Localizable.xcstrings`、`WritingReferenceScanner.swift`、`CharacterDetailPreviewOrdering.swift`、`CharacterReferenceSynchronizer.swift`、`CompositionAwareTextField.swift`、`UnlinkedReferenceReviewView.swift`、`TimelineDateProjection.swift`、`TimelineCardProjection.swift`、`TimelineOutlineSourceProjection.swift`、`TimelineEraManagementViews.swift`、`CharacterTimelineProjectionView.swift`、`KinshipGraphViews.swift`、`ItemInspectorViews.swift`、`AbilityInspectorViews.swift`、`CharacterInspectorViews.swift`、`PlaceWorldTermViews.swift`、`SidebarSettingsManagerView.swift`、`PowerSettingViews.swift`、`PowerHierarchyStore.swift`、`V5SettingsSearch.swift`、`SidebarSettingCatalog.swift`。
- V9 修改：`AGENTS.md`、`docs/README.md`、`architecture.md`、`backup-and-migration.md`、`consistency-audit.md`、`coding-standards.md`、`testing.md`、`ux-principles.md`、`project-status.md`、`spec-map-v7.md`、`spec-power-v5.2.md`；功能程式為 `BookOutline.swift`、`BookOverviewView.swift`、`CharacterHistoryViews.swift`、`CharacterSectionViews.swift`、`ContentView.swift`、`EditorWorkspaceView.swift`、`InspectorViews.swift`、`ItemCopy.swift`、`MapCatalog.swift`、`MapManagementViews.swift`、`MapViews.swift`、`OutlineViews.swift`、`PlanningRecordProjection.swift`、`RelationshipWorkspaceViews.swift`、`SailuneAIAnalysisContext.swift`、`SailuneAIChatSidebarView.swift`、`SailuneApp.swift`、`SailuneBackupService.swift`、`StoryTagViews.swift`、`TimelineViews.swift`、`V5SettingModels.swift` 與預設資料 View 檔；`V5SettingViews.swift` 已由上述三個領域畫面檔取代；上述只屬 V9 變更範圍，原有 V8.2 工作文件未回復。
- 本輪未操作正式作者資料、SwiftData schema、遷移、實際備份／還原或發布。

## 新聊天最小讀取集合

1. `AGENTS.md`
2. `docs/project-status.md`
3. `docs/work-items/v9.1-shared-ui-pilot.md`
4. `docs/handoffs/v9-current.md`
5. UI 工作時再讀 `docs/ux-principles.md` 和 `docs/coding-standards.md` 的 UI 章節。

接續時先取得可操作的 Sailune 畫面，核對外觀列與已保存深色截圖的可見位置及 Picker／刪除按鈕命中邊界，再核對 Light、身體特徵、焦點及輸入；若位置或命中回歸，僅在已批准的試行範圍內修正共用控制。

- 2026-09-25：固定清單 Button 八筆已依原生 contextMenu／swipeActions、既有共用 helper／PlanningActionStyle 核對，來源理由見 `review-button-contexts.md`；逐項校驗目前 701／341／1,214。V9.2am 將角色外觀兩個 View 搬到具名檔，空狀態 helper 放寬為同模組可見，無簽章 Debug build 通過。`CharacterSectionViews.swift` 仍列待共用。嘗試以獨立測試 store 啟動新 app 實例未成功；已執行中的 Sailune 可能連正式作者資料，因此沒有操作其畫面。GUI 與故障注入仍待驗收。

- 2026-09-25：V9.1ar／1at 已獲使用者同意。親屬圖搜尋欄接共用 compact variant；兩處新增副本用同一 `addCopy` 字形，事件卡片刪除用共用 trash。三個固定 ID 已記入 ledger，主機無簽章 Debug build 通過；GUI／CJK／VoiceOver 未驗收。完整程式測試首次平行執行因一個 AI 測試的 session invalidated 失敗，單獨重跑通過，完整非平行模式 208／208 通過（xcresult 11:26:05）。目前固定清單 704／338／1,214。

- 2026-09-25：V9.1aw 依固定 `dialog` 家族將地圖兩處與大綱／故事背景四處原生錯誤 alert 共用為 `SailuneErrorAlert`，保留標題、fallback、按鈕 role 與清除時機；六個固定 ID 接線，主機無簽章 Debug build 通過。錯誤注入與實際提示畫面待驗收；固定清單 710／332／1,214。

- 2026-09-25：V9.1ax 把固定 15 組、30 個重複 help／accessibilityLabel 命中接入 ActionCopy 或 AccessibilityCopy；13 個新 key 已存 String Catalog，原字句逐字保留，主機無簽章 Debug build 通過。hover／VoiceOver 尚待驗收；清單目前 740／302／1,214。此前 V9.1aw 接線後的完整非平行 XCTest 208／208 通過（xcresult 11:33:35）。

- 2026-09-25：`accessibility` 家族另有 14 個書籍封面、版本、地圖縮放／檔案操作 ID 經來源複核列合理例外，逐 ID 理由見 `review-accessibility-domain-text.md`；目前固定清單 740／288／1,228。hover／VoiceOver 尚待驗收。

- 2026-09-25：再將五個 help ID（V9-0452、0605、0635、1180、1226）接到既有 ActionCopy，ledger 更新為已共用；最後一次 build 在執行時遭對話中斷，尚未確認結果。清單現為 745／284／1,227；需補跑 Debug build 與測試。

- 2026-09-25 暫緩檢查點：依使用者決定，V9 工作暫緩，優先把算力投入功能增加與穩固；未結案、未取消。固定 ID 2,256 筆當前 745 已共用／284 待共用／1,227 合理例外，11 個模組候選待審。剩餘分類：button 50、button_style 154、accessibility 31、dialog 41、symbol 8。五處 ActionCopy help 接線的 build 尚未確認；208／208 全測發生在較早變更點，不涵蓋最新 V9.1ax／五處 help。完整狀態、approved／pending decisions、逐步續接、驗收缺口與版號建議見 `v9-pause-checkpoint-2026-09-25.md`。

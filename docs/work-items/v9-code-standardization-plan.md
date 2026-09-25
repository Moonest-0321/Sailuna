# V9 整體程式碼規則化規劃

> 狀態：active（規範基線已建立；共用元件採用、內部責任整理與驗收持續進行）
>
> 階段：V9.0b 規則納入完成；V9.1 共用元件採用及 V9.2 內部整理持續進行
>
> 工作單位：盤點現況並規劃如何把可維護性、可擴充性與 UI 互動規則納入專案文件。

2026-09-25 起，V9 剩餘採用改以 [固定逐項盤點基準](../v9-freeze/README.md)及 [清單處置工作單](v9-frozen-inventory.md)為唯一新增範圍來源；原本的階段進度與靜態數字保留作歷史，不再因新發現單一呼叫點擴張 V9。

## 目標

建立適用於 Sailune 後續開發的程式碼規範化方向，涵蓋內部程式結構、UI 互動，以及可重用的共用 UI 元件與操作流程，讓新增功能能直接呼叫統一實作，減少重複樣式和行為分歧。

本規劃工作本身只修改工程規範文件並盤點程式；後續功能程式變更由獨立的 V9.1 工作單管理。使用者已指示依具體規範草案繼續；尺寸與間距先作 V9 試行基準，實際 UI 採用時仍須由 V9.1 工作單驗收。

## 規劃進度

- 已完成：讀取 coding standards、UX principles、architecture、testing、development workflow 與主要功能規格；建立文件覆蓋矩陣初稿。
- 已完成：靜態盤點書櫃、正文編輯器、設定集、敘事大綱、時間軸、地圖、AI、store 修復／備份及 schema 區域；列出暫定優先級和試行候選。
- 已完成：追蹤地圖、角色事件、跨 store 刪除、備份還原與 AI 對話責任鏈，映射既有程式規格及測試。
- 已完成：擬定下方內部程式與 UI 工程規則、共用按鈕／欄位／編輯器／tokens／操作外殼方向、文件責任分配、檢核情境及建議更新項目。
- 已完成：使用者確認依具體規範草案繼續；更新 coding standards、UX principles、architecture、testing、AGENTS 的規則入口與責任說明。
- 已完成：完成共用元件／語意資源第一輪 inventory 與 V9.1 試行候選比較；正式實作前仍須在工作單內做逐呼叫點語意核對。
- 已完成：V9.1 `AppearanceRow` 候選比較、深色截圖現況核對及獨立工作單；使用者已批准 R／U／I，刪除按鈕與條件式單行欄已接入共用元件。位置、命中、Light／Dark、身體特徵及輸入待 GUI 驗收。
- 已完成：V9.1a 已建立 `SharedUI` 語意資源／tokens，並將既有 `InsetTextEditor`、`PlanningActionStyle` 宣告集中；主機無簽章 Debug build 通過，V9.1 試行畫面尚未接入。
- 已完成：V9.1b 把六個功能 View 檔共 24 處相同的低對比背景色改由 `SailuneTheme.subtleSurface` 提供，原有值、形狀與互動不變；本批未執行 GUI 驗收或程式測試。
- 已完成：V9.1c 把已跨三個功能檔使用的搜尋欄位移入 `SharedUI`，七個呼叫點統一使用 `SailuneSearchField`；圖標與底色由語意資源提供，主機 Debug build 通過。
- 已完成：V9.1d 依刪除語意接入 35 個畫面圖標呼叫點；資料刪除、移除持有人與移除封面分別命名，保留同一原有字形。其後 `AppearanceRow` 一處也依批准的試行接入 `.delete`，主機 Debug build 通過。
- 已完成：V9.1e 讓 48 個取消、10 個儲存按鈕共用 `SailuneActionCopy`；兩個既有儲存圖標引用 `SailuneSymbol.save`。建置產物中的中文值與原文案相同，主機 Debug build 通過。
- 已完成：V9.1f 讓 47 個刪除／新增／關閉 Button 或 Label 呼叫點引用共用文字資源；三個原有圖標引用對應語意 key，建置產物中的中文值不變，主機 Debug build 通過。
- 已完成：V9.1g 讓 33 個新增圖標及一個地圖放大圖標分別引用 `.add`／`.zoomIn`，原有 `plus` 字形不變，主機 Debug build 通過。
- 已完成：V9.1h 讓 12 個 `xmark` 畫面圖標依關閉、取消、移除 AI 選取、解除事件角色關聯及刪除時間分類，保留原字形，主機 Debug build 通過。
- 已完成：V9.1i 讓八個 `minus.circle` 與四個 `checkmark` 圖標分別按解除關聯／移除紀錄、確認／已選取狀態引用語意表；字形不變，主機 Debug build 通過。
- 已完成：V9.1j 讓七個重新命名／編輯的 `pencil` 圖標引用 `.edit` 語意 key，原字形與 action 不變；主機 Debug build 通過。
- 已完成：V9.1k 讓九個搜尋／設定／更多入口引用具名圖標，並使原未使用的 `.more` 對齊兩個既有 `ellipsis.circle` 入口；字形未改，主機 Debug build 通過。
- 已完成：V9.1l 把六個設定頁相同的原生多行編輯器邊框組合接入 `SailuneBorderedTextEditor`；原 Binding、尺寸與 modifier 順序不變，主機 Debug build 通過。
- 已完成：V9.1m 讓六個一般單行 V5 設定欄位接入 `SailuneFormTextField`，原 title、Binding 與原生圓角樣式不變；主機 Debug build 通過，特殊 focus／容器樣式未遷移。
- 已完成：V9.1n 將書籍背景彈窗現有 28 pt 關閉圖標按鈕抽為 `SailuneIconButton`；其後 `AppearanceRow` 刪除按鈕也依批准的 U／I 接入，目前共兩處。原 action 維持，主機 Debug build 通過。
- 已完成：V9.1o 把兩個故事背景編輯欄及兩個可點擊導覽卡片的重複 `0.08` 背景按用途接入語意 token，保留原色值、圓角與互動；AI 訊息、登入列及錯誤內容未因同色而混用。
- 已完成：V9.1p 把 15 個功能檔中的 32 個提示確認「好」按鈕接入 `SailuneActionCopy.acknowledge`；繁體中文值、closure、role 和快捷鍵不變，主機 Debug build 通過。
- 已完成：V9.1q 把九個檔中的 17 個流程結束「完成」按鈕接入 `SailuneActionCopy.done`；只統一標題來源，不合併各流程的儲存／關閉 action，主機 Debug build 通過。
- 已完成：V9.1r 將角色區五個無特殊 focus／提交行為的單行欄位接入 `SailuneFormTextField`；保留 title、Binding、圓角樣式與列內次序，主機 Debug build 通過。具 rename focus 的別名名稱欄與垂直事件摘要欄保留專用實作。
- 已完成：V9.1s 將能力階段、物品及關係歷史五個一般文字欄位接入 `SailuneFormTextField`；保留 title、Binding、modifier 與 `updatedAt` 觸發，主機 Debug build 通過。
- 已完成：V9.1t 將五個「新增節」圖標接入 `SailuneSymbol.addSection`，保留 `doc.badge.plus` 與 action。
- 已完成：V9.1u 將八個返回導覽圖標接入 `SailuneSymbol.back`，保留各處返回文案與 action；前往上一節仍用獨立圖標語意。
- 已完成：V9.1v 將四個欄位與前置資料要求提示接入 `SailuneSymbol.requirementNotice`，原文字與圖形不變。
- 已完成：V9.1w 將能力、物品、資源與勢力層級圖標集中為領域語意 key，原字形與各操作不變；AI 助手的 `sparkles` 繼續獨立。
- 進行中：依使用者新增要求建立 V9.1x 欄位首行／圓角安全內距稽核；已將具體繪製安全區、單／多行 inset 責任及驗收案例納入工程與 UX 規則。兩個 editor wrapper 的 inset 結構不同，但尚無故障畫面的直接證據；先核對呼叫點並取得重現步驟，不臆改欄位外觀。
- 已完成：V9.1y 將三個警告狀態的 `exclamationmark.triangle.fill` 呼叫接入 `SailuneSymbol.warning`；原圖標、文字、顏色與顯示條件不變，靜態引用數由 144 增為 147，直接系統圖標字串由 138 降為 135。
- 已完成：V9.1z 將三個時間序控制的 `clock` 呼叫接入 `SailuneSymbol.timeline`；原空狀態、accessibility label、圖形與行為不變，靜態引用數由 147 增為 150，直接系統圖標字串由 135 降為 132。
- 已完成：V9.1aa 將四個進入下層的 `chevron.right` 接入 `SailuneSymbol.disclosure`；時間軸末端表延續方向的第五處保留例外，引用數由 150 增為 154，直接系統圖標字串由 132 降為 128。
- 已完成：V9.1ab 將三個 `plus.circle` 與三個 `plus.circle.fill` 接入分開命名的圓形新增語意 key，保留填色差異與所有按鈕／選單行為；引用數由 154 增為 160，直接系統圖標字串由 128 降為 122。
- 已完成：V9.1ac 將三個相同「新增卷」入口的 `folder.badge.plus` 接入 `SailuneSymbol.addVolume`；文案、控制形式與 action 不變，引用數由 160 增為 163，直接系統圖標字串由 122 降為 119。重複 `doc.text` 已核實包含不同用途，先記錄例外，不合併節標記及空狀態。
- 已完成：V9.1ad 將兩處「匯出 TXT」入口接入 `SailuneSymbol.exportText`，而節標記與空白狀態的 `doc.text` 保留獨立用途；引用數由 163 增為 165，直接系統圖標字串由 119 降為 117。
- 已完成：V9.1ae 將四處故事線、三處角色關係及兩處 EPUB 匯出圖標接入語意資源；書籍總覽與編輯器的 TXT／EPUB 匯出標題共四處改用相同文字鍵，既有字形與繁體中文不變。圖標引用數為 174，直接系統圖標字串為 108，主機 Debug build 通過。
- 已完成：V9.2a 將 `WritingReferenceScanner`、`InspectorSectionNameMatcher`、`CharacterDetailPreviewOrdering` 從大型 View 檔移至獨立責任檔，保留原 API／呼叫點；主機 Debug build 通過。
- 已完成：V9.2b 將角色正文參照同步流程與候選資料移至 `CharacterReferenceSynchronizer.swift`；審核 View 保留在 `InspectorViews.swift`，原呼叫點與資料保存順序不變，主機 Debug build 通過。
- 已完成來源碼稽核：V9.2c 將能力建立的主保存／link／補償失敗，與地圖查詢吞錯對顯示、驗證及寫入的影響列為獨立 R／U／I 草案；尚未核定產品失敗政策或修改功能程式。
- 已完成：V9.2d 把 `TimelineDateProjection` 及五個日期投影資料型別／累積器從 `TimelineViews.swift` 逐字搬至專責檔，保持原 API 與演算法；主機 Debug build 通過。
- 已完成：V9.2e 讓勢力承接與勢力關係建立的重複檢查查詢失敗由既有 throwing API 傳至 View 錯誤提示，避免當作空清單後繼續插入；主機 Debug build 通過。
- 已完成：V9.2f 在完整備份匯出時，若封面或地圖目錄存在卻無法列舉，沿既有 throwing API 回報錯誤；不存在仍可沒有該資產，主機 Debug build 通過。還原 rollback 另待高風險切片處理。
- 已完成：對當時剩餘 55 處 `try?` 逐用途靜態分組，記錄於 `docs/v9-error-suppression-audit.md`；V9.2h 後為 48 處，V9.2j 後為 46 處，V9.2k 後為 45 處，V9.2c 診斷批次後 21 處，V9.2y 後 19 處，V9.2z 後 17 處，V9.2ab 後 15 處，V9.2ae 後 13 處，V9.2aj 後 10 處，V9.2ak 後目前 9 處。還原 rollback、跨 Store 建立補償與決策型查詢優先，解碼 fallback 和取消睡眠不可只因語法相同就機械改寫。
- 已完成：V9.2ab 將時間軸與大綱兩處相同的規劃投影空清單 fallback 集中到 `PlanningRecordProjectionBuilder.buildForDisplay`；失敗記錄來源與原因，原顯示結果及 throwing `build` 契約不變，主機 Debug build 通過。
- 已完成來源碼與文件差異核對：V9.2g 指出還原搬回原檔失敗被吞掉、可能清除仍含原檔的 rollback 目錄，而啟動訊息卻宣稱「原資料已回復」；需求／錯誤流程草案已獨立建單，R／U／I 尚待核定。
- 已完成：V9.2h 讓 AI 設定分析快照的七個主 store 查詢錯誤經既有附件送出 catch 回報，不再視為空資料；V9.2i 讓同一勢力分析附件中的設定 store 讀取改走可拋錯入口，保留既有畫面列表 API。兩批主機 Debug build 通過，未執行故障注入或 GUI 驗收。
- 已完成：V9.2j 讓地點與世界條目刪除先成功讀取清理所需關聯；查詢失敗即記錄並停止，不改原資料。主機 Debug build 通過；保存失敗與錯誤呈現仍待後續流程設計。
- 已完成：V9.2k 把啟動資料目錄建立錯誤接到既有 `StartupStageError`，在備份還原與 store 開啟前回報；原正式／DEBUG 路徑不變，主機 Debug build 通過。
- 已完成：V9.2l 把 `PowerHierarchyError`、`PowerHierarchyStore`、`PowerGraphStore` 從同時保存歷史 schema／一般設定 Store 的檔案移至專責檔；三段正文與原版逐字一致，主機 Debug build 通過。
- 已完成：V9.2m 把地點／世界條目搜尋及側邊欄目錄預設列／選取規則移至各自專責檔；兩段正文與原版逐字一致，Store／View 呼叫點不變，主機 Debug build 通過。
- 已完成：V9.2n 把角色未連結文字審核 View 與專用 AppKit 組字欄位封裝移出 `InspectorViews.swift`；原畫面本文、Binding／closure 與呼叫點不變，主機 Debug build 通過。
- 已完成：V9.2o 讓地圖／版本刪除的必要查詢在模型修改前完成並傳遞錯誤；`MapManagementViews` 原 catch 不變，主機 Debug build 通過。其餘地圖決策讀取仍屬 V9.2c。
- 已完成：V9.2p 讓地圖／版本建立與改名、標記目的地配對的地圖／版本查詢在寫入前傳遞錯誤；原有管理與跳轉 catch 不變，主機 Debug build 通過。首次初始化、來源標記查詢及畫面列表仍屬 V9.2c。
- 已完成：V9.2q 讓首次地圖初始化先完成 profile／地圖／版本／placement／Place 必要查詢再插入資料；從地圖建立標記的 Place 排序讀取也改為可拋錯。主機 Debug build 通過，來源標記讀取及畫面列表仍屬 V9.2c。
- 已完成：V9.2r 讓標記跳轉前的 Place／placement 來源查詢可拋錯且核對關聯；既有跳轉錯誤出口不變，主機 Debug build 通過。標記編輯與畫面列表的吞錯仍屬 V9.2c。
- 已完成：V9.2s 讓既有標記編輯重用可拋錯來源查詢，來源缺失或查詢失敗不再轉成新增；主機 Debug build 通過。標記刪除與畫面列表仍屬 V9.2c。
- 已完成：V9.2t 將標記刪除的 Place／placement 查詢與保存錯誤傳至地圖既有提示；依使用者決定維持確認後關閉。保存失敗後 context rollback 尚未核定。
- 已完成：V9.2u 將事件卡片呈現資料與來源節錄投影從 `TimelineViews.swift` 逐字移至 `TimelineCardProjection.swift`；原卡片與面板呼叫點不變，主機 Debug build 通過。
- 已完成：V9.2w 將事件建立所用 `TimelineOutlineSourceProjection` 從 `TimelineViews.swift` 移至專責檔；來源宣告與 HEAD 原文逐字一致，呼叫／測試 API 不變，主機 Debug build 通過。
- 已完成：V9.2x 將年號管理、年號列及改元／編輯 popover 移至 `TimelineEraManagementViews.swift`；跨檔存取層級依範圍調整，保留 Store 協作與操作順序，主機 Debug build 通過。
- 已完成：V9.2aa 將角色卡片時間投影與主時間軸顯示事件列移至 `CharacterTimelineProjectionView.swift`；跨檔顯示名稱輔助函式只調整存取層級，保留呈現與保存流程，主機 Debug build 通過。
- 已完成：V9.2ac 將地點與世界條目兩個清單及兩個詳情 View 從 `V5SettingViews.swift` 移至 `PlaceWorldTermViews.swift`；467 行搬移段落與搬移前工作樹一致，原綁定、操作與畫面不變，主機 Debug build 通過。
- 已完成：V9.2ad 將剩餘的側邊欄管理與勢力管理畫面分別移至 `SidebarSettingsManagerView.swift`、`PowerSettingViews.swift`，原 `V5SettingViews.swift` 由兩個具名檔取代；78 行及 910 行宣告保留搬移前正文，主機 Debug build 通過。
- 已完成：V9.2ae 將改元接續提示的最後紀元與最後年份查詢失敗記入 private OSLog，保留原空提示／第 1 年 fallback；主機 Debug build 通過，剩餘 `try?` 靜態命中 13 處。
- 待核定：V9.1af 四組上下移動控制的圖標與操作名稱提案已列出精確畫面、原 action／style／禁用邊界與文字線框；U 核定前不修改圖形。
- 已完成：V9.1ag 將作者設定與書櫃兩個筆名欄、物品副本名稱及角色勢力職稱共四個單行欄位接入 `SailuneFormTextField`；原 Binding、文字、外層字體／保存觸發及版面不變，主機 Debug build 通過。
- 已完成：V9.2af 將角色親屬關係圖與新增血緣關係 sheet 的 284 行宣告從 `InspectorViews.swift` 移至 `KinshipGraphViews.swift`；原查詢、操作及畫面不變，主機 Debug build 通過。
- 已完成：V9.2ag 將物品清單、詳情、副本詳情與等級編輯六個 View 的 647 行宣告移至 `ItemInspectorViews.swift`；僅三個跨檔入口調整可見度，原物品操作與畫面不變，主機 Debug build 通過。
- 已完成：V9.2ah 將能力清單、詳情與補償失敗 logger 從 `InspectorViews.swift` 移至 `AbilityInspectorViews.swift`；兩個跨檔入口調整可見度，建立／刪除及錯誤出口不變，主機 Debug build 通過。
- 已完成：V9.2ai 將角色清單、詳情、勢力成員、參照區段與出生日期欄等九個 View 的 1021 行宣告移至 `CharacterInspectorViews.swift`，根導覽保留；宣告正文逐字相同，主機 Debug build 通過。
- 已完成：V9.1ah 三個時間格刪除按鈕的 help／accessibility label 共六個字面值改由既有 `SailuneActionCopy.deleteTime` 提供；繁體中文、圖標與原 action 不變，主機 Debug build 通過。
- 已完成：V9.1ai 將能力詳情頁名稱、等級名稱、描述、代價與其他五個相同圓角單行欄接入 `SailuneFormTextField`；原 Binding、更新時間、順序與版面不變，主機 Debug build 通過。共用單行欄位目前 26 處。
- 已完成：V9.1aj 將物品新增、詳情、歷史與等級編輯六個相同圓角單行欄接入 `SailuneFormTextField`；原 Binding、驗證與資料操作不變，主機 Debug build 通過。共用單行欄位目前 32 處。
- 已完成：V9.1ak 將新建書籍／總覽的書名與作者、故事線名稱五個圓角單行欄接入 `SailuneFormTextField`；原 Enter、更新時間、字級與保存不變，主機 Debug build 通過。共用單行欄位目前 37 處。
- 已完成：V9.2aj 將 backend、Gemini interaction 與 model output 三處 AI 回應解碼失敗加入 private OSLog；原 `nil`／`invalidResponse` 結果不變，主機 Debug build 通過。目前 `try?` 靜態命中 10 處。
- 已完成：V9.2ak 將自訂封面缺檔與已存在封面讀取／解碼失敗分開診斷，維持預設封面 fallback；主機 Debug build 通過。目前 `try?` 靜態命中 9 處。
- 已完成：V9.1al 讓 AI 閱讀範圍及角色資訊整理的入口與已選摘要各共用同一語意圖標；四處字形、文案和動作不變，主機 Debug build 通過。
- 待核定：V9.1am 依使用者地點「簡介」截圖定位到 `SailuneBorderedTextEditor` 首行安全距不足；已提出保留外框／背景／資料行為、由共用元件負責 9 pt 水平及 8 pt 垂直內距的 U 方案。U 核定前不修改畫面。
- 已完成：V9.1an 書籍與地圖兩個匯出選單引用同一 `.export` 圖標，發布及格式專用圖標保留獨立語意；主機 Debug build 通過。此項完成後依使用者指示凍結 V9 逐項盤點基準，不再以新發現的單點自動擴張。
- 已完成：V9.2v 將能力進度、物品副本與故事規劃 Store 共七處 rollback 後重載失敗改為明確 OSLog 記錄，保留主要錯誤出口；主機 Debug build 通過，目前 `try?` 命中降至 38。
- 已完成限定決策：V9.2c 依使用者決定只記錄能力補償保存及 16 個列表查詢錯誤、保留原操作結果；V9.2g 只改還原失敗文字；V9.2t 讓標記刪除的查詢／保存錯誤顯示於地圖既有提示並保留確認後關閉。主機 Debug build 通過；rollback 及部分操作結果語意仍待另議，目前 `try?` 命中為 21。
- V9.0a／0b 盤點階段只做唯讀程式與文件整理；後續 V9.1a／1b 的程式變更各由獨立工作單管理。

## 現況與問題

- `docs/coding-standards.md` 已涵蓋命名、View 職責、狀態管理、SwiftData、錯誤處理及測試原則；尚未完整說明功能模組的責任邊界、依賴方向、跨 store 流程設計及整理既有程式的判斷準則。
- `docs/ux-principles.md` 記錄產品互動原則；按鈕有效命中範圍、重疊視圖的事件接收、視覺裁切與 hit-testing 的差異，以及多種手勢共存方式仍可更具體。
- V7 地圖經過多次命中區、拖曳／平移競爭和 viewport 邊界修正。這些案例適合作為 UI 規則與驗收案例的依據。
- `InspectorViews.swift`、`TimelineViews.swift`、`OutlineViews.swift`、`V5SettingModels.swift` 等檔案較大，可作責任與耦合度稽核候選；檔案行數本身不作為拆檔或重構依據。
- `docs/architecture.md` 與 `docs/testing.md` 已記錄部分執行結構和測試策略；規劃時需避免重複建立互相矛盾的規則來源。

## 範圍草案

### 納入

1. **內部程式規則**：模組／型別責任、依賴方向、View／Store／協調器／純邏輯分工、狀態生命週期、副作用入口、actor 隔離、錯誤回報與共用邏輯位置。
2. **UI 互動規則**：控制項與整列的命中範圍、按鈕位置與群組、重疊層級與事件攔截、視覺裁切和互動邊界、點擊／拖曳／縮放等手勢競爭、圖示按鈕的輔助功能名稱、載入／錯誤／禁用狀態。
3. **共用 UI 程式碼與語意資源**：盤點按鈕、文字欄位、多行編輯器、背景／表面顏色、表單區塊、圖標、功能名稱／提示文案及新增／刪除／確認等重複動作；定義集中實作位置、語意 variants、文字／圖標對照與所有呼叫端的採用策略。
4. **文件責任分配**：決定哪些穩定規則放在 `coding-standards.md`、`ux-principles.md`、`architecture.md`、`testing.md` 或功能規格，指定單一規則來源並以連結避免複製漂移。
5. **現有程式稽核方法**：按責任混雜、依賴耦合、重複邏輯／視覺／操作、錯誤風險、測試難度及修改牽連程度建立候選清單與優先級，不以檔案大小單獨排序。
6. **採用與遷移策略**：新程式先呼叫已核定的共用元件／操作；既有程式依風險分區逐步遷移，避免全專案一次性重寫。

### 明確不納入

- 本工作不修改 Swift／SwiftUI 功能程式、資料模型、schema、遷移或正式作者資料。
- 本工作不要求一次拆分所有大型檔案，也不以統一格式為由改寫穩定模組。
- 本工作不改變產品功能、已批准 UI 行為或使用者可見文案。
- 不強迫所有不同語意的控制項共用同一外觀；按鈕、欄位與編輯器以共用基礎元件加明確用途 variants 實作。原生正文 `NSTextView` 等需要特殊輸入行為的控制項保留專用實作，能共用的色彩與設計 tokens 仍由共用來源提供。
- 共用刪除／確認外殼不接管各領域刪除規則；確認文案、影響範圍及實際 Store／Coordinator action 由領域呼叫端明確提供。
- 後續實際模組整理與功能變更須依各自工作單和 R／U／I 狀態處理，不由本規劃自動授權。

## 建議文件納入方式

- `coding-standards.md`：加入程式分層、依賴、狀態／副作用及漸進整理準則；加入 UI 控制項命中與手勢實作的工程規則，或連結到 UI 原則中的唯一正式條目。
- `ux-principles.md`：細化可觀察的互動契約，例如哪個區域可點、點擊是否穿透、拖曳何時成立，以及重疊控制如何保持可操作。
- 共用 UI 元件與語意資源：依盤點結果建立集中 source of truth，統一按鈕語意樣式、欄位／多行編輯器基礎外觀、surface／background／feedback tokens、功能對應圖標與一致的標題／按鈕／tooltip／accessibility 文案，以及重複確認操作的共用呈現；各功能 View 統一呼叫這些元件／資源，不複製 style modifier、顏色常數或同義文案。
- `architecture.md`：補足模組責任地圖、允許的依賴方向及跨 store 協調原則；只記架構事實與已核准決策，不放通用編碼風格。
- `testing.md`：補充各類規則如何驗證，尤其是複雜 hit-testing／手勢使用人工冒煙，純資料轉換使用可測試邏輯；不以脆弱的純像素／版面測試取代使用者流程驗證。
- `docs/README.md`：提供 V9 規劃文件索引；規範核定後再連至正式規範來源。

以上為 V9.0b 文件更新提案；正式文件已按使用者指示加入 V9 規則。其後 V9.1a～1d 已建立部分共用 API 並接入搜尋欄位及刪除圖標；按鈕／一般欄位／編輯器完整 variants 仍未完成，尺寸與間距尚未經 `AppearanceRow` 畫面驗收。

## 規劃工作拆解

1. 對照 coding standards、UX principles、architecture、testing、development workflow 與 V7 地圖修正案例，整理已涵蓋、缺漏、重複及互相衝突的規則。
2. 以規則主題撰寫提案，每條說明適用情況、建議原則、例外處理與可檢查的完成條件；使用 V7 實例示範 UI 命中和手勢要求。
3. 稽核主要功能區的責任、依賴、跨 store 流程、重複邏輯、測試難點及回歸風險，形成分階段優先序；本階段只讀取和整理，不改程式。
4. 提出採用方式及文件變更清單，確認正式規則來源、既有程式的漸進遷移原則及後續整理是否另立工作單。
5. 使用者確認規範提案後，才將其納入正式文件；若後續要修改功能程式，另行提出具體模組、驗收條件及測試計畫。

## 建議版本路線與實作流程

以下 V9.x 是本次工程規則化工作的里程碑名稱，不自動代表 App 的 marketing version，也不改變 SwiftData schema 版本。是否將 App 發布版本命名為 V9，仍依產品發布決策處理。

### V9.0 盤點時採用的固定檢查表

每個功能區均以相同欄位盤點，避免只看檔案長度或主觀感受：

1. **責任邊界**：每個 View／Store／服務／模型負責哪些行為；有沒有一個型別同時處理呈現、查詢、資料修改和流程協調。
2. **依賴方向**：依賴由 UI 流向資料操作層是否清楚；模組間是否存在反向依賴、循環或重複的資料規則。
3. **狀態與副作用**：狀態存活範圍是否明確；寫入、檔案操作、通知、非同步工作是否由明確事件觸發並有錯誤出口。
4. **資料一致性**：SwiftData 關係、UUID 跨 store、刪除／修復／遷移／備份是否有單一責任者與既有驗證。
5. **UI 互動契約**：控制項命中範圍、遮罩與疊層接收事件、裁切區、手勢優先級、鍵盤與輔助功能名稱是否明確。
6. **可驗證性**：純邏輯能否獨立測試；整合流程是否覆蓋失敗、重試、取消和跨書隔離；UI 是否有必要人工驗收。
7. **修改牽連**：一項小改動需觸及多少責任不相關的型別、模組或測試；共用規則修改是否容易造成回歸。

首輪盤點按功能邊界覆蓋：書櫃／書籍總覽、正文編輯器、設定集與角色詳情、敘事大綱、世界時間軸、地圖工作區、AI 助手，以及 store 啟動修復／跨 store 刪除／備份遷移。逐區依文件和實際程式追蹤，不代表每個區域都要重構。

### 稽核排序方式

- **P0**：可能造成資料遺失／跨書污染，或已知操作會被錯誤命中、錯誤執行；先明確責任與防護，再排修正工作單。
- **P1**：功能責任混雜、跨層依賴或重複規則已使常見需求牽動多個區域，且可用有限切片降低風險。
- **P2**：命名、檔案切分或表現方式不一致，但目前沒有明顯錯誤風險或顯著拖慢變更。

每個候選記錄證據、影響範圍、觸發頻率、回歸風險、可隔離程度與預估驗收方式；不以行數設定硬門檻。排序結果由使用者確認後，才成為後續工作批次。

### 內部程式第二輪具體候選（2026-09-23）

| 候選 | 程式證據與目前風險 | V9 建議工作邊界 |
|---|---|---|
| 能力建立的跨 store 補償 | `InspectorViews.swift` 的 `addAbility()` 先保存主 store 能力，再呼叫 `AbilityProgressStore.register` 保存書籍連結；後者失敗後，刪除主 store 能力的第二次 `modelContext.save()` 使用 `try?`。若補償保存也失敗，畫面只呈現第一個錯誤，主 store 可能留下無書籍連結的能力。現有 `CrossStoreDeletionCoordinator` 測試涵蓋主操作／附屬清理結果，但不等於此建立流程已驗證。 | 優先建立獨立 V9.2 工作單：明確定義主保存、連結失敗與補償失敗的三種結果，將流程交由具名協調責任者，保留可診斷錯誤與修復路徑；修改前核對既有修復邏輯、產品規格及跨 store 測試。這是靜態風險候選，尚未重現失敗。 |
| 地圖清單查詢錯誤被呈現為空資料 | `MapCatalog.swift` 的 `maps`、`versions`、`placements` 查詢以 `try? fetch(...) ?? []` 回傳；查詢失敗與真的沒有地圖共用空陣列結果。 | 另立有界工作單，先追蹤所有呼叫端的載入／空狀態，再設計可傳遞錯誤且不破壞正常空清單的 API。不可只把 `try?` 機械改成 `try`。 |

兩項都涉及可觀察錯誤或資料一致性；本輪只完成靜態稽核與排序建議，沒有改動資料流程或宣稱已重現缺陷。

## V9.0a 第一輪盤點結果

> 盤點方式：閱讀既有規範文件、架構與測試策略，靜態檢視主要 Swift 型別、狀態／資料依賴與 UI 手勢使用點。以下是規劃階段觀察，不是程式缺陷判定；未執行 App UI 操作、建置或測試，也未修改功能程式。

### 文件規範覆蓋矩陣

| 主題 | 現有正式來源 | 目前覆蓋 | V9.0a 發現的缺口／重疊 |
|---|---|---|---|
| Swift 命名、檔案、註解、View 與資料責任 | `coding-standards.md` | 有基礎命名規則及「View 呈現、資料操作放 Store／服務」原則 | 缺少如何判斷一個 View／Store 職責已混雜、拆分時如何維持垂直流程完整的操作準則 |
| 模組責任與依賴地圖 | `architecture.md`、`coding-standards.md` | 架構文件按主要檔案記錄現況責任；coding standards 提供通用方向 | 邊界有描述但缺少允許／禁止的依賴方向及跨模組接口檢查表；兩份文件需區分「現況描述」與「規範要求」 |
| 狀態、副作用、非同步與 actor | `coding-standards.md`、`architecture.md` | 已指出 `@State` 用途、避免 `body` 副作用、actor 隔離原則 | 尚缺可審查的狀態生命週期分類、非同步操作取消／失敗出口及 UI 對 Store 直接寫入的判斷準則 |
| SwiftData、跨 store、遷移與刪除 | `coding-standards.md`、`data-model.md`、`backup-and-migration.md`、`consistency-audit.md` | 資料與相容性規則相對完整，含 UUID、快照、冪等回填、刪除及備份原則 | 文件需明確規定哪份是規範權威、哪份是資料現況；一般程式拆分不得移動／改寫歷史 schema snapshot |
| UI 原則與互動 | `ux-principles.md`、`coding-standards.md`、功能規格 | 已有低干擾、一致性、響應式定位、空白處關閉與 Enter 提交規則 | UI 產品原則與 SwiftUI 工程寫法有重疊；hit-testing 範圍、事件穿透、層疊接收者、手勢優先級和鍵鼠驗收需整理為明確契約 |
| 錯誤處理與復原 | `coding-standards.md`、`architecture.md`、各功能規格 | 已要求錯誤可見、資料安全及跨 store 復原；各模組另有流程說明 | 缺少可共用的錯誤分類、操作失敗後 UI 狀態／重試責任及禁止靜默失敗的審查例子 |
| 測試與人工驗收 | `testing.md`、`coding-standards.md`、`development-workflow.md` | 已有資料、文字、遷移、跨 store 和 UI 冒煙原則 | `testing.md` 與 coding standards 各自重複一般測試要求；需要清楚分開規則、測試方法和專案目前測試缺口 |

### 功能區責任與整理訊號

| 功能區 | 已觀察到的責任／邊界 | 稽核訊號 | 暫定順位 |
|---|---|---|---|
| 書櫃與書籍總覽 | `ContentView` 管導覽及書籍入口；`BookOverviewView` 另含書籍資訊、卷節樹、拖曳排序、刪除和匯出入口 | 同檔含數個子 View 與互動流程；需核對重用狀態和資料操作是否仍限於單一清晰區域 | P2 盤點；目前無足夠證據列為重構工作 |
| 正文編輯器 | `EditorWorkspaceView` 組合工作模式、目錄、Inspector／AI 導航和工作區；`RichEditorView` 封裝 AppKit `NSTextView`、輸入法、文字選取與正文連動 | SwiftUI 工作區協調器與 AppKit 文字橋接已分檔；需盤點跨節儲存、選取跳轉及 Undo 的接口契約 | P1 盤點；以正文資料安全與跨模組回歸為主，不預設拆分 |
| 設定集／角色詳情 | V9.0a 盤點時 `InspectorViews.swift` 約 3,100 行，含掃描／matcher／preview 投影、Inspector 路由、列表、角色詳情、關係圖與新增 sheet；其中三個投影型別已在 V9.2a 移至獨立檔案。`CharacterSectionViews.swift` 約 980 行，部分 View 直接使用 `ModelContext`、多個 `@Query` 和 feature store | 多種設定頁責任集中，部分呈現與保存責任相鄰；需依資料種類追一條完整 CRUD／刪除流程，確認哪些邏輯重複或適合抽離 | P1 盤點；試行候選之一，待比較修改牽連與隔離度 |
| 敘事大綱與時間軸 | `OutlineViews.swift` 約 2,100 行；`TimelineViews.swift` 約 2,760 行並含 Workspace Inspector、時間投影、面板、卡片、編輯與角色時間序投影；部分純投影已抽到具名型別 | 同檔包含呈現和投影邏輯；需追蹤 projection 輸入、Store 寫入者、跨大綱／時間軸一致性及既有測試落點 | P1 盤點；避免同一批同時重整大綱和時間軸 |
| 地圖工作區 | `MapViews.swift` 約 980 行；座標轉換在 `MapCoordinate.swift`，catalog 操作在 `MapCatalog.swift`，PDF／資產各有專責檔案 | 模型／幾何／資產已有分層；主要風險在 SwiftUI hit-testing、疊層與手勢互動。規格和 V7.4a／V7.4b 紀錄有具體回歸案例 | P1 互動規則試行候選；還需確認內部依賴重整價值 |
| AI 助手 | 聊天側欄、ViewModel、client、models／context、conversation store 分檔；正文及設定內容以快照傳遞 | 已呈現相對明確的 ViewModel／Client／資料快照分工；作為較成熟對照組，盤點取消、上下文組裝、對話儲存與錯誤責任 | P2 對照樣本；除非稽核發現具體風險，不優先重構 |
| Store 修復、跨 store 刪除與備份 | `PersistentStoreRepair.swift` 約 850 行，含修復、模型刪除操作與跨 store coordinator；`SailuneBackupService.swift` 約 360 行，處理多 store snapshot、manifest、資產及還原 | 資料安全責任集中且風險高；優先確認流程邊界、失敗／重試矩陣及測試對應，不因行數先做大拆分 | P0 先完成責任／失敗模式盤點；若無已知缺口，不直接安排重構 |
| Schema 與模型 | `V5SettingModels.swift` 約 3,300 行，內含 settings V1–V13 歷史快照、目前模型、migration plan 與 store／領域操作；其他 schema 亦與模型放在各自檔案 | 歷史快照與目前領域操作同檔，但歷史 schema 需保持不可變；拆分的安全邊界必須明訂 | P0 設定相容性規則；先只改善文件責任，不搬動快照 |

### 首輪優先結論

1. **P0：把資料安全不變條件列成重構硬門檻**。包括各 store 所有權、跨書 UUID 驗證、刪除／修復失敗語意、備份還原及 schema 快照不可變性；目前是風險盤點優先，不代表已發現資料損壞。
2. **P1：細化 UI 事件與 hit-testing 規則**。V7 的實際案例及 `MapViews` 的 `contentShape(.interaction, ...)`、`clipShape`、`allowsHitTesting`、`zIndex`、多手勢組合證明需把視覺邊界和輸入邊界分開驗收。
3. **P1：沿一項 Inspector／Timeline 流程追責任鏈**。大檔案內確實存在多個 View／純邏輯型別，且部分 View 直接觸及 model context 或多個 feature store；需查看一條具體流程後再判斷抽離，不先建立普遍的 View 禁止直接保存規則。
4. **對照樣本：保留 AI 與 MapCoordinate／MapCatalog 的既有分工作比較**，抽取有效模式，不為追求一致而將成熟邊界重新包裝。

### 代表性呼叫鏈與測試對照

| 流程 | 程式責任鏈觀察 | 現有驗證落點 | 規範提案需處理的問題 |
|---|---|---|---|
| 地圖 placement 與跳轉 | `MapWorkspaceView` 讀取 store 狀態、呈現地圖互動；`V5SettingsStore` 的 `MapCatalog.swift` extension 查詢／儲存 map、version、placement 並執行導航配對；座標數學在 `MapCoordinate.swift`；檔案資產在 `BookMapPDFStore` | `MapV7Tests.swift` 覆蓋座標、viewport、catalog、遷移及跳轉邏輯；地圖 UI 手勢另依 V7 規格以隔離 App 冒煙驗收 | 幾何／catalog 有可測試邊界；純 SwiftUI hit-testing 與手勢互斥要用哪些人工情境證明，需明訂。另需確認 map catalog 的 fetch 失敗是否應和空清單區分；目前部分查詢以 `try?` 回傳空集合，這是錯誤呈現策略的稽核項，不在此判定為缺陷 |
| 角色事件 | `CharacterEventSectionView` 從多個 `@Query` 與三個 feature store 組裝 `CharacterTimelineProjectionBuilder`；新增時直接插入 `Event`／`Node`；刪除時呼叫 `CrossStoreDeletionCoordinator` | `CharacterDetailPreviewTests`／角色時間投影測試覆蓋純投影；`ItemV3Tests.swift`、`V42OutlineTests.swift` 涵蓋時間軸與跨 store 行為 | 明訂 View 何時可直接保存單一同 store 編輯，何時新增／刪除／投影應改由專用操作邊界負責；避免以「View 不可碰 ModelContext」一刀切，先按流程複雜度訂判斷準則 |
| 跨 store 刪除 | View 呼叫 `CrossStoreDeletionCoordinator`；協調器先保存主 store，再清理附屬 stores，回傳 deferred cleanup 狀態；`PersistentStoreRepair.run` 於啟動分段修復主 store 關係 | `V42OutlineTests.swift`、`V5SettingsTests.swift`、`ItemV3Tests.swift` 覆蓋不同模型、跨書隔離、冪等清理與失敗情境 | 現有 coordinator 是集中責任的正例；規範要保持主資料與附屬清理失敗的明確語意，並要求每個新跨 store 關聯有責任者、重試途徑與測試矩陣 |
| 備份還原 | `SailuneBackupService` 負責 manifest／checksum 驗證、備份、pending restore、重啟前置換與 rollback；App 啟動順序需在 ModelContainer 開啟前套用還原 | `ItemV3Tests.swift` 備份測試、啟動與還原流程文件 | 邊界相對集中；整理時保護安全備份、sidecar、checksum、rollback 及資產路徑驗證，不因拆分重複實作檔案策略 |
| AI 對話 | Sidebar 負責畫面，ViewModel 負責每書對話狀態／取消，Client 負責模型請求，快照組裝器負責選取範圍，ConversationStore 負責 JSON 持久化 | `SailuneAITests.swift` 覆蓋每書隔離、請求範圍、引用、取消與錯誤 | 可作為分層與值快照傳遞的對照樣本；規範要描述責任及契約，不要求所有模組照搬相同型別數量 |

### V9.0a 結論

- 已完成規範文件覆蓋初盤、8 個功能區靜態責任盤點、P0／P1／P2 候選排序，以及地圖、角色事件、跨 store 刪除、備份還原、AI 對話的代表性責任鏈／測試映射。
- 暫定最重要的文件缺口：依賴邊界和責任判定準則、狀態／副作用生命週期、失敗回饋策略、UI hit-testing／gesture 驗收、跨 store 相容性保護、測試文件職責分配。
- 尚未逐一檢查所有 view 或測試實作；本次是功能區風險盤點，不宣稱完整 code review，也沒有認定既有程式必須重構。
- **V9.0a 完成條件已達成**：形成文件矩陣、責任候選、排序依據與代表性呼叫鏈。V9.0b 條文已依使用者「繼續」指示納入權威工程文件，現進行實際呼叫點 inventory 和試行切片評估。

### 共用 UI 程式碼初盤（使用者追加範圍）

- 已有共用基礎：`AppTheme.swift` 定義 `Color.appBackground`、`Color.workspacePanelBackground` 及 `workspaceFloatingPanel()`；`CharacterSectionViews.swift` 定義 `InsetTextEditor` 並被 Inspector／角色歷史共用；多個區域使用系統 `.roundedBorder`／`.plain` 欄位和 SwiftUI 標準 ButtonStyle。
- 有局部共享但尚未建立一致的全域語意元件：`InsetTextEditor` 定義於 `CharacterSectionViews.swift`，已由角色設定、Inspector 和角色歷史區呼叫；`PlanningActionStyle` 定義於 `OutlineViews.swift`，並由 Outline／Timeline 共用。這表示可沿用既有需求，但需重新界定放置位置、責任和統一 API。
- 初步靜態搜尋（2026-09-23）在 `Sailune/` 發現 229 個 `.buttonStyle(...)` 呼叫、104 個 `TextField`、18 個 `TextEditor`、112 個 `Image(systemName:)`；共有 79 個 `.help(...)` 與 28 個 `.accessibilityLabel(...)` 呼叫。這些數字是搜尋命中數，不等同需要遷移的數量，也不代表其餘控制項缺少無障礙標籤。
- 按鈕 style 搜尋命中包括 `.plain` 111、`.borderless` 46、`.borderedProminent` 24、`.link` 5、`.bordered` 4，以及 `PlanningActionStyle` 39。呼叫集中度較高的檔案為 `InspectorViews.swift` 47、`TimelineViews.swift` 39、`V5SettingViews.swift` 39、`OutlineViews.swift` 26。
- 圖標初步統計：`trash` 18、`xmark` 11、`minus.circle` 8、`plus` 5、`checkmark` 3、`magnifyingglass` 3。相同 `xmark` 同時出現在關閉／取消語意和 Timeline「刪除這個時間」控制；先依功能語意核對，再決定是否共用或分開語意 key，不能機械換圖。
- 直接寫在 SwiftUI 呼叫中的重複短字串搜尋命中：`取消` 48、`好` 32、`刪除` 31、`完成` 17、`儲存` 10、`關閉` 7、`新增` 4。這是 literal 初篩，需逐處確認語意；目前未找到 `.xcstrings` 或 `Localizable.strings`，本地化／共用文案 key 尚無專門清單。
- `AppTheme.swift` 已集中 `appBackground`、`workspacePanelBackground` 與 `workspaceFloatingPanel`，但直接色彩／透明度／描邊仍散布多檔；特別地圖資料顏色與 canvas overlay 需分清語意，不能直接轉成一般 surface token。
- 欄位／編輯器有不同用途：一般短欄位、數字／日期欄、搜尋欄、多行敘述、聊天輸入與正文 `NSTextView` 的輸入／高度／提交語意不同，不應硬做成沒有 variants 的單一元件。
- 新增／刪除／確認：各功能有重複的按鈕、confirmationDialog／alert、錯誤狀態呈現方式，但刪除影響及 Store action 不同。可統一元件外殼和視覺／輔助功能，不得把領域資料操作合併成通用刪除邏輯。
- 下一步完成 component／resource inventory：將上述搜尋結果映射到操作語意與實際 View，列出逐呼叫點遷移表、鍵盤／組字／保存例外及建議 API；不把搜尋命中直接當遷移指令。

| 元件家族 | 現況代表 | V9 共用實作目標 | 預期例外／界線 | 暫定順位 |
|---|---|---|---|---|
| 按鈕 | 盤點時 `PlanningActionStyle` 在 `OutlineViews.swift`，已於 V9.1a 移至 `SharedUI`；其餘畫面混用系統 `.bordered`／`.borderedProminent`／`.borderless`／`.plain` 及自訂組合 | 集中 semantic style/component variants、命中區、標籤、hover／disabled／loading 狀態；各畫面呼叫同一實作 | Menu、Picker 及系統語意按鈕保留原生控制；整列導航與小型 icon action 用不同明確 variant | P1，適合 pilot |
| 單行欄位 | 大量直接使用 `.roundedBorder`／`.plain`；搜尋、數字／日期、inline rename 欄位分布多個功能檔 | 集中背景、邊框、字體、padding、focus/error 狀態；以用途 variants 保留輸入驗證和 onSubmit 差異 | AppKit 組字／特殊鍵盤欄位需獨立驗證，不強制替換系統控制 | P1 |
| 多行編輯器 | `InsetTextEditor` 已供部分角色及歷史欄位重用，V9.1a 已移至 `SharedUI`；大綱、設定集、作者資訊和聊天另有 TextEditor／composer 用法 | 整理固定高度／可擴展、placeholder、scroll／focus 等 variants，統一可共用的 surface 和內距 | 富文字正文 `NSTextView`、AI 聊天送出 composer 保留專用互動 contract | P1 |
| 顏色與表面 tokens | `AppTheme.swift` 已有動態 `appBackground`、`workspacePanelBackground` 和浮動 panel modifier；其他檔仍直接組合 system background、secondary／accent opacity 和形狀描邊 | 建立語意命名的角色 tokens／surface modifiers，統一淺深外觀、panel/card/border/selection/feedback 色彩 | 地圖底色、圖表線色或經產品確認的特殊可視化色用具名例外 | P1，底層先行 |
| 重複操作外殼 | 各功能自行組新增列、trash／minus icon、alert／confirmationDialog、取消／確認及錯誤提示 | 共用 icon action row、確認／刪除對話框、表單 action group 和錯誤回饋外殼；所有呼叫端沿用統一呈現／命中行為 | 標題、資料影響說明、儲存與刪除操作由領域層提供；不做通用 model delete helper | P1 |

遷移原則：先做元件家族與呼叫點清冊，選定 pilot，再用集中元件替換呼叫端；每種語意只保留一份樣式／互動實作，現有 raw modifiers 在完成遷移後逐步退場。搜尋只能找候選，必須逐個核對行為，避免把不同用途欄位或系統按鈕機械式換成同一元件。

### 本階段下一步

確認下方 V9.0b 條文和文件分工，再依確認內容更新正式規範；程式整理仍須另立 V9.1 試行工作單。

### V9.0b 正式規則條文草案

以下條文已依使用者指示納入正式工程文件。28 pt 等 UI 尺寸屬 V9 試行基準，程式採用前仍需以選定畫面驗收；未通過驗收時記錄調整理由，不機械套用。

#### A. 責任邊界與依賴

1. **每個操作有明確責任者。** 新增或整理一項功能時，須能指出讀取來源、執行寫入、維持不變條件及呈現錯誤的責任型別。資料一致性規則不可只存在於某一個 View 的操作 closure。
2. **View 可以做簡單、局部的同 store 編輯。** 單一模型欄位綁定或簡單建立／修改可留在 View；涉及多模型不變條件、批次／破壞性刪除、跨 store、重試／修復、遷移或多畫面共用的操作，放入明確的 Store／Operations／Coordinator 責任邊界。判斷依流程複雜度和重用性，不以「View 絕不可使用 `ModelContext`」一刀切。
3. **純投影保持純值輸入輸出。** 排序、過濾、座標、摘要投影等不需讀寫資料庫的邏輯，以值型別輸入與輸出；不在投影過程保存資料或讀取 SwiftUI 環境。
4. **依賴由組合端流向功能內部。** Store／服務不得依賴 SwiftUI View；跨功能呼叫透過明確參數、值型別結果或既有協調器，不直接操作另一功能的私有 UI 狀態。不得為了規則形式而替每個型別新增 protocol 或 wrapper。
5. **型別／檔案依單一可命名責任整理。** 一個檔案可含數個緊密相關的小型型別；需要拆分的依據是責任、依賴、修改牽連或測試邊界，不設定行數門檻。多版本 schema 歷史快照不可因程式整理改寫其欄位、關係或版本語意。

#### B. 狀態、副作用與錯誤

1. **狀態標出所有者與生命週期。** View 私有、短期狀態留在 View；跨畫面或跨操作流程共享的狀態放在明確的工作區／ViewModel／Store 所有者；持久化作品資料留在 model／store。狀態移動時要說明生命週期與重建行為。
2. **副作用由明確事件觸發。** 儲存、刪除、檔案讀寫、模型請求與跨 store 操作由具名 action／方法執行，不藏在 `body` 計算或無法重複辨識的 render side effect；啟動修復等生命週期工作須明示順序、冪等性及失敗出口。
3. **錯誤不能偽裝成空資料或成功。** `try?` 僅用於失敗可安全等同「沒有可選值」且不影響資料正確性的情境，並需由上下文／註解說明；查詢、保存、刪除、遷移、備份或清理若失敗會改變使用者決策或資料完整性，須回報明確錯誤狀態。回復失敗時保留診斷資訊。
4. **跨 store 操作聲明部分成功語意。** 指定主資料保存順序、附屬清理失敗如何記錄、重試／啟動修復方式及跨書隔離測試；不得暗示獨立 store 具備單一原子交易。
5. **非同步和 actor 邊界可追蹤。** UI／SwiftData 寫入依其 actor 隔離；長任務需定義取消、過期結果丟棄及錯誤呈現，不從背景工作直接改動 UI 或持久化模型。

#### C. UI 互動與命中規則

1. **每個控制項明確定義操作區域。** 需說明只有圖示／文字可點、整列可點，或包含更大的自訂命中區；命中區不得覆蓋相鄰操作或超出所屬互動容器。macOS 控制項不套用單一固定 hit target 尺寸；依控制用途、視覺尺寸、相鄰間距和實際指標／輔助操作驗收。
2. **視覺邊界與互動邊界分開驗證。** `clipShape`／`clipped` 只視為繪製裁切，除非明確設置並驗證 interaction shape；透明遮罩、浮層、放大內容和 viewport 要標明由誰接收點擊、是否阻擋背景。純裝飾層不得攔截操作。
3. **重疊層級有唯一輸入所有者。** 同一位置的按鈕、畫布、浮動控制與遮罩須定義 z-order 和事件接收者；點擊控制不能同時觸發底層畫布，空白遮罩需阻止穿透並執行已定義的取消行為。
4. **競爭手勢須寫成操作契約。** 點擊、拖曳、平移、縮放、hover 同時存在時，明訂啟動門檻、優先／同時辨識策略、操作成功／取消後狀態清理和邊界行為；以真實 GUI 情境驗證，不以純幾何單元測試取代命中驗收。
5. **按鈕位置依父容器排版。** 與視窗、版面或畫布邊緣比較的定位依父容器可用尺寸、比例和上下限計算；固定點數只用於元件尺寸、間距及最低可讀邊界。不得以固定 `offset` 模擬跨區定位。
6. **圖示操作可辨識且有狀態回饋。** 純圖示控制需提供正確 accessibility label；語意不直觀時加 tooltip。載入、禁用、錯誤、確認與取消狀態均需定義可見回饋；文案依既有 UI 原則保持必要且精簡。
7. **同類畫面的按鈕位置一致且有意圖。** UI 提案須標明主要、次要、取消與破壞性操作各自位置及群組；相同流程沿用既有模式，破壞性操作不與主要確認按鈕混成難以區分的一組。不得只為填滿空間而移動按鈕。
8. **窄版適配不犧牲操作性。** 版面不足時可改成圖示或收納次要操作，但須保留清楚標籤／輔助功能名稱、合理命中範圍及相鄰操作間隔；不得靠重疊、縮到難以操作或讓底層內容繼續收事件來塞入控制項。

#### D. 驗證與漸進採用

1. 純轉換／排序／驗證測試核心值邏輯；Store／跨 store 測試保存、重開、失敗、冪等、重試及跨書隔離；UI／AppKit 測試作者可觀察的流程與操作命中。
2. 修改互動時列出點擊／拖曳／鍵盤或輔助操作中適用的驗收路徑，以及遮擋／取消／失敗情境；純版面測試不取代 GUI 冒煙。
3. 規則先套用於新增程式；整理舊程式時以有界垂直切片記錄外部行為、資料不變條件、回歸範圍和回復點。除非該工作明確批准行為變更，不順便調整 UI 或資料語意。

#### E. 共用 UI 元件與重複操作

1. **重複語意只維護一份實作與資源定義。** 當按鈕類型、欄位基礎外觀、surface／background／狀態色、功能圖標、功能標籤／提示文字或確認外殼在多處具有相同語意時，抽為共享元件、style、modifier、design token 或語意資源；呼叫端透過明確 variant／參數／語意 key 選擇，不複製整段 modifier、顏色常數或各自撰寫同一功能的替代文字。
2. **共用元件以語意 variants 支援差異。** 按鈕至少按用途區分主要、次要、破壞性、圖示／工具列和整列導航等實際存在類型；欄位按單行、數值／日期、搜尋、多行文字等需要的互動差異定義 variants。variants 保持最小，實際分類以 component inventory 為準。
3. **樣式和動作共用，但業務規則留在領域。** 共用確認元件可統一標題／訊息／取消與破壞性按鈕呈現；呼叫端仍提供精確影響說明及 domain operation。共用新增列／刪除圖示可統一尺寸、命中區、label 和 feedback，不隱藏資料保存與錯誤處理。
4. **語意不同或系統行為必要時保留專用元件。** 正文 CJK 組字／Undo 編輯器、聊天 composer、數字驗證欄等若需不同提交、選取、儲存或鍵盤行為，可保留專用包裝；應重用相容的底色、字體、間距或設計 tokens，並記錄不共用完整控制項的理由。
5. **設計 tokens 是顏色和表面樣式唯一來源。** 定義命名角色而非散落 raw color，例如 app background、window surface、panel surface、raised card、separator／border、selection、accent、destructive、warning、success；淺／深外觀由同一 token 正確映射。特定資料視覺化顏色可例外，但需有語意名稱及規格依據。
6. **相同功能沿用相同圖標與文案。** 建立「功能語意 → 圖標 → 顯示名稱 → tooltip／accessibility label」對照，讓同一操作在不同功能區使用一致資源；若因上下文需要不同表述，登記為明確例外並說明原因，不讓同一功能散落多套同義圖標或標籤。
7. **共享元件與資源須可逐步採用。** 新 UI 先使用核定共享元件與語意資源；舊 UI 依元件／資源類別與功能區分批替換。對每項記錄已遷移使用處、尚存例外和視覺／互動／文案驗收，不以全域搜尋替換取代語意檢查。

建議的共用程式責任家族（尚未定名或定案）：

- **按鈕**：按主要／次要／破壞性／圖示工具列／整列導航等已盤點語意 variants，共用字體、內距、形狀、命中區、disabled／loading 樣式與輔助功能名稱。
- **欄位與編輯器**：單行、多行、搜尋、數值／日期等 variants，共用背景、邊框、字體、內距、focus／error 樣式；正文 `NSTextView` 等特殊控制保留自己的輸入與 Undo 行為。
- **主題 tokens**：集中 app/window、panel、card、selection、border、accent、destructive、warning／success 顏色與淺／深色映射。
- **圖標與文案資源**：建立重複功能的語意清單，統一圖標、顯示名稱、tooltip 與 accessibility label；同一動作共用同一組資源，保留上下文差異的明確例外。
- **重複操作外殼**：統一新增列、刪除／確認、儲存／錯誤提示的呈現；各功能仍傳入領域影響說明和 Store／Coordinator action。

具體採用 `View`、`ButtonStyle`、`ViewModifier`、泛型容器或 extension，待 component inventory 確認後提出；避免一種樣式就建立一個過大的 wrapper。

### V9.0c 可直接審查的具體規範草案

以下把方向改寫為可以逐項檢查的專案規則。元件名稱是建議 API 名稱，須在 V9.0b 核定後才建立；尺寸與間距是供本專案試行的基準，不宣稱是 Apple 平台強制值。

#### 1. 共用 UI 元件與禁止事項

1. 共用元件集中於一個 UI foundation 區域（建議 `SharedUI/`），主題值集中於 `SailuneTheme`；功能畫面不得另建同義的全域樣式、顏色常數或按鈕 modifier。
2. 新增共用控制項前，先搜尋現有共用元件和呼叫點；若語意及互動相同，直接使用。只有可說明的鍵盤、輸入、選取、提交或保存差異才能新增 variant／專用元件。
3. 呼叫端只能設定語意、內容和事件，不重複指定共用元件已擁有的 padding、font、foreground/background、corner radius、hover、disabled 樣式或命中範圍。
4. 建議呼叫形式：`SailuneButton(role: .primary, size: .regular, "儲存", action: save)`、`SailuneTextField(kind: .search, text: $query)`、`SailuneTextEditor(kind: .notes, text: $notes)`。具體 initializer 可在盤點現有 Binding／`Label` 用法後定稿。
5. 不提供 `style: AnyView`、任意顏色參數或大量互相矛盾的 Boolean 開關來繞過 variants；新差異要命名出語意，例如 `.destructive`，而不是 `isRed: true`。

#### 2. 按鈕種類、大小、位置與命中範圍

1. 按鈕角色固定分為 `.primary`、`.secondary`、`.destructive`、`.toolbar`、`.navigation`；不得用顏色或自訂 modifier 臨時表達角色。一般內容操作用文字 label；只有空間受限且圖標語意明確時才用純圖標。
2. V9 試行尺寸基準：一般按鈕高度 28 pt；工具列純圖標按鈕的互動框至少 28 × 28 pt；同列按鈕間距至少 8 pt。控制項視覺圖形可小於互動框，但互動框不可重疊、不可超出父容器，且須經指標和鍵盤驗收。
3. 一般表單或面板底部，主要動作放在 trailing 端；取消緊鄰主要動作之前；破壞性動作獨立成組或放在被操作項目的 context menu，與主要確認至少隔一個標準間距（12 pt）。同一流程不得同時放兩個同等強度的 primary。
4. 導覽列只放目前區域的主要導覽／工具操作；刪除、永久清除等破壞性操作不得只靠相鄰的紅色圖標暗示，必須有明確 label、confirmation 或可復原方案。
5. 位置由 `HStack`／`VStack`／`Grid`、alignment、safe area 或父容器幾何決定；禁止用固定 `.offset` 把按鈕推到視窗／版面另一區。`.offset` 僅可作不改變排版語意的微調，且須註明原因。
6. 禁用按鈕保留可理解的 disabled 狀態；若使用者需要知道原因，原因文字置於控制旁，不把說明只藏在 tooltip。

#### 3. 欄位、編輯器、間距與表面樣式

1. 單行文字欄和搜尋欄使用共用 `SailuneTextField`；多行一般文字使用 `SailuneTextEditor`。數值、日期、正文富文字、聊天輸入等只有在提交、格式驗證、組字、選取或 Undo 行為不同時才使用命名清楚的專用 variant／控制項。
2. 單行欄位試行高度 28 pt；同一表單欄位高度、label 對齊及欄間距一致。多行編輯器高度依父容器與內容用途配置，不以固定 offset 定位；最小高度由表單類型在 variant 設定。
3. 欄位的 placeholder 不可取代欄位名稱；欄位須有可見 label，或在純圖標／空間受限情境提供 VoiceOver 可讀 label。錯誤訊息緊鄰欄位，並能指出如何修正。
4. 共用 spacing scale 固定為 4、8、12、16、24 pt；新 UI 優先使用該 scale，不新增近似值（如 7、10、14 pt）。既有畫面若有已核准的特殊密度，列為明確例外。
5. 背景、面板、卡片、選取、分隔線、焦點、錯誤、警告與成功色只能由語意 token 取得（建議 `SailuneTheme`）；功能 View 禁止直接建立重複的 `Color(red:green:blue:)`、hex 色或 `.opacity(...)` 來仿製既有表面。透明度只用於 token 定義或具名的 overlay token。
6. token 使用語意名稱（例如 `appBackground`、`panelSurface`、`raisedSurface`、`separator`、`selection`、`destructive`），不可用 `gray1`、`blue2` 等依色相／順序命名。Light／Dark 外觀映射在 token 唯一定義處維護。

#### 4. 圖標、功能命名與重複文案

1. 建立集中 `SailuneSymbol` 語意表；畫面以 `.delete`、`.add`、`.edit`、`.search`、`.more`、`.confirm`、`.cancel`、`.settings` 等語意 key 取圖標，不直接在功能 View 各自填 SF Symbol 字串。
2. 語意表初始對照建議：新增＝`plus`、刪除＝`trash`、編輯＝`pencil`、搜尋＝`magnifyingglass`、更多＝`ellipsis`、確認＝`checkmark`、取消／關閉＝`xmark`、設定＝`gearshape`。同一語意不得因畫面作者不同而換圖；若圖標字形需因操作情境不同，新增另一個明確語意 key 並記錄差異。
3. 顯示文字集中於 String Catalog／本地化資源；同一通用操作重用同一 key，例如新增、編輯、刪除、儲存、取消、搜尋。包含對象名稱的確認句採格式化參數，不在多處手動串接同義句。
4. 按鈕文字使用明確動詞，例如「新增角色」「儲存」「刪除章節」；同一操作不得在不同畫面混用「移除／刪除」除非語意確實不同。tooltip 只補充圖標按鈕的操作意思，不重複已顯示的按鈕文字。
5. 純圖標按鈕必須有 accessibility label，採「動作＋對象」格式（例如「刪除角色」）；tooltip 與 accessibility label 指向同一動作，不以 SF Symbol 名稱作 label。若操作需要說明影響或不可逆性，放在確認內容，不塞進短 label。
6. 文案例外須登記在語意清單，包含功能 key、共用文案、例外畫面、例外文案及原因；不得為了避免新增 key 而讓文案失去準確性。

#### 5. 重複操作與內部程式責任

1. 重複的新增列、空狀態、錯誤提示、確認對話框可共用呈現元件；元件接收明確標題／訊息／按鈕語意／closure，不直接讀取任意 Store 或自行推斷要刪除的資料。
2. View 可直接處理單一模型欄位的簡單同 Store 綁定；建立／刪除多個互相關聯模型、跨 Store、檔案操作、備份／修復、重試或需維持跨畫面不變條件的流程必須有具名 Store／Coordinator action。View 不複製該流程的步驟。
3. 每個寫入 action 集中維護其前置條件、變更順序、保存點與錯誤出口；不得同一領域操作一部分放 View、一部分放 Store，且沒有單一可追蹤入口。
4. 純投影／格式轉換／排序函式只接收值並回傳值，不讀取 `ModelContext`、SwiftUI Environment、全域可變狀態，也不保存資料。
5. `try?` 不得用於儲存、刪除、遷移、備份、重要查詢或清理。只有「失敗與沒有值完全等價且不影響使用者決策／資料正確性」時可用，並須在同一行或相鄰註解說明理由。
6. 非同步操作須有具名入口，並處理取消、過期結果及錯誤呈現；生命週期啟動任務須說明執行順序及冪等性。跨 Store 流程不得假稱為單一原子交易，須定義主操作成功而附屬清理失敗時的修復方式。
7. 一次整理只改一個可獨立驗收的元件家族或垂直流程；先記錄既有行為和資料不變條件，再替換呼叫端。禁止順手改文案、互動或資料語意，除非該項變更已獨立核准。

#### 6. Code review 必查項

- 新畫面是否重用共用按鈕、欄位、編輯器、theme token、圖標和文案 key？新增例外是否列出理由？
- 相同操作是否具有相同圖標、顯示文字與 accessibility label？
- 按鈕命中框是否至少 28 × 28 pt（適用於純圖標工具列按鈕），且沒有互相重疊或穿透？
- 排版是否使用父容器與 spacing scale，沒有用固定 offset 假造跨區位置？
- View 是否只保留簡單局部編輯；跨模型／跨 Store 流程是否有單一具名責任者？
- 錯誤是否有明確出口；有沒有把錯誤藏成空清單、成功或無動作？
- 新例外是否記入 inventory，並有視覺、互動、文案及必要資料流程驗收？

### V9.0b 文件更新結果與責任分工

| 文件 | 提案變更 | 文件角色 |
|---|---|---|
| `docs/coding-standards.md` | 已增補共用元件／語意資源、28 pt 試行尺寸、按鈕位置與間距、欄位／編輯器、色彩 token、圖標／文案 key、View／Store 責任、純投影、跨 Store 失敗及非同步操作條文 | 唯一工程規則來源 |
| `docs/ux-principles.md` | 已增補相同功能圖標／文字一致、主要／取消／破壞性按鈕位置、純圖標標籤、命中範圍、欄位標籤、疊層／手勢和父容器定位契約 | 唯一產品互動原則來源 |
| `docs/architecture.md` | 已新增共用 UI foundation 責任、不得依賴領域 Store、輸入特殊控制例外及既有局部共用型別作為盤點起點 | 架構現況與已定技術邊界 |
| `docs/testing.md` | 已增補共用元件 variants／狀態、逐呼叫點遷移與圖標文案一致性、實際 hit-testing／遮罩／手勢人工驗收要求 | 唯一測試策略與目前覆蓋基線 |
| `AGENTS.md` | 已加入新 UI 先重用元件／tokens／圖標／文案 key、code review 項目及共用遷移驗收的入口規則 | 任務啟動與完成的強制入口 |
| 共用 UI 程式碼與語意資源 | V9.1 依 component／resource inventory 決定專責檔案／namespace，集中主題 tokens、按鈕／欄位／編輯器 variants、功能圖標與文案對照、重複操作外殼，讓已遷移畫面統一呼叫 | 統一視覺、命中、語意呈現與共用操作的唯一實作來源 |
| `docs/README.md` | 保留已新增的 V9 規劃文件索引；正式規範修改完成後核對技術文件索引 | 文件導航 |

本工作不修改 `docs/work-items/current.md`、`docs/handoffs/current.md`、`docs/project-status.md` 或任何功能規格，因為目前 current 工作仍是 V8.2，且 V9.0b 不改產品行為。V9 規則更新證據記錄於本工作單；若 V9 成為主要下一版本工作，再由使用者決定何時接替 current 工作單。

### 目前共用元件與語意資源盤點

> 搜尋基線：2026-09-23；以 `rg` 靜態搜尋 `Sailune/**/*.swift`。這是候選點盤點，不是 GUI 驗收、逐項 code review 或自動遷移清單。字面相同仍須確認實際語意。

| 家族 | 搜尋基線與現況 | 具體重複／差異 | V9 後續處理 |
|---|---|---|---|
| 按鈕樣式 | 229 個 `.buttonStyle(...)`：`.plain` 111、`.borderless` 46、`.borderedProminent` 24、`.link` 5、`.bordered` 4、`PlanningActionStyle` 39。集中檔案包含 Inspector 47、Timeline 39、V5 settings 39、Outline 26。 | 既有 SwiftUI 原生 style 與 Outline／Timeline 的專用 style 並存；style 名稱不等於按鈕語意，需逐項分類 primary、secondary、destructive、toolbar、navigation。 | 按所有呼叫點做語意分類，再決定哪些能由共用 `SailuneButton`／`ButtonStyle` 承接；整列導覽與系統原生控制保留明確例外。 |
| 文字欄位 | 104 個 `TextField`；較集中於 Inspector 20、Timeline 20、V5 settings 19、Character History 9、Character Section 8。 | 同時包含一般文字、搜尋、座標、日期／數字與條件欄位；不能單靠 placeholder 或 `.roundedBorder` 推斷用途。 | 為每一呼叫點標註 kind、提交方式、驗證、鍵盤／組字差異、label 與錯誤呈現；共用基礎樣式，僅保留必要 variants。 |
| 多行編輯器 | 18 個原生 `TextEditor`；另外 `InsetTextEditor` 已被 Inspector、Character Section、Character History 呼叫至少 6 次。 | `InsetTextEditor` 已重用字體、padding、背景、圓角及描邊，但定義在 feature 檔 `CharacterSectionViews.swift`；設定頁另有直接 `TextEditor`。 | 搬遷前先比較 binding、minHeight、CJK 輸入、選取、保存、focus 行為；共用一般文字編輯器外觀，不包覆正文 `NSTextView` 或 AI composer。 |
| 背景／surface／狀態色 | `AppTheme.swift` 已提供 `appBackground`、`workspacePanelBackground`、`workspaceFloatingPanel`。初篩仍找到 76 個指定的 raw color／opacity 表現。 | 另有 `Color.secondary.opacity(...)`、白／黑／灰、直接 RGB、AppKit 系統背景及個別圓角／stroke；地圖 canvas 顏色可能是資料語意而非一般 surface。 | 把 raw 使用分為 surface、overlay、狀態色、資料視覺化四類；合併同語意 token，保留地圖／圖表專用語意色。 |
| 圖標 | 112 個 `Image(systemName:)`。初篩頻率：`trash` 18、`xmark` 11、`minus.circle` 8、`plus` 5、`checkmark` 3、`magnifyingglass` 3。 | `trash` 和 `minus.circle` 可能分別代表永久刪除與解除關聯；`xmark` 同時代表關閉／取消及 Timeline 刪除時間，不可未核對就強制同圖。 | 建立 `SailuneSymbol` 語意 key 對照表，至少區分 `.delete`、`.removeAssociation`、`.close`、`.cancel`；逐使用點核對並記錄例外。 |
| 顯示文字／提示 | 初篩 literal：取消 48、好 32、刪除 31、完成 17、儲存 10、關閉 7、新增 4；79 個 `.help(...)`、28 個 `.accessibilityLabel(...)`；未找到 String Catalog 或 `Localizable.strings`。 | 重複 literal 數量不等於可共用數量；「好」「完成」「刪除」需依操作與確認上下文分類。圖標、tooltip、label 也有少數已配對例子，多數未形成中央對照。 | 建立「操作語意 → 顯示字串 key → tooltip → accessibility label」表；對相同動作共用資源，保留帶對象名稱／上下文的格式化參數。 |
| 重複操作外殼 | 初篩看到多處 trash／minus.circle 刪除操作、新增按鈕、確認／取消按鈕；各區直接接自己的 Store closure。 | 呈現方式可共用；刪除範圍、級聯關係、保存／重試不可移入通用 View。 | 按「只統一呈現、呼叫端明確傳入 message 與 action」設計；先清冊對話框、confirmation、空狀態、錯誤提示和新增列。 |

#### 圖標語意核對：同一圖形的不同操作

| 程式證據 | 操作語意 | V9 資源規則 |
|---|---|---|
| `AppearanceRow`、AI 對話清單以 `trash` 刪除資料；角色物品副本列也以 `trash` 執行「移除持有人；副本仍保留」。 | 刪除整筆資料與解除持有人不同。 | 分別使用 `.delete`／`.removeHolder` 語意 key；現有圖形先維持，若要改成相同或不同圖形，須在對應 U 決策。 |
| AI 側欄的 `xmark` 用於關閉側欄、移除選取模板／閱讀範圍；卷節改名用它取消；Timeline 日期格用它要求刪除時間。 | 關閉、取消、移除選擇、刪除時間不同；V6.4 已確認時間格的 `xmark` 視覺。 | `.close`、`.cancel`、`.removeSelection`、`.deleteTime` 分開命名。時間格保留現有 `xmark`，不以一般 `.delete` 的 `trash` 規則覆蓋已批准的 UI。 |
| `plus` 用於新增節／AI 對話，也用於地圖放大 25%。 | 新增資料與縮放不同。 | `.add` 與 `.zoomIn` 分開命名，即使目前同為 `plus`。 |
| `checkmark` 用於確認卷節改名，也出現在 AI 對話選取狀態。 | 確認操作與「目前已選取」狀態不同。 | `.confirm` 與 `.selected` 分開命名；後者是狀態圖標，不包裝成按鈕 action。 |

此清單根據程式 action 與目前功能文件判斷操作語意；沒有實際畫面證據時不改既有圖標。V9.1a 的 `SailuneSymbol`／`SailuneActionCopy` 已建立上述初始 key，呼叫點遷移時逐項核對 tooltip、accessibility label 和實際資料副作用。

#### V9.1 pilot 候選比較

| 候選切片 | 可涵蓋家族 | 風險／限制 | 評估 |
|---|---|---|---|
| `CharacterSectionViews.swift` 的 `AppearanceRow` | 刪除圖標、單行欄位、多行 `InsetTextEditor`、表面樣式、label 與條件欄位 | 同列還有類型 Picker 和時間定位；須凍結刪除、時間關聯及資料保存行為，只換呈現基礎 | **使用者已選定並批准 R／U／I**；深色截圖已核對，共用刪除按鈕與單行欄已接入，GUI 待驗收。 |
| `SearchReplaceView.swift` | 搜尋／替換欄位、提交鍵盤行為、文字操作按鈕 | 範圍清楚、風險低，但無純圖標／多行編輯器／刪除 shell，覆蓋元件家族較少 | 作為較小的 TextField API 備選，不是目前 V9.1 目標。 |
| `MapViews.swift` 的地圖標記表單 | 數值欄位、驗證錯誤、儲存／刪除文案與圖標、surface | 地圖座標與 viewport／手勢既有回歸風險高，表單也與地圖操作關聯 | 暫不作第一個 pilot；待共用元件穩定後再遷移。 |
| `TimelineViews.swift` 單一表單 | 多種欄位、圖標、狀態與操作 | style 呼叫多且時間資料語意複雜，可能將 UI 樣式試行與時間軸回歸混在同一批 | 暫不作第一個 pilot；拆到元件基礎完成後再排。 |

使用者已選定 `AppearanceRow` 作為 V9.1 試行目標並批准 R／U／I。獨立工作單為 `docs/work-items/v9.1-shared-ui-pilot.md`；使用者深色截圖已核對，共用刪除按鈕與單行欄已接入，實際命中、Light／Dark、身體特徵與輸入仍待 GUI 驗收。

### V9.0b 驗收情境

- 審查一個單欄位 `@Bindable` 編輯時，能依「單一同 store 局部編輯」規則保留簡單流程。
- 審查角色刪除或跨 store 清理時，能找到唯一協調責任者、部分失敗語意與重試／修復測試，不在 View 重複編排清理。
- 檢查地圖被放大至 viewport 外：點擊工具列不新增標記；點擊標記只開標記；拖曳標記不移動畫布；點擊 viewport 外不觸發其內容。
- 遮罩／自訂彈窗顯示時，點擊空白執行已定義取消且不操作背景；短輸入欄位 Enter 行為符合其確認語意。
- 故障查詢不會被 UI 呈現為確定的空清單；允許的 best-effort `try?` 有明確可忽略理由。
- 修改歷史 schema snapshot 或以行數自動要求拆檔會被 code review 檢核表攔下。
- 每條正式規則只在指定文件維護，其他文件用連結引用，無兩份互相競爭的文字。
- 同類 primary／secondary／destructive 按鈕、短欄／多行編輯器與淺／深 surface 從同一元件／token 家族呼叫，差異以明確 variant 表示。
- 更新共用 token／variant 後，所有使用它的呼叫端一致更新；保留的特殊控制有理由及操作驗收，不形成散落的第二套樣式。
- 同類新增／刪除確認使用共用呈現外殼；刪除影響說明和領域操作仍由各呼叫端明確提供。
- 相同功能在不同畫面使用一致圖標、功能名稱、tooltip 和 accessibility label；上下文差異可被列出並有具體理由。

### V9.0：基線盤點與規範定稿

- **目的**：先知道現有規則、程式責任與風險，再決定規範內容；本階段不改功能程式。
- **工作**：建立規範覆蓋矩陣；盤點主要功能模組的責任／依賴／狀態／跨 store 流程／測試缺口；把 UI 點擊、命中、手勢和疊層案例納入具體檢核項。
- **文件**：核定 `coding-standards.md`、`ux-principles.md`、`architecture.md`、`testing.md` 各自的唯一責任和互相連結；建立短小的 code review／區域稽核檢查表。
- **完成門檻**：每條規則有明確適用範圍、例外或判斷依據、可檢查的驗收條件；稽核清單依風險排序；使用者確認規範和整理順序。
- **停止條件**：若規則會改變產品行為、資料語意或跨模組契約，先列待決策，不把它當成純程式風格規則。

### V9.1：共用 UI 基礎與代表性垂直切片

- **目的**：讓一組共用元件真正被功能畫面呼叫，驗證它能減少重複碼並保持預期互動，再驗證內部責任規則可用於一個垂直切片。
- **進入條件**：V9.0b 規則確認；完成 UI component inventory，列出按鈕、欄位、文字編輯器、色彩／表面 token 和重複操作的語意 variants、使用頻率、例外及候選 API。
- **工作順序**：先完成元件與語意資源 inventory，再建立共享設計 tokens、圖標／文案對照和按鈕／欄位／多行編輯器／確認操作的共用元件；選一個代表性 View 流程採用這些元件與資源。API 和具體共用檔案／namespace 由 inventory 決定，避免在盤點前預設符號名稱。
- **試行選區**：從書籍總覽、Inspector 單一資料種類、Timeline 表單或地圖表單中，按重複元件覆蓋、差異可表達性、行為風險、可隔離程度和 GUI 可驗收性排序後提出一個；使用者確認後作為 pilot。
- **完成門檻**：相同語意的 pilot controls、圖標與文案都呼叫／引用共享實作；按鈕位置／命中範圍、欄位鍵盤行為、錯誤／禁用狀態、淺／深外觀符合已批准規格；領域資料操作仍由正確 Store／Coordinator 執行；使用者驗收試行結果。
- **停止條件**：共用抽象迫使不同鍵盤、選取、CJK 組字、驗證或保存行為變得不一致時，拆成命名清楚的 variant 或保留專用控制，記錄例外，不強行套版。

### V9.2 起：按風險分批整理

- **目的**：依 V9.0 稽核順位與 V9.1 得出的規則，逐個有界功能切片採用共用元件並降低程式耦合和維護成本。
- **排序原則**：先處理錯誤容易造成資料損壞、互動攔截或多處連鎖修改的區域；再處理責任混雜、重複邏輯與難以測試的區域。檔案行數只作盤點線索，不直接決定順位。
- **批次邊界**：UI 共用元件按類別／功能區逐步遷移，每批以搜尋與人工確認列出呼叫點、已轉換點和有意保留的例外；內部架構整理一個工作單聚焦一個模組或垂直流程。基線記錄要保留的外部行為和資料不變條件；不混入新產品功能或 schema 遷移。
- **每批流程**：記錄基線 → 提出 R／U（適用時）／I → 實作小步變更 → 依風險執行自動驗證與人工冒煙 → 更新正式規範／架構文件與交接 → 使用者驗收 → 關閉該批工作單。
- **完成門檻**：相同語意的 UI 樣式／操作使用共用 source of truth；必要例外有理由及驗收記錄；每批變更可獨立 review、可回復、測試結果可追溯；未處理問題留在下一批，不以大範圍一次性重寫收尾。

### V9.3：內部程式責任整理與收尾

- 依已確認的高優先模組清單，把 View／Store／協調器／純邏輯責任以有界切片整理；共享 UI library 僅處理呈現／互動共用，不承接領域資料規則。
- 對照元件 inventory 和呼叫點，確認已遷移的重複按鈕、欄位、編輯器、色彩與操作外殼；保留的例外需有語意差異理由。
- 更新架構責任地圖、測試策略、review checklist 與專案狀態；未完成的分區工作轉入 backlog，不視為已完成。

### V9 收尾：規範採用與後續維護

- 確認新增程式依規範撰寫；回顧完成批次與未完成候選，將未做項目保留於 backlog，不標成已完成。
- 更新專案狀態與技術文件索引；任何仍需行為、資料或 UI 決策的事項分流到新的具體工作單。
- 若規範試行後證明成本大於收益，調整規範並記錄原因，不要求為符合文件而製造抽象層。

### 每階段批准與版本邊界

1. **V9.0 先確認規範與稽核計畫**：本規劃完成後，確認需求範圍與完成條件；正式文件修改計畫提出後再批准文件更新。此為純文件工作，U 記為 `not_applicable`；不涉及程式實作時 I 亦為 `not_applicable`。
2. **V9.1 另開試行工作單**：先批准試行範圍／行為基線，再批准技術計畫與驗證方法，之後才修改程式。UI 行為受影響時依流程完成 UI 提案與批准。
3. **V9.2+ 每個整理批次各自建工作單**：不以 V9 總體方向視為對任意模組重構的概括授權；每批需指出檔案／責任邊界、相容性、停止條件和完成證據。
4. **版本標記**：V9.0a／V9.0b／V9.1／V9.2／V9.3 是工程工作里程碑；產品版本號、build number 和各 SwiftData schema 版本維持各自管理，不因里程碑自動升版。

## 規劃階段交付物

- [x] 規範現況矩陣：已涵蓋、缺漏、重複、衝突與權威文件位置。
- [x] 內部程式規則提案：分層／依賴、狀態／副作用、跨 store、錯誤／並行、測試與漸進整理原則。
- [x] UI 互動與共用元件／語意資源規則提案：命中區、事件接收邊界、按鈕位置／種類、欄位／編輯器 variants、重疊層級、手勢競爭、共用色彩 tokens、功能圖標／標籤／提示文案、輔助功能與互動狀態驗收。
- [x] UI component／resource 第一輪 inventory：類別、搜尋命中數、主要檔案、已知差異及候選 API；逐功能呼叫語意核對留作 V9.1 pilot 前的技術拆解。
- [x] 現有模組稽核表及優先序，含優先依據而非只有檔案行數。
- [x] V9.0a／V9.0b／V9.1／V9.2／V9.3 各階段的進入條件、交付物、完成門檻、停止條件與批准點。
- [x] 文件變更清單與唯一規則來源安排。
- [x] 試行候選比較與暫定推薦；最後試行範圍仍待 V9.1 工作單確認。

## 完成條件草案

- [x] 完成上方規劃交付物第一輪並提交使用者審閱；逐呼叫點行為核對將放入 V9.1 試行工作單。
- [x] 記錄版本里程碑不是產品／schema 升版的決定。
- [x] 記錄被否決或暫緩的方案、理由、暫時假設與待確認事項。
- [x] V9.0b 規劃階段只修改工程規範文件；其後程式試行各由獨立工作單管理。

## 暫定建議與待確認

- 已決定：V9.0b 規則已納入正式文件；共用程式碼需涵蓋控制項、顏色、圖標、功能文字與重複操作，呼叫端統一引用。
- 已決定：V9.1 第一個試行範圍採 `AppearanceRow`；其獨立工作單為 `docs/work-items/v9.1-shared-ui-pilot.md`。
- 待確認：28 pt 尺寸／間距是否保留為 project baseline；在 U 實際畫面核對後再確認，此項不影響已完成的 V9.0b 文件修訂。
- 已決定：`AppearanceRow` 的 U 位置與互動提案已獲使用者批准；Sailune UI 讀取逾時，但使用者深色截圖已保存。實際命中、Light、身體特徵與 hover／focus 尚待後續 GUI 驗收。
- 暫無被否決方案。

## 工作樹與相容性

- 使用者授權本輪開始 V9 文件規劃，並指示依具體規範草案繼續；本輪修改 coding standards、UX principles、architecture、testing、AGENTS 與 V9 規劃文件。
- `docs/work-items/current.md`、`docs/handoffs/current.md` 仍追蹤 V8.2 的既有工作，不在本工作中覆寫。
- 本工作不改功能程式、資料、schema、遷移、備份格式或作者資料，無程式相容性影響。
- 不執行程式測試；文件修改後執行 `git diff --check`。

## 批准狀態

| 關卡 | 狀態 | 說明 |
|---|---|---|
| R：規劃目標與範圍 | approved | 使用者指示依具體規範草案繼續；批准範圍限 V9.0 文件更新與唯讀 inventory，不含功能程式重構 |
| U：介面設計 | not_applicable | 本工作不修改產品畫面或互動 |
| I：程式實作 | not_applicable | 本工作只規劃規範文件，不修改功能程式 |

# V9 暫緩檢查點 — 2026-09-25

> 狀態：依使用者優先投入功能增加與穩固，暫緩 V9；未結案、未取消。工作樹修改保留。
>
> V9 唯一續接起點：先核對 `Sailune/CharacterSectionViews.swift`、`Sailune/EditorWorkspaceView.swift`、`Sailune/OutlineViews.swift` 五處 help 改用既有 `SailuneActionCopy` 的修改，完成 Debug build；再按本文件的凍結清單處理，不重建基準。

## 1. 凍結基準與當前盤點狀態

- 固定基準：`docs/v9-freeze/README.md`。
- 產品 Swift 原始碼基準 86 檔、測試 Swift 檔 7 檔；固定 callsite 2,256 筆、模組 93 檔；原始 CSV 的 SHA-256 值保存在 README，禁止重生或覆蓋三份凍結 CSV。
- 最後一次盤點校驗：`python3 docs/v9-freeze/check_inventory.py` 通過。
- 最新分類總數：已共用 745、待共用 284、合理例外 1,227。
- 待共用分布：button 50、button_style 154、accessibility 31、dialog 41、symbol 8。field、editor、surface、copy、failure_path 目前待共用為 0。
- 模組責任 ledger：已共用 2、待共用 11、合理例外 80。十一檔清單與原始理由見 `docs/v9-freeze/module-resolution-ledger.csv`。
- `git diff --check` 在最後一輪程式編輯後通過；最新五處 help 接線尚未取得 build 結果。不要把本 checkpoint 的停點描述為已完成驗收。

## 2. 已完成與目前證據

- V9.1ar：使用者核准親屬圖搜尋欄 compact variant；已改接 `SailuneSearchField`，固定 ID V9-0897 記為已共用。Debug build 通過；一般／最窄視窗、命中範圍、CJK、Light／Dark GUI 尚未驗收。
- V9.1at：使用者核准兩處「新增副本」統一 `plus.square.on.square`、事件卡片刪除使用 `trash`；固定 ID V9-0789、V9-2131 已接線。Debug build 通過；GUI／VoiceOver／Light／Dark 尚未驗收。
- V9.1aw：六處地圖、大綱與故事背景錯誤 alert 使用 `SailuneErrorAlert`，標題、未知錯誤 fallback、按鈕 role 與 Binding 清除方式保留。Debug build 通過；完整非平行 XCTest 在這批修改後 208／208 通過；故障注入及實際 alert GUI 尚未做。
- V9.1ax：30 個固定重複 help／accessibilityLabel 命中接入 ActionCopy／AccessibilityCopy，13 個 String Catalog key 保留原字面值。第一次接線後 Debug build 通過；hover／VoiceOver 尚未驗收。
- V9.2am：`CharacterAppearanceSectionView` 和 `AppearanceRow` 從 `CharacterSectionViews.swift` 搬至 `CharacterAppearanceViews.swift`；helper 可見性調整；來源語句保持。Debug build 通過；實際 UI 和模組責任尚未驗收。
- 又有五個 help 固定 ID（V9-0452、0605、0635、1180、1226）改用既有 ActionCopy。這是 checkpoint 前最後的程式改動；ledger 已記錄已共用，但其後 build 啟動時對話被中斷，結果未知。208 項 XCTest 在這五處修改及 V9.1ax 整批之前，因此不涵蓋最新工作樹。
- 獨立測試 App 未能啟動；當時既有 Sailune 可能使用正式作者資料，未操作其畫面、未新增或刪除正式資料。

## 3. 已核定但未完成驗收

| 項目 | 使用者決定 | 實作／驗收狀態 |
|---|---|---|
| V9.1ar 親屬圖搜尋 compact | 同意方案 | 已接線、build 通過；GUI 尚未驗收 |
| V9.1at 同功能圖標 | 同意統一 | 已接線、build 通過；GUI／VoiceOver 尚未驗收 |
| V9.2c 能力補償／查詢錯誤 | 先記錄錯誤，不改操作結果 | 已依決定保留結果並加診斷；故障注入尚待驗收 |
| V9.2g 還原錯誤 | 只修正錯誤文字，其餘另議 | 文字已修；rollback 政策留待後續決策 |
| V9.2t 標記刪除失敗 | 維持關閉，只顯示錯誤 | 已依決定保留關閉行為並呈現錯誤；store rollback 尚未核定 |

## 4. 未決 UI 關卡與整類範圍提案

- V9.1am：使用者提供地點「簡介」欄首行貼近圓角上框截圖。已提出共用 bordered editor 增加 9 pt 水平／8 pt 垂直內距的提案；U 未核定，禁止先改共用 editor，因會影響其他欄位。截圖：`docs/assets/v9-place-intro-first-line-clipping-2026-09-25.png`。
- V9.1af：八個上下移動控制圖標提案尚待 U 核定；不改其位置或圖形。
- `scope-change-proposal-hit-testing.md`：凍結時 14 檔 115 個非 Button hit-test／gesture／overlay 修飾器。這是原 V9 規劃中整類漏項的範圍變更提案，尚未獲使用者決定；提案核准前不新增這個家族或 ID。

## 5. V9 結案尚缺工作

1. 依 `resolution-ledger.csv` 逐 ID 完成 284 個待共用的來源核定，為仍保留項目留下具體理由；不把候選數視為修改數。
2. 審查 11 個待判責任檔的跨檔依賴，只拆有清楚責任邊界且能保留外部行為的模組。
3. 完成核准項目的 GUI：AppearanceRow 的 28 pt hit area、Light／Dark、身體特徵、focus／組字；搜尋 compact 最小／一般寬度；圖標與提示的 hover／VoiceOver；地點首行穿模修正與相關欄位。
4. 完成故障注入：使用者已核定政策下的能力補償、地圖操作、封面／備份／rollback 與其他重要 failure paths；維持 V9.2g 未核定政策不自行改動。
5. 決定是否採納整類非 Button 手勢範圍變更；若核准，保留原 2,256 ID，新增補充表與固定搜尋規則，不能重生原快照。
6. 最後一次無簽章 Debug build、完整測試、`git diff --check`、固定清單 `--final` 及逐條 README 五項結案門檻核對；任何 GUI／故障證據缺少時維持 V9 active。

## 6. 續接操作順序

1. 讀 `AGENTS.md`、`docs/project-status.md`、本 checkpoint、`docs/work-items/v9-frozen-inventory.md`、`docs/handoffs/v9-current.md`；UI 工作再讀具體工作單與 `docs/coding-standards.md` UI 章節。
2. `git status --short`、`git diff --check`；不要 checkout、reset、clean 或覆蓋現有工作樹。
3. 核對五個 help 改動，再跑 Debug build；視是否仍符合產品功能優先順序，決定何時跑完整 XCTest。
4. 繼續更新固定 ledger 與模組 ledger；每一批維持 ID，結尾執行 `python3 docs/v9-freeze/check_inventory.py`。未結案時 `--final` 預期會失敗，不要為了通過而把待辦硬改成例外。
5. 先取得可安全操作的隔離 Sailune GUI，再做畫面驗收。不可把連正式 store 的使用中 App 當隔離測試環境。

## 7. 使用者原有修改邊界

- 起始工作樹已有 V8.2 未提交修改，至少包括 `docs/work-items/current.md`、`docs/handoffs/current.md`、`docs/spec-ai-v8.md` 等；本 V9 工作不得回復或覆寫。
- V9 目前的 Swift、SharedUI、String Catalog、專用工作單、固定 inventory 與交接均是未提交工作樹內容。沒有 commit、發布、schema 遷移或正式資料操作。
- 完整 `git status` 是恢復工作第一步；無法從未提交混合工作樹可靠推斷每個檔案的初始所有者，需以本交接明列的 V9 變更及既有 V8.2 文件邊界為準。

## 8. 版本號建議（提案，未改版號）

- 把 V9 保留為**內部工程規則化工作軌**，不因 V9 共用化而改使用者可見產品版號，也不因暫緩就宣告完成。
- 功能軌沿用完成的 V8.2 作為下一個開發起點：新增一組向後相容功能建議用 **V8.3**；若接下來只有 V8.2 範圍內的穩定性修正，建議用 **V8.2.1**。跨相容性／產品定位的大改再另立主要版號，不預先把 V9 工程整理等同產品 V9。
- 發布時再以 `MARKETING_VERSION` 記錄正式產品版本，`CURRENT_PROJECT_VERSION` 單調遞增作 build number；schema／migration 版號仍獨立。專案文件目前記錄已發布 V4.2.1，但 Xcode target 的 `MARKETING_VERSION` 是 1.0、`CURRENT_PROJECT_VERSION` 是 1，存在需在下一次實際封裝前釐清的對照差異。此 checkpoint 不擅自修改設定。

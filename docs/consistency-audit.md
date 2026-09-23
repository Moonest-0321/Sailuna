# 文件與實作一致性檢查

> 稽核日期：2026-09-23。範圍包含 Swift 原始碼、XCTest、Xcode 設定與 `docs/`；本文件記錄程式事實和產品文件的差異，不代表已修正程式。

## 已確認一致

- 主資料使用 `NovelWriterSchemaV5`；故事規劃使用 `StoryPlanningSchemaV7`，產品版本與 schema 版本分離。
- 應用建立一個既有主 store 與五個獨立功能 store；V5 settings store 只以 UUID 連結，不遷移主資料。
- V5 settings schema V13 保存 V12 全部資料，另以可空目標地圖 UUID 記錄來源 placement 的跨層級跳轉；刪目標圖清除來源綁定但保留 Place 與來源 placement。跨主 store 資料仍只保存 UUID。V1～V12 快照保持不可變。
- V7.2 地圖 PDF 與 placement 分離：每版本 PDF 保存於 `Sailune/Maps/<book>/<map>/<version>.pdf`，切換背景不重設座標；匯入非 4:3 單頁 PDF 時完整等比例補白，白邊也屬於 `4000 × 3000` 座標平面。
- V8 AI 對話依書籍 UUID 存於獨立 JSON；刪除對話不刪正文與節次，刪書清除該書對話檔；完整備份／還原包含對話，舊備份還原清除現有對話。
- V5.0「不連接角色、物品、能力等」是第一版歷史邊界；V5.2～V5.6 的成員、資產、生命週期與結構化關係是後續增量能力。長期文件不得把 V5.0 邊界誤寫成目前產品限制。
- 勢力 WorldTerm 連接由欄位語意限制：宗教只能連「信仰」、政體只能連「制度」；核心／範圍目前不連 WorldTerm，既有欄位只作相容保留，後續改接地點／地圖。
- 角色正文引用使用穩定 URL；已連結名稱可同步，未連結文字只列候選。
- 正文大綱來源和伏筆／修改標籤均可重新定位；來源消失時分別採大綱降級與標籤刪除。
- 世界時間軸使用主 store Timeline／Era／Node／Event；既有敘事大綱可建立 Event 並以 metadata 關聯。
- V6.4 紀元刪除由 `CrossStoreDeletionCoordinator.deleteEra` 限定目前 Book 的所有 Timeline 找出仍連結的 Node；主 store 同次保存刪除 Era／Node，Node cascade 刪除 Event，歷史來源保留但解除定位，StoryPlanning／ItemCopy／AbilityProgress／V5 settings 的 Node references 隨後清理。每本書的 Era／設定獨立，不存在跨書共享；`Book.currentEra` 使用既有 nullify；不改 schema。
- V6.4 時間軸排序由紀元順序優先，再比較紀元內年月日、同日 `sortOrder` 與 UUID；日期格建立後仍維持此順序，角色時間定位及物品副本歷史也共用同一節點比較器。未指定紀元排在已指定紀元之後。
- 原始碼中共有 140 個 XCTest 方法；2026-09-18 完整 140 項均通過，包含六 store／封面備份還原、AbilityProgress／ItemCopy／V5 settings reconcile 及原有遷移。

## 2026-09-18 已修正

### 匯出目的地不再依賴開發者帳號

TXT 與 EPUB 現均使用 SwiftUI `fileExporter` 與共用 `FileDocument`；取消不寫檔，覆寫由系統確認，寫入失敗顯示警告，成功後在 Finder 選取成品。產品匯出路徑不再直接建立 `NSSavePanel`。
Debug 與 Release App target 均設定 `ENABLE_USER_SELECTED_FILES = readwrite`；實際 Debug 簽章包含 `com.apple.security.files.user-selected.read-write`，避免系統輸出面板因 sandbox entitlement 不足而停止。
EPUB 匯出會使用畫面目前顯示的封面：優先直接讀取書籍 UUID 對應的有效 PNG，否則產生同色彩與首字的預設封面；兩者皆嵌入 `OEBPS/cover.png` 並以 OPF `cover-image` 宣告。獨立封面檔缺失或損壞不會阻斷正文匯出。

### 跨 store 一致性、刪除與備份

- Book／Character／Item／Ability／Node／Timeline／Event 的破壞性操作已透過 `CrossStoreDeletionCoordinator` 協調；Volume／Section 的五秒 Undo 保留，但標記與最終儲存也改由協調服務進入。
- 啟動與刪除後會以主 store UUID／book 對照冪等修復 V5 settings、ItemCopy 與 AbilityProgress；失效 Node 只清除定位，保留歷史文字。

已提供單檔 `.sailunebackup`，內含六個 SQLite online snapshot、封面、遞迴地圖 PDF、schema manifest 與 SHA-256；還原保留安全相對路徑並拒絕路徑穿越，先建安全備份且可 rollback。沒有地圖的舊備份可還原並清除目前地圖；settings V10／V11／V12 manifest 可交由現行 V13 migration 升級，其他 store schema 仍須完全相符。

## P1：產品宣稱邊界

### 伏筆不是「未回收伏筆管理」

`StoryTagKind.allCases` 目前只有伏筆與修改；設定集可列出、跳回正文及刪除伏筆。但 `StoryTag` 沒有回收狀態、回收錨點、完成時間或篩選欄位。因此：

- 可以宣稱：標記伏筆、集中查看伏筆標記、跳回原文。
- 不可宣稱：自動列出尚未回收伏筆、追蹤伏筆回收、判斷整體連動是否完成。

### 敘事大綱與世界時間軸不是同一筆資料

舊文件將 V4.2 過渡時間軸描述為和大綱共用 OutlineItem，這只適用歷史版本。現況世界時間軸由 Event 擁有內容，可選擇關聯 OutlineItem；兩者可連動但不會雙向等值同步。

## P2：可靠性與 UX

- 刪除後復原規則不一致：卷節有短期 UI Undo，部分設定刪除立即生效；跨 store 刪除沒有垃圾桶或跨啟動復原。
- 角色同步只自動更新已連結引用；同名、別名與未連結文字必須維持「候選替換」描述。
- 物品正文引用依名稱掃描，不具角色引用同等的 UUID 穩定性。
- 固定最低 macOS 26.5、簽章、封裝與 V4.4.9 實機右鍵狀態仍需發布前驗證。

## 結論

帆夢已具備可展示的「正文—設定—敘事大綱—世界時間」連動骨架，也有相當完整的模型與遷移測試。現階段最值得發展的產品方向是伏筆生命週期，但在 schema 與 UI 完成前只能作為預告方向。匯出路徑、刪除入口一致性與多 store 備份已補齊；公開測試前仍需完成真實 UI、故障注入、簽章與封裝驗證。

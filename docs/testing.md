# 測試策略

> 更新日期：2026-09-18。

## 現況

- `SailuneTests/ItemV3Tests.swift`：41 個 XCTest，新增物品副本 reconcile 與六 store／封面完整備份還原。
- `SailuneTests/V42OutlineTests.swift`：53 個 XCTest，新增能力舊歷史同次可見、冪等遷移與跨書／失效 Node 修復。
- `SailuneTests/V5SettingsTests.swift`：46 個 XCTest，新增勢力跨書端點、重複、隸屬方向與允許承接循環的 reconcile 驗證。
- 原始碼合計：140 個 XCTest 方法。
- 最近執行：2026-09-18，完整 140 項 XCTest 通過；無簽章 Debug build 與測試成功。
- 前次文件化基線：2026-09-14，V5 settings 專項 16 項及完整 106 項均通過；無簽章 Release 建置成功。

## 每次修改至少驗證

- `git diff --check`。
- 受影響模型的建立、修改、保存重開與刪除。
- 觸及正文時檢查 CJK 輸入、自動儲存、字數、角色引用、StoryTag、OutlineItemAnchor 及 Undo／Redo。
- 觸及跨 store 時檢查主資料先保存、附屬清理失敗、冪等重試及其他書籍隔離。
- 觸及 schema 時檢查全新 store、前一版實體 store 與重開不重複遷移。
- 觸及畫面或 AppKit 行為時補人工冒煙，不以 view projection 單元測試取代。

## 已有高價值覆蓋

- 世界時間：bootstrap 冪等、紀元排序與改元、年月日粒度、主副軸可見性、同日事件順序、保存重開、節點／軸刪除保留正文。
- 故事規劃：四類故事線、單一主線、多階段、正文與手動項目、位置與排序、失效來源降級、V1→V7 遷移，以及時間序日期／節次／總開關矩陣。
- 錨點：前方插入、重複文字最近候選、完全消失、StoryTag 刪除與 OutlineItem 節首草稿降級、同一步 Undo／Redo。
- 跨 store：Book／Event 清理、primary failure 與 deferred cleanup、孤立 metadata 修復及兩書隔離。
- 物品副本：獨立實例、持有人、等級、歷史、舊 quantity 回填及刪除收斂。

## 尚缺覆蓋

- 六個 store 任一保存失敗時的完整 fault matrix，以及還原中斷的人工故障注入。
- TXT／EPUB 存檔面板、卷節 Undo、備份排程重啟與刪除錯誤訊息的實機 UI 驗收。
- 大型長篇正文、數百角色、同名角色／物品、密集重複錨點的效能與準確度。
- V4.4.81 Undo／Redo、V4.4.9 右鍵工具、Apple 寫作工具的實機 UI 組合。

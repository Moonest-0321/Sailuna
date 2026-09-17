# 測試策略

> 更新日期：2026-09-17。

## 現況

- `SailuneTests/ItemV3Tests.swift`：39 個 XCTest，涵蓋編輯器橋接、右鍵選單、主 store、世界時間軸、標籤、物品副本、跨 store 刪除與投影。
- `SailuneTests/V42OutlineTests.swift`：51 個 XCTest，涵蓋故事規劃 schema V1–V7、錨點、Undo／Redo 快照、故事背景、故事線／階段／安置、敘事／時間序投影、事件與來源 metadata 及修復。
- `SailuneTests/V5SettingsTests.swift`：38 個 XCTest，涵蓋七項分類（語言退役後不再列入新選項）、八套政體、九套信仰、十四套技術階段（九套現實、五套虛構）、39 套資源及 18 套族群／種族固定案例的完整性、穩定 UUID、選擇保存／清除、勢力條目分類限制及參照修復保留；族群測試另驗證現實／虛構分組、普通條目可編輯與分類提示。
- 原始碼合計：127 個 XCTest 方法。
- 最近執行：2026-09-17，V5 settings 專項 38 項及完整 127 項 XCTest 通過，包含政體、信仰、現實／虛構技術階段、資源與族群／種族目錄、選擇保存、唯讀辨識、勢力連接分類限制與修復保留；無簽章 Debug 測試建置成功。
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

- Volume／Section／角色事件各 UI 入口是否使用集中刪除及立即清除跨模組引用。
- 六個 store 任一保存失敗時的完整 fault matrix、備份與還原。
- 固定匯出路徑在其他 macOS 帳號下的失敗與 UI 回饋。
- 大型長篇正文、數百角色、同名角色／物品、密集重複錨點的效能與準確度。
- V4.4.81 Undo／Redo、V4.4.9 右鍵工具、Apple 寫作工具的實機 UI 組合。

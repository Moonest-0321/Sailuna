# 程式寫法規則與操作文件更新

> 狀態：closed（文件工作完成；V9 共用化工作仍維持 paused）

## 目標與範圍

- 目標：把 UI 共用規則與內部 Swift／SwiftUI 責任邊界整理成可執行的寫法規範，並更新日常開發流程與驗收文件。
- 範圍：`AGENTS.md`、程式碼規範、開發流程、測試策略、專案狀態及 V9 交接。
- 非目標：修改產品程式、變更 UI／資料行為、重開 V9、擴充 V9 固定盤點基準、建置或執行程式測試。

## R／U／I

| 關卡 | 狀態 | 理由 |
|---|---|---|
| R | approved | 使用者明確要求記錄程式寫法規則並更新操作文件。 |
| U | not_applicable | 純文件更新，不改產品畫面或互動。 |
| I | approved | 文件位置沿用既有 `coding-standards.md`、`development-workflow.md` 與 `testing.md`，另建立此工作單保存決策及驗收。 |

## 已定規則

- View 呈現並發送意圖；資料責任與跨模型不變條件集中於具名 Store／Coordinator action；共用 UI 不依賴領域資料層。
- 新增／重構前搜尋既有型別、共用 UI、token、圖標、文案和測試；重用既有契約，例外需列呼叫點與理由。
- 抽取／搬檔只改責任位置，不暗中改變互動、保存、錯誤或資料結果。
- 使用者已核定的產品政策優先；改變產品結果須回到需求批准流程。
- V9 固定 2,256 筆盤點保持凍結；不因單一新命中擴張，只有整個需求類別漏列或原分類錯誤才提出範圍變更。

## 驗收

- 已更新 `AGENTS.md`、`docs/coding-standards.md`、`docs/development-workflow.md`、`docs/testing.md`。
- 已在專案狀態與 V9 交接記錄文件更新及 V9 暫停邊界。
- 已執行 `git diff --check`；未執行 build／XCTest，符合純文件工作範圍。

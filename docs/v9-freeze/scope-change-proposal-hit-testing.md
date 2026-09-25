# V9 範圍變更提案：非 Button 命中與手勢

> 狀態：提案，尚未納入凍結基準或授權實作（2026-09-25）。

## 漏項證據

V9 原規劃的「UI 互動契約」明確包含整列命中、遮罩與疊層接收事件、裁切區、拖曳／縮放手勢競爭；固定十家族的 `button` 規則只搜尋 `Button(`/`SailuneIconButton(`，`surface` 只搜尋背景／色彩，沒有對非 Button 的 hit-test／gesture 修飾器建立逐項 ID。因此這是**整個需求類別未被固定清單覆蓋**，不是單一新發現的呼叫點。

在同一批已凍結的 86 個產品 Swift 檔中，以 `\.(onTapGesture|gesture|highPriorityGesture|simultaneousGesture|allowsHitTesting|contentShape|dropDestination|draggable|onDrop|onDrag|zIndex)\b` 唯讀搜尋，找到 14 檔共 115 筆：`contentShape` 64、`onTapGesture` 20、`zIndex` 14、`allowsHitTesting` 10、`highPriorityGesture` 4、`simultaneousGesture` 2、`gesture` 1。例：`MapViews.swift` 同時有 pan 的 `simultaneousGesture`、標記拖曳的 `highPriorityGesture` 和 `zIndex`；角色詳情有整列 `contentShape(Rectangle())`。沒有 `dropDestination` 等命中不代表可排除其他語法，需要在核定範圍後定清搜尋規則。

## 建議邊界

- 保留原 2,256 個 ID、十家族及三個原始 CSV 的雜湊，不重建或重排。
- 若核定，另建 `interaction_hit_test` 補充家族，僅對**凍結當時 86 個產品檔**中上述修飾器產生獨立 ID、逐項三態與理由；先審原有整列與手勢，不藉此加入後來新檔或額外視覺變更。
- 先做唯讀風險分類。任何與既有 UI 不同的 hit area、拖曳／點擊優先級或遮罩行為，都須按具體 U／I 工作單核定。共用化只處理契約相同的外殼；原生地圖和正文手勢可列合理例外。
- 驗收至少覆蓋地圖標記點擊／拖曳／平移、書籍／章節列點擊及拖曳、overlay 空白取消與不穿透、Light／Dark 對照；用隔離資料，避免正式作者資料。

## 成本與決策

範圍變化為最多 115 個新的靜態命中點，涉及 14 檔；後續實際需要修改的數量待來源核對，不預設為 115。這會增加逐項分類與實機互動驗收成本。未核定前，原 V9 清單照既定批次處置；本提案不改原結案門檻，也不把新 ID 計入 2,256。

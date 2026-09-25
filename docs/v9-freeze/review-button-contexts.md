# V9 固定按鈕清單：原生容器與共用樣式複核

本頁只記錄凍結 ID 的來源契約，不變更按鈕位置、外觀或資料動作。畫面命中、鍵盤、Light／Dark 仍須獨立驗收。

| ID | 來源位置 | 處置與證據 |
|---|---|---|
| V9-0113 | `BookOverviewView` 封面右鍵選單 | 合理例外。破壞性 `Label("移除封面")` 由系統 `contextMenu` 承載；共用自訂 icon 按鈕會改變選單契約。 |
| V9-0286 | `CharacterInspectorViews` 角色列尾端滑動操作 | 合理例外。`swipeActions` 提供系統破壞性動作，標籤與刪除符號已取共用來源；保留系統命中與滑動語意。 |
| V9-0509 | `ContentView` 書卡右鍵選單 | 合理例外。書籍刪除是 `contextMenu` 的系統破壞性選項；文案與符號已取共用來源。 |
| V9-0535 | `ContentView.accountAction` | 已共用。帳號選單項目集中由同一 helper 建立，`Label` 整列 `contentShape(Rectangle())`、`.plain` 與 `minHeight: 28` 在 helper 內固定。 |
| V9-1176 | `OutlineViews` 故事線刪除 | 已共用。使用 `PlanningActionStyle` 及 `SailuneActionCopy.deleteStoryLine`／`SailuneSymbol.delete`；確認目標由領域 state 保存。 |
| V9-1222 | `OutlineViews` 階段刪除 | 已共用。使用 `PlanningActionStyle` 及 `SailuneActionCopy.deleteStage`／`SailuneSymbol.delete`，另有明確 help；確認由領域 state 控制。 |
| V9-1299 | `OutlineViews` 大綱項目刪除 | 已共用。使用 `PlanningActionStyle`、共用刪除符號及領域專用文字；領域確認 state 保留。 |
| V9-2021 | `TimelineViews` 副軸刪除 | 合理例外。位於原生選單，與「重新命名」同為 `Label` 選項；保留系統選單命中，刪除字形取共用來源。 |

上述「已共用」僅表示來源接線與既有命中契約已對齊，不表示實際畫面驗收通過。

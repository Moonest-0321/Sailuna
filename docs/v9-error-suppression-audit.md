# V9 `try?` 失敗路徑稽核

> 靜態核對：2026-09-25，`rg -n 'try\?' Sailune --glob '*.swift'` 初始盤點為 45 處；V9.2v 完成後為 38 處；依 V9.2c 診斷批次為 21 處，V9.2y 處理 ItemCopyHistory 後為 19 處，V9.2z 處理故事背景後為 17 處，V9.2ab 集中兩處規劃投影診斷後為 15 處，V9.2ae 為改元接續提示兩處查詢加診斷後為 13 處，V9.2aj 三處 AI 回應解碼加診斷後為 10 處，V9.2ak 自訂封面讀取加診斷後目前為 9 處。此清單依來源碼用途初分；「候選風險」不是已重現的缺陷，搜尋數量也不能替代故障注入。

## 優先處理：可能改變資料正確性或還原結果

| 範圍與命中 | 來源碼中的失敗折疊 | 建議工作邊界 |
|---|---|---|
| `SailuneBackupService.swift` 七處還原 catch 中的刪除／搬回、另有一處暫存目錄清理 | 還原中途失敗後，清除部分新資料、把原檔從 rollback 目錄搬回及清理目錄時使用 `try?`；若搬回失敗，最後只拋出最初的錯誤。暫存清理屬不同等級。 | 單獨設計「原錯誤＋rollback 錯誤」結果；失敗時保留 rollback 來源與可診斷路徑，確認啟動錯誤文案不能宣稱已完全回復。任何正式修正前先檢查恢復流程與檔案型失敗情境。 |
| `InspectorViews.swift` 能力補償保存 | link 失敗後的刪除補償保存若失敗，現在會記入 OSLog，但仍向使用者呈現原始 link 錯誤；是否改變部分成功結果待核定。 | 依 `v9.2c-persistence-failure-paths.md` 後續決定部分成功與修復入口。 |
| `MapCatalog.swift` 三處地圖列表與 `V5SettingModels.swift` 十三處設定列表 | fetch 失敗仍回傳空清單以維持既有操作結果，現已記錄 OSLog 診斷；操作呼叫端仍可能把錯誤視為無資料。標記刪除已改用可拋錯 Place 查詢並使用既有地圖錯誤提示。 | 依 `v9.2c-persistence-failure-paths.md` 後續核定空集合與讀取失敗是否需有不同結果；不得把目前的日誌當成已區分結果。 |
| `V5SettingModels.swift` 十三處 | 列表／關聯查詢把 fetch 失敗視為空列表；部分結果仍用於操作決策或設定選取。 | 按「純顯示」與「操作決策」拆分，先核對依空列表建立或修改資料的入口；不要把全部畫面 API 一次改成 throwing。 |
| `ItemCopy.swift` JSON encode/decode（已診斷） | UUID 陣列 encode 失敗仍回空 `Data`，decode 失敗仍回空陣列；錯誤已記 OSLog，若資料已損壞仍可能被當成沒有關聯。 | V9.2y 只補診斷並維持 fallback；追查欄位 schema、寫入位置與舊資料相容性，再決定保留原值或回報資料損壞。兩處失敗後 `refresh()` 失敗也已另記 OSLog。 |

## 次序處理：資訊可能不完整或修復失敗被遮蔽

| 範圍與命中 | 來源碼中的失敗折疊 | 建議工作邊界 |
|---|---|---|
| `OutlineViews.swift`／`TimelineViews.swift` 規劃投影（已診斷），另兩處年號查詢 | 規劃投影失敗已由共用入口記錄 OSLog，但顯示仍為空集合；改元接續提示的年號查詢失敗已記 OSLog，畫面仍以沒有提示或預設第 1 年顯示，與真正沒有資料同形。 | 規劃投影與改元提示的錯誤／空資料 UI 政策待另議；目前均只補診斷。 |
| `BookOutline.swift` 背景 JSON 轉換（已診斷） | decode 失敗仍走舊自由文字相容路徑；以 `{` 開頭的疑似 JSON 失敗會記 OSLog。encode 失敗仍回退 `otherBackground` 並記 OSLog。 | V9.2z 未改格式與操作結果；是否為疑似損壞資料提供修復入口待另議。 |

## 目前看似可容忍，仍需保留理由

- `SailuneAIClient.swift` 三處解碼已加入分支明確的 private OSLog，失敗仍回 `nil` 並由既有 `invalidResponse` 出口處理；仍需以故障注入核對格式錯誤與空答案情境。
- `BookCoverStore.swift` 自訂封面缺檔仍走預設封面 fallback；檔案存在但讀取或解碼失敗已記 private OSLog，回傳與匯出顯示契約未改，仍需實際匯出驗收。
- `OutlineViews.swift` 一處 `Task.sleep`：短暫成功提示的延遲可因取消而結束，和資料保存無關。
- `SailuneBackupService.swift` 一處建立封裝時的暫存目錄 `defer` 清理：失敗不改封裝內容，但可能留下暫存檔；應有清理診斷或維護策略。

## 已修正與使用方式

- V9.2e：勢力承接／關係新增的兩個 throwing API 已將重複檢查 fetch 改為 `try`，查詢失敗不會繼續插入。
- V9.2f：完整備份中的封面／地圖資產目錄存在但無法列舉時已改為拋錯，避免漏檔卻回報成功。
- V9.2h：AI 設定分析快照的七個主 store fetch 已透過既有錯誤出口回報，不再用空資料組裝附件；當時尚未涵蓋設定 store 讀取。
- V9.2i：AI 勢力分析附件的設定 store 查詢已改走單獨的 throwing 入口；原有畫面列表 API 的 `try?` 數量與行為不變，因此全專案靜態命中仍為 48 處。設定選取器的失敗呈現不在本批範圍。
- V9.2j：地點與世界條目刪除前的 `MapPlacement`／勢力／`PowerAssetLink` 查詢需全部成功，才開始刪除與解除連結；失敗會記入 Store 診斷並停止，靜態命中減至 46 處。保存失敗與 UI 錯誤呈現仍須另行處理。
- V9.2k：主 store 父目錄建立從 `storeURL` 的 `try?` 移到啟動的 throwing 流程，失敗時以資料目錄階段回報；靜態命中減至 45 處。
- V9.2v：能力進度、物品副本與故事規劃 Store 的七處 rollback 後快取重載改為明確記錄次要錯誤，保留原始錯誤；當時 `try?` 靜態命中減至 38 處。未執行故障注入。
- 使用者核定 V9.2c 先只記錄錯誤、不改操作結果：能力補償保存及 16 個設定／地圖列表 fetch fallback 已使用 OSLog 共用診斷；地圖與設定列表仍維持空陣列結果。當時 `try?` 靜態命中為 21 處。
- 使用者核定 V9.2g 只改錯誤文字；啟動不再宣稱原資料已回復，而是標示回復狀態未確認。rollback 行為仍待議。
- 使用者核定 V9.2t 刪除後仍關閉標記編輯器，只顯示錯誤；來源 Place 查詢改用 throwing API 並送入既有地圖錯誤提示，Store placement／save 錯誤沿用既有提示。
- V9.2y：ItemCopyHistory JSON encode／decode 改明確 `do/catch` 並記錄 private OSLog，維持空 `Data`／空陣列 fallback；build 與 `git diff --check` 通過，靜態命中為 19 處，未跑 XCTest／故障注入。
- V9.2z：故事背景的疑似 JSON 解碼失敗與編碼失敗改記 private OSLog；舊自由文字與 `otherBackground` fallback 維持原結果，build 與 `git diff --check` 通過，靜態命中為 17 處，未跑 XCTest／故障注入。
- V9.2ab：時間軸與大綱兩處規劃投影的 `try?` 改走同一個 `buildForDisplay` 診斷入口；來源可區分，失敗仍回空清單。build 與 `git diff --check` 通過，當時靜態命中為 15 處，未跑 XCTest／故障注入。
- V9.2ae：改元接續提示兩處查詢失敗已記 private OSLog，原空提示及第 1 年 fallback 不變；build 與 `git diff --check` 通過，目前靜態命中 13 處，未跑 XCTest／故障注入。
- V9.2aj：backend 回應、Gemini interaction 及 model output 三處解碼失敗加入 private OSLog，原 `nil`／`invalidResponse` 結果不變；build 與 `git diff --check` 通過，目前靜態命中 10 處，未跑 XCTest／故障注入。
- V9.2ak：自訂封面不存在仍直接 fallback；檔案存在但讀取或內容無效則記 private OSLog 並沿用相同 fallback。build 與 `git diff --check` 通過，目前靜態命中 9 處，未跑 XCTest／故障注入／匯出。
- V9.2o：地圖刪除先完成版本與 placement 查詢才修改模型；版本刪除以可拋錯查詢判斷是否最後一版。三個 nonthrowing 列表 API 未刪，靜態 `try?` 命中仍為 45 處。
- V9.2p：地圖／版本建立與改名、標記目的地配對的必要地圖／版本查詢會在寫入前傳遞錯誤；三個畫面列表 API 保留，靜態 `try?` 命中仍為 45 處。
- V9.2q：預設地圖初始化在插入 profile／地圖／版本／placement 前完成必要查詢；地圖標記建立的 Place 排序查詢也會傳遞錯誤。畫面列表 API 保留，靜態 `try?` 命中仍為 45 處。
- V9.2r：標記跳轉前以可拋錯查詢核對來源 Place／placement，查詢失敗不會被當成標記不存在。畫面列表 API 保留，靜態 `try?` 命中仍為 45 處。
- V9.2s：既有標記編輯沿用可拋錯來源查詢；來源缺失或讀取失敗時停止，不轉成新增。三個畫面列表 API 保留，靜態 `try?` 命中仍為 45 處。
- 後續每批以一條具體操作鏈建立工作單，列出正常空值、讀取／保存失敗、部分成功、錯誤出口與資料相容性；需要 R／U／I 的行為決策依專案流程核定。V9 完成前需以實際錯誤路徑證據核對高風險項，不能只把 `try?` 數量降為零。

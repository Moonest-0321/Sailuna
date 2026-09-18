# 備份、遷移與資料修復

V4.4.81 的 StoryPlanning schema V7 以新增 `PlanningRecordMetadata` 的輕量遷移升級 V6；既有時間序不改寫、不猜測故事線。產品 V5.6 不遷移既有主 store：主資料維持 `NovelWriterSchemaV5`。設定集配置、自訂勢力層級、勢力、直接隸屬、非隸屬關係、成員、勢力資產／優勢、地點與世界條目保存於獨立 `V5SettingsSchemaV10` store，並由 `V5SettingsMigrationPlan` 依序升級 V1～V10。

V5.5 新增 V9 snapshot，保存勢力生命週期、承接與成員職務時間序；V8→V9 採自訂遷移，舊 `PowerMember.title` 若非空且尚無職務，會回填為第一筆現任 `PowerMemberRole`。V8 保留 V5.4 原始結構，不可再就地擴充；時間定位只保存 Node UUID，不複製世界日期或正文節次。

V5.6 新增 V10 snapshot 與 `PowerRelation`；V9→V10 採輕量遷移。既有 `relationshipNotes` 原文保留，新結構化關係初始為空，不從自由文字猜測同盟、敵對或宗主關係。

Book 狀態曾直接加入 `NovelWriterSchemaV5` 而造成既有 `Sailune-v5.store` 無法載入，該持久化變更已撤回。V6.0c 僅保留 `@Transient` 狀態並預設草稿；正式保存連載／完結／草稿前，必須先建立不可變 V5 snapshot、相容的新 schema 與舊 store 遷移測試。

## 目前啟動順序

1. 若有已驗證的待還原備份，先建立當前六 store 與封面的安全備份，再於任何 `ModelContainer` 開啟前整組置換；中途失敗立即 rollback。
2. 尋找舊版 V3 或 V2 store。
3. 以既有 `NovelWriterSchemaV5` 原樣開啟主資料庫，不執行 schema migration。
4. 將舊資料匯入 V5；若 V5 已有資料，先驗證匯入完整性。
5. 執行懸空資料修復與 V4／V5 回填，並冪等清除舊 `Organization`、角色—組織關聯、組織身分歷史及其 StoryPlanning metadata；其他主資料不允許刪除。
6. 開啟獨立的 V5 settings、物品副本、能力進度與故事規劃 store；settings store 依 `V5SettingsMigrationPlan` 由既有版本逐步升級至 V10，故事規劃 store 依 `StoryPlanningMigrationPlan` lightweight migration 至 V7，再轉換舊結構標籤。
7. 依主 store 的 Book／Character／Item／Ability／Node UUID 與 book 對照，冪等修復 settings、物品副本與能力進度後才顯示主畫面。

V4.4.8 在主 container 與 StoryPlanning store 都成功開啟後，會以現存 Book／Event UUID 執行跨 store 一致性修復；進入世界時間軸時再做一次相同的冪等檢查。它不新增 schema 或 migration，也不會因 OutlineItem 來源缺失而刪除 Event metadata。

## 目前資料檔

- 主資料：`Sailune-v5.store`
- V5 設定集與勢力：`Sailune-v5-settings.store`
- 舊資料來源：`Sailune-v3.store`、`Sailune.store`
- 物品副本：`Sailune-v5-item-copies.store`
- 副本等級選擇：`Sailune-v5-item-copy-level-selections.store`
- 能力進度：`Sailune-v5-ability-progress.store`
- 故事規劃：`Sailune-v5-story-planning.store`

實際位置由應用程式的 Application Support 目錄決定；測試時可使用 `SAILUNE_TEST_STORE_URL` 指定主資料庫。

## 歷史版本差異（保留、不修改）

- V1／V2 使用較早的模型命名與資料範圍。
- V3 將時間軸、紀元、時間釘子與事件納入 released schema。
- V5 將物品、角色設定與多項歷史資料納入主 schema，並把物品副本拆至獨立 store。
- Git 產品版本曾出現 V2.3.4、2.4.5 後再回到 V2.3.5 等命名順序差異；這些是歷史事實，不修改提交訊息。

## 可持續遷移規則

- 歷史 schema 只能新增新快照，不得修改已發布快照。
- 遷移與回填必須可重複執行（idempotent）。
- 匯入前後驗證每個核心實體的 UUID 數量與集合。
- 任何回填不得刪除原始資料，除非有明確且可驗證的孤立資料規則。
- 新版本發布前，使用代表性舊 store 做開啟、匯入、重新開啟與資料抽查。
- 多 store 備份必須視為一組；只備份主 store 會造成副本、能力或故事規劃遺失。

## V5.6 完整備份／還原

- 作者設定可輸出單一 `.sailunebackup`；內容是帶 manifest 的版本化封裝，包含六個 SQLite online snapshot、封面、檔案大小與 SHA-256 checksum。
- 建立備份前先提交全部 store；任一儲存或 snapshot 失敗時不產生成功備份。
- 還原選擇時先驗證封裝版本、schema、檔案清單與 checksum，只排程已驗證備份。
- 正式置換在下次啟動、container 開啟前執行；先強制建立 `Sailune/Recovery Backups` 安全備份，再整組置換。失敗會復原原 store 與封面，並停止啟動顯示原因。

## V4.2 故事規劃遷移

- `StoryPlanningSchemaV1`、V2、V3 均保持不變；V3 新增 `OutlineItemAnchor`，不回寫 V2 的 `OutlineItem` snapshot；V4 只新增獨立的階段開始定位與手動安置模型，不改寫 V3 的 `OutlineStage`／`OutlineItem`。
- store 檔名維持 `Sailune-v5-story-planning.store`，由 SwiftData lightweight migration 原地升級；發布前仍需把它與主 store 一起備份。
- V2→V3 開啟後在同一個 save 內將主軸／支線／計劃加入轉為同 UUID 的大綱項目及錨點，成功後才刪除原標籤；伏筆／修改不變。檔案型測試會驗證轉換與重開不重複。
- V4.3 的故事背景引導不新增 SwiftData 欄位或 schema；使用既有 `backgroundText` 的可版本化結構值保存。舊自由文字讀取時視為「其他背景」，首次儲存才轉為結構值，內容不遺失。
- V3→V4 以 lightweight migration 開啟。既有階段不從最早正文項目猜測開始位置，既有手動項目不猜測安置位置；兩者保留原資料並在 UI 顯示需設定／待安置提示。檔案型測試驗證舊 V3 資料重開後 UUID 與數量不變。
- V4.4 的寬版工作區、時間軸投影及故事背景入口搬移均為呈現層變更，不新增 schema、不複製 `OutlineItem`，也不搬動 `backgroundText`；因此不需要新的資料遷移。無法解析的時間軸位置只在執行期間列入待安置區。
- 主 store 內既有 `Timeline`、`Node`、`Event` 不刪除、不改寫，也不自動複製為 V4.2 `OutlineItem`；第一版採保留策略，避免在時間語意尚未定案時錯誤轉換使用者資料。
- V5→V6 只新增空的 `TimelineEventCardMetadata` entity；不替舊 Event 猜測 OutlineItem。舊 Event 若已有有效 Section，執行期仍視為已寫入相容卡；作者主動綁定後才建立 metadata。
- 產品 V5 的 `BookSidebarSetting`、`PowerLevel`、`PowerUnit`、`PowerSubordination`、`Place` 與 `WorldTerm` 位於獨立 settings store；主 store 不升級 schema。舊 Organization 型別保留於主 schema 以安全開啟舊 store，啟動清理只移除其資料，不轉換為勢力。
- Settings V1→V2 保留既有勢力 UUID、名稱、簡介、側邊欄配置、地點與世界條目；既有勢力遷移為未指定層級。舊連線沒有層級可供驗證，因此遷移只刪除 `PowerSubordination`，不建立預設層級，也不刪除或改寫其他 store 的資料。
- Settings V2→V3 新增高層管理員、其他名單、勢力關係、政治與宗教自由文字欄位；既有 V2 勢力與自訂層級完整保留。尚無層級的既有書補上兩個中性預設層級，已有自訂層級者不增補、不改名。
- Settings V3→V4 新增地點的其他名稱、類型、詳細描述與備註，以及世界條目的其他名稱、分類、詳細說明、使用範例與備註；既有 Place／WorldTerm UUID、名稱、簡介與排序保留。新增 persisted 欄位可為空值，編輯器以空字串呈現尚未設定，避免破壞既有 V3 store。
- Settings V4→V5 新增勢力的世界條目 UUID 連接、目的與 `PowerMember`；既有自由文字不猜測轉換。Settings V5→V6 只為 `BookSidebarSetting` 新增目錄版本，讓既有書籍顯示世界條目一次，並保留作者之後的隱藏選擇；不修改任何 WorldTerm 內容。
- Settings V6→V7 為 WorldTerm 新增運作與表現、限制／差異／例外及世界影響三個可空欄位；既有 `detailedDescription` 不改名、不拆分，完整成為 UI 的核心定義。檔案型測試確認既有 UUID、書籍、分類、簡介、詳細說明、範例、備註、排序與 sidebar 目錄版本皆保留。
- 世界條目有限分類不另升級 schema；`termCategory` 仍以可空字串保存。既有 V4 自由文字分類（包括退役的「語言」）不被猜測或刪除，編輯器以「既有分類」保留，作者選擇制度、信仰、技術、資源、族群／種族、文化習俗或專有名詞後才替換。族群／種族預設只保存既有 WorldTerm 文字欄位，不新增遷移步驟。
- V6→V7 只新增空的 `PlanningRecordMetadata` entity。既有時間序若有節次但沒有歸屬，執行期列入「未分類時間序」；作者儲存定位後才建立 metadata。來源刪除後，工作區開啟時會冪等清理孤立 metadata。
- 新建／綁定採先保存主 Event、再保存 metadata；後者失敗時保留 Event 並允許重試。刪 Event 後若 metadata 清理失敗，孤立記錄不顯示，下一次時間軸載入時冪等清理。

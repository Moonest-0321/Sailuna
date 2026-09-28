# 拾頁 `.shiye` 作品發布與帆夢一鍵發布需求草案

> 狀態：active；R／U／I approved，開始跨 Sailune／Pagelet 實作。
>
> 更新時間：2026-09-28（Asia/Taipei）
>
> 工作名稱：`.shiye` 發布契約與帆夢一鍵發布

## 批准狀態

| 關卡 | 狀態 | 批准依據 |
|---|---|---|
| R：需求 | approved | 使用者 2026-09-28 回覆「R」 |
| U：UI | approved | 使用者 2026-09-28 回覆「U」；移除 `.shiye` 匯出／另存操作 |
| I：實作與測試 | approved | 使用者 2026-09-28 回覆「固定顯示節，批准 I」 |

- 最近一次使用者批准：I（2026-09-28）；網站固定顯示「節」，封包保留來源 sectionUnit。

## 問題、期待與不可破壞事項

- **問題**：帆夢目前匯出 `sailune.reader-book` 單一 JSON；拾頁 CLI 只讀 `pagelet-book` 資料夾（`book.json`、封面圖片及 `chapters/*.md`）；另有 `.shiye` ZIP 草案。三者欄位、區塊表示法及封裝皆不同，帆夢匯出檔目前不能直接由拾頁匯入。
- **期待結果**：以版本化 `.shiye` 作為帆夢與拾頁唯一的正式發布交換格式；作者在帆夢選擇發布／更新後，App 在內部產生封包並直接傳送至拾頁，不提供另存 `.shiye` 的使用者流程。
- **必須保留**：
  - 書籍、卷、節穩定 UUID；重複發布更新原有資料，不產生重複書或章節，也不令讀者進度指向錯誤節次。
  - 拾頁資料庫完整驗證、資料寫入交易、RLS 與作者作品權限；Service role／secret 不得進入帆夢 App 或瀏覽器。
  - 拾頁推薦排序及網站下架狀態由網站管理；匯入不得意外重設這些管理欄位。
  - 正文以區塊純文字傳送，只保留正文、幕標題及必要空行；不傳送帆夢本機字型／顏色格式、設定集、AI 對話、備註或地圖。
  - App 尚未登入或離線時，本機寫作、資料及現有匯出能力不受影響。

## 使用流程與情境

1. 作者在帆夢發布列表選擇可發布的作品，先完成目前既有的發布狀態／標籤設定。
2. 作者查看即將發布的作品摘要，選擇「發布」或「更新至拾頁」。
3. 帆夢在記憶體中產生符合已核定版本的 `.shiye` 封包，透過已登入作者的受權限保護介面直接傳送；不寫出供使用者另存的 `.shiye` 檔案。
4. 拾頁驗證格式、ID、區塊、雜湊及作者對該書的權限；驗證成功後建立或更新書籍、卷、節及封面。
5. 發布完成時回傳建立／更新／下架數量及可供作者檢視的結果；失敗時提供可採取的修正或重試方式，不留下半套可見作品。

## 範圍提案

### 必要

- 以 `docs/spec-shiye-book-package.md` 為起點，核定唯一的 `.shiye` v1 格式，並讓帆夢 exporter、拾頁 importer 與直接發布介面遵守同一契約。
- 讓拾頁本機 CLI 能預檢及匯入 `.shiye`，供維運與格式驗證使用；保留現有 `pagelet-book` 匯入相容性至明確淘汰／轉換政策核定，避免既有樣本與已發布流程失效。
- 帆夢登入作者後可一鍵發布／更新；網路失敗時從本機來源重新產生相同 ID 的封包重試，不要求作者先匯出檔案。
- 建立有版本號的發布介面；作者身分及 `authors.user_id`／書籍歸屬由資料庫層驗證，不信任 App 傳入的作者 ID。
- 確認發布／更新的狀態語意：只可發布連載或完結作品；草稿及已下架狀態不能被匯出檔悄悄轉成網站可見作品。Web 管理的書籍／章節下架狀態維持既有政策。
- 做錯誤可恢復設計：驗證或資料庫失敗時沒有部分可見資料；儲存服務中的暫存封面／檔案若已先寫入，須可清理或安全重用。

### 非目標（本提案）

- 開放其他作者註冊、作者自助綁定或多作者後台。
- 網頁後台編輯正文、手動逐章編輯、TXT／DOCX／EPUB 轉換匯入。
- 發布人物、物品、能力、勢力、地圖、大綱、AI 對話、備註或其他只供作者使用的資料。
- 在本階段改動讀者書架／閱讀進度模型，或改造目前推薦、分析數據與網站閱讀 UI。
- 以標題猜測同一本書；作品與章節配對一律使用契約 ID。

## 格式核對與待解差異

目前 `.shiye` 草案已定義 `manifest.json`、`cover.png` 與每節 JSON 檔，並含穩定 ID、章節雜湊與區塊內容。不過實際 exporter 與草案仍有具體差異，須在 I 階段收斂，不可假設已相容：

- 草案格式標記為 `sailune.shiye-book`；目前 exporter 使用 `sailune.reader-book`。
- 草案封面是獨立 PNG entry；目前 JSON 內含 Base64 封面。
- 草案章節區塊類型是 `heading`／`paragraph`／`blank`；目前 exporter 使用 `sceneHeading`／`paragraph`，空行目前表示為空文字 paragraph。
- 草案雜湊涵蓋章節 JSON 原始位元組並帶 `sha256:` 前綴；目前 exporter 雜湊自訂的 block 序列，沒有同一個演算法標記形式。
- 草案索引從 1 起；目前 exporter 對 `order` 使用從 0 起的索引。
- 草案有語言、標籤、sectionUnit 與生成器版本；目前 exporter 欄位名稱及巢狀結構不同。
- 草案寫可增量同步；R 核定第一版傳送完整 `.shiye` 快照，以穩定 ID 做新增／更新／下架，使用 hash 判斷未變更章節並可跳過正文寫入，不另做差異封包協定。
- 格式擴充規則提案已納入 R：未知的選填欄位可忽略；封包宣告的必要 capability 若接收端不支援，須在寫入前清楚拒絕；新增選填欄位不升版，改變既有欄位語意或必要結構才升 `formatVersion`。新版 parser 應在明確支援期限內繼續讀取舊版封包。
- 新增傳輸資料時以新增明確版本的檔案／資料區段承載，避免持續把不同領域塞進單一 manifest；每項資料需標明是否必要、對應 ID、hash 與接收端處理方式。實際資料類別及隱私政策仍由未來工作核准。

## 驗收條件提案

- [ ] 帆夢輸出的 `.shiye` 通過拾頁同版本 parser；版本未知、缺檔、重複 ID／位置、錯誤引用、雜湊不符或不合法區塊均在寫入前被拒絕並指出原因。
- [ ] 有／無封面的作品皆可發布；封面 bytes 與 manifest 一致，公開作品引用正確封面路徑。
- [ ] 首次發布建立書籍、卷、節；再次發布更新同一 UUID 的資料，不建立副本。
- [ ] 更新時，新 ID 章節建立、相同 ID 章節更新、不再出現在完整快照中的舊章節依既有政策下架；重新出現的同 ID 章節不會另建副本。
- [ ] 既有閱讀進度仍關聯原章節 ID；拾頁推薦狀態與站長下架設定不會因發布覆寫。
- [ ] 非作者、未登入者、公開匿名請求及作者嘗試操作他人作品均不能寫入；App／瀏覽器建置產物與網路請求不含 service role／secret。
- [ ] 驗證失敗、上傳中斷、資料庫失敗及重試不留下半套可見書籍；已建立的暫存檔可清理或安全復用。
- [ ] App 可辨識成功、可重試網路錯誤、格式／權限錯誤及登入失效；網站仍可用 CLI 匯入同一 `.shiye`。
- [ ] 舊 `pagelet-book` 匯入樣本在相容政策內仍有明確可驗證的處理方式。

## 已決定事項與理由

- 使用 `.shiye` 作為目標封裝格式：使用者 2026-09-28 明確選擇此方案。
- 目標流程包含帆夢一鍵發布及網站端受保護發布介面；CLI `.shiye` 匯入限維運／格式驗證用途，不作 App 使用者的備份或手動發布流程。
- Service role／secret 不進 App 或瀏覽器：沿用現有拾頁安全政策。
- 使用穩定 ID 更新作品：符合現有 App 資料模型與格式設計，可保留讀者進度。
- 第一版採完整快照，以每節 hash 跳過未變更內容；不建立差異封包協定。
- 拾頁 CLI 支援 `.shiye` 維運匯入並保留現有 `pagelet-book` 匯入相容性，直到另有淘汰決定；App 不提供 `.shiye` 匯出按鈕或另存功能。
- `.shiye` 以選填欄位和宣告 capability 擴充；改變已發布欄位語意時升版，並保留舊版讀取相容。
- 傳輸範圍限讀者可見的書籍內容；私人設定資料等不同領域需另立需求及權限規則。
- 同一作品由原作者帳號發布及更新；作品轉移不在本工作。
- 拾頁仍是已發布內容副本的呈現端；帆夢是作者來源，網站修改不回寫帆夢。

## 待確認與暫時假設

- **已實作容量**：ZIP 24 MiB、解壓 32 MiB、manifest 2 MiB、單節／extension 1 MiB、封面 4 MiB／4096 px、4096 entries；真實大書效能仍待隔離環境量測。
- **U 已核准**：發布前顯示封面、書名、筆名、分類標籤、卷數、節數與總字數，並說明完整快照更新及缺少章節的下架行為。
- **已實作重試**：DB 同交易保存冪等收據；App 在本次操作記憶體保留遠端結果，sidecar 失敗只重試本機保存。重開 App 以相同作品 UUID 的新快照更新。

## UI 提案（U approved）

- 是否適用：適用於帆夢「發布」列表；沿用既有發布頁、分類標籤與 Email 登入，不新增獨立發布區。
- 發布列表：草稿與連載中作品提供「傳送至拾頁」；完結作品也可傳送最後更新。`.shiye` 封包只在 App 內產生並直接傳送，不提供手動匯出按鈕。既有「完結」「下架」「恢復連載」操作保持獨立。
- 草稿第一次傳送沿用目前分類標籤選擇，然後進入發布預覽；連載／完結作品預覽已保存的標籤。
- 預覽內容：封面、書名、筆名、標籤、卷數、節數、總字數，以及完整快照更新的說明；明確提示封包未包含的既有網站章節會下架，不承諾預覽時列出差異清單。
- 未登入時選「傳送至拾頁」顯示登入提示並開啟既有 Email 登入；登入完成後返回本次預覽，作者再次確認傳送，避免未確認的內容自動送出。
- 傳送中顯示可取消狀態與進度；取消只在伺服器尚未提交更新時生效。提交結果不明或短暫網路失敗時提供「重試」，重試使用相同書籍／節 UUID，不建立副本。
- 成功結果顯示新增、更新、未變更及下架的節數；第一次傳送成功後才把本機草稿改為連載並保存標籤。更新失敗不改本機發布狀態及標籤。
- 權限、封包驗證、版本不支援與登入失效分別顯示可理解的原因；失敗提供重試或關閉，不提供另存 `.shiye` 檔案。
- 點遮罩或按 Escape 可取消預覽且不可穿透操作底層發布列表；傳送中是否可取消依伺服器是否已進入提交階段清楚呈現。
- 沿用現有置中確認面板樣式及 `SailuneTheme` surface token；不新增自訂視覺語言。

### 流程

1. 發布列表 → 選擇「傳送至拾頁」。
2. 草稿先選標籤；所有狀態進入封面／書目／卷節摘要預覽。
3. 未登入者登入後回到預覽；登入本身不會直接觸發上傳。
4. 確認傳送 → 顯示進度 → 成功結果／可重試錯誤。
5. 既有本機發布狀態只在首次遠端發布成功後轉為連載；失敗可用相同作品 ID 重試，不另存封包。

### 文字線框

```text
發布

《孤鷹群舞》　連載中
上次傳送：2026/09/28 14:20（若本機有成功紀錄）
[傳送至拾頁] [完結] [下架]

傳送至拾頁
┌─────────────────────────────────────────┐
│ [封面]  《孤鷹群舞》                     │
│         筆名｜奇幻、冒險                 │
│         3 卷・42 節・共 123,456 字       │
│                                         │
│ 這次會依穩定 ID 更新整本作品。           │
│ 封包中缺少的既有節會在拾頁下架。         │
│                                         │
│ 上傳 `.shiye` 前會檢查帳號及作品權限。    │
│                                         │
│                              [取消] [傳送]│
└─────────────────────────────────────────┘

傳送中：正在傳送《孤鷹群舞》     [進度條] [取消]

傳送完成
新增 2 節・更新 3 節・未變更 37 節・下架 0 節
                                      [完成]

傳送失敗：登入已逾期，尚未更新拾頁作品。
[登入] [重試] [關閉]
```

## I 實作與測試計畫（approved）

### 建議架構

1. **同一份 `.shiye` 契約**：把現有 `BookJSONExporter` 改成建構 canonical ZIP entries：`manifest.json`、選填 `cover.png`、`sections/<UUID>.json`。輸出仍只在 App 記憶體／暫存區，不提供使用者另存。以固定測試封包鎖定 NFC、UTF-8、entry path、區塊類型、1-based index 及對 section JSON bytes 計算的 SHA-256；封包宣告未知必要 capability 或版本時拒絕，未知選填欄位忽略。
2. **App 直傳私有暫存 Storage**：登入後以現有 Supabase Swift client／鑰匙圈 Session，將 `.shiye` 傳到 private `publication-staging` bucket 的 `<auth.uid>/<attemptUUID>.shiye`。RLS 只允許本人新增、讀取與刪除本人路徑。封包用量超過一般上傳建議值時改用 TUS resumable upload，讓既有 U 的進度、重試與中斷復原有真實進度來源；設定封包大小上限低於目前 Supabase Free 專案的 50 MB 全域上限。
3. **小請求觸發拾頁 API**：App 呼叫拾頁 `POST /api/publications/v1`，只送 `attemptUUID`，並帶目前作者 JWT。Next route 以 publishable key 建立帶該 Bearer token 的使用者 client，向 Supabase 驗證使用者、依該使用者 RLS 讀取 staging object、驗證／解開 ZIP、轉為 DB payload；不使用 service role。實際 `.shiye` 位元組從 App 直達 Supabase Storage，Vercel route 不做代理檔案上傳，只處理小型請求與回傳結果。
4. **驗證後才寫入**：Pagelet 共用純值 `.shiye` parser 與現有章節正文格式投影，CLI 和 API 使用同一 parser。API 將解析後資料呼叫 `publish_book_v1` RPC，沿用呼叫者 JWT，讓資料庫以 `auth.uid()` 再次驗證作者與作品歸屬。RPC 在單一交易內新增／更新全部書、卷、節、標籤與封面路徑；未出現在完整快照的舊卷／節依既有政策下架。
5. **封面和跨服務失敗**：封面使用 content-hash 命名的不可變公開路徑，例如 `<authorUUID>/<bookUUID>/<sha256>.png`；新增 Storage policy 僅允許已綁定作者寫入自身 namespace。先通過封包／所有權檢查再上傳封面，DB commit 成功後才公開引用該路徑；DB 失敗時盡力刪除孤兒物件，相同 hash 可安全重用。私有 staging 成功處理後刪除；網路結果不明時先保留供同一 attempt 重試。
6. **冪等與本機狀態**：新增以 `(user_id, attempt_uuid)` 唯一的發布收據，在同一 DB transaction 保存結果；同一 request 重送時回傳原結果。相同書／節 UUID 仍是資料更新識別。只有遠端 RPC 成功後才呼叫 `BookPublicationStore.publish` 將首次草稿轉為連載及保存標籤；若本機 sidecar 保存失敗，明確顯示「拾頁已發布，但本機狀態保存失敗」，讓重試不會重建遠端副本。
7. **相容入口**：新增 `npm run import -- <封包.shiye> [--dry-run]` 供維運與格式驗證；既有 `pagelet-book` 資料夾 importer 與 service-role-only `import_book` 保持原行為。新的 App 流程不把 service role 放在 App 或 Vercel。

### 預計資料庫變更

- `authors.user_id` 已存在且 unique，但目前沒有作者綁定／作者發布權限。以使用者人工確認的 Supabase Auth user 綁定既有作者列；不從封包筆名自動認領或自行建立作者。
- 新增 authenticated-only `publish_book_v1`，檢查 `auth.uid()` 非空、作者列綁定該 user、既有 `books.author_id` 必須仍是該作者；新書的 `author_id` 由 DB 依 user 決定。不得讓 payload 改綁其他作者。
- 新 RPC 只更新作者可發布的內容欄位；明確保留 `is_featured`、`featured_position`、網站 `is_hidden`。傳入 App 的草稿／下架狀態拒絕，允許的網站狀態限 ongoing／completed。
- 在新 migration 中新增 `books.tags text[]`、`books.section_unit` 及 `chapters.content_hash`（具體 check constraint 與 default 在 I 核准後核實）；必要時新增僅 RPC 可用的發布收據表。舊列採安全預設，不回填猜測值。
- 新 security-definer RPC 設定固定空 `search_path`、完整 schema qualification、revoke public／anon，僅 grant authenticated；舊 `import_book` 保持 service-role grant。作者權限不能只放在 Next route／App UI。
- 封面 bucket 維持讀者公開讀取；新增只限已綁定作者 namespace 的 authenticated insert policy。staging bucket private，限定使用者路徑 insert/select/delete，禁止公開讀取。

### Sailune 影響範圍

- `BookJSONExporter.swift`：從現有單 JSON/Base64 轉為 `.shiye` v1 entries 與 ZIP；保留穩定 ID、幕標題及 hash，但依已核准格式統一 field names、block type、1-based order 與 hash algorithm。
- 新增 package builder／ZIP 產生器（實際沿用從 EPUB 抽出的 stored ZipBuilder，不增加 Swift ZIP 套件），以及 `PublicationClient`／`PublicationCoordinator`：呼叫 Supabase Storage、拾頁 API；沿用既有唯一 Supabase auth client，不建立第二個 session client。
- `SailuneAccountAuthService` 提供安全的登入／Session 存取入口，錯誤文案不顯示 token、key 或伺服器原始內容。
- `StartPublishingView`／`ContentView` 接入已核准 U 的摘要、登入後返回確認、傳送／取消／重試／結果；傳送成功才更新 `BookPublicationStore`。保留既有匯出 TXT／EPUB，不增加 `.shiye` file exporter。

### Pagelet 影響範圍

- `tools/import/`：加入 ZIP entry reader、嚴格 `.shiye` parser、共用 domain conversion、CLI file input；不在檔案系統解壓任意路徑，只接受 allow-listed entries，限制檔案數、壓縮／解壓大小與 ratio，拒絕重複路徑、symlink、路徑穿越、無效 UTF-8、重複 UUID／順序及 hash 不符。
- 新增 Next route handler `src/app/api/publications/v1/route.ts` 與使用 caller JWT 的 server client；路由只接收 attempt UUID，限制可操作 bucket path／owner，並在所有成功／確定失敗路徑清理 staging object。
- 新 migration 及 `supabase/tests/`：作者綁定、作者 scoped publish RPC、storage policies、內容欄位與冪等收據；不改動 Pagelet 使用者目前未提交的 V2 檔案。
- `docs/import-format.md`、`docs/data-model.md`、API/auth contract、`spec-shiye-book-package.md` 更新為實作後的唯一契約與版本支援政策。

### 工作拆解與完成條件

1. 對 `.shiye` spec 與 Sailune exporter 建立跨語言 fixture；先收斂 block、空白、hash、order、cover、status、tags、sectionUnit 的精確語意。
2. 實作 Swift 封包建立與 Pagelet parser／CLI；`--dry-run` 顯示書名、卷／節／字數與所有驗證錯誤，未確認前不寫 DB。
3. 完成作者帳號綁定、資料庫 migration、作者檢查 RPC、storage policies、冪等結果與 rollback／孤兒檔策略；用 PostgreSQL 測試匿名、作者、非作者與另一作者資料。
4. 接 staging TUS upload、Next route、App Publisher client 和 U 畫面。實測封包大小後核定 app/bucket/file/cover 上限；若實際 payload 不適合單次 RPC，先在 I 實作中回到設計決策，不拆成可見的多次章節 commit。
5. 以隔離 Supabase／測試作者／隔離 Sailune stores 完成端到端首次發布、重複發布、修改章節、移除章節、完結、登入失效、跨作者拒絕、網路中斷／重試與結果遺失後冪等恢復；正式作者資料不作測試。

### 驗證計畫

- **格式單元測試**：Swift exporter 與 TypeScript parser 共用 golden `.shiye`；覆蓋舊／新版支援、unknown optional／required capability、空節／空行／幕標題、Unicode NFC、UTF-8、hash、大小上限與 ZIP 惡意項目。
- **資料庫測試**：同作者建立及更新、別人書 UUID 攔截、筆名冒認不能認領、作者 user 未綁定被拒、admin 欄位維持原值、章節 ID 保留閱讀進度、移除節只下架、transaction 失敗回復、相同 attempt_uuid 回傳同結果。
- **Storage／API 測試**：anon 不能 staging upload/read；作者不能讀寫其他 user path 或其他作者封面 namespace；API 不信任 body 的 user／author id；不含 service-role header／secret；錯誤清理或重用暫存資料。
- **Sailune 測試**：package manifest/block/hash；未登入提示與登入後返回確認；成功才改本機 draft／tags；失敗不改 sidecar；同一 attempt 重試；cancel／進度／錯誤可存取。
- **整合與人工驗收**：隔離資料完成 U 每條流程及手機／桌面 site 顯示；序列執行相關 XCTest、Pagelet typecheck/lint/unit/SQL/e2e、無簽章 Debug build、`git diff --check`。隔離測試結果見下方實作紀錄。

### 部署前限制與已決定規則

- **已核准顯示語意**：使用者 2026-09-28 選擇網站固定顯示「節」；封包及資料庫保留來源 `sectionUnit`，網站顯示不使用它。
- **容量**：Vercel Function 單次 request／response body 上限為 4.5 MB，因此 App 不會把封包直接 POST 至 Vercel；封包直傳 Supabase Storage，Vercel 只接收 attempt UUID。Supabase Storage 官方建議大於 6 MB 使用 TUS resumable；目前 Free plan 單檔全域上限最高 50 MB。以實際範例量測及限制明確發布上限，未用大檔資料推論所有作品。
- **作者綁定前置**：目前 `authors.user_id` 欄位已存在但沒有 App／Pagelet 的作者綁定流程。第一版假設一個已驗證帳號手動綁定現有作者；不提供作者自助認領／轉移。
- **工作樹邊界**：Pagelet 目前已有使用者未提交的 V2 修改（`docs/work-items/current.md`、admin metadata、`serverAccount.ts`、E2E）；若 I 核准，開始前逐檔檢查並保留，不重置或覆寫。

### 技術依據

- [Vercel Functions limits](https://vercel.com/docs/functions/limitations)：Function request／response payload 上限。
- [Supabase Storage resumable uploads](https://supabase.com/docs/guides/storage/uploads/resumable-uploads)、[file size limits](https://supabase.com/docs/guides/storage/uploads/file-limits)：TUS 建議、Free plan 限制。
- [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control)：RLS 限制 Storage object 路徑操作。
- [Supabase Database Functions](https://supabase.com/docs/guides/database/functions)：資料密集型交易放資料庫函式並限制 grant。
- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation)：Swift ZIP 建立／讀取候選套件。

## 相關文件與程式

- [`.shiye` 格式草案](../spec-shiye-book-package.md)
- [帆夢發布 exporter](../../Sailune/BookJSONExporter.swift)
- [拾頁匯入格式草案](../../../Pagelet/docs/import-format.md)
- [拾頁 CLI importer](../../../Pagelet/tools/import/cli.ts)
- [拾頁 parser](../../../Pagelet/tools/import/parseBook.ts)
- [拾頁資料模型與寫入權限](../../../Pagelet/docs/data-model.md)
- [拾頁 V2 目前工作及作者權限非目標](../../../Pagelet/docs/work-items/current.md)
- [帆夢登入與發布 API 約定](../pagelet-auth-contract.md)

## 實作進度

- 2026-09-28：I 核准；先實作格式、解析及作者交易，接著接線 App。現有 EPUB 已有 stored ZIP writer，將抽成共用 writer，避免為產生 ZIP 新增 Swift 套件；TypeScript 採 yauzl 的逐 entry 有界讀取，不解壓到檔案系統。

### 已完成的程式與驗證

- Swift internal ZIP builder／共用 stored ZIP writer、版本契約與純值摘要；TypeScript 有界 yauzl parser、必填能力與選填 extension 相容、CLI 維運入口。
- 作者所有權 RPC、完整快照交易、admin 欄位保留、同交易冪等收據、staging／cover Storage RLS；Supabase Swift Session + TUS + 小型 Next API。
- 預覽／登入返回／進度／提交不可取消／重試／成功結果；遠端成功後才改本機狀態，sidecar 失敗只重試本機。
- 42 項 Vitest（含 7 項 PGlite PostgreSQL 交易／RLS）、16 項 XCTest、4 項本機實際 HTTP Playwright 通過；typecheck、lint、CLI golden dry-run、Next webpack 正式建置通過。最終追加檢查結果持續更新在 handoff。
- GUI 已以停用 Auth 的隔離 stores 驗收草稿入口、標籤、預覽摘要、登入入口、取消登入返回預覽、關閉仍是草稿；座標點擊工具回報 noWindowsAvailable，遮罩實際命中尚未可靠驗收。Escape 最初未觸發，已加 cancel keyboard shortcut，建置驗證後仍需 GUI 複驗。正式作者／書籍未作測試。
- 孤兒封面不立即刪除：不可變 hash 路徑可能同時被另一成功交易引用；改由維運確認無 DB 引用後清理。staging 確定成功／失敗會盡力清理；可重試／結果不明則保留。

### 待啟用與下一步

- 正式 Supabase migration、作者綁定、Vercel API 部署尚未執行。CLI 與 App 需要對應 migration；不能把本機驗證誤寫成後端已啟用。
- 依 [拾頁發布啟用文件](../../../Pagelet/docs/publication-api.md) 先在隔離 Supabase／staging 網站驗證真實 TUS、RLS 與作者第一次發布，再啟用正式環境。

### 最終本機驗證（2026-09-28）

- 兩個 repo 均位於本機 `feat/shiye-publication` 分支，未 commit／push，使用者原有 Pagelet 三個功能檔修改維持原樣。
- 42 項 Vitest、15 項發布／格式／網路專項 XCTest，加 1 項容量邊界 XCTest 通過；4 項 Next 正式模式本機 HTTP Playwright 通過。
- 真實 Swift builder 產生的含／不含封面 `.shiye` 均由 TypeScript CLI `--dry-run` 驗證通過；檔案只位於 /private/tmp。
- typecheck、lint、Next webpack 正式建置、兩個 repo 的 diff check、新增文字檔空白檢查與 auth-contract 正本／複本一致性通過。
- 完整快照移除封面會清空網站自訂封面，改顯示網站預設封面；舊維運入口保留無新封面就維持原封面的相容行為，SQL 測試覆蓋兩次發布的移除。
- 隔離 GUI 程序已結束；遮罩實際座標命中與 Escape 修正後複驗仍列為未驗證。沒有執行正式 Supabase、作者綁定或部署。

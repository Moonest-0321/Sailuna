# 帆夢／拾頁實作紀錄

這是兩個專案共用的實作紀錄正本。使用者於 2026-09-28 明確要求每次實作記在同一份文件；開始工作先讀本檔，結束或暫停前追加紀錄並更新下方目前狀態。工作單保留需求與批准，規格保留契約，本檔集中保存實際操作與證據。

## 記錄規則

- 修改前記錄目標、授權範圍、實際 Git 狀態及既有修改；修改後列出檔案、原因、驗證命令與結果。
- 分開記錄：使用者確認、直接查證、尚未驗證。沒有證據不得寫成已完成；不得用提交、build 或替身測試推論正式串接成功。
- 提交、推送、部署、資料庫套用及實際驗收各自記錄。每項外部操作記錄環境與可核對結果，不記錄金鑰、token、私人帳號或作品正文。
- 歷史紀錄不代表即時狀態；新的結果追加並註明取代哪項舊結論。跨對話必須沿用本檔，不另建平行實作紀錄。
- 每次紀錄包含：日期、目標、變更／操作、驗證、未完成／阻礙、下一步。未執行的測試寫「未執行」。

## 目前狀態（2026-09-28）

- V11.1 登入／鑰匙圈修正已接線；最終 9 項專項通過，1 項真實後端測試明確略過。先前該真實測試 signal term 失敗，原因與測試項目清理未確認。使用者實際 App 路徑／簽章／ACL 及四項實機驗收待完成，工作 active；詳細證據見末段。


- 本次要求的「整本上傳、再次傳送覆蓋」已完成正常 App → TUS → 正式網站的真實驗收。獨立測試書首次新增 1 節；再次傳送新增 0 節、更新 1 節，書／節 UUID 與網址均相同，正文、章名及簡介已更新，只有一本同名測試書。
- Pagelet main 與發布分支均已為 fda616e；正式 Vercel G3n7sUw7N7KzpAbTsmyJprgpRqzk 從 main 建置，Ready／Current，正式 API 與測試書閱讀頁正常。
- 網站 51 項、Swift 17 項專項、4 項 HTTP 邊界、型別／lint／建置已通過。實際驗收使用最新 Debug App 與獨立本機資料庫，不代表使用者其他既有安裝版本已更新。
- 測試書保留在現有網站供核對；原有作品未用作覆蓋測試。移除卷節／封面的行為有程式測試，本次真實兩次傳送未覆蓋那些情境；完整 migration 歷史與所有拒絕權限情境也未逐項稽核。
- 本次需求與 main 整合部署已完成；沒有本次功能的未完成實作。Sailune 尚有未提交文件／測試修改，使用者其他既有待辦保留。詳細證據見本檔末段。

## 2026-09-28：狀態調查與兩邊程式檢查

### 目標與操作

- 依使用者要求檢查現況及程式；本輪沒有修改功能程式、提交、推送、部署或正式資料。
- 檢查 Swift 封包 builder、PublicationClient、Coordinator、登入預檢、網站 API／parser、保存 RPC、Storage policies 與閱讀頁。
- 本機 Sailune HEAD `ab6a0a8`，`feat/shiye-publication`，檢查時工作樹乾淨。
- 本機 Pagelet HEAD `fb062a4`，`feat/shiye-publication`；既有未提交修改為 `docs/work-items/current.md`、`src/app/(site)/admin/page.tsx`、`src/lib/db/serverAccount.ts`、`tests/e2e/reader.e2e.ts`，未覆蓋。
- 以 `git ls-remote origin refs/heads/feat/shiye-publication refs/heads/main` 直接查 GitHub：Pagelet 發布分支為 `fb062a4`、main 為 `1ad2a6c`；Sailune 該發布分支沒有回傳，main 為 `b77a7f5`。取代舊文件「兩邊未 commit／push」說法；這是當次查詢結果，不代表未來狀態。
- 正式網址 `/api/publications/v1` GET 回傳 404，`x-matched-path: /404`；僅證明當次該網址沒有回傳發布路由，不推論 Supabase 是否已設定。
- 本機已有 Auth Local xcconfig 的 Supabase URL；不能沿用舊文件「URL 未填入」說法，也不能據此判定登入成功。

### 已查證問題

1. `Pagelet/src/lib/db/publications.ts` 封面 `upsert:false` 僅接受 HTTP 409 為已存在。Supabase 官方也記載既有路徑回傳 400 Asset Already Exists：<https://supabase.com/docs/guides/storage/uploads/standard-uploads>。以 `/private/tmp/shiye-cover-from-swift.shiye` 和模擬 400 回應呼叫實際 `publishStagedBook`，得到 `cover_upload_failed`／503，`publish_book_v1` 呼叫次數 0。這是程式分支重現，不宣稱它就是使用者先前實作失敗的根因。
2. `Pagelet/src/lib/format/chapterBody.ts:85` 將 `blank` 轉成空陣列。實際呼叫 `parseStoredChapterBody`，兩段正文間的兩個 blank 全部消失；閱讀頁因此無法保留作者的空行數量。

完整快照保存程式會更新同 UUID 的內容、隱藏快照缺少的卷／節、清空缺少的封面；RPC 在同一交易執行。這是程式與本機測試證據，不是正式整條流程成功證據。

### 本輪驗證

- Pagelet：`npm test`，8 個測試檔／42 項通過；`npm run typecheck`、`npm run lint` 通過。既有測試未覆蓋上述兩項問題。
- Sailune：`xcodebuild -quiet -project Sailune.xcodeproj -scheme Sailune -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/ShiyePublicationDerived -disableAutomaticPackageResolution -parallel-testing-enabled NO -only-testing:SailuneTests/BookTextTransferTests -only-testing:SailuneTests/PublicationClientTests CODE_SIGNING_ALLOWED=NO test` 通過。
- `xcresulttool get test-results summary` 讀取 `/private/tmp/ShiyePublicationDerived/Logs/Test/Test-Sailune-2026.09.28_18-13-27-+0800.xcresult`：16 項通過、0 失敗、0 略過。日誌 `/private/tmp/shiye-review-tests.log`。
- Swift 首次使用新 derivedData 執行因 sandbox 無法解析 github.com 而失敗；改用既有套件快取與核准執行後通過。不得把第一次失敗藏成未曾發生。
- 本輪未執行 GUI、真實 TUS、正式 DB 查詢或首次／覆蓋發布。

## 2026-09-28：建立統一記錄規則

- 使用者授權：每次實作必須記錄於同一文件。
- 變更：新增本檔，在兩邊 AGENTS.md 加入持續記錄規則；current 文件連到本檔，標明目前仍有問題待修。
- 範圍：純文件修改，依兩邊協作規則略過不適用的功能 R／U／I 關卡；未改功能程式及既有 Pagelet 三個功能檔。
- 驗證：文件差異與 `git diff --check`；功能測試未重跑（純文件修改）。
- 未完成：兩項程式問題尚未修正、串接尚未驗收。

## 2026-09-28：完善整本上傳／覆蓋程式（進行中）

- 授權：使用者指示先完善兩邊需要的程式；本工作修正已查證問題及必要接線，不部署、不操作正式作品。
- 起始：Sailune 有 AGENTS.md、current.md 修改及未追蹤本紀錄；Pagelet 有 AGENTS.md、current.md 和既有後台三檔修改。保留原有修改。
- 計畫：修正封面已存在的 400／409 相容處理並核對 hash；將空行區塊保留至閱讀呈現；補充跨端完整快照與回歸測試。
- 驗證：待執行。正式串接仍未完成。


### 本輪完成結果

- Pagelet `src/lib/db/publications.ts`：辨識 409 與明確的 400 Asset Already Exists／The resource already exists；重用前下載核對 hash。一般 400 不當成功；核對連線失敗保留 staging 可重試，hash 衝突停止保存。
- Pagelet `src/lib/format/chapterBody.ts`、`src/components/reader/ReaderView.tsx`：blank 保留到閱讀區塊，每個顯示一個跟隨字級的正文行高，輔助工具不讀取佔位文字。舊規格允許合併空行，本輪依已指出問題與使用者完善指示改為逐個顯示，同步 `spec-shiye-book-package.md`、網站匯入規格。
- 新增 `samples/shiye-v1/cover.shiye`，來源是前輪 Swift 專項測試產生的 8×8 紅色測試封面封包（/private/tmp/shiye-cover-from-swift.shiye），不含正式作者或作品。
- 新增／修改 Pagelet publication、database、chapterBody、shiye 與 ReaderView 測試，覆蓋首次封面、重複封面 400／409、hash 衝突、其他 400、封面核對離線、空行解析／實際元件輸出、整本替換書名／簡介／狀態／標籤／卷／節而不產生書籍副本。
- 新增 `vitest.config.ts` 對齊既有 @ 路徑 alias 與 JSX automatic；新增 ReaderView 測試首次因測試環境未解析 alias 失敗，補設定後通過。
- Sailune 新增 `BookTextTransferTests` 整本替換回歸測試：同書 UUID、新卷節、舊節不在新封包、連續與首尾空行、狀態／標籤替換。現有 Swift 傳送程式未發現本輪須修改的已證實問題，沒有為了兩邊都有修改而更改它。
- 新增 SQL 測試首次 typecheck 因 status 推論為 string 失敗，補明確 payload 型別後通過。

### 最終驗證與限制

- Pagelet `npm test`：9 檔／51 項通過；`npm run typecheck`、`npm run lint` 通過。
- `npm run build -- --webpack` 通過，/api/publications/v1 列於正式建置路由；日誌 /private/tmp/shiye-implementation-site-build.log。
- 本機 Next 正式模式 localhost:3215；`PLAYWRIGHT_BASE_URL=http://127.0.0.1:3215 npm run test:e2e -- tests/e2e/publication.e2e.ts`：4 項 HTTP 邊界測試通過，不執行作品交易。
- Sailune 同前輪 xcodebuild 專項命令（包含新測試）通過；/private/tmp/shiye-implementation-tests.log；xcresulttool 直接核對 Test-Sailune-2026.09.28_18-25-16-+0800.xcresult：17 項通過、0 失敗。
- 兩邊 `git diff --check` 通過；原有後台三檔修改保留。本輪未提交／推送／部署，未變更 DB migration 或正式資料。
- 未驗證：真實 Supabase TUS／作者綁定／首次與覆蓋發布、GUI 的 390／1280px 空行視覺。元件渲染測試通過不等同瀏覽器 GUI 驗收。
- 下一步：核對隔離後端及部署的實際狀態，使用測試作者完成真實首次發布和完整覆蓋。


## 2026-09-28：真實串接前置核對

- 使用者指示「下一步」；先讀本紀錄及 API 啟用文件，再檢查環境。保留所有未提交修改。
- 沒有可呼叫的 Supabase／Vercel 管理 connector；PATH 未找到 supabase、vercel、gh CLI。現有設定檔只有目前一組網站 Supabase 設定，尚未確認獨立測試專案。
- 使用現有設定做唯讀 HTTP 查詢，憑證未輸出，未變更權限或資料。公開角色 GET books 的 tags／section_unit、chapters 的 body_format／content_hash（limit=0）均 200。publication_receipts 公開讀取為 401／42501，這是權限拒絕，不是表不存在。
- 以本機維運憑證唯讀 GET bucket 清單：covers 公開；publication-staging 私有、單檔上限 25165824、MIME application/octet-stream。
- 唯讀 schema GET 可見 publication_author_v1、publish_book_v1、apply_publication_snapshot_v1 與 publication_receipts。這證明物件存在，不代表 migration 執行歷史或函式實際內容已逐項核對。
- 作者綁定唯讀統計：2 位作者，1 位已有 user_id。未輸出私人帳號，未自動認定該綁定就是目前 App 登入者。
- 正式網站 /api/publications/v1 GET：404，x-matched-path=/404。
- git ls-remote 直接查 Pagelet：發布分支 fb062a4，main 1ad2a6c。本輪新修正未提交或推送。
- 目前限制：未確認隔離環境／測試作者，正式網址缺發布路由；不能開始宣稱真實發布成功，也不能把現有正式作品當測試資料。
- 已向使用者詢問選擇既有獨立測試環境，或現有環境的獨立測試書；回覆前不進行依賴該選擇的部署或測試資料寫入。
- 下一步：確定測試環境，部署本輪修正到對應網站，核對 App 指向同一環境，再驗收整本首次上傳與完整覆蓋。
- 本輪僅環境唯讀核對與紀錄；未部署、未寫 DB／Storage、未綁定作者、未使用 service role 模擬 App 的發布。


## 2026-09-28：改用現有環境驗收（進行中）

- 使用者澄清：只有現有環境，沒有獨立測試專案；採現有環境的獨立測試書驗收，既有作品不作覆蓋測試。
- 下一步：發布本輪修正並核對 Vercel，再以登入作者的正常傳送流程驗收。不可使用 service role 繞過作者權限來宣稱 App 成功。
- 目前 Vercel 內建瀏覽器停在登入頁，尚未讀取部署分支／失敗紀錄；已請使用者登入。不索取密碼或 token。
- 先準備只包含本工作程式／測試／規格的 Pagelet 提交；保留既有後台 page.tsx、serverAccount.ts、reader.e2e.ts 及 current.md，避免混入原有修改。


### 提交與推送結果

- Pagelet 已本機提交 fda616e「修正整本發布覆蓋與空行呈現」，11 檔，包含程式、測試、測試封包、vitest 設定與匯入規格。原有後台三檔及 AGENTS／current 修改未混入。
- 嘗試 git push origin feat/shiye-publication 被自動批准審查拒絕；命令未執行。理由：私人程式碼屬外部資料匯出，對話尚未明確授權本次內容傳至設定的 GitHub 倉庫。未繞過拒絕，已向使用者說明並請求具體推送授權。
- 待授權目標：GitHub Moonest-0321/SailuneWeb，feat/shiye-publication 分支，提交 fda616e 的 11 個檔案（無金鑰／正式作品）。main 未變更，網站尚未部署。
- Vercel 登入仍待使用者完成；內建瀏覽器保留登入頁作交接。


## 2026-09-28：Vercel 登入後唯讀核對

- 使用者確認已登入；只讀後台，未推送或變更部署。
- Preview：部署 8M7TSbw2D1wL2XjyQXVMaubGpiFQ，Ready；來源 feat/shiye-publication、fb062a4；2026-09-28 15:23:05 GMT+8，建置 28 秒。網址 pagelet-git-feat-shiye-publication-moonest.vercel.app。
- Production：部署 5opNkd2iC6NoTgKnbko1K57QH2iq，Ready；來源 main、1ad2a6c V2.0；2026-09-27 20:42:01 GMT+8，建置 28 秒。綁定 pagelet-nu.vercel.app。
- 最新兩個部署都成功；發布功能目前只有舊提交的 Preview，正式網址仍是未含發布 API 的 V2.0。這解釋已觀察到的正式 API 404，但不能當作所有 App 傳送失敗的根因。
- 後台當前部署列表尚無 fda616e。最新修正仍只有本機提交，推送授權待使用者明確同意；Vercel 登入回覆不視為推送授權。
- 下一步：取得對 Moonest-0321/SailuneWeb 的 feat/shiye-publication 分支推送 fda616e 的明確授權，再核對新 Preview 部署及後續正式啟用。


## 2026-09-28：授權推送與部署

- 使用者回覆「好」，明確授權把修正上傳到既有 GitHub 倉庫並接續部署驗收。
- Pagelet git push origin feat/shiye-publication 已執行；Vercel 出現 fda616e 新 Preview，部署 ID 14hG1h8wZi9SFWQQH5bPkNzFZVSv，初始為 Building。等待實際 Ready，不把 Building 記為部署成功。
- 正式作品與資料庫仍未變更。


### Vercel 預覽成功、正式更新待授權

- git push 成功：fb062a4..fda616e 至 feat/shiye-publication。
- Vercel 部署 14hG1h8wZi9SFWQQH5bPkNzFZVSv 已 Ready，來源 fda616e，2026-09-28 18:49:06 GMT+8，24 秒。預覽網址 pagelet-exhoxu7xf-moonest.vercel.app。
- Promote to Production 確認頁明確顯示：會使用正式環境重新建置 fda616e，指派 pagelet-nu.vercel.app。
- 嘗試確認被自動批准審查拒絕；理由為使用者授權推送／測試尚未明確涵蓋替換 live site。正式更新未執行，未以合併 main 或其他方式繞過拒絕。
- 已告知使用者需明確授權正式網址更新至新版；此更新只部署程式，本步不改既有作品或執行 DB migration。
- 下一步：取得正式更新授權，完成 Vercel Production 部署並直接核對 API；再以獨立測試書驗收。


## 2026-09-28：正式更新與真實 App 驗收（進行中）

- 使用者明確回覆「同意」正式網站更新；Vercel Promote to Production 已執行。
- Production GL2XVTS6jEmGQY7bxnS71XkeGb5t：Ready，fda616e，2026-09-28 18:51:31 GMT+8，26 秒，pagelet-nu.vercel.app 已指向新版。
- 正式 API 無登入 POST {}：401／login_required，no-store，x-matched-path=/api/publications/v1。取代前次正式網址 404 狀態；尚未代表作品發布成功。
- 以 SAILUNE_TEST_STORE_URL=/private/tmp/SailunePublicationAcceptance/Isolated.store 啟動最新 Debug App。實際書櫃為空、既有鑰匙圈登入已恢復；App bundle 指向已核對的現有 Supabase 與正式拾頁。
- 獨立本機測試書「發布驗收測試 20260928」，測試筆名「發布驗收」，1 卷／1 節。初次 CUA 中文 typeText 只輸入標點，核對後改為 ASCII 明確字串 FIRST_UPLOAD_20260928；已保存 45 字。未將工具輸入失敗誤記為正文保存完整。
- App 發布預覽已確認 1 卷／1 節／45 字，實際按傳送，上傳狀態已開始；結果待核對。只用正常作者 Session／TUS／API，不使用 service role 寫入。


## 2026-09-28：首次上傳與再次覆蓋真實驗收完成

- 取代前段「結果待核對」：正常 App 首次傳送顯示完成，新增 1 節、更新 0 節。公開唯讀 REST 200 與實際閱讀頁均確認初版標記 FIRST_UPLOAD_20260928。
- 測試書 UUID B6016C38-4502-4762-9868-8BCB674E80F4，節 UUID F89E9508-CB11-443C-BD0A-1831414746A7。只記錄人工測試資料，不記正式作品正文或私人登入帳號。
- 在同一本本機書修改章名為「覆蓋驗收」、正文為 SECOND_UPLOAD_20260928 測試內容，簡介為 WHOLE_BOOK_REPLACEMENT_20260928。App 預覽 1 卷／1 節／51 字，實際再次傳送顯示完成：新增 0 節、更新 1 節、未變更 0 節、下架 0 節。
- 正式閱讀頁重新載入，同一網址顯示新章名、新正文及 End.，初版已被替換。公開角色 GET 同名 books 與該書 chapters 均 200：只有一本同名書／一節，UUID 未變，簡介更新；正文 blocks 保留一個空行及後段兩個連續空行。
- 閱讀驗收網址：https://pagelet-nu.vercel.app/book/B6016C38-4502-4762-9868-8BCB674E80F4/F89E9508-CB11-443C-BD0A-1831414746A7 。保留測試書與閱讀頁供使用者查證，未刪除資料。
- 兩次發布都透過既有作者 Session／App TUS／正式 API；未使用 service role 模擬發布，也未修改既有作者綁定或正式作品。獨立本機資料庫 /private/tmp/SailunePublicationAcceptance/Isolated.store。
- 限制：本次真實驗收沒有測試自訂封面重複上傳、卷節移除、跨作者拒絕、全部重試故障；這些不得標記為已完成真實驗收。已完成本次最小需求的首次／覆蓋流程。main 未合併，Sailune 文件與新增測試尚未提交；使用者原有 Pagelet 三檔修改完整保留。
- 下一步：正式後續部署前整合發布分支至 main；不擅自擴充功能或操作其他作品。


## 2026-09-28：整合已驗收版本至 main（開始）

- 使用者「ok那繼續做吧」授權接續先前明列的 main 整合工作。目標是讓正式部署分支包含已驗收的同一提交，不新增功能。
- git ls-remote 直接確認 GitHub main=1ad2a6c9e911a945241bd43fe826cf27df2a17b0、發布分支=fda616eb04accd1fe822e98e55dcd1ee81570b47；merge-base --is-ancestor 回傳 0，main 可直接 fast-forward，無需製造合併提交或解衝突。
- Pagelet 工作樹現有 AGENTS.md、current.md 與使用者原有 admin/page.tsx、serverAccount.ts、reader.e2e.ts 修改；本次僅推送已驗收提交至 main，不 checkout、不提交這些修改。Sailune 文件／測試修改繼續保留。
- 已驗收提交內容不變，沿用既有測試結果；接續核對遠端 main 與 Vercel 正式建置／API，未完成前不記為部署完成。


### main 整合與正式部署完成

- git push origin fda616eb04accd1fe822e98e55dcd1ee81570b47:refs/heads/main 成功，1ad2a6c..fda616e，非強制推送。git ls-remote 確認遠端 main 完整 SHA 與已驗收提交相同。本機 main 指標同步；工作分支仍 feat/shiye-publication，工作樹五項既有修改保留。
- Vercel G3n7sUw7N7KzpAbTsmyJprgpRqzk 實際詳情：Ready、Latest、Production／Current；來源 main、fda616e，2026-09-28 19:30:20 GMT+8，23 秒，pagelet-nu.vercel.app 已指派本部署。取代前述 main 未整合的目前狀態。
- 部署後無登入 POST /api/publications/v1 為 401 login_required，x-matched-path=/api/publications/v1。既有測試書閱讀頁 GET 200，SECOND_UPLOAD_20260928 與新章名存在，FIRST_UPLOAD_20260928 不存在。
- 此步沒有變更已驗收程式內容，未重跑相同本機測試；驗證重點是遠端分支、實際正式建置與部署後 HTTP。未執行 DB migration／作品寫入／再次發布。
- 本次整本上傳／覆蓋與主分支整合已完成。沒有新增功能待辦；既有其他工作及未提交修改繼續保留。詳細動作只記於本正本，其他文件更新目前狀態指標。


## 2026-09-28：使用者回報其他帳號與鑰匙圈反覆授權

- 本輪唯讀調查，不修改登入、權限、鑰匙圈或正式作品。先前完成結論只涵蓋已綁定作者的首次／覆蓋驗收，不代表任意帳號可發布或所有 App 安裝版本可正常授權。
- 當前 Supabase 作者查詢 200：2 位作者，只有 1 位 user_id 已綁定；不輸出私人識別資訊。publication_author_v1 程式明確拒絕未綁定作者（publication_author_unbound），App 也在傳送前呼叫此檢查。其他帳號目前不會自動建立作者身份。
- SMTP 尚未直接核對當前後台；官方文件確認預設寄信只寄給組織成員，但不可推論本專案目前確實未配置 SMTP。若其他帳號卡在驗證碼寄送，需要另外核對此設定，不能混同作者綁定拒絕。
- 截圖的 supabase.gotrue.swift 與 App 使用 KeychainLocalStorage 預設 service 完全一致。當前解析 SDK 預設 autoRefreshToken=true，每 30 秒 tick 透過 SessionStorage.get 讀取鑰匙圈；讀取失敗返回 nil，tick 下一次仍繼續，未停止反覆要求。這證實可重複觸發的程式路徑，不是捕捉使用者該次每個彈窗的 trace。
- codesign -dv 核對先前驗收 Debug App：adhoc／linker-signed、TeamIdentifier 未設定、無 internal requirements。此驗收建置沒有穩定開發者簽章。唯讀 ps 查詢未找到正在執行的 Sailune 程序，不能斷言截圖來源就是這份建置，亦未核對鑰匙圈 ACL 或使用者點過哪個按鈕。
- 建議修正方向：正常開發者簽章與固定 App 身份；登入儲存避免背景反覆觸發授權，失敗後停下並提供明確登入錯誤，保留 token 安全儲存。不要求使用者反覆輸入系統密碼作為程式修正。
- 其他帳號發布需決定作者自動建立或管理者綁定；不得私自解除作者所有權驗證。若要開放全體使用者，另需其他帳號的正常登入／發布驗收。

## 2026-09-28：V11.1 Sailune 鑰匙圈修正（開始）

- 使用者直接授權具體修正；範圍限登入／鑰匙圈，不改拾頁權限、service／account key、ACL 或明文保存。
- 起始工作樹：既有 AGENTS.md、Localizable.xcstrings、BookTextTransferTests.swift、project-status、spec-shiye-book-package、兩份 current 修改及未追蹤本紀錄，全部保留。
- 已查證：主機 ps（提升權限）目前無 Sailune 程序；已詢問实际安裝路徑。截圖確認為系統鑰匙圈 supabase.gotrue.swift 提示，不能由截圖判定 App 簽章或 ACL。
- 工作單元：SDK 儲存層串行存取、背景禁止彈授權、失敗封鎖、明確重試、避免吞寫入失敗導致假登入成功；正常更新仍保存鑰匙圈。只在記憶體快取已成功讀取資料，不持久化至其他位置。
- 驗證計畫：拒絕／取消／讀寫刪失敗與重試回歸、成功後快取、重建 storage 讀取、既有傳送測試及建置；兩分鐘實機、重開與真實傳送另列未驗證，不以替身測試取代。

### V11.1 已修正與階段驗證

- 新增 `SailuneAuthStorage`：Security API 沿用 service／account／AfterFirstUnlock；背景用 LAContext.interactionNotAllowed，不更改既有 ACL。串行快取成功讀取／空值；讀寫刪任一失敗即封鎖並清除快取，唯一解鎖入口為手動重試。操作及 OSStatus 診斷不包含憑證或私人帳號。
- `SailuneAccountAuthService`：停用 SDK lifecycle 自動重啟，保存成功才啟動續期、失敗停止；View restore 每 instance 一次；SDK 吞保存／刪除失敗不當成功；傳送仍沿原作者 RPC。
- `EmailLoginView`：沿用既有錯誤與 Button，新增手動重試；失敗時寄碼／登入入口禁用，未新增其他視覺流程。新增本地規格，不改跨專案 auth-contract 或拾頁任何程式／權限。
- 已查證讀取入口：App State 建立共用 service；ContentView.task restore；SDK SessionStorage.get 的 sessionNewKey／storeSessionDirectly／useDefaultEncoder 遷移及最終讀取；背景 SessionManager tick；publicationCredentials 與 RPC SDK token provider。SDK storage store／delete 也吞錯，故服務須讀取獨立 failure 狀態。
- 第一次 sandbox build 無法寫 Xcode／SwiftPM 快取而失敗；提升權限後首次編譯發現預設參數 Self 與 SDK actor 呼叫需 await，均修正；棄用的 kSecUseAuthenticationUIFail 改為 Apple 建議 LAContext API。沒有把失敗當通過。
- 中間最終專項命令：`xcodebuild -quiet -project Sailune.xcodeproj -scheme Sailune -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/ShiyePublicationDerived -disableAutomaticPackageResolution -parallel-testing-enabled NO -only-testing:SailuneTests/SailuneAuthStorageTests -only-testing:SailuneTests/PublicationClientTests CODE_SIGNING_ALLOWED=NO test`。
- `/private/tmp/sailune-v111-tests-final.log` exit 0；xcresult `Test-Sailune-2026.09.28_19-53-39-+0800.xcresult` 直接 summary：9 通過／0 失敗／0 略過（6 儲存／SDK、3 PublicationClient）。這是替身及 SDK 路徑測試，不是實際登入／傳送成功。
- 最後新增真實 Security backend 的隨機 `sailune-v111-test-UUID` 測試項目（只用固定測試 bytes，不碰原 Session），驗證保存／更新／新 storage 重讀／刪除；並補寄碼／登出吞錯檢查及 UI 狀態先回報後停止續期。相同專項 final2 執行中，結果待補。
- 簽章：本次測試產物 codesign adhoc、TeamIdentifier not set、Internal requirements none。Xcode Release 設定有 DEVELOPMENT_TEAM，Debug 無該設定；測試明確 CODE_SIGNING_ALLOWED=NO，不能由此推論使用者最新版簽章。未修改簽章設定或鑰匙圈權限。
- 未驗證：實際最新版 App 路徑／簽章／ACL、使用者那次授權完整 trace、正常登入兩分鐘閒置、拒絕／取消實機、App 重開 Session、真实續期與書籍傳送。等待已發出的 App 路徑問題；工作維持 active。

### V11.1 真實後端測試限制（取代「final2 執行中」）

- final2 命令 exit 65；xcresult `Test-Sailune-2026.09.28_19-54-58-+0800.xcresult`：9 通過／1 失敗。真實鑰匙圈測試 `testRealKeychainBackendPersistsReopensAndDeletesIsolatedItem` 被 signal term 終止，Xcode 測試階段 384.575 秒。無法證明保存／更新／重開／刪除任何步驟完成，也無法確認隨機測試項目已清理；不能列為實機通過。
- CUA 查看测试 App AX 呼叫自身耗時 336.779 秒，返回無系統授權畫面；這不是兩分鐘正常登入驗收。ps 確認當時唯一本機 Sailune 是本輪 /private/tmp 測試產物，不是使用者最新版安裝。
- 保留真實後端測試，改為 off-main detached、環境 `SAILUNE_REAL_KEYCHAIN_TEST=1` 才執行；一般回歸明確 XCTSkip。阻塞原因尚未查明（主執行緒／系統 Security／測試 host 皆未排除），不把 skip 當問題已解決。後續需在可核對簽章的 App／測試環境重試並確認測試項目清理。

### V11.1 最後檢查點

- final3 同專項命令 exit 0；`/private/tmp/sailune-v111-tests-final3.log`，xcresult `Test-Sailune-2026.09.28_20-04-14-+0800.xcresult` summary：9 通過、0 失敗、1 明確略過（真實 Security 測試）。建置隨 test 完成，`git diff --check` 通過。
- 本輪未提交／推送／安裝替換 App／部署拾頁／更改 ACL。使用者原有修改保留。
- 目前仍 active；第一個下一步是取得使用者實際最新版 App 路徑，核對其簽章與相關 ACL，再釐清真實後端測試阻塞並完成四項實機驗收。未取得路徑，不宣稱問題已全面驗收完成。

## 2026-09-28：V11.1 使用者確認從 Xcode 執行／Debug 簽章修正（開始）

- 使用者確認目前 App 由 Xcode 開啟，不再要求使用者找安裝路徑。此次 ps 無執行中 Sailune，因此仍不能確定 screenshot 對應的那個程序。
- 唯讀核對 Xcode 三份預設 DerivedData Debug 產物全部 adhoc／TeamIdentifier not set。最新候選為 `~/Library/Developer/Xcode/DerivedData/Sailune-enkjfgwzzvvzqgduotdmwyjudtsw/Build/Products/Debug/Sailune.app`，執行檔 mtime 2026-09-28 19:34:39；不把「最新候選」當已確認當時執行路徑。
- 專案 Debug 缺 DEVELOPMENT_TEAM；Release 設有 Team。主機（提升權限）有一份有效 Apple Development identity，公開憑證 OU 與既有 Release Team 相同；sandbox 內 0 identity 是權限視角，已被主機查證取代。沒有讀取私鑰或寫出憑證。
- 起始工作樹沿用前輪所有修改。本次依原有登入／鑰匙圈修正授權，僅使 Debug 使用與 Release 相同 Team 的穩定開發者身份；不修改 bundle ID／service／ACL／拾頁權限。
- 計畫：補 Debug DEVELOPMENT_TEAM，啟用簽章建置，再直接查產物 Authority／Team／designated requirement。仍需真實 App 閒置、取消及重開驗收，不由簽章成功推論全部解決。

### Xcode Debug 簽章 checkpoint

- 只修改 project.pbxproj 的 Debug DEVELOPMENT_TEAM，與既有 Release 相同；diff check 通過。此為既有授權登入／鑰匙圈修正中的穩定身份修正，未新增權限。
- 簽章開啟命令 `xcodebuild -quiet -project Sailune.xcodeproj -scheme Sailune -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/ShiyePublicationDerived -disableAutomaticPackageResolution build`，日誌 `/private/tmp/sailune-v111-signed-build.log`；仍在執行（exec session 51297）。
- ps 確認 codesign 與 SecurityAgent 正在執行，尚未成功簽章；建置中讀 codesign 曾顯示未簽章，不能當最終產物結論。
- 嘗試透過 CUA 唯讀核對 SecurityAgent，被該工具安全規則禁止存取此 app，未讀取／操作授權視窗，未輸入密碼、未修改 private key ACL。需使用者自行完成 macOS codesign 的開發者憑證授權；這與 Sailune 登入 Session 存取是不同項目。
- 下一步：使用者完成該系統授權後恢復 session 51297，檢查 exit／codesign Authority／Team／designated requirement，再從 Xcode Run 驗收。若使用者取消則記錄未完成，不宣稱簽章修正驗收成功。一般程式專項沿用 9 通過／1 略過，未因單一 Team 設定重跑；真實四項仍未驗收。

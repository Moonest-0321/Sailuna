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


## 2026-09-29：V11.2 開始前專案閱讀

- 使用者要求先閱讀完整專案；本工作單元為全專案脈絡盤點，完成條件為掌握模組責任、資料邊界、現行工作及驗證限制。非目標為功能實作、既有待辦續作、部署及作者資料操作。唯讀調查與必要紀錄依 AGENTS 略過不適用的 R／U／I；V11.2 需求尚未提出。
- 文件修改前：分支 `feat/shiye-publication`、HEAD `c4f513b`，`git status --porcelain` 空白，工作樹乾淨；本輪只追加本紀錄及 project-status／handoff 閱讀 checkpoint。
- 閱讀範圍：協作規則、狀態與 current 歷史／現行工作、實作紀錄、架構／資料模型／備份、工程與 UX／測試規則、功能規格與一致性盤點；盤點全部 Swift 檔的型別／責任與 XCTest 名稱，深入核對啟動、正文保存、發布狀態、登入／鑰匙圈、整本封包／TUS／Coordinator、AI 提示／容量預檢及備份／刪除／模板等關鍵路徑。此為專案脈絡閱讀及關鍵路徑核對，並非所有原始碼逐行稽核。
- 直接查證：106 個 App Swift 檔、12 個 XCTest 檔，244 個 test 方法（原始碼數量，不是執行通過數）。主 schema V5、settings V13、story planning V7；共六個 SwiftData stores，其他檔案資料依既有保存與備份契約。
- 最新待辦：V11.1 簽章／鑰匙圈實機驗收仍 active；既有 9 通過／1 略過是歷史專項結果，本輪未重驗。整本首次／覆蓋正式驗收已記錄完成，本輪未重新查正式環境。V9 暫緩及其他 GUI 待辦保留。
- 驗證：讀取、rg／Python 原始碼盤點與 `git diff --check`；本輪未執行 build、XCTest、GUI、真實鑰匙圈或網路串接。沒有修改功能程式、schema、版本顯示或作者資料。
- 唯一下一步：接收 V11.2 的具體需求，依既有流程整理 R；不把版本名稱當作實作授權。

## 2026-09-29：V11.2 帳號與彈窗修正（開始）

- 使用者直接授權四項具體修正：關閉 Apple 登入、Email 帳號登入、登入後以筆名稱號、修正帳號彈窗排列與越界；依 AGENTS 略過不適用的重新 R／U／I。Email 沿用現行 OTP，筆名沿用 AuthorProfile，不建立新帳號 schema 或網站作者同步。
- 起始 HEAD c4f513b；已有本輪閱讀留下的 implementation-log、project-status、handoff 三份文件修改，保留。
- 查證現行 AccountPopoverView 的 Apple 提示為佔位，沒有 SignInWithApple 接線；內層 250 與外層 220 寬度衝突。範圍為 ContentView 帳號彈窗與侧欄稱號；非目標為方案、切換帳號、鑰匙圈政策及網站授權。
- 計畫：移除 Apple 佔位、未登入顯示 Email 入口、已登入顯示筆名與次要 Email、統一父容器尺寸約束；Swift parse、Debug build、diff check，GUI 未驗證另列。

### V11.2 接線及驗證結果

- ContentView 移除 Apple 提示，Email OTP 入口只在未登入時呈現；登入後側欄／彈窗使用既有筆名，空白顯示「尚未設定筆名」，Email 為次要識別。沒有變更遠端身份或 schema。
- 彈窗統一父容器限寬（最多 300 pt）與可用高度，ViewThatFits／ScrollView 處理長內容；筆名最多兩行、Email 單行截斷；Picker 不再重複顯示方案。既有外部遮罩取消保留。
- `swiftc -frontend -parse Sailune/ContentView.swift` 與 `git diff --check` 通過。初次 xcodebuild sandbox 因 SwiftPM／clang 快取寫入權限失敗；核准主機相同 Debug 無簽章 build exit 0，/private/tmp/sailune-v112-build-host.log。
- CUA `getApp("Sailune")` 159.7698 秒後 timeoutReached，未取得畫面；不宣稱 GUI 排列／命中已验收。未跑 XCTest、真實 OTP、正式簽章或部署。
- 更新 current 工作單／交接、project-status、新增 spec-account-v11.2.md。既有 V11.1 狀態保留；未提交。
- 唯一下一步：Xcode Run 最新版，核對筆名稱號、長文字與小視窗彈窗、外部空白取消。

## 2026-09-29：V11.2 彈窗定位校正（開始）

- 使用者指出彈窗過高，並以「可」批准「緊接帳號按鈕上緣、小間距、高度不足才捲動」提案；本輪僅修正定位。前輪四項修正已被使用者指出未確認，改記為未批准草案；不可沿用先前自行宣稱 R／U／I 批准。
- 起始保留 ContentView、Localizable.xcstrings 與文件既有修改；Localizable 為本輪開始前出現的修改，不覆蓋。
- 實作方式：量測帳號按鈕實際 bounds，以父容器相對座標決定彈窗下緣，不用視窗高度比例估計按鈕位置；保留 8 pt 間距與既有內容。

### 定位校正結果

- 新增 AccountButtonFramePreference 量測按鈕 bounds，換算 GeometryReader 父容器座標；彈窗下緣與按鈕上緣相距 8 pt，可用高度不足時保留 ScrollView fallback。沒有改動彈窗內容。
- `swiftc -frontend -parse Sailune/ContentView.swift`、`git diff --check` 通過；同既有主機無簽章 Debug build exit 0，日誌 /private/tmp/sailune-v112-position-build.log。未執行 XCTest；先前 GUI 工具逾時阻礙仍未解除，本輪未取得修正版畫面，不宣稱已完成人工間距／捲動驗收。
- current、handoff、project-status 與規格同步校正批准狀態。未提交；保留 Localizable.xcstrings 既有修改。唯一下一步：Xcode Run 驗收按鈕上方的小間距與小視窗捲動。

## 2026-09-29：V11.2 彈窗未顯示修復（開始）

- 使用者回報前次定位修正使彈窗無法出現，授權修復同一問題。本輪保持已確認按鈕上緣 8 pt／高度不足捲動；不改內容或帳號行為。
- 查證前版以 CGRect preference 回存 State，再跨 global 座標運算；default zero 可讓可用高度被壓成 0。改用按鈕 bounds Anchor 在父 overlay 同次 layout 解析，移除零值狀態與跨 layout 時序依賴。這是靜態定位，不宣稱已取得 runtime trace。
- 起始既有 ContentView／Localizable／文件修改全部保留。

### Anchor 顯示修復與實際 GUI 驗證

- ContentView 改為按鈕 .anchorPreference 與父 .overlayPreferenceValue 同次排版解析；Preference reduce 保留非空 anchor，移除 CGRect 回存 State／global 換算。彈窗仍在按鈕上方 8 pt。
- Swift parse、主機無簽章 Debug build exit 0（/private/tmp/sailune-v112-anchor-build.log）及 diff check 通過。
- 首次 sandbox 直接啟動隔離 App exit 134；主機核准後以 SAILUNE_TEST_STORE_URL=/private/tmp/SailuneV112AnchorGUI/Isolated.store 啟動成功。bundle ID 查找有多份安裝歧義，改用明確 /private/tmp/ShiyePublicationDerived/Build/Products/Debug/Sailune.app 取得正確畫面。
- 實際 GUI：AX 按鈕「作者頭像、登入」點開後出現帳號／方案／Email／設定／切換／退出列；截圖確認彈窗下緣緊接按鈕上緣，小間距且沒有上浮。點空白後 AX 移除彈窗列，再點帳號重新出現。這是最新建置的實際未登入 GUI 驗收。
- 未驗證：登入後高度、小視窗捲動與長筆名；未跑 XCTest／真實 OTP。未操作作者正式 stores；測試 App 已送出 Quit。
- 本次「不出現」修正已完成建置與開啟／取消／重開 GUI 驗證；其他 V11.2 未批准草案及待驗收事項保留。

## 2026-09-29：集中作者／帳號入口（需求與 UI 提案）

- 使用者確認先集中入口，資料切換稍後討論。R approved：集中左下帳號入口，移除側欄獨立「關於我」入口；不新增身份綁定或資料遷移。
- 本輪只讀 ContentView 入口／callback，未改程式。U 提案：帳號彈窗在既有設定前增加「關於我」，點擊關閉帳號彈窗並開啟原有筆名／頭像／簡介編輯彈窗；未登入也可使用。U pending、I pending，等待排列確認。
- 保留所有既有修改；未執行 build／XCTest／GUI。下一步為確認 U 排列，再確認實作計畫。

## 2026-09-29：帳號頁與頭像選單（I approved，開始）

- 使用者確認 R／U：「帳號」文字開主內容頁，筆名／簡介可編輯，Email 為帳號名稱，使用方案沿用選單；頭像另開登入／切換帳號／登出／設定小選單。資料切換延後。使用者回覆「I」批准實作計畫，取代前段彈窗內「關於我」提案。
- 本輪起始 git status 僅三份文件修改（implementation-log／current work item／handoff），先前程式已在目前基線，保留所有既有修改。
- 沿用 AuthorProfile、SailuneFormTextField／AuthorBioEditor、Book Account auth service 與 Anchor 彈窗定位；移除獨立關於我入口，保存既有頭像編輯能力。切換帳號先登出成功才開 Email 表單，失敗保持錯誤；不更改資料歸屬或 schema。
- 驗證計畫：Swift parse、Debug build、實際隔離 GUI 兩個入口／保存／取消；真實登入者切換需另列驗收邊界。

### 帳號頁實作與驗證結果

- ContentView 分離頭像及帳號文字按鈕，建立 account 路由及 AccountPageView／Form，移除關於我獨立入口／modal。頁內筆名、簡介、Email 與方案，沿用共用欄位與編輯器；保留更換頭像，明確保存主 context，失敗回報。
- 頭像四項選單與登入状態／busy disabled 已接入；切換 callback 等待 signOut 後只在 signedInEmail nil 且 error nil 時開 Email。尚未用真實登入者驗收，不把程式接線當成功。
- 編輯腳本第一次因搜尋舊 modal 後續標記不符而停止，尚未寫 source；讀正確標記後修改成功。Swift parse／diff check、主機無簽章 Debug build exit 0，日誌 /private/tmp/sailune-v112-account-page-build.log。
- 隔離 App 用 /private/tmp/SailuneV112PageGUI/Isolated.store；實際 AX／截图確認頭像「帳號選單」、文字「開啟帳號頁」，頁內四欄及無關於我入口。輸入固定測試筆名／簡介後 AX 反映新值，唯讀 SQLite 新連線驗證兩欄已保存 True。沒有正式作者資料輸出。
- 頭像選單實際出现登入／切換／登出／設定；當次 restore 尚在處理，帳號操作 disabled。按設定後工具報 native pipe closed；reset 重連同錯，未取得設定結果或正常 Quit；session 42229 尚運行。未宣稱保存 UI 重開、登入表單或真實切換驗收完成。
- 未執行 XCTest、真實 OTP／切換、簽章或部署。工作單維持 active；唯一下一步最新 Xcode Run 補剩餘 GUI／真實登入者流程。更新工作單／handoff／spec／project-status，未提交。

## 2026-09-29：頭像彈窗再次未顯示（修正開始）

- 使用者確認頭像原有彈窗無法出現；修復已批准的頭像選單，帳號文字仍開主頁。此為具體 bug 修正，沿用 R/U/I approved。
- 起始 ContentView、Localizable.xcstrings 與五份文件已有修改，全部保留。程式仍有 overlay，不能將缺失判定為選單被刪除；CUA 重連仍報 native pipe closed，尚未取得當前故障畫面。
- 將 anchor 恢復至底部整列容器，頭像使用明確 44 pt 命中範圍；避免拆分後 anchor 綁在內層小按鈕。這是修正候選，未宣稱已確認故障根因。

### 本輪結果／限制

- 頭像 44 × 44 命中範圍，anchor 改回底部整列；維持按鈕上方 8 pt、自訂選單四項與空白取消。帳號頁及登入資料契約未改。
- Swift parse、git diff --check 通過；Debug 無簽章 build exit 0，/private/tmp/sailune-v112-avatar-repair-build.log。
- CUA 原生連線仍報 native pipe closed，本輪無法驗證實際點擊、取消／重開；不得將 build 當作故障已消除。唯一下一步：最新 Xcode Run 點頭像確認選單顯示。Localizable.xcstrings 既有變更未觸碰。

## 2026-09-29：頭像事件誤入帳號頁（修正）

- 使用者補充實際故障是點擊頭像直接開帳號頁，並非只有彈窗看不見。保留兩個已批准入口，改為兩個明確且互不重疊的 44 pt 命中區：頭像按鈕固定寬度、裁切並提高同列命中優先；帳號文字只使用剩餘寬度並裁切。
- 彈窗內容、定位 anchor、帳號頁與資料行為均未改動。待以下建置與實際 GUI 驗證結果補記。

### 頭像事件修正驗證

- Swift parse、git diff --check 與無簽章 Debug build通過。
- 最新建置實際 GUI：點 accessibility「帳號選單」後出現登入／切換帳號／登出／設定四項；再次點頭像後四項消失；點「開啟帳號頁」後主內容顯示筆名、簡介、Email 帳號名稱與方案。兩個入口已分流，未再發生頭像誤開帳號頁。
- 當次登入服務已恢復 Email，畫面顯示既有 Email；未操作登出、切換或 OTP。工作單維持 active，剩餘真實帳號流程驗收不變。

## 2026-09-29：頭像實際滑鼠命中再調查（開始）

- 使用者提供截圖並確認實際滑鼠點擊頭像仍未出現彈窗。前次 CUA 使用 accessibility action，會直接呼叫按鈕 action，不能證明實體座標 hit testing 正確；撤回「兩入口已完成實際點擊驗證」的結論。
- 本輪以最新建置的畫面座標重現，檢查同列 layout／hit area／overlay 層級，再依結果修正。保留帳號頁及其他工作樹修改。

### 詳查與修正結果

- 找到前次誤判：accessibility click 直接執行 action，不能代表滑鼠 hit testing；測試視窗另有底部超出螢幕的狀態，早期座標測試也未點到頭像。
- 「帳號」Button 原先以 `maxWidth: .infinity` 擴張，與頭像同列時存在覆蓋頭像命中區的可能；已改為文字固有寬度並在後方放 Spacer。頭像不再包在 Button label，改為獨立 44 × 44 `contentShape` 與直接 `onTapGesture`，accessibility action 另行保留。兩者不共享或重疊 hit area。
- 中途 build 因 accessibilityAction 使用不支援的 `perform:` 標籤 exit 65；改用 closure 語法後，Swift parse、diff check 與最終 Debug build exit 0。
- 實際座標驗證：在移除帳號按鈕延展後，最新建置以畫面座標點頭像成功顯示四項彈窗；最終 direct gesture 版本因 CUA 全螢幕／視窗座標反覆回報 noWindowsAvailable，未取得第二張實體座標截圖。最終建置的 accessibility tree 仍明確分成「帳號選單」「開啟帳號頁」，頭像 action 可顯示四項彈窗。尚待使用者以正常視窗確認最終滑鼠結果。

## 2026-09-29：右下帳號卡片流程校正（開始）

- 使用者明確校正 UI：右下整張卡片（頭像與「帳號」文字）第一次點擊都只開帳號彈窗；由彈窗內新增的「帳號」項目進入帳號主頁。這取代先前將頭像與文字分成兩個入口的設計。
- 實作範圍：恢復整張卡片為單一 Button；彈窗最上方新增「帳號」action，沿用既有 account route。登入／切換／登出／設定、資料模型與帳號頁欄位不變。

### 單一卡片流程驗證

- Swift parse、git diff --check 與無簽章 Debug build exit 0。
- 最新 App accessibility tree 的右下入口只有一個「開啟帳號選單」Button；啟動後選單顯示帳號、登入、切換帳號、登出、設定。點選單「帳號」後，選單關閉並進入含筆名、簡介、帳號名稱、使用方案的帳號頁。
- 此流程校正已完成；真實登出／切換／OTP 仍屬原工作單未驗證範圍。

## 2026-09-29：登入後帳號卡片顯示筆名

- 使用者明確要求：右下帳號卡片未登入顯示「帳號」，登入後將兩字替換為筆名；卡片仍開啟帳號選單。
- StartSidebarView 接收共用登入服務的登入狀態，登入後讀既有 AuthorProfile.penName；空白筆名回退「帳號」，長筆名單行尾端截斷。未改資料模型、登入流程或彈窗路由。
- Swift parse、git diff --check 與無簽章 Debug build exit 0。最新 App 未恢復登入 session，實際 GUI 僅確認未登入仍顯示「帳號」；登入後筆名分支未用真實 session 驗證，不把程式接線當作登入整合成功。


## 2026-09-29：V11.5 前置專案閱讀

- 目標／授權：使用者要求「V11.5 完整閱讀專案」；本輪為唯讀脈絡建立與文件 checkpoint，R／U／I 不適用，不授權新增功能。完成條件為核對基線、規格、模組責任及待驗收邊界；非目標為修改功能、部署、操作作者資料。
- 起始 git status 曾顯示 ContentView、Localizable 與五份文件修改；後續核對 HEAD `4b3d1a7`（V11.4）、分支 `feat/shiye-publication`，寫本紀錄前工作樹乾淨。本輪沒有提交、回復或清除那些修改，不推論其狀態變化原因。
- 閱讀：協作規則、實作紀錄、狀態／current 工作與交接、主要產品規格、架構／模型／備份／工程／測試文件；盤點全部 Swift 檔與型別／action／測試入口，閱讀啟動、首頁帳號、登入儲存、發布、匯入及 sidecar 的主要路徑。大型編輯器、遷移快照及各 View 未逐行完整審查；這不是全專案逐行 code review。
- 直接查證：106 個 App Swift 檔、12 個 XCTest 檔、244 個 test 方法；計數不代表執行通過。六個 store、主 V5／settings V13／planning V7 契約維持；設定畫面開發版本字串仍為 V10.1，bundle marketing version 1.0，未因聊天標題 V11.5 自動修改。
- 未完成／邊界：V11.1 實機鑰匙圈與 V11.2 真實切換等既有待驗收保留；歷史規格的部署待辦與最新發布成功紀錄並存，未擅自改寫 auth 契約複本。未重跑 build、XCTest、GUI、遠端部署或真實串接。
- 本輪修改僅追加紀錄與狀態／交接；V11.5 具體需求尚未提供。下一步為接收具體需求，再閱讀受影響程式全文並整理 R。


## 2026-09-29：V11.5 三個資料空間 R 批准（開始）

- 使用者「確認需求」批准一個未登入空間、最多兩個帳號空間、快速切換及完整移除此裝置上的指定帳號資料；本輪只整理需求與 U 草案，不修改功能、不實際刪除資料。
- 起始：`feat/shiye-publication`／`4b3d1a7`；既有 implementation-log、project-status、handoffs/current 三份閱讀紀錄修改保留。
- 工作單元：保存 R 契約、驗收條件與待確認事項，提供可評估 U 流程；非目標為雲端同步、永久刪除拾頁會員、網站作品刪除或實作授權。

### R 紀錄結果

- current 工作單新增 V11.5 R approved、U／I pending、隔離與刪除契約、非目標、驗收及 U 草案；project-status 與 handoff 新增目前階段與單一下一步。舊文件內容及三份既有修改保留。
- `git diff --check` 通過；本輪純文件，未執行 build／XCTest／GUI，未修改功能／帳號憑證或作者資料，未提交。
- 下一步：使用者評估 U 的切換面板、登出與刪除確認；舊資料遷移歸屬仍是待確認提案。


## 2026-09-29：V11.5 U 批准與 I 計畫（開始）

- 使用者「U」批准上一輪工作區選擇面板與刪除確認、登出／刪目前帳號返回未登入空間。僅 U 批准，不當作 I 實作授權。
- 起始 HEAD 4b3d1a7；work-items/current、handoffs/current、project-status、implementation-log 四份既有修改保留。本輪只改文件。
- 已核對固定 App startupState、六 store 建立、全域資料位置、封面快取、AI 任務、發布提交及鑰匙圈單一 Session；I 提案沿用單一 Session，不保存兩組 token，不改 V11.1 service／ACL。

### U／I 文件結果

- current 工作單 U 改 approved，補六階段 I 計畫、驗證、身分與備份相容提案；project-status／handoff 追加目前階段。R 契約、V11.1 安全儲存與舊工作未驗收狀態保留。
- 本輪純文件，未跑 build／XCTest／GUI，未修改程式、憑證或作者資料，未提交；下一步 I 明確批准後實作。


## 2026-09-29：V11.5 I 批准／實作開始

- 使用者「I」批准三空間、Guest 舊資料遷移、啟動恢復、單一 Session 身分核對與備份政策。R／U／I approved。
- 起始 HEAD 4b3d1a7，四份工作文件已有本對話修改，保留。目標為完成工作區生命週期／隔離／切換／刪除及驗證；正式作者資料不作測試。
- 共用搜尋：沿用 SailuneDataLocations、既有六 store Factory／migration、BookCoverStore、SectionUnitPreference、SharedUI tokens／圖標／copy、EditorBridge flush 與 PublicationCoordinator；新增具名工作區 Coordinator 集中跨模組不變條件。


## 2026-09-29：景停品牌官網首頁設計原型

- 使用者批准開始設計；景停為內容品牌、拾頁保持閱讀品牌、帆夢為創作工具。三者以繁體中文為核心，題句「張燈樓結綵 留風盼景停」不改字。
- 起始 Sailune 分支 feat/shiye-publication、HEAD 4b3d1a7，已有 project-status/current handoff/implementation-log 文件修改；Pagelet HEAD c80fa3b，工作樹乾淨。保留既有修改與 V11.5 U/I pending，沒有實作資料空間。
- 新增工作區 Innisfree-site 靜態首頁原型（HTML/CSS/JS、favicon、燈樓生成圖片、README）；此為獨立品牌設計，不改帆夢或拾頁功能、schema 或正式資料。文字為設計草案；沒有虛構作者、作品或營運數據。
- 驗證：本機 http://127.0.0.1:4173 回應 200；CUA 桌面 1280px 畫面確認標題、繁體中文、燈樓圖片及首頁排版。拾頁介紹彈窗開啟及 Escape 關閉通過。CSS 手機配置已建立，實際手機、200% 放大及帆夢介紹尚未逐項驗證。沒有 build、XCTest、遠端串接或部署；本輪只交付設計預覽。
- 唯一下一步：使用者檢視首頁設計，校正視覺及資訊結構，再決定後續頁面。

- 補充驗證：CUA 390 × 844 手機尺寸核對主視覺、題句及旗下品牌單欄排列；未見截字或橫向溢出。已 reset 暫時 viewport override 並保留預覽 tab。

## 2026-09-29：景停首頁移除敘述與圖片

- 使用者直接要求刪除新增敘述文字、保留空間，暫不放圖片。保留品牌名稱、題句、導覽、區段標籤及原布局；移除所有新增敘述與裝飾文字、彈窗描述／清單及頁面圖片引用。圖片檔保留但不呈現。
- 以空白文字行保留排版，原圖片區維持尺寸並改為透明。未改帆夢／拾頁功能或正式資料。
- 驗證：重新載入本機預覽，CUA 畫面確認題句保留、敘述空白且無主視覺圖片；AX 確認敘述與 image 節點已移除。未部署。下一步由使用者檢視留白版。


## 2026-09-29 V11.5 I 實作結果與檢查點

- 目標：使用者「I」批准三空間實作、Guest 遷移、啟動恢復、單一 Session、備份相容政策。工作樹 `feat/shiye-publication`／`4b3d1a7`；起始前置四文件保留，無原有程式修改覆蓋，未提交。
- 變更：新增 WorkspaceRegistry／Factory／Coordinator／LegacyMigration／SelectionView；App 根共用生命週期與偏好注入；六 store、封面／地圖／AI／模板／論壇／統計／發布／restore 隔離；保存 participant、發布 busy 及 UUID／環境核對；本機刪除先標清理狀態、釋放 bundle、清除相符 Session／偏好／資料，失敗可重試。保留所有 domain schema。Guest snapshot 遷移保留 UUID／舊來源，建立工作區安全備份。備份 manifest 帶 workspaceID，舊備份限 Guest。
- 原因與範圍：實際網站只有一組 Session，因此本機切換不冒充登入；驗證實際 user UUID 後才發布。靜態資產路徑由 coordinator 提供，持久服务捕捉位置；延遲拖曳／刪除、封面／地圖／TXT 匯入及發布準備回呼核對舊 context 是否仍為現空間。
- 文件：更新 spec-workspaces-v11.5、architecture、data-model、backup-and-migration、consistency-audit、批准計畫／狀態／交接。長期規格與驗證限制分開保存。
- 驗證命令：`xcodebuild -quiet -project Sailune.xcodeproj -scheme Sailune -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/SailuneV115Derived -clonedSourcePackagesDirPath /private/tmp/ShiyePublicationDerived/SourcePackages -disableAutomaticPackageResolution -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test`；最後 exit 0。xcresult `Test-Sailune-2026.09.29_14-12-45-+0800.xcresult`（同 derived Logs/Test）由 `xcrun xcresulttool get test-results summary` 核對 253 passed／1 skipped／0 failed／254 total。Debug build 及 diff check 通過。11 WorkspaceTests 含 coordinator 完整刪目前帳號與保留另一帳號，無真實網站登入／刪除。
- 過程失敗：初次 sandbox build 的空 SourcePackages／網路 DNS／Simulator 權限錯誤，改用既有快取與主機 build；工作區首兩輪 3 passed／5 failed，修正 `/var` 與 `/tmp` 系統 alias 的符號連結判定，第三輪 10 全通過。回呼補強一輪 compile 因 EditorSidebarView 缺 coordinator 環境失敗，補齊後完整通過。新增清理測試後一回完整 runner abort 被記在 V42Outline test，實際 crash lastExceptionBacktrace 在 SailuneAIClient.chat 的 NSURLSession 背景請求；重跑 253 全通過，偶發原因未解決，非宣称功能修復。紀錄 log `/private/tmp/sailune-v115-*`。
- GUI：隔離路徑 `/private/tmp/SailuneV115GUI/legacy/Sailune-v5.store`，確認工作區選單、Guest active、兩個 add slots、空白點擊取消且不穿透；最後回呼修正前產物。CUA 正常退出後 session 80050 exit 0。未操作正式資料。
- 未驗證／下一步：真實 OTP／Keychain／網站发布、多視窗未存正文與組字、帳號列切換／刪除確認／備份與小視窗 keyboard；需隔離真實帳號人工驗收。保留 active，不將編譯／fixture／提交等同串接成功。


## 2026-09-29 V11.5 Guest 移入帳號／R 與 U 提案開始

- 使用者「可以」接受整個未登入空間移入空帳號方案，R approved；未明確要求開始實作，U／I pending。目標為來源完整移入、成功後 Guest 清空，失敗保留來源；不合併既有帳號資料。
- 起始工作樹沿用 V11.5 全部未提交改動（feat/shiye-publication／4b3d1a7）；另發現 Localizable.xcstrings 39 行新增，非本輪修改，保留。只修改工作／交接／狀態文件。
- 唯讀核對 WorkspaceSelectionView、WorkspaceRegistry、WorkspaceCoordinator、WorkspaceFactory、既有 spec：可沿用面板與保存屏障；跨空間還原目前禁止，移入需独立具名流程，不能放寬一般備份還原限制。空帳號不能只檢查書籍數量，需區分系統初始化資料與使用者資料。

- 結果：新增 work/current 獨立 R／U 工作單，提供目的帳號、確認、取消、處理／錯誤文字線框；更新 status／handoff。精確空帳號／發布紀錄等列待 I 收斂，非已決規格。`git diff --check` 通過；純文件未跑 build／測試。下一步確認 U，依 AGENTS R→U→I 規則未修改功能。


## 2026-09-29 V11.5 Guest 移入／U approved、I 提案

- 使用者「Ｕ」批准上一輪 UI；R／U approved、I pending。目標為核對並提出完整移入／空間判定／中斷復原實作計畫，不修改功能程式。沿用上一輪工作樹與未提交修改。
- 唯讀核對 WorkspaceFactory／LegacyMigration／DataLocations、AuthorProfile／ContentView 預設作者、BookPublicationStore／論壇／統計與 schema 型別清單。發現發布 status 無遠端作者 UUID，提出非草稿 Guest 拒絕策略供 I 批准，不推論遠端所有權；完整空間檢查涵蓋作者與所有 stores／sidecar／偏好，排除已知初始化基線。
- 計畫：Coordinator action＋專用 snapshot／驗證／journal／recovery；保存屏障、卸載 context、目的地 commit、Guest 重置、重開復原；安全備份獨立保存，pending restore 不搬移，既有跨空間還原限制不放寬。純文件更新批准、I 計畫與驗收／風險，保留原三空間未驗收事項。
- 驗證：git diff --check 通過；未跑 build／XCTest／GUI，未改功能／schema／憑證／正式資料。唯一下一步 I 明確批准後實作。

## 2026-09-29：景停 logo／文案／配色修正

- 使用者指出 AI 感過重，要求更換 logo、全部敘述及配色；先以簡潔中文文字標誌取代印章，白／深灰／少量藍色取代米白／墨青／朱紅／金色。保留原空間及不放圖片的要求。
- 敘述維持空白，剩餘詩意操作與裝飾改為直接名稱：作品、品牌、拾頁、關於景停；中文序號改阿拉伯數字。只保留使用者指定題句。無正式資料或既有產品變更。
- 驗證：CUA 重新載入與實際畫面確認文字 logo、白／深灰配色、無圖片與敘述，題句維持原字。未公開部署；等待使用者檢視設計。


## 2026-09-29 Guest 移入 I approved／開始實作

- 使用者「Ｉ」批准完整移入計畫與非草稿／pending restore 限制。目標：完整六 store／資產移入空帳號、保存／備份／驗證、持久進度與重開復原、已批准 UI 及故障測試。
- 當前 HEAD 已由其他工作前進至 `0966e7c`（V11.7），非前輪 `4b3d1a7`；起始僅四份流程文件修改，既有三空間功能已在目前程式。核對現有 Workspace/App／Factory／備份與 shared 資源，沿用現況，不回復其他工作。

## 2026-09-29：景停標誌四方向比較稿

- 使用者確認三款中文字標，並要求加入抽象化「景」字搭配全名的輔助方向。本輪只做黑白比較稿，不換網站、不新增網站敘述或圖片。定位為多文體／多表現形式／多產品的文學集合中樞，僅作設計依據。
- 設計說明保存於工作區 Innisfree-site/design/logo-directions.md；使用內建 imagegen 製作 A 俐落、B 宋體骨架、C 自由節奏、D 抽象「景」字配全名比較稿。生成結果待核對。
- Sailune 既有四份文件修改及未追蹤 WorkspaceTransferService.swift 保留；未修改其功能。
- 結果：首張對比失常不可用，以一次針對白底黑字的 imagegen 編輯修正；完成比較稿保存在 Innisfree-site/design/logo-comparison-v1.png。A 幾何化筆畫仍需校正「景」字辨讀，B/C 風格差距偏小，D 為符號配全名的探索；不宣稱已完成正式向量 logo。下一步由使用者選方向，再精修字形。


## 2026-09-29 Guest 移入實作／驗證結束檢查點

- 批准與工作樹：R「可以」、U「Ｕ」、I「Ｉ」均 approved；目標整個 Guest 移入空帳號、不合併。HEAD 0966e7c／feat/shiye-publication，起始四份流程文件保留；其他景停設計紀錄未覆寫，無提交。產品版本與 schema 分開，六個領域 schema／migration 沒有改版。
- 變更與原因：新增 WorkspaceTransferService／10 個 WorkspaceTransferTests，來源及空目的地先精確掃描、雙端安全備份、SQLite online snapshot、全部模型欄位／實體主鍵與資產 SHA256、stage 重開驗證；不比對 Core Data 內部 Z_OPT 修訂值。root transfer.json 持久 preparing／prepared／installing／committed／completed，Transfer Recovery/<UUID> 保留雙備份／原 Guest／原目的地；commit 前復位、commit 後繼續重置 Guest，未知或驗證錯誤保留 journal／資料。不能以普通跨空間還原替代移入。
- UI／生命週期：WorkspaceCoordinator 保存所有 participants／contexts／偏好並停止 AI，卸載 bundle／根 generation 等釋放後置換；所有 scene 共用工作區。WorkspaceSelectionView 提供已批准目的地原因／確認取消／進度重試，App root 卸載進度與可恢復失敗，完成 alert 跨 root 保留。目的 Auth UUID／環境／Email／Session 不被來源替換，作者写作資料移入；另一帳號不變。
- 必要修正：ItemCopyStore 強持有 levelSelectionContainer，實際寫入 selection 才不會在 context 失去容器時 SIGTRAP。ContentView／BookOverviewView／EditorWorkspaceView 比較主 context 本身，避免旧回呼讀 destroyed context.container。SailuneAIClient.chat 先 Task.checkCancellation，阻止已取消排隊請求使用 invalidated session；新增取消回歸測試。這些修正均由本輪資料測試／卸載流程實際暴露，不增加產品功能。
- 保護政策：只允許空初始作者／已知預設偏好；六 store 任何孤立資料、自訂作者／資產／sidecar／偏好均拒絕覆寫。未知 schema／檔案、損毀、symlink、清理中／pending restore 拒絕；Guest 非草稿發布狀態沒有遠端作者識別，所以拒絕。來源偏好在 validateFiles 檢查，避免有 Book 時 early-return 漏掉壞 plist。commit 後資產 checksum 不符停止 Guest 重置，原始副本保留。
- 共用搜尋／例外：沿用工作區 panel 的 SailuneLayout／Theme／Symbol／ActionCopy；原生文字 Button 與現有工作區列一致（共用只有純圖標按鈕），未另造樣式。跨模型不變條件集中 Service／Coordinator；View 只送意圖。更新 spec-workspaces-v11.5、architecture、data-model、backup-and-migration、consistency-audit 及工作／交接／狀態文件。
- Debug build：xcodebuild -quiet -project Sailune.xcodeproj -scheme Sailune -configuration Debug -destination 'platform=macOS' -derivedDataPath /private/tmp/SailuneTransferDerived -clonedSourcePackagesDirPath /private/tmp/ShiyePublicationDerived/SourcePackages -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build；exit 0。測試共用同參數，另加 -parallel-testing-enabled NO test；主機環境執行，未將沙盒失敗當程式失敗。
- 完整回歸：/private/tmp/sailune-transfer-full-tests-r2.log，Test-Sailune-2026.09.29_18-01-12-+0800.xcresult（/private/tmp/SailuneTransferDerived/Logs/Test），xcodebuild exit 0；xcrun xcresulttool get test-results summary 核對 Passed／264 passed／1 skipped／0 failed／265 total、runtimeWarnings 空。略過既有 SAILUNE_REAL_KEYCHAIN_TEST opt-in，沒有真實 Security／OTP 成功宣稱。
- 最後小幅補強：pending recovery = journal exists OR bundle nil，確保 journal 完成後最終 activation 失敗仍有重試入口；其後相同 test 命令加 -only-testing:SailuneTests/WorkspaceTransferTests -only-testing:SailuneTests/SailuneAITests，/private/tmp/sailune-transfer-completion-check.log、Test-Sailune-2026.09.29_18-07-53-+0800.xcresult，exit 0／25 passed／0 failed／0 skipped。最後程式沒有再改；完整回歸在這一行補強前，最後專項在補強後。diff check 通過。
- 測試覆蓋：六個真實檔案 store／UUID／正文／作者／物品副本及選定等級／能力／設定／規劃與資產、source prefs、另一帳號、Coordinator switch 與重開；preparing／backup／copy／validate／prepared、installing／rename／commit、Guest move／reset／completed／registry 等邊界中斷。每個注入測試確認 reachedBoundary，防止準備失敗被誤當故障復原通過；重複 recover 不再次匯入。拒絕 nonempty author／prefs／orphan settings／unknown file／corrupt prefs／non-draft／pending restore／symlink；commit 後 asset damage 保留 Guest 與 journal。
- 過程失敗保留：17-34-54 第一輪 4 passed／3 failed，摘要不一致；17-37-11 1 passed／6 crash，ItemCopyStore 容器持有問題；17-41-37 4 passed／3 failed，model 摘要相同但 assets 不同，Foundation /var→/private/var 導致绝對路徑字元截取错位，改資產內相對 key。17-49-53 9 passed 後加腐損偏好成 10 tests。17-53-01 中途取消（exit 75），不算測試通過。17-54-27 完整 261 passed／2 failed，crash 被歸鄰近 Outline／Keychain，實際診斷 Sailune-2026-09-29-175714.ips 的 lastExceptionBacktrace 在 SailuneAIClient.chat URLSession.data，取消前置檢查後上述完整回歸通過。中途 xcresult 猜錯路徑／沙盒 TestReport 寫入權限錯誤改主機讀取，無功能影響。
- 隔離 GUI：SAILUNE_TEST_STORE_URL=/private/tmp/SailuneTransferGUI/legacy/Sailune-v5.store。先以本機 fixture 身分建立 A／B（非 OTP），透過 GUI 建「移入測試作品／測試作者」、另一 scene 編入「隔離測試正文：移入後仍需保留。」；macOS 自動分頁成兩個 scene。目的地選擇→確認取消無 journal；實際移入顯示移入完成，兩 scene 同步目的地、保留 15 字、舊 editor 卸載；切 Guest 空書櫃且新建可用，再回 A 保留作品。正常 quit session 55600 exit 0；唯讀 SQLite 檢查 Guest 0 book／A 1／B 0、selected A、無 transfer.json、兩個安全備份。
- 最新 GUI 重開：最後 test build 副本獨立 bundleID com.MooNest.Sailune.TransferPreview／路徑 /private/tmp/SailuneTransferReopenUnique.app（只改暫存 plist 並 ad-hoc 重簽，未改專案身分），同隔離 env 啟動。CUA 確認書籍 15 字、可開卷節、全文與「已儲存」顯示，quit session 83815 exit 0，無存活 Sailune 程序。工具同名快取曾在 shell 沙盒啟動 exit 134 後另開無隔離 env 的測試副本，顯示預設資料；未在該視窗編輯／移入／刪除／發布，只讀辨識後正常關閉。另兩次隔離啟動為辨識改路徑 Ctrl-C exit 130，不算正常 GUI 退出；最終獨立路徑可用。CUA 某 getApp 超時等候約 364 秒，未將等待當驗收成功。
- 未驗證與下一步：本輪 coordinate click 反覆 noWindowsAvailable，空白取消只保留既有 handler／前輪驗證，沒有宣稱新一輪通過。實體分離視窗、中文 IME 組字 flush、小視窗／keyboard 確認／hit area、磁碟耗盡／真實程序 kill／斷電未實測；故障注入不等同上述實機故障。fixture 不代表真實 OTP／Session／發布或雲端移轉。沒有對正式作者資料執行移入／編輯／刪除。工作維持 active；唯一下一步隔離實體分離視窗與中文 IME 保存驗收，原三空間真實帳號／Keychain／發布／刪除待辦保留。


## 2026-09-29 測試版暫時放行已發布 Guest／開始

- 使用者直接要求這一測試版允許遷移、下一版改回。已發出範圍釐清：已發布來源／非空目的地／兩者；目前按「曾登入／測試」採最小暫時假設，先只放行 Guest 非草稿紀錄，不覆寫非空帳號。若回覆指定其他範圍再調整。
- 可驗證工作單元：僅 Debug 此版暫時允許本機已發布紀錄完整移入空帳號；Release 預設仍拒絕，目的地空間／pending restore／未知與損毀／備份／驗證／journal 保護不變，不代表遠端所有權轉移。直接授權具體調整略過重走 R／U／I，無新 UI。
- 工作樹仍 HEAD 0966e7c；前輪移入程式／测试／文件全部保留，Localizable.xcstrings 新既有修改亦保留。本輪不執行使用者資料移入，由使用者在 App 確認操作。

### 測試版暫時放行驗證

- 最小例外已實作：WorkspaceTransferService 在 #if DEBUG 下預設允許非草稿來源；Release constant／init 都固定 false。保留發布 sidecar 狀態與標籤，不清掉發布資料，不放寬空目的地／結構／pending restore／備份／journal，不執行網路。下一版恢復點：Debug 常數改 false＋預設測試恢復拒絕。
- fixture 明確注入嚴格模式，原 10 tests 继续驗證正式限制；新增預設 Debug 移入已發布記錄／tags／book UUID／帳號識別／Guest 重置，以及暫時放行下仍拒絕非空／未知／pending restore。此版專項共 12 tests。
- 命令：xcodebuild -quiet -project Sailune.xcodeproj -scheme Sailune -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/SailuneTransferDerived -clonedSourcePackagesDirPath /private/tmp/ShiyePublicationDerived/SourcePackages -disableAutomaticPackageResolution -parallel-testing-enabled NO -only-testing:SailuneTests/WorkspaceTransferTests CODE_SIGNING_ALLOWED=NO test；/private/tmp/sailune-transfer-test-override-r2.log，exit 0。Test-Sailune-2026.09.29_19-48-53-+0800.xcresult（derived Logs/Test），xcrun xcresulttool get test-results summary 核對 12 passed／0 failed／0 skipped、runtimeWarnings 空。
- 首輪 19-47-18（/private/tmp/sailune-transfer-test-override.log）11 passed／1 crash，新增 XCTest 臨時 WorkspaceBundle(...).container.mainContext 的 assertion 先釋放容器；DiagnosticReports/Sailune-2026-09-29-194750.ips 為該 test line 144／XCTAssertTrue 的 SIGTRAP。改保留 guest 局部 bundle 後重跑通過；不是 migration 資料驗證錯誤，不把失敗輪當已通過。
- 本輪沒有新 UI／schema／migration 格式，沒有移入使用者資料／GUI 操作／OTP 或網站驗收，不重跑此前完整 264 pass／1 skip。Localizable 既有 18 additions／3 deletions 保留。範圍詢問仍無回覆，沒有推論獲准覆寫非空帳號。工作／狀態／交接／spec／consistency audit 已記本版例外与恢复点。

- Release 驗證：同專案／scheme／快取，-configuration Release -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/SailuneTransferReleaseDerived CODE_SIGNING_ALLOWED=NO build。首輪 /private/tmp/sailune-transfer-override-release.log exit 0 且產物存在，但出現「command failed with exit code 0」矛盾訊息；增量重查移除 -quiet，/private/tmp/sailune-transfer-override-release-confirm.log exit 0、** BUILD SUCCEEDED **。Release 嚴格行為由 #if DEBUG／Release 固定 false 分支查證，未在正式使用者資料上執行移入。Debug 12 tests 與 Release build 不等同真實帳號迁移完成。
- 結束檢查：git diff --check 通過；未提交，未執行 GUI／使用者資料移入。唯一下一步使用者在 Xcode Debug Run 確認移入，下一版恢复暫時 Debug 限制（本版仍開啟）；原工作／人工驗收保留。


## 2026-09-29 關閉暫時移入許可／禁止未登入發布：開始

- 使用者直接授權「可以關掉許可了，另外，如果是未登入的話禁止發布」。工作單元：移除 Debug 非草稿來源 bypass，預設嚴格且不保留可注入的放行路徑；Guest／無相符有效登入不可開發布預覽或送出，更新入口與服務層防護。已移入內容／備份不回復，不做登出／資料搬移／遠端寫入。
- 現況查證：ContentView send 已 guard currentAccount＋canPublish，但 publishPublication 可從 Guest 準備預覽；StartPublishingView 的三個傳送按鈕沒 disable。PublicationCoordinator／Auth credentials 的 optional expectedUserID 可漏核對。本輪接到既有 action 契約，集中帳號身分檢查。
- HEAD 0966e7c，先前全部未提交改動與 Localizable 既有修改保留。使用者直接授權具體調整略過不適用 R／U／I；無額外 UI 改版，僅停用相關傳送操作。完成條件：非草稿移入拒絕、Guest 即使記住別帳號 Session 仍拒絕發布、正確帳號發送契約可用，適用專項與 build 通過。

### 關閉許可／Guest 發布封鎖：結果

- 移除整個 allowsPublishedGuestInCurrentTestBuild／allowsPublishedGuestForTesting 與放行欄位，來源非草稿 guard 恢復無條件嚴格；不保留 Debug 測試後門。以預設服務測 ongoing／completed／delisted 全拒絕，Guest 原 UUID／標籤／狀態、空目的地與 journal 皆不改；先前移入成功資料／備份不作回復。
- 发布規則集中 WorkspaceCoordinator.requirePublicationAccount：無本機帳號（Guest）丟 publicationRequiresAccount；缺有效／不相符 Session 丟 identityMismatch。identityMatches 接 optional account，nil 即使配相符的記住 user UUID／環境仍 false。ContentView 準備預覽／送出有主 context／帳號檢查；PublicationCoordinator.send(auth:store:workspace:) 在取得憑證前檢查，Auth.publicationCredentials 的 expectedUserID 改必填，實際 session 必須相符，不以 UI disabled 代替服務保護。
- UI 呼叫點：StartPublishingView 的草稿／連載／完結三個「傳送至拾頁」傳入 canPublish 值並停用；延遲標籤確認仍經 ContentView 再檢查。沒新 icon／文字樣式或讀 Store 的共用 UI，原本機狀態管理／寫作與數據瀏覽保留。View 只呈現授權結果／送意圖。
- 測試：新增 WorkspaceTests product service guard 驗 Guest／registered-but-unverified 在 credentials 前拒絕、無結果／發布 status 檔不生成／草稿維持；原身分匹配測試擴 Guest 記住另一帳號情境。移除暫時 Debug 成功 tests，改預設嚴格測試，原失敗復原／所有 stores 驗證保留。
- 命令：xcodebuild -quiet -project Sailune.xcodeproj -scheme Sailune -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/SailuneTransferDerived -clonedSourcePackagesDirPath /private/tmp/ShiyePublicationDerived/SourcePackages -disableAutomaticPackageResolution -parallel-testing-enabled NO -only-testing:SailuneTests/WorkspaceTransferTests -only-testing:SailuneTests/WorkspaceTests -only-testing:SailuneTests/PublicationClientTests -only-testing:SailuneTests/BookTextTransferTests CODE_SIGNING_ALLOWED=NO test；/private/tmp/sailune-guest-publication-guard-tests.log exit 0，Test-Sailune-2026.09.29_20-12-44-+0800.xcresult（derived Logs/Test）用 xcrun xcresulttool get test-results summary 核對 Passed／40 passed／0 failed／0 skipped、runtimeWarnings 空。quiet build 有舊 SwiftCompile exit 0 訊息矛盾，但實際 XCTest 完成摘要 Passed，不記為測試失敗。未重跑全套 264／Release／真實 Keychain。
- 最後將一行 .disabled 縮排對齊後，以同 build 參數（無 only-testing／改 build）Debug 建置，/private/tmp/sailune-guest-publication-guard-build.log exit 0；git diff --check 通過，rg 未找到任何舊放行符號。除縮排以外測試後未改程式。
- 隔離 GUI：複製前輪 /private/tmp/SailuneTransferGUI/legacy 到 /private/tmp/SailuneGuestPublishGUI/legacy，從備份的 original-guest 複本建立測試 Guest，registry selectedID=guest；全是已知 fixture，不讀取使用者資料作測試。從最新 Debug 複製 /private/tmp/SailuneGuestPublishCheck.app，仅暫存 bundleID 改 com.MooNest.Sailune.GuestPublicationCheck 並 ad-hoc sign，SAILUNE_TEST_STORE_URL 指該隔離 mainStore。CUA 首頁→發布，AX 顯示「傳送《移入測試作品》至拾頁」disabled；沒有預覽／登入／網路傳送。正常 quit session 64792 exit 0；使用者的另一 Sailune 未操作。
- 文件：工作／spec／architecture／consistency audit 更新現況，狀態／交接頂部標明暫時許可已關閉；舊許可／測試紀錄保留為歷史，不宣稱其仍開啟或使用者已完成實際資料移入。本輪沒有提交／正式資料修改／外部發布。限制：僅隔離草稿按鈕實際 GUI，連載／完結共用 canPublish 路徑已編譯；真實 Session 過期／重登／多視窗／IME／網站仍待原人工驗收。唯一下一步隔離實體分離視窗與 IME 保存驗收，維持整體 active。

# 拾頁／帆夢 帳號登入實作約定（auth-contract）

> 版本：v0.4｜2026-10-06；V12.1 帆夢專用 schema／管理員已在正式專案手動部署，跨帳號驗收待完成
> 正本：SailuneWeb `docs/auth-contract.md`。帆夢 repo 的 `docs/pagelet-auth-contract.md` 是複本，只能整份覆蓋同步，不在複本上修改。
> 每一項都標示狀態：**已實作**（可以照著寫程式）／**已決定**（規則定了，後端尚未完成）／**計畫中**（還會變，不可據此實作）。

## 0. 分工

| 範圍 | 負責 |
|---|---|
| 共用 Supabase 專案設定、Auth、寄信及唯一 migration 部署序列 | 共用基礎設施；目前檔案存於拾頁 repo |
| 帆夢論壇／模板 schema、RLS 與公告管理員契約 | 帆夢；SQL 原稿在帆夢 repo，同版部署副本進共用序列 |
| 帆夢 App 內的登入畫面、Session 保存、呼叫 RPC | 帆夢（Sailune）agent |
| 本文件修改 | 只由拾頁 agent 修改正本並升版；帆夢 agent 有需求時寫在自己的工作單，由使用者轉達 |

- 帆夢社群 SQL 由帆夢定義與測試；正式部署仍需併入同一 Supabase 專案 migration 序列，不能讓兩個 repo 各自推送不相容歷史。帆夢 App 不得假設尚未部署的 schema／RPC 已可用。
- 雙方各自依自己 repo 的 AGENTS.md 走 R／U／I；本文件不取代工作單。

## 1. 帳號系統（已決定）

- 只有一套帳號：拾頁的 Supabase Auth。帆夢帳號＝拾頁帳號，同一個 Email 就是同一個人。
- 帆夢不另建會員資料、不存密碼。
- 角色：讀者、作者、站長，由資料庫判斷（見 §5，計畫中）。

## 2. 連線設定（已決定）

- 帆夢只使用 **Supabase 專案網址** 與 **publishable（anon）金鑰**；兩者由使用者提供，放在 build 設定，不寫死在程式碼、不提交進 git。
- **絕不可**在帆夢使用或打包 service role / secret 金鑰。
- 套件：官方 `supabase-swift`（Swift Package Manager）。
- 帆夢已開啟 App Sandbox 與對外連線（`ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES`），不需另加 entitlement。

## 3. Email 驗證碼登入

### 流程（已決定）

1. 讀者輸入 Email → 呼叫 `auth.signInWithOTP(email:)`（允許首次登入自動建立帳號）。
2. 收信取得 **6 位數驗證碼** → 呼叫 `auth.verifyOTP(email:token:type: .email)`。
3. 成功後取得 Session；之後的 API 呼叫由 supabase-swift 自動帶上使用者憑證並自動續期。
4. 登出：`auth.signOut()`，並清除本機 Session。

- 不使用登入連結（magic link），也沒有密碼。
- 網站與帆夢寄出的是同一封信、同一種驗證碼。

### 後端前置（使用者 2026-09-27 回報已完成；見 V2 工作單）

- Email 範本改為顯示驗證碼（`{{ .Token }}`），不是登入連結。
- 自訂 SMTP：完成前 Supabase 只能寄給專案團隊成員、每小時數封，**開發期只能用使用者本人的 Email 測試**。
- SMTP、驗證碼範本與正式登入已由使用者在 V2 驗收；本輪隔離程式測試不寄信。

### 錯誤對應（已決定）

| 情況 | Supabase 錯誤碼（參考） | 帆夢顯示 |
|---|---|---|
| 驗證碼錯誤或過期 | `otp_expired` 等 | 驗證碼錯誤或已過期，可重新寄送 |
| 寄信太頻繁 | `over_email_send_rate_limit` | 請稍後再試 |
| 無網路／伺服器錯誤 | — | 無法連線，可重試 |
| Session 失效且無法續期 | — | 回到未登入狀態，提示重新登入 |

- 錯誤訊息不得顯示 token、金鑰或原始回應內容；診斷紀錄以 private 方式記錄，不記錄 token。

## 4. Session 保存（已決定）

- Session 只存 macOS 鑰匙圈（可沿用 `SailuneAISettings.swift` 既有的鑰匙圈存取方式，或 supabase-swift 的鑰匙圈儲存）。
- **不得**寫入 SwiftData、UserDefaults、JSON sidecar 或 `.sailunebackup`；還原備份後需重新登入。
- V12.1 起，未登入仍可建立／匯入書籍、寫正文及編輯角色／設定等整套本機創作；尋找、發布、模板、論壇、成就等非創作頁須登入且工作區身分與 Session 相符。離線不封鎖本機創作；需要共享資料的操作在離線時顯示可重試錯誤。

## 5. 作者綁定（程式已實作，正式 migration 待套用）

- `authors.user_id` unique 連到 Auth 使用者；首次發布可由登入者自動建立自己的作者紀錄。既有作者及作品不以封包筆名自動認領，轉移仍須管理者核對。
- `publication_author_v1(p_book_id text default null)` 回傳 caller 的作者 UUID；未登入、未綁定或書屬於另一作者即拒絕。包含隱藏作品，不依公開 RLS 的可見性猜測。
- `my_account_v1()` 與完整角色資料仍屬後續需求；App 登入頁仍只顯示 Email，發布時才查作者權限。

## 6. 帆夢發布介面（程式已實作，正式 API 待部署）

- 私有 Storage staging + TUS 上傳 `.shiye`，再 `POST /api/publications/v1` 傳 attempt UUID。所有請求使用同一 SDK Session 的 JWT，不使用 service role。
- `publish_book_v1` 以 caller UID 驗證作者歸屬並單一交易更新內容／收據；資料庫不信任 App 的 userId／authorId／筆名。
- 版本化格式、容量、HTTP 回應、重試與啟用步驟見 [發布 API](publication-api.md)。
- 讀者數據 API 仍屬後續需求。
- 新增範圍依 2026-09-28 跨專案 `.shiye` 工作單 R／U／I 核准，取代 v0.1 對作者與發布「計畫中，不可實作」的限制；既有登入 UI 與鑰匙圈保存契約維持。

## 7. V12.1 帆夢共享模板與論壇（App／資料庫已接線；跨帳號驗收待完成）

- 帆夢與拾頁共用 Supabase Auth，但論壇、公開模板、公告管理員由 `sailune_community` schema 管理。`public.site_admins`／`public.is_admin()` 只決定拾頁網站後台權限；`sailune_community.admins`／`sailune_community.is_admin()` 只決定帆夢公告權限。兩邊管理員不互相繼承。
- `20261005000000_sailune_community.sql` 是帆夢 SQL 原稿在同一 Supabase migration 序列中的部署副本。舊 `20261003010000_community.sql` 如已套用，前向遷移保留原表作唯讀、將資料與 UUID／時間戳複製到帆夢 schema 並封住舊表的 authenticated 寫入；舊表退役另作檢查點。若舊表不存在，直接建立新表。2026-10-06 正式 SQL Editor 唯讀查證舊／新社群表都不存在，既有拾頁核心表存在但無 CLI migration ledger；本次 SQL 由 SQL Editor 單獨手動執行成功，未登記 CLI 版本。不得直接 `db push` 重播既有拾頁 migration。
- 模板 payload 沿用帆夢 `BookTemplateDocument` V1 JSON，排除正文及寫作結構並限制負載；作者主動確認才公開。論壇文章純文字、五分類；舊本機 `Forum Posts.json` 不自動上傳。匿名不得查詢，作者只能改自己的內容，公告只由帆夢管理員發表／改動；App 隱藏按鈕不能代替 GRANT／RLS。
- App 使用同一 Supabase SDK Session 與 publishable key，以 `client.schema("sailune_community")` 讀寫社群表及呼叫帆夢管理員 RPC；發布 API 仍使用原 `public` 契約。正式 Data API 已加入 `sailune_community` Exposed schemas、兩張內容表與 `is_admin` RPC，`admins` 表不暴露；首位帆夢管理員已由受控 SQL 指派，App 或網站站長不能自行取得。Data API 的 Exposed tables／functions 開關曾額外授予 `anon` 表 SELECT、`authenticated` 表 DELETE 等過大權限；已於存檔後用 SQL 收回，再驗得匿名 schema／表／RPC 權限、登入者 DELETE 與 `admins` 讀寫權限皆為 false，登入者必要讀取、指定欄位寫入與 RPC EXECUTE 為 true。後續調整 Data API 開關也必須重做最小 GRANT 稽核；具體收斂 SQL 在帆夢 `docs/community-deployment-v12.1.md`。
- 文章與模板的 ID 在送出前由 App 生成，重試使用同一 ID。正式套用 migration 後，以兩個不同登入帳號／安裝核對共享、作者權限、兩種管理員互不繼承、取消公開，以及 Guest 本機創作仍可用。替身測試與建置不代表正式串接成功。

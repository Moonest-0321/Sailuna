# 拾頁／帆夢 帳號登入實作約定（auth-contract）

> ⚠ 複本：正本在 SailuneWeb `docs/auth-contract.md`。只能整份覆蓋同步，請勿在此修改。

> 版本：v0.1（草案）｜2026-09-27
> 正本：SailuneWeb `docs/auth-contract.md`。帆夢 repo 的 `docs/pagelet-auth-contract.md` 是複本，只能整份覆蓋同步，不在複本上修改。
> 每一項都標示狀態：**已實作**（可以照著寫程式）／**已決定**（規則定了，後端尚未完成）／**計畫中**（還會變，不可據此實作）。

## 0. 分工

| 範圍 | 負責 |
|---|---|
| Supabase 專案設定、Auth 設定、寄信、migration、RLS、RPC | 拾頁（SailuneWeb）agent |
| 帆夢 App 內的登入畫面、Session 保存、呼叫 RPC | 帆夢（Sailune）agent |
| 本文件修改 | 只由拾頁 agent 修改正本並升版；帆夢 agent 有需求時寫在自己的工作單，由使用者轉達 |

- 帆夢 agent **不得**修改 Supabase 設定、資料表或 migration，也不得自行假設尚未標為「已實作」的 RPC 存在。
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

### 後端前置（拾頁 agent；狀態：**未完成**）

- Email 範本改為顯示驗證碼（`{{ .Token }}`），不是登入連結。
- 自訂 SMTP：完成前 Supabase 只能寄給專案團隊成員、每小時數封，**開發期只能用使用者本人的 Email 測試**。
- 完成後本節改標「已實作」並升版。

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
- 未登入、離線或 Session 失效時，寫作與所有本機功能照常運作；只有需要網站的功能（發布、讀者數據）要求登入。

## 5. 角色與作者綁定（計畫中，不可實作）

預計提供（名稱與欄位可能變動）：

- `my_account_v1()` → `{ userId, email, isAuthor, isAdmin, authorId, penName }`
- 作者綁定：第一次以作者身分登入時，把既有筆名（`authors`）綁到該帳號；流程待拾頁 V2 決定。

## 6. 帆夢會用到的網站介面（計畫中，不可實作）

- 發布 `.shiye`、讀取讀者數據（閱讀數、加入書架人數、追更率）。
- 一律帶版本號（`*_v1`），權限由資料庫檢查「登入者是這本書的作者」。
- 另開約定章節，本版不定義。

## 7. 之後的 Google／Apple 登入（計畫中）

- 使用系統登入視窗（`ASWebAuthenticationSession`）＋ PKCE，回呼 `sailune://login-callback`；不使用 App 內嵌網頁（Google 會拒絕）。
- Apple 走網頁 OAuth，不需要 App 的 Sign in with Apple capability，但需付費 Apple 開發者帳號。
- 屆時拾頁 agent 會把回呼網址加入 Supabase 允許清單，帆夢 agent 再加 URL scheme。

## 8. 帆夢端驗收（建議）

- 用使用者本人 Email 完成寄碼→輸入→登入；錯誤碼顯示正確訊息。
- 關閉重開 App 仍為登入狀態；登出後鑰匙圈清空。
- 建立 `.sailunebackup` 後檢查內容不含任何 Session 或 token。
- 關閉網路時寫作、存檔、匯出不受影響。
- 以隔離資料驗收，不操作正式作者資料。

## 變更紀錄

- v0.1（2026-09-27）：初版草案。§1–4 已決定；§3 後端前置、§5–7 未完成。

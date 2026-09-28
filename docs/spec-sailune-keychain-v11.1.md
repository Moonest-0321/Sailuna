# V11.1 Sailune 登入鑰匙圈

## 已授權行為

- 範圍只限 Sailune 登入與安全儲存，不變更拾頁作者綁定或發布授權。
- 沿用 service `supabase.gotrue.swift` 與 SDK 原 account key，既有憑證不搬移、不刪除重建。Session 不存明文檔、UserDefaults、sidecar 或備份。
- 儲存層串行執行；成功讀取／不存在結果僅快取於記憶體。更新值先成功保存鑰匙圈才更新快取；相同值不重複保存。
- 一般／背景操作透過 `LAContext.interactionNotAllowed` 禁止鑰匙圈授權 UI。任何非 item-not-found 錯誤封鎖後續讀、寫、刪；清除記憶體快取，記錄操作與 OSStatus（無憑證、Email 或帳號 key）。
- SDK lifecycle 自動啟動續期關閉，登入或恢復且保存成功後由服務啟動續期；儲存失敗後停止。SDK 即使吞掉錯誤或重試，也不能再觸及實際鑰匙圈。
- 既有登入表單與帳號錯誤顯示鑰匙圈錯誤；「重試鑰匙圈授權」才清除封鎖並允許前景互動。取消／拒絕當次重試即再次封鎖；不自動重試。沒有已存 Session 時仍可走 Email OTP。
- 登入／登出不可將 SDK 吞掉的保存／刪除失敗當成功。重複 View task 每服務实例只恢復一次；實際 App 重開建立新服務再讀鑰匙圈。
- 登入表單保留既有原生 Button 樣式；新增重試與其相同，不順帶遷移表單共用元件。

- Xcode Debug 與 Release 使用同一個既有開發者 Team；bundle ID 不變，禁止以無簽章驗收產物代表穩定身份版本。舊鑰匙圈 ACL 是否接受新簽章仍需實機查證。

## 驗收及證據邊界

1. 正常登入閒置至少兩分鐘無連續系統授權視窗。
2. 拒絕／取消後背景不持續彈窗；明確重試可恢復。
3. 關閉再開 App 可恢复 Session。
4. 憑證更新與正常書籍傳送成功。

上述四項均需使用者實際安裝版本實機驗收。SDK／儲存替身回歸及獨立測試鑰匙圈項目不是實際登入／發布證據。實際路徑、codesign、ACL 尚未查證，不把 adhoc 測試建置當作使用者 App 根因。

Apple API：<https://developer.apple.com/documentation/security/ksecuseauthenticationcontext>、<https://developer.apple.com/documentation/localauthentication/lacontext/interactionnotallowed>。

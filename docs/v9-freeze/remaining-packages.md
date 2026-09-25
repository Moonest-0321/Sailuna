# V9 固定清單的剩餘處置批次

> 狀態：來源初審後的執行索引；命中 ID 與家族不增補。逐筆原始證據及三態見 `callsite-inventory.csv`、`resolution-ledger.csv`；模組責任見 `module-resolution-ledger.csv`。

| 批次 | 暫列待共用 ID | 核定工作 | 完成證據 |
|---|---:|---|---|
| 按鈕角色、位置與命中 | 50 | 對照同畫面原生 Button，分文字／整列／純圖標／破壞性；核對 28 pt 命中與相鄰欄位，不強制替換原生 Button | 每 ID 確認角色與保留或共用理由；Dark／Light、鍵盤 focus、實際 hit-test 的代表畫面證據 |
| 按鈕樣式 | 154 | 與所屬 Button 同批核定 `.plain`、`.borderless` 或具名 style 的用途 | 每 ID 對照按鈕 ID；沒有擴大點擊範圍或改變原生操作的回歸證據 |
| 單行與搜尋欄 | 0 | 核對一般文字、數值／日期、組字、提交與搜尋；只將契約相同者接入既有欄位或具名 variant | 逐 ID 最終處置、首行／圓角／CJK／焦點及提交驗收 |
| 多行欄 | 0 | 作者簡介兩處已接 V9.1au 共用元件；V9.1am 地點首行內距另待 U 核定 | 欄位首行不碰描邊、placeholder 與資料綁定不變的畫面證據 |
| 背景與色彩 | 0 | 核對可見表面用途、系統材質與狀態色；相同用途才共用語意 token | Light／Dark 對照與選中、hover 狀態證據 |
| 圖標 | 8 | 逐操作核對同功能字形；V9.1af 上下移動另待 U 核定 | 同 action 使用同 key；不同語意保留理由、tooltip／VoiceOver 對照 |
| 操作文案 | 0 | V9.1ao 已把 24 組、65 個操作 ID 接入共用來源；三組靜態狀態文字保留例外 | String Catalog／Debug build 已通過；同 action 畫面與 VoiceOver 仍待驗收 |
| 輔助描述 | 31 | 核對動態標題、help 與 accessibilityLabel 是否表達同一 action | VoiceOver／hover 提示及滑鼠操作對照，必要時含資料名稱 |
| 確認與錯誤呈現 | 41 | 核對破壞動作、取消、成功／失敗訊息與 sheet 邊界；只共用相同提示殼，不共用資料 action | 取消無副作用、失敗仍依已核定產品政策呈現的證據 |
| 錯誤出口 | 0 | V9.2al 已為三個靜默 catch 加 private 診斷；全 219 筆來源決策已分類，V9.2g 還原政策明確延後 | 隔離 store／檔案故障注入、紀錄可追蹤、結果不違反原核定政策 |
| 模組責任 | 11 檔 | 以資料／視圖／投影／Store 邊界審查，按 `module-resolution-ledger.csv` 的逐檔理由決定分離或保留 | 跨檔 API、schema 與外部行為核對；必要時 build 和相關回歸 |

以上為**待核定候選數**，不是應修改數。`合理例外` 1,214 筆及 80 個模組的理由仍須按固定清單審核；原分類判錯時只修訂原 ID 的處置紀錄。發現新單一呼叫點只記觀察，不新增 V9 批次。整個需求類別遺漏或原分類錯誤須先提出範圍變更證據、受影響家族與驗收成本。

## 批次順序與關卡

1. 完成按鈕與樣式對照、dialog 與 failure path 的最終三態；同期覆核各家族暫列例外。只有有具體共用契約的 ID 進入接線。
2. 依清單執行 UI 與程式接線。V9.1am、V9.1af 的 U／I 核定狀態獨立保留；未核定的畫面變更不得實作。
3. 每批完成後在 `resolution-ledger.csv` 對原 ID 寫最終理由、對應工作單及驗收結果；模組處置寫 `module-resolution-ledger.csv`。不要重生凍結快照。
4. 依 `README.md` 五條結案門檻統一驗收，任何一條無證據即保持 V9 active。

# 拾頁書籍交換格式（`.shiye`）規格 v1

> 狀態：v1 已實作（2026-09-28，R／U／I approved）；正式 API 與 migration 待部署。帆夢在內部建立封包直接傳送，不提供 `.shiye` 另存入口。
> 依據：目前 `Book`／`Volume`／`Section` 模型、`BookPublicationStore`（狀態／標籤）、`EpubExporter` 的幕標題判斷。

## 1. 設計原則

- **網站不必懂 SwiftData 或 AttributedString**：正文轉成純文字區塊陣列，網站只負責排版。
- **可更新連載**：卷、節使用 app 內既有 UUID，重複匯出同一本書時 ID 不變；網站以 ID upsert，不靠標題比對。
- **可增量同步**：每節附 `updatedAt` 與 `contentHash`，網站只需重新處理有變動的節。
- **不含設定集**：人物、物品、地圖、大綱、AI 對話、作者備註都不輸出；只輸出讀者看得到的內容。
- 為何不直接用 EPUB：EPUB 沒有穩定節 ID、連載狀態與標籤，網站要自行解析 XHTML；EPUB 匯出保留給電子書用途。

## 2. 封裝

- 副檔名 `.shiye`，實體為 ZIP（Deflate 或 Store 皆可）。
- 所有文字檔 UTF-8（無 BOM）、Unicode NFC、換行 `\n`。
- ZIP 內路徑一律 ASCII，不使用書名作為路徑，避免編碼問題。

```text
<書名>.shiye
├── manifest.json            必要
├── cover.png                可選；有封面時存在
└── sections/
    ├── <sectionUUID>.json   每節一檔
    └── ...
```

## 3. `manifest.json`

```json
{
  "format": "sailune.shiye-book",
  "formatVersion": 1,
  "generator": { "app": "Sailune", "version": "V10.6" },
  "exportedAt": "2026-09-27T08:00:00Z",
  "book": {
    "id": "6F1C...-UUID",
    "title": "孤鷹群舞",
    "author": "筆名",
    "synopsis": "簡介純文字，可含 \n",
    "language": "zh-Hant",
    "status": "ongoing",
    "tags": ["奇幻", "冒險"],
    "sectionUnit": "chapter",
    "cover": "cover.png",
    "wordCount": 123456
  },
  "volumes": [
    {
      "id": "UUID",
      "index": 1,
      "title": "啟航",
      "sections": [
        {
          "id": "UUID",
          "index": 1,
          "title": "相遇",
          "file": "sections/UUID.json",
          "wordCount": 3210,
          "updatedAt": "2026-09-26T15:44:00Z",
          "contentHash": "sha256:9f86d0..."
        }
      ]
    }
  ]
}
```

| 欄位 | 必要 | 規則 |
|---|---|---|
| `format` | 是 | 固定 `sailune.shiye-book`；網站不符即拒收。 |
| `formatVersion` | 是 | 整數。網站只接受已知版本；新增可選欄位不升版，改變既有欄位意義才升版。 |
| `exportedAt`、`updatedAt` | 是 | ISO 8601 UTC，`Z` 結尾，精確到秒。 |
| `book.id`／`volumes[].id`／`sections[].id` | 是 | app 內 UUID 大寫字串；同一書重複匯出不變。 |
| `book.status` | 是 | 只接受 `ongoing`／`completed`；首次草稿傳送使用 ongoing，遠端成功後才改本機狀態。 |
| `book.tags` | 是 | 可為空陣列；去除空白與重複，保留作者順序。 |
| `book.sectionUnit` | 是 | `section`／`zhang`／`chapter`，保留來源的節／張／章設定；使用者 2026-09-28 決定網站固定顯示「節」。 |
| `book.cover` | 否 | 有封面時為 `cover.png`，否則 `null`。PNG、sRGB，建議 1600×2400（2:3）；傳送自訂封面；沒有自訂封面時不含 cover.png，由網站使用預設封面。 |
| `index` | 是 | 從 1 起算，依 app 的 `sortOrder` 重新編號，連續不跳號。 |
| `title` | 是 | 作者原始卷名／節名純文字，不加「第X卷」前綴；前綴由網站依 `index` 產生，章節單位固定「節」。可為空字串。 |
| `wordCount` | 是 | 沿用 app 字數計算；`book.wordCount` 為各節總和。 |
| `contentHash` | 是 | 對該節 JSON 檔「原始位元組」做 SHA-256，小寫 hex，前綴 `sha256:`。 |

## 4. `sections/<id>.json`

```json
{
  "id": "UUID",
  "title": "相遇",
  "blocks": [
    { "type": "heading", "text": "第一幕　碼頭" },
    { "type": "paragraph", "text": "海風從港口吹來。" },
    { "type": "blank" },
    { "type": "paragraph", "text": "她抬起頭。" }
  ]
}
```

- `blocks` 依正文順序；每個 `\n` 分隔的段落轉成一個區塊。
- `heading`：app 的「幕標題」段落（對應編輯器 ⌘2，與 EPUB `<h2>` 同一判斷）。
- `paragraph`：內文段落。`text` 為純文字，保留全形空白與行首縮排字元；不含 HTML、Markdown 或 `#`。
- `blank`：作者刻意留的空行；連續多個照實輸出，網站可自行合併顯示。
- 不輸出字型、字級、顏色等本機編輯器格式；網站用自己的閱讀樣式。
- 空節（沒有任何文字）仍輸出，`blocks` 為空陣列；是否對讀者隱藏由網站決定。

## 5. 相容與擴充

- 第一版每次傳送完整快照；相同 ID 更新，缺少的舊卷／節下架，不刪除。以 hash 及正文／標題／位置／字數比較跳過未變更的節，保留 updated_at。
- 未知 formatVersion 拒絕；未知選填 JSON 欄位忽略；新增選填欄位不升版，改變既有欄位語意／必要結構才升版。
- `requiredCapabilities` 為選填陣列；v1 支援 `full-snapshot-v1`。未知必要 capability 在任何寫入前拒絕。省略時仍按完整快照處理。
- 新資料領域可使用 `extensions` 描述獨立版本與檔案。v1 不解讀 extension 的領域內容，接受已宣告且 hash 正確的選填 extension；未知必要 extension 拒絕。

```json
{
  "extensions": [{
    "id": "illustrations",
    "version": 1,
    "required": false,
    "files": [{
      "path": "extensions/illustrations-v1/scene.json",
      "contentHash": "sha256:<64 lowercase hex>"
    }]
  }]
}
```

`id` 僅小寫英數與連字號，1–64 字；version 1–999999；檔名僅 ASCII 英數、底線、點及連字號，不能以點開頭。每個檔案必須位於對應的 `extensions/<id>-v<version>/`，不可重複引用或未宣告。新領域仍須另行核定資料與權限規則；舊接收端能忽略選填 extension，能明確拒絕必要 extension。

## 6. 第一版容量與驗證

| 項目 | 上限 |
|---|---|
| ZIP bytes | 24 MiB |
| 全部解壓 bytes | 32 MiB |
| manifest.json | 2 MiB |
| 每節／extension 檔案 | 1 MiB |
| cover.png | 4 MiB；長寬各 4096 px |
| entries | 4096；只接受白名單檔案，不含 directory entries |
| 卷與節合計 | 4094 |
| entry 解壓倍率 | 200 |

ZIP 接受 Store／Deflate，拒絕加密、symlink、重複路徑、路徑穿越、CRC 不符或非合法 UTF-8；文字不含 BOM、NUL、CR，已知文字欄位須為 NFC。UUID 必須大寫，卷／節 index 從 1 連續編號，節 JSON 的 ID／標題須與 manifest 相同，全書字數等於各節加總。空卷及空節皆可傳送，但作品至少一卷，書名與筆名不可空白。

拾頁將正文以 `shiye-blocks-v1` JSON blocks 保存，不再經 Markdown 字串轉換。幕標題只依 block.type 呈現；作者正文中的 `##` 保持純文字。blank block 保留於資料庫，閱讀頁合併空行。完整快照不含封面時清除網站自訂封面，顯示網站預設封面；舊 pagelet-book 維運入口仍維持沒有新封面就保留的相容行為。

發布流程與啟用步驟見 [拾頁 API 與部署約定](../../Pagelet/docs/publication-api.md)。

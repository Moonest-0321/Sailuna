# 拾頁書籍交換格式（`.shiye`）規格草案 v1

> 狀態：v1。帆夢匯出給拾頁網站讀取並轉為閱讀頁的檔案格式。
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
| `book.status` | 是 | `draft`／`ongoing`／`completed`，對應 app 的草稿／連載／完結。 |
| `book.tags` | 是 | 可為空陣列；去除空白與重複，保留作者順序。 |
| `book.sectionUnit` | 是 | `section`／`zhang`／`chapter`，對應節／張／章；網站用來顯示「第 N 章」等字樣。 |
| `book.cover` | 否 | 有封面時為 `cover.png`，否則 `null`。PNG、sRGB，建議 1600×2400（2:3）；沿用 EPUB 匯出的「畫面實際顯示封面」。 |
| `index` | 是 | 從 1 起算，依 app 的 `sortOrder` 重新編號，連續不跳號。 |
| `title` | 是 | 作者原始卷名／節名純文字，不加「第X卷」前綴；前綴由網站依 `index`＋`sectionUnit` 產生。可為空字串。 |
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

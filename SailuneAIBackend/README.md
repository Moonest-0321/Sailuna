# 帆夢 AI 本機後端

第一階段只處理目前節次內文與聊天訊息。服務只綁定 `127.0.0.1`，未配置公開服務所需的登入、額度與防濫用機制。

## 啟動

需要 Node.js 26、可呼叫 Gemini API 的 Google 專案與 API key。在本目錄執行；金鑰只在目前終端機設定，勿輸入 App 或提交版本庫：

```sh
npm ci
read -s GEMINI_API_KEY
export GEMINI_API_KEY
npm run smoke:live
npm run dev
```

輸入 `read -s` 時貼上金鑰後按 Enter，不會顯示在終端。`smoke:live` 只用固定虛構句子實際呼叫模型，輸出是否回答與引文驗證，不傳作者資料。預設監聽 `http://127.0.0.1:8787`。可透過 `SAILUNE_AI_MODEL` 與 `SAILUNE_AI_PORT` 調整模型與埠號。不要提交 `.env` 或 API key。正式建置必須將 App 的 `SailuneAIBaseURL` 設為具認證與額度限制的 HTTPS 服務。

## API

`POST /v1/ai/chat` 的請求：

```json
{
  "sectionContent": "目前節次內文",
  "messages": [{ "role": "user", "text": "這一節的人物動機清楚嗎？" }]
}
```

回覆：

```json
{
  "answer": "回覆或建議",
  "evidenceQuotes": ["逐字摘錄的本節原文片段"]
}
```

App 會再次核對引文是否存在目前節次內文；未匹配的引文標為未驗證。後端不保存正文或對話，也不輸出其內容至日誌。呼叫 Gemini Interactions API 時使用 `store: false`，不建立供後續回合取用的服務端 Interaction 紀錄；Google 的資料處理仍依其 API 條款。

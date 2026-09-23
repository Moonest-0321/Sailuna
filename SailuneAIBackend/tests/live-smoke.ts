import { GoogleGenAI } from "@google/genai";
import { analyze } from "../src/server.ts";

const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  console.error("請先在目前終端機設定 GEMINI_API_KEY，再執行真實模型測試。");
  process.exit(1);
}

const sectionContent = "她握緊鑰匙，停在門前。她知道門後的人可能不會原諒她。";
const reply = await analyze(
  {
    sectionContent,
    messages: [{ role: "user", text: "這段人物的猶豫清楚嗎？請引用原文回答。" }]
  },
  new GoogleGenAI({ apiKey }),
  process.env.SAILUNE_AI_MODEL || "gemini-3.8-flash"
);

const allQuotesVerified = reply.evidenceQuotes.length > 0
  && reply.evidenceQuotes.every((quote) => sectionContent.includes(quote));
console.log(JSON.stringify({
  answered: reply.answer.trim().length > 0,
  evidenceQuotes: reply.evidenceQuotes,
  allQuotesVerified
}));
if (!allQuotesVerified) process.exitCode = 1;

import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { analyze, createSailuneAIServer } from "../src/server.ts";

const calls = [];
const server = createSailuneAIServer(async (input) => {
  calls.push(input);
  return { answer: "可以再寫出她的猶豫。", evidenceQuotes: ["她握緊鑰匙"] };
});
let baseURL;

before(async () => {
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  baseURL = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  server.close();
  await once(server, "close");
});

test("Gemini request uses the selected model, structured JSON and stateless processing", async () => {
  let modelRequest;
  const fakeAI = {
    interactions: {
      create: async (request) => {
        modelRequest = request;
        return { output_text: JSON.stringify({
          answer: "她有猶豫。",
          evidenceQuotes: ["她握緊鑰匙"]
        }) };
      }
    }
  };
  const input = {
    sectionContent: "她握緊鑰匙。",
    messages: [{ role: "user", text: "她猶豫嗎？" }]
  };
  assert.deepEqual(await analyze(input, fakeAI, "gemini-3.8-flash"), {
    answer: "她有猶豫。",
    evidenceQuotes: ["她握緊鑰匙"]
  });
  assert.equal(modelRequest.model, "gemini-3.8-flash");
  assert.equal(modelRequest.store, false);
  assert.equal(modelRequest.response_format.mime_type, "application/json");
  assert.ok(modelRequest.input.includes(JSON.stringify(input)));
});

test("valid request forwards only the current section and chat to the analyzer", async () => {
  const payload = {
    sectionContent: "她握緊鑰匙。",
    messages: [{ role: "user", text: "這段如何？" }]
  };
  const response = await fetch(`${baseURL}/v1/ai/chat`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload)
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    answer: "可以再寫出她的猶豫。",
    evidenceQuotes: ["她握緊鑰匙"]
  });
  assert.deepEqual(calls, [payload]);
});

test("empty section and malformed JSON never reach the analyzer", async () => {
  const callCount = calls.length;
  const emptyResponse = await fetch(`${baseURL}/v1/ai/chat`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ sectionContent: "  ", messages: [{ role: "user", text: "分析" }] })
  });
  assert.equal(emptyResponse.status, 400);
  assert.deepEqual(await emptyResponse.json(), { error: "INVALID_REQUEST" });
  const malformedResponse = await fetch(`${baseURL}/v1/ai/chat`, {
    method: "POST",
    body: "{"
  });
  assert.equal(malformedResponse.status, 400);
  assert.deepEqual(await malformedResponse.json(), { error: "INVALID_JSON" });
  const extraContextResponse = await fetch(`${baseURL}/v1/ai/chat`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      sectionContent: "測試正文",
      sectionTitle: "不得接收的標題",
      messages: [{ role: "user", text: "分析" }]
    })
  });
  assert.equal(extraContextResponse.status, 400);
  assert.equal(calls.length, callCount);
});

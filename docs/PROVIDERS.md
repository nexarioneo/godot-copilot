# PROVIDERS.md — Provider Catalog & Configuration

This document covers everything about LLM providers: presets, config format,
multi-key strategy, testing, model import, and streaming behavior.
For the provider architecture see [ARCHITECTURE.md](ARCHITECTURE.md) §5.

---

## 1. Two Provider Kinds (`kind`)

| `kind` | Implementation | Protocol | Authentication |
| --- | --- | --- | --- |
| `openai` | `CopilotOpenAiProvider` | OpenAI-compatible: `/chat/completions` or `/responses` | `Authorization: Bearer <key>` |
| `anthropic` | `CopilotAnthropicProvider` | Anthropic Messages API: `/messages` | `x-api-key: <key>` + `anthropic-version: 2023-06-01` |

`api_type` (only for `kind: openai`):

- `chat_completions` — default, compatible with almost every server
  (OpenAI, Groq, DeepSeek, OpenRouter, Ollama, LM Studio, vLLM, etc).
- `responses` — OpenAI Responses API (`/responses`) for endpoints that support it.

Providers with `kind: anthropic` always use the native Messages API (not Anthropic's
OpenAI-compatibility mode), so `tool_use`/`tool_result` and `max_tokens` are handled
correctly.

---

## 2. Provider Presets

Presets live in `CopilotProviderPresets` (data only, not in the dialog).

| Preset | kind | api_type | Base URL | Key URL |
| --- | --- | --- | --- | --- |
| OpenAI | openai | chat_completions | `https://api.openai.com/v1` | platform.openai.com/api-keys |
| Anthropic | anthropic | — | `https://api.anthropic.com/v1` | console.anthropic.com/settings/keys |
| Gemini | openai | chat_completions | `https://generativelanguage.googleapis.com/v1beta/openai` | aistudio.google.com/apikey |
| Vertex AI | openai | chat_completions | `https://aiplatform.googleapis.com/v1` | console.cloud.google.com/apis/credentials |
| OpenRouter | openai | chat_completions | `https://openrouter.ai/api/v1` | openrouter.ai/keys |
| DeepSeek | openai | chat_completions | `https://api.deepseek.com/v1` | platform.deepseek.com/api_keys |
| Groq | openai | chat_completions | `https://api.groq.com/openai/v1` | console.groq.com/keys |
| Ollama | openai | chat_completions | `http://localhost:11434/v1` | — |
| Agnes AI | openai | chat_completions | `https://api.agnesai.com/v1` | agnesai.com |
| Kiro | openai | chat_completions | `https://api.kiro.ai/v1` | kiro.ai |
| Blackbox AI | openai | chat_completions | `https://api.blackbox.ai/v1` | blackbox.ai |
| OpenCode Zen | openai | chat_completions | `https://opencode.ai/zen/v1` | opencode.ai |

Presets contain **initial values** only. Once created, a provider becomes a regular
entry in `settings.json` and can be edited freely (base URL, api type, prefix, etc.).

Provider logos live in `assets/providers/<name>.svg`. Logo matching for custom
providers is name-based (heuristic): `deepseek`, `kiro`, `gemini`, `groq`, `vertex`,
`agnes`, `anthropic`/`claude`, `ollama`, `openrouter`, `openai`, etc.
Providers without a logo get an initial-letter badge.

---

## 3. Multi-Key Strategy

All keys are stored as a list; only keys with `enabled: true` are used.

| `key_strategy` | Behavior |
| --- | --- |
| `sticky_count` | Always use the **first** enabled key for the next `sticky_count` requests, then move to the next key, rotating. |
| `round_robin` | Rotate on every request (sticky_count = 1). |

Implementation: `CopilotConfig.next_api_key(provider_name) -> Dictionary`
(`{"value", "label", "index"}`) or `{}` when no key is enabled.
The `_rr_counters` counter is per provider (in-memory, reset when the editor restarts).

The user can reorder keys (↑/↓ buttons in the Provider Manager); that order is the
rotation order.

---

## 4. Testing Keys & Model Import

**Testing a single key**: `GET <base_url>/models` with the provider's auth header.
`kind: anthropic` uses `POST <base_url>/messages` with a minimal body
(`max_tokens: 1`, user message `"ping"`) because Anthropic has no `/models` endpoint
for a regular API key. Success = HTTP 2xx.

- "Test All" runs the tests sequentially (one at a time) so rate limits stay low and
  progress is visible; the Stop button cancels the queue.
- Per-key status: `queued`, `testing`, `success`, `failed`.

**Model import**: `GET <base_url>/models`, read the `data[]` or `models[]` array, take
`id` (fallback `name`), then add it to `providers.<name>.models`. Existing models are
not duplicated (the name is updated if needed).

**Adding a model manually**: through `CopilotModelEditor` (id, display name, vision,
reasoning). The `vision` capability → input modalities `["text","image"]`;
`reasoning` → the `reasoning: true` flag.

Models with `disabled: true` do not appear in the agent's model picker, but remain in
the manager list (dimmed, at the end).

---

## 5. Streaming

All providers use SSE streaming except internal calls (compaction, subagent, title),
which use non-streaming requests.

The OpenAI parser (`CopilotOpenAiProvider`) tolerates several line variants:

1. **Standard SSE** — `data: {...}` terminated by `data: [DONE]`; comment lines
   `: ping` are ignored.
2. **Chat deltas** — `choices[0].delta.content` and `choices[0].delta.tool_calls[]`
   (with `index` for argument accumulation).
3. **Ollama NDJSON** — JSON lines without the `data:` prefix, content in `message.content`.
4. **Responses API** — `response.output_text.delta`,
   `response.function_call_arguments.delta`, `response.output_item.added/done` events.
5. **Anthropic fallback** (for compatible proxies) — `delta.text`.

Anthropic native streaming (`CopilotAnthropicProvider`):

- Events: `message_start`, `content_block_start`, `content_block_delta`
  (`text_delta` / `input_json_delta`), `content_block_stop`, `message_delta`,
  `message_stop`, `error`.
- Tool use: a `tool_use` block (`id`, `name`) + partial JSON arguments from
  `input_json_delta.partial_json`, accumulated and parsed at block stop.
- Endpoint errors (e.g. `overloaded_error`) are emitted as `stream_failed`.

Internal format (OpenAI chat) → Anthropic conversion on request:

- `system` message → the `system` parameter (merged if there is more than one).
- `role: tool` → a `user` message containing a `tool_result` block (merged in order).
- `assistant` with `tool_calls` → a `text` block (if present) + `tool_use` per call.
- Chat tool schema `{type: function, function: {...}}` → `{name, description, input_schema}`.
- `max_tokens` is required; the default value is 8192 (can be changed in code).

---

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `HTTP 401` | Wrong/disabled key | Test the key; enable the correct key |
| `HTTP 404` on `/chat/completions` | Base URL with a missing/extra `/v1`, or the server uses `responses` | Check the Advanced tab (`base_url`, `api_type`) |
| `HTTP 404` on `/responses` | The endpoint does not support the Responses API | Switch `api_type` to `chat_completions` |
| `HTTP 400 invalid_request_error` from Anthropic | Missing `max_tokens` (internal bug) or wrong message format | Report it; the provider handles the format |
| Empty stream then finish | The server sends no text delta (refusal / missing parameter) | Check the error message in the chat; try another model |
| Connect timeout | Local base URL down (Ollama) or a network issue | Start the server / check the connection |
| Model missing from the picker | `disabled: true` | Enable it in the Models tab |
| Answers truncated oddly | Large/complex tool output | Increase `memory.tail_size`, check pruning |
| 429 rate limit | Key strategy | Enable `round_robin` with multiple keys |

---

## 7. Adding a New Provider

Via the UI: Provider Manager → `+ Add ▾` → `Custom Provider…` → complete the wizard.
The resulting `settings.json` entry:

```jsonc
"providers": {
  "MyServer": {
    "kind": "openai",
    "base_url": "http://192.168.1.10:8000/v1",
    "api_type": "chat_completions",
    "keys": [{ "label": "Key 1", "value": "sk-local", "enabled": true }],
    "models": { "my-model": { "name": "My Model" } }
  }
}
```

Via code (adding a new preset): add an entry in
`CopilotProviderPresets.get_presets()` — just `kind`, `base_url`, `api_type`,
`key_url`, `icon_path` (optional), and its SVG icon in `assets/providers/`.
No other changes are required; the wizard and manager read this data automatically.

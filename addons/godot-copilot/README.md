# Godot Copilot

AI agent chat for the Godot 4 editor, running in the **right dock** (next to the
Inspector). The plugin manages its own conversation sessions, editor context, tool
execution, and action permissions — without touching your project code unless permitted.

Version: **2.0.0** — see [docs/CHANGELOG.md](../../docs/CHANGELOG.md).

**Early version**: built with AI assistance, reviewed by its author; features
work but the plugin may still contain bugs and rough edges. License: **MIT**
(Author **Nexarioneo**), see [LICENSE](../../LICENSE).

---

## Features

- **Multi-provider**: `openai` providers (chat_completions/responses) and `anthropic`
  (native Messages API), including popular presets (OpenAI, Anthropic, Gemini,
  DeepSeek, Groq, OpenRouter, Ollama, and more) plus custom providers.
- **Multi API keys** per provider with the `round_robin` (rotate on every request) or
  `sticky_count` (a key persists for several requests) strategy.
- **Tool execution**: file (read/write/edit/patch/delete/list), search (glob/grep),
  non-blocking terminal, web (read_url/http_request), scene editor (with undo/redo),
  editor (project settings, script editor), and MCP servers.
- **Subagents**: `spawn_subagent` runs an isolated task in `read_only` or `full_access`
  mode; the model of each subagent can be overridden.
- **Permission engine** `action(target)` with three presets: `sandbox`, `review`,
  `turbo`, plus editable Deny/Ask/Allow rule lists.
- **Conversation memory**: automatic compaction with summaries, pruning of old tool
  output, `text` or `native` mode.

## Installation

1. Copy the `godot-copilot/` folder (this folder) into `<project>/addons/`.
2. Open **Project > Project Settings > Plugins** and enable **Godot Copilot**.
3. The **Copilot** dock appears on the right; focus it with `Alt+Shift+C` or
   **Project > Tools > Godot Copilot: Focus Chat**.

Godot 4.7+ is recommended (modern dock: movable, floatable, closable per tab).
Godot 4.4–4.6 still works via the classic dock fallback.

## First Steps

1. Click the key icon in the chat header (or **Project > Tools > Godot Copilot:
   Provider Manager…**).
2. **Add** a provider from a preset (enter the API key when the wizard appears) or
   choose *Custom Provider…* for your own endpoint.
3. In the **Keys** tab, add a key and press **Test** to verify it.
4. In the **Models** tab, press **Import from /models**, then select the **Active model**.
5. Close the dialog and start sending messages in the dock.

Permission, memory, and subagent settings live in **Settings** (the settings icon in
the header, or the Tools menu).

## Permissions

| Preset | Behavior |
| --- | --- |
| `sandbox` | Operations inside the project are allowed; outside the project the plugin asks for permission. |
| `review` | Every action asks for permission unless allowed by an Allow rule. |
| `turbo` | Every action is allowed automatically unless blocked by a Deny rule. |

Rules use the `action(target)` format, e.g. `read_file(res://scripts/)`,
`command(git)`, `http_request(godotengine.org)`. The inline permission card in the
chat selects the scope: this target only, a whole directory/domain, or unlimited.

## Data & File Locations

All data is stored in `user://godot-copilot/`:

```
settings.json          provider, permission, memory, agent, and MCP configuration
settings.backup.json   automatic backup
sessions/              conversation history per session
```

Data from version 2 (`user://godot_copilot/`) and version 1 (`res://.godot/.copilot/`)
is migrated automatically on first load.

## Documentation

- [docs/DESIGN.md](../../docs/DESIGN.md) — visual UI design.
- [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) — technical architecture.
- [docs/PROVIDERS.md](../../docs/PROVIDERS.md) — provider & API key management.
- [docs/CONVENTIONS.md](../../docs/CONVENTIONS.md) — code conventions.

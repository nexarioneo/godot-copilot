# Godot Copilot

**Godot Copilot** is an AI agent chat for the Godot 4 editor, running in the
right dock next to the Inspector. It supports multiple LLM providers
(OpenAI-compatible and Anthropic), executes tools on your behalf (files,
terminal, web, scenes, MCP), spawns subagents for isolated tasks, and routes
every sensitive action through an `action(target)` permission system.

Current version: **2.0.0** — see [docs/CHANGELOG.md](docs/CHANGELOG.md).
Author: **Nexarioneo**. License: **MIT** — see [LICENSE](LICENSE).

---

## Project Status

**Early version.** Godot Copilot is a young project: it works, but expect rough
edges, incomplete polish, and bugs. It executes tools (files, terminal, web,
scenes, editor settings) with real effects on your project, so keep regular
backups of your work and review carefully what you grant permission for. Bug
reports and suggestions are welcome through GitHub Issues.

**AI-assisted development.** This project was built with AI assistance: the
code, documentation, and UI were written in collaboration with an AI coding
agent, then reviewed and smoke-tested by the author.

---

## Features

- **Multi-provider** — `openai` kind (Chat Completions and Responses APIs) and
  `anthropic` kind (native Messages API), with presets for OpenAI, Anthropic,
  Gemini, DeepSeek, Groq, OpenRouter, Ollama, and more, plus custom endpoints.
- **Multi API keys** per provider with `round_robin` (rotate on every request)
  or `sticky_count` (reuse a key for several requests) strategies, including a
  built-in key tester.
- **Tool execution** — file operations (read, write, edit lines, patch, delete,
  list, glob), text search (grep), a non-blocking terminal, web access
  (`read_url`, `http_request`), scene editing with undo/redo, editor and project
  settings, and MCP servers (`mcp_list_tools`, `mcp_call_tool`).
- **Subagents** — `spawn_subagent` runs a focused task with its own context in
  `read_only` or `full_access` mode; each subagent can use its own model.
- **Permission engine** — `action(target)` rules with `sandbox`, `review`, and
  `turbo` presets, editable Deny/Ask/Allow lists, and an inline permission card
  with scope selection (this target, whole directory/domain, unlimited) and a
  remember option.
- **Sessions and memory** — independent conversation sessions, automatic
  compaction with summaries, and pruning of old tool output (`text` or `native`
  mode).
- **Editor-native UI** — built entirely in code and themed from the editor
  theme; no `.tscn` scene files.

## Requirements

- **Godot 4.7 or newer** (recommended): the dock is a full `EditorDock`, so it
  can be moved, floated, and closed like built-in docks.
- **Godot 4.4–4.6**: supported through the classic dock fallback.
- An API key for at least one provider, or a local endpoint such as Ollama.

## Installation

1. Copy the `godot-copilot/` folder into your project's `addons/` directory, so
   that the result is `addons/godot-copilot/`.
2. Open **Project > Project Settings > Plugins** and enable **Godot Copilot**.
3. The **Copilot** dock appears in the right dock area (next to the Inspector).
   Press `Alt+Shift+C` or use **Project > Tools > Godot Copilot: Focus Chat**
   to focus it.

## Quick Start

1. Open the **Provider Manager** with the key icon in the chat header, or via
   **Project > Tools > Godot Copilot: Provider Manager…**.
2. Click **Add** and choose a provider preset (the wizard asks for the API
   key), or choose *Custom Provider…* for your own endpoint.
3. Open the **Keys** tab and verify the key with **Test**.
4. Open the **Models** tab, press **Import from /models**, then select the
   **Active model**.
5. Close the dialog and start typing in the dock. `Enter` sends the message;
   `Shift+Enter` inserts a new line.

Permission, memory, and subagent behavior are configured in **Settings**
(settings icon in the header, or **Project > Tools > Godot Copilot:
Settings…**).

## Using the Chat Dock

- The header contains the session selector, new/delete session, Provider
  Manager, Settings, and Clear buttons.
- The status bar shows the agent state (`Ready`, `Thinking…`, `Replying…`,
  `Running tools…`, `Waiting for permission…`, `Compacting memory…`) and the
  active model.
- While a turn is running, **Stop** cancels it; a pending permission request
  (if any) is resolved as denied.
- Tool calls and permission requests appear inline in the conversation; once an
  action is allowed, the agent continues automatically.

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Alt+Shift+C` | Focus the Copilot dock |
| `Enter` | Send the message |
| `Shift+Enter` | New line in the composer |

## Permissions

| Preset | Behavior |
| --- | --- |
| `sandbox` | Operations inside the project are allowed; operations outside it ask for permission. |
| `review` | Every action asks for permission unless allowed by an Allow rule. |
| `turbo` | Every action is allowed automatically unless blocked by a Deny rule. |

Rules use the `action(target)` format, for example `read_file(res://scripts/)`,
`command(git)`, or `http_request(godotengine.org)`. The inline permission card
offers a one-off allowance, a remembered scope, or a permanent rule.

## Subagents and MCP

- Subagents declared in Settings (names recognized by `spawn_subagent`) run in
  `read_only` (no write actions, never asks for permission) or `full_access`
  (write actions are forwarded to the main permission flow) mode, optionally
  with a dedicated model.
- MCP servers are declared in the settings file under `mcp.servers`; the model
  discovers their tools with `mcp_list_tools` and calls them with
  `mcp_call_tool`.

## Storage and Migration

All plugin data lives in `user://godot-copilot/`:

```
settings.json          providers, permissions, memory, agent, and MCP settings
settings.backup.json   automatic backup of the settings file
sessions/              one JSON file per conversation session
tmp/                   temporary files created by tools
```

On first load, the plugin migrates data automatically from the previous v2
location `user://godot_copilot/` (settings and sessions) and, if necessary, from
the v1 location `res://.godot/.copilot/`.

## Project Layout

```
godot-copilot/
├── AGENTS.md                  repository index for humans and AI agents
├── README.md                  this file
├── LICENSE                    MIT license text
├── docs/                      DESIGN, MATERIAL3, ARCHITECTURE, CONVENTIONS, PROVIDERS, CHANGELOG
├── project.godot              development/test project (plugin enabled)
└── addons/godot-copilot/      the plugin itself
    ├── plugin.cfg             plugin metadata
    ├── plugin.gd              EditorPlugin entry point (dock, menu, lifecycle)
    ├── assets/                bundled fonts (Roboto) and Material Symbols icons
    └── src/
        ├── config/            paths and settings (CopilotPaths, CopilotConfig)
        ├── chat/              agent, sessions, subagents, editor context
        ├── providers/         provider implementations, factory, presets
        ├── security/          permission engine
        ├── tools/             tool catalog, router, tool implementations
        └── ui/                dock, chat view, dialogs, md3/ component library
```

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — technical architecture and data flow.
- [docs/DESIGN.md](docs/DESIGN.md) — visual design: Material 3-based component library and layouts.
- [docs/MATERIAL3.md](docs/MATERIAL3.md) — Material 3 reference data (tokens, component specs).
- [docs/PROVIDERS.md](docs/PROVIDERS.md) — provider kinds, presets, and key management.
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md) — code conventions.
- [docs/CHANGELOG.md](docs/CHANGELOG.md) — version history.
- [addons/godot-copilot/README.md](addons/godot-copilot/README.md) — short addon overview.

## Development

- The development environment has no Godot binary: changes are verified by
  static review plus a manual smoke test in the Godot 4.7 editor.
- Follow [docs/CONVENTIONS.md](docs/CONVENTIONS.md) and keep documentation,
  comments, and UI strings in English; Markdown files are emoji-free.
- Check `git status` before and after changes; see [AGENTS.md](AGENTS.md) for the
  full workflow.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 **Nexarioneo**.

Third-party assets bundled with the plugin keep their own licenses: the Roboto
fonts (`addons/godot-copilot/assets/fonts/`) and the Material Symbols icons
(`addons/godot-copilot/assets/symbols/`) are Apache License 2.0; see the README
and `LICENSE.txt` files inside those folders.

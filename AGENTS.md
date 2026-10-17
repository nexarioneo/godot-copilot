# AGENTS.md — Godot Copilot Project Map

This document is the **primary index** for anyone (human or AI agent) working in
this repository. Read it before changing code.

**Godot Copilot** is a Godot 4 editor plugin (target 4.7+) that provides an AI
agent chat running in the editor's right dock, with multi-provider support
(OpenAI-compatible & Anthropic), tool execution (file, shell, web, scene, MCP),
subagents, and an `action(target)` permission system.

Current version: **2.0.0** (full rebuild — see [docs/CHANGELOG.md](docs/CHANGELOG.md)).

---

## Documents

| Document | Content | Use when |
| --- | --- | --- |
| [docs/DESIGN.md](docs/DESIGN.md) | **Visual design**: GodotStyle, right dock layout, message cards, permission card, dialog layouts, icons, visual checklist | Changing look/UI/UX |
| [docs/MATERIAL3.md](docs/MATERIAL3.md) | **Material 3 reference**: color roles and palettes, type scale, shape, elevation, motion, states, component specs, accessibility, Godot mapping concept | Redesigning the UI / looking up design values |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | **Technical architecture**: folder structure, classes, turn data flow, config schema v2, providers, permission engine, tool system, subagents, session/memory, editor integration | Changing logic/backend/integration |
| [docs/CONVENTIONS.md](docs/CONVENTIONS.md) | **Conventions**: GDScript style, file/class/function naming, config access, UI, providers, permissions, tools, paths, git | Writing/reviewing any code |
| [docs/PROVIDERS.md](docs/PROVIDERS.md) | **Providers**: kinds, presets, multi-key strategy, testing, model import, streaming, troubleshooting | Touching providers/APIs |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | Version history & breaking changes | Releasing / looking up change context |
| [README.md](README.md) | Project overview: features, installation, quick start, storage, layout | Onboarding / first read |
| [addons/godot-copilot/README.md](addons/godot-copilot/README.md) | Short addon overview from the user's point of view | Installation/usage |

**Key rule**: DESIGN.md covers visual topics only, ARCHITECTURE.md covers
technical topics only. Do not mix their contents.

---

## Repository Map

```
godot-copilot/
├── AGENTS.md                  ← this document
├── README.md                  ← project overview & quick start
├── docs/                      ← documentation (DESIGN, MATERIAL3, ARCHITECTURE, CONVENTIONS, PROVIDERS, CHANGELOG)
├── project.godot              ← test project; plugins are enabled in [editor_plugins]
└── addons/godot-copilot/
    ├── plugin.cfg             ← plugin metadata (name, version, script)
    ├── plugin.gd              ← EditorPlugin: right dock, Tools menu, lifecycle
    ├── README.md
    ├── assets/
    │   ├── icons/             ← plugin icons (copilot.svg, optional)
    │   └── providers/         ← provider logos *.svg
    └── src/
        ├── config/            ← CopilotPaths, CopilotConfig
        ├── chat/              ← CopilotAgent, CopilotSessionStore, CopilotSubagent, CopilotEditorContext
        ├── providers/         ← CopilotProvider + OpenAI + Anthropic + factory + presets
        ├── security/          ← CopilotPermissions
        ├── tools/             ← catalog, router, file/search/shell/web/scene/editor/mcp tools
        └── ui/                ← theme, dock, chat view, permission card, dialogs
```

---

## Key Decisions Summary

1. **Right dock, not a bottom panel.** `EditorDock` + `add_dock()` (4.7+),
   `default_slot = DOCK_SLOT_RIGHT_BL` (5), `available_layouts = DOCK_LAYOUT_ALL` (7),
   `icon_name = &"Terminal"`, shortcut `Alt+Shift+C`. Fallback to
   `add_control_to_dock()` when `EditorDock` is unavailable.
2. **Storage in `user://godot-copilot/`** (`settings.json`, `settings.backup.json`,
   `sessions/`, `tmp/`) with automatic migration from the legacy v2 location
   `user://godot_copilot/` and the v1 location `res://.godot/.copilot/`.
3. **Config schema v2**: `providers.<name>` (`kind`, `base_url`, `api_type`,
   `model_prefix`, `key_strategy`, `keys[]`, `models{}`), `permissions.preset`
   (`sandbox`/`review`/`turbo`), `memory.*`, `agent.*`, `mcp.servers`.
4. **Two provider kinds**: `openai` (chat_completions/responses) and `anthropic`
   (native Messages API). Tolerant stream parsers (SSE + NDJSON + Responses events).
5. **Permission single choke point in CopilotAgent**; verdicts `ALLOW`/`ASK`/`DENY`;
   rules `action(target)`; `full_access` subagents forward permissions to the main
   agent, `read_only` subagents never ask for permission.
6. **UI 100% built in code** (no `.tscn`); colors/icons from the editor theme via
   `CopilotTheme`; dynamic content inserted with `add_text()` (anti BBCode injection).
7. **Non-blocking shell tool** (`OS.create_process` + poll); all tools return
   `{success, error?, ...}`.

---

## Standard Workflow

1. Read the relevant documents in the table above.
2. Check `git status`/structure before changing anything (no `.uid`/`.import` files
   need to be preserved unless new assets are added).
3. Follow CONVENTIONS.md; if a new convention is needed, update that file too.
4. After changes:
   - grep for symbols across files (`CopilotConfig.`, `CopilotTheme.`, `CopilotPaths.`,
     signal names) to ensure there are no stale references;
   - ensure no leftover v1 terms: `CopilotSettings`, `CopilotToolRegistry`,
     `CopilotBaseProvider`, `execute_url`, `checkApiKey`, `provider_dialog`,
     `bottom_panel`, `.tscn`;
   - ensure no leftover `godot_copilot` (underscore) anywhere — not in paths,
     identifiers, or documentation (legacy names are allowed only where migration
     behavior is explicitly documented);
   - ensure no Indonesian text in code or documentation;
   - ensure Markdown files contain no emoji;
   - update CHANGELOG.md when behavior changes.
5. There is no Godot binary in this environment — verification is static review plus
   a manual smoke test by the user (see ARCHITECTURE.md §12).

---

## Environment Constraints

- No Godot CLI/binary for parse checks or running the editor.
- Environment: Linux (Android/Termux-style paths), with no additional Node/Python
  tooling assumed.
- Prefer `/tmp/opencode` for temporary files outside the project when needed.
- This project is a local git repository: the initial commit is in place, commits
  use the project identity (`Nexarioneo`, configured locally in this repo), and the
  folder is registered under git's `safe.directory` configuration, so
  `git status`/`git diff` are available for change review.

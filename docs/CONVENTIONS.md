# CONVENTIONS.md — Code & Naming Conventions

This document is the single source of naming/style rules. All new code must follow
it. A short summary is also available in [AGENTS.md](../AGENTS.md).

---

## 1. GDScript Style

- **Tabs**, not spaces (the GDScript editor standard).
- Every file starts with `@tool` (all scripts run in the editor), then `class_name`
  when the class is used across files, then `extends`.
- Order inside a class: `signal` → `const` → `enum` → `static var`/`var` →
  `@onready` → lifecycle (`_init`, `_ready`) → public methods → private (`_` prefix).
- **Typing is required** for variables (`var x: int = 0`), parameters, and return
  values (`-> void`, `-> Dictionary`). `Variant`/untyped only for dynamic JSON values.
- Use `:=` for obvious inferred types.
- Private names & helpers: `_` prefix (`_build_header()`, `_generation`).
- Signals: past-tense `snake_case` names (`tool_started`, `stream_completed`),
  parameters always typed.
- Do not add unused mock/"compatibility" APIs or aliases (avoid v1 leftovers such as
  `set_api_key`). Dead code is deleted, not kept.
- Comments in **English**, identifiers in **English**. Comments explain *why*, not *what*.
- User-facing strings are in **English** ("Send", "Deny"); technical terms (token,
  streaming, scope) are not force-translated.
- All documentation, code comments, and user-facing UI strings are written in English;
  Markdown files contain no emoji.

## 2. File & Class Naming

| Kind | Rule | Example |
| --- | --- | --- |
| Script file | `snake_case.gd`, `copilot_` prefix for every file in `src/` | `copilot_tool_router.gd` |
| Class name | `PascalCase`, `Copilot` prefix | `CopilotToolRouter` |
| `src/` folders | `config`, `chat`, `providers`, `security`, `tools`, `ui` | — |
| Constants | `SCREAMING_SNAKE_CASE` | `SCHEMA_VERSION` |
| Enums | `PascalCase` name; `SCREAMING_SNAKE_CASE` values | `Verdict.ALLOW` |
| Signals | past-tense `snake_case` | `permission_resolved` |
| Functions | `snake_case`, verb first | `build_messages()`, `next_api_key()` |
| Variables | descriptive `snake_case` | `active_provider_name` |

Full class names in use (do not change without updating every reference):

`CopilotPaths`, `CopilotConfig`, `CopilotAgent`, `CopilotSessionStore`,
`CopilotSubagent`, `CopilotEditorContext`, `CopilotProvider`,
`CopilotOpenAiProvider`, `CopilotAnthropicProvider`, `CopilotProviderFactory`,
`CopilotProviderPresets`, `CopilotPermissions`, `CopilotToolCatalog`,
`CopilotToolRouter`, `CopilotFileTools`, `CopilotSearchTools`, `CopilotShellTools`,
`CopilotWebTools`, `CopilotSceneTools`, `CopilotEditorTools`, `CopilotMcpTools`,
`CopilotTheme`, `CopilotDock`, `CopilotChatView`, `CopilotPermissionCard`,
`CopilotProviderManager`, `CopilotProviderRow`, `CopilotProviderWizard`,
`CopilotKeyRow`, `CopilotKeyEditor`, `CopilotModelRow`, `CopilotModelEditor`,
`CopilotSettingsDialog`.

Note: the abbreviation **AI** is written `Ai` in PascalCase names
(`CopilotOpenAiProvider`), following the engine style (`EditorInterface`, `OS` use
full uppercase, so the alternative `OpenAI` was also considered — **decision: use
`OpenAi`** and stay consistent in all references).

Material 3 design-system classes share the `CopilotMd3` prefix (tokens, scheme,
motion, icons, components); the full component catalog lives in DESIGN.md
section 4.

## 3. Config Access

- All `settings.json` access goes **only** through `CopilotConfig`. No direct
  `config.data["..."]` from the UI/agent (except inside `CopilotConfig` itself).
- Accessor naming: `get_*` to read, `set_*` to write, `is_*` for booleans, and every
  mutation calls `save()` internally.
- JSON keys are `snake_case` (v2). Old camelCase keys (`baseURL`, `apiKeys`, etc.)
  appear only in migration code.

## 4. UI

- UI is built **in code**; there are no `.tscn` files in the addon.
- Colors & icons: UI built on the editor theme goes through `CopilotTheme` (a
  fallback is mandatory); components in `src/ui/md3/` use the `CopilotMd3*`
  design system (`CopilotMd3Scheme` / `CopilotMd3Motion` / `CopilotMd3Icons`)
  instead — see DESIGN.md. The dock, chat view, and permission card are already
  migrated; the dialogs migrate next, and `CopilotTheme` is retired at the end.
- Every icon button requires `tooltip_text`.
- Use native Godot base widgets (`Button`, `OptionButton`, `CheckButton`, `SpinBox`,
  `LineEdit`, `TextEdit`, `Tree`/`ItemList` where appropriate).
- UI classes may `extends` a widget; child construction happens in `_build_ui()`
  (called from `_ready`), not in `_init`.
- Dynamic content in `RichTextLabel` uses `add_text()` (safe against BBCode);
  BBCode comes only from internal templates.
- Built node names use `snake_case` (`session_option`, `send_button`).

## 5. Providers & APIs

- Provider `kind`: `"openai"` or `"anthropic"`.
- `api_type` only applies to kind openai: `"chat_completions"` | `"responses"`.
- The internal message format is always OpenAI chat format; conversion happens only
  in providers.
- Model name in a request = `model_prefix + model_key` (prefix optional).
- There is no `checkApiKey` concept (removed). Key testing uses a real key from the list.
- Request User-Agent: `"GodotCopilot/2.0"`.

## 6. Permissions

- Official actions: `read_file`, `write_file`, `command`, `read_url`, `http_request`,
  `mcp`, `subagent`. A new action must be added to `CopilotPermissions` (+ info prompt
  + scope options) **and** to `CopilotToolCatalog.action_and_target()`.
- Verdicts: `ALLOW` / `ASK` / `DENY` (do not use the word "decision" in new code).
- Rules are always `action(target)`; the wildcard `*` means all targets.
- The only place that checks permissions is `CopilotAgent` (and subagents through the
  callback to the agent). Tools must not check permissions themselves.

## 7. Tools

- Adding a new tool means:
  1. a schema definition in `CopilotToolCatalog.get_definitions()`,
  2. an entry in `CopilotToolCatalog.action_and_target()`,
  3. an implementation in the relevant tools class (`Copilot*Tools`),
  4. dispatch in `CopilotToolRouter.execute()`,
  5. adding it to `core_names()` only if it is truly used in almost every task.
- All tools return a `Dictionary` with `success: bool`; on failure include a
  model-readable `error: String`.
- Tools that need async (shell/MCP/web) return a coroutine; callers always `await`,
  and `CopilotToolRouter.execute()` itself is a coroutine.

## 8. Storage & Paths

- All paths go through `CopilotPaths`; writing literal `user://` / `res://.godot`
  paths in other files is forbidden (except migration code in
  `CopilotPaths`/`CopilotConfig`).
- Always write files via `CopilotPaths.write_text()` (creates directories automatically).
- Session file names: `ses_<8 chars>.json`.

## 9. Git & Assets

- `.godot/` is not committed.
- `.uid` files are not committed manually (Godot creates them when opening the project).
- Provider SVGs live in `assets/providers/`; do not commit stale `.import` files
  (old `.import` files for moved/deleted assets must be deleted as well).

## 10. Checklist Before Closing a Change

- [ ] No references to old-version classes/functions (`CopilotSettings`,
      `CopilotToolRegistry`, `CopilotBaseProvider`, `execute_url`, `checkApiKey`,
      `provider_dialog`, etc.).
- [ ] All new `class_name`s are unique and do not collide with engine classes.
- [ ] Grep signal names to ensure emitter and connections match.
- [ ] No `await` on non-coroutine functions (and vice versa).
- [ ] All dialogs/docks are cleaned up in `_exit_tree()`.

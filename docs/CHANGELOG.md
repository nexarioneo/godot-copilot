# CHANGELOG.md

All notable changes to Godot Copilot. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

### Added

- **Material 3 foundation** (`addons/godot-copilot/src/ui/md3/`):
  `CopilotMd3Tokens` (color roles light/dark, type scale, shape, elevation,
  states, motion), `CopilotMd3Scheme` (role resolution, editor light/dark
  detection), `CopilotMd3Motion` (durations, easings, springs, cubic-bezier
  sampler, Tween helpers), `CopilotMd3Icons` (bundled Material Symbols with
  editor-icon fallback).
- **Bundled design assets**: Roboto Regular/Medium (`assets/fonts/`, Apache-2.0)
  and a curated 40-icon Material Symbols set as white 24px SVGs
  (`assets/symbols/`).
- **Material 3 base components** (`src/ui/md3/`): `CopilotMd3StateLayer`,
  `CopilotMd3Button`, `CopilotMd3IconButton`, `CopilotMd3Card`,
  `CopilotMd3TextField`, `CopilotMd3Chip`, `CopilotMd3ListItem`,
  `CopilotMd3Divider`, `CopilotMd3Badge`, `CopilotMd3Tooltip`.
- **Material 3 chat components** (`src/ui/md3/`): `CopilotMd3Spinner`
  (indeterminate circular progress), `CopilotMd3Checkbox`, `CopilotMd3EmptyState`,
  `CopilotMd3Snackbar` (inline rise/fall reveal, 4s auto-dismiss),
  `CopilotMd3ToolRow` (collapsible tool call row with output block) and
  `CopilotMd3Composer` (autogrowing pill input, Enter to send).
- **Retry last turn**: `CopilotAgent.retry_last_turn()` +
  `CopilotSessionStore.trim_after_last_user()` re-run the last exchange; the
  assistant message card exposes a Retry action.

### Changed

- **UI design concept reworked**: the plugin now targets its own Material 3-based
  component library (standalone components derived from stock Godot controls)
  instead of following the editor theme; `docs/DESIGN.md` was rewritten for the new
  concept, with reference data in `docs/MATERIAL3.md`.
- **Dock, chat view, and permission card rebuilt on the Material 3 system**:
  header (Sessions, New, Tools, Keys, Clear) with the title hiding under 320px;
  user bubbles and assistant cards with hover Copy/Retry; notice cards; tool rows;
  thinking row; streaming caret; empty state; composer pill with Send/Stop;
  "Jump to latest" chip; snackbar; and a 28px status strip (state dot + text +
  provider/model). The permission card now uses a shield badge, location chip,
  single-select scope chips, a remember checkbox and Deny / Always allow /
  Allow once: Allow once grants nothing, the checkbox turns Allow into a session
  grant, and Always allow writes a permanent rule.
- Chat rendering keeps the `add_text()`-only rule (no BBCode evaluation) and the
  pinned-to-bottom auto-scroll; the sessions menu uses a styled `PopupMenu` until
  `CopilotMd3Menu` lands in the dialogs phase.
- **Chat surfaces reuse `CopilotMd3Card`**: user bubbles, assistant cards and
  notices configure role, padding and corner overrides (`set_roles`,
  `set_padding`, `set_corner_radii`) instead of building one-off styleboxes; the
  permission card also applies its inherited elevated surface again (`super._apply`).

---

## [2.0.0] — 2026-10-17

Full rebuild from scratch. The structure, naming, system flow, and UI were rebuilt;
no file was kept as it was.

### Added

- **Project documentation**: `AGENTS.md`, `docs/DESIGN.md`, `docs/ARCHITECTURE.md`,
  `docs/CONVENTIONS.md`, `docs/PROVIDERS.md`, `docs/CHANGELOG.md`.
- **Right dock (EditorDock)**: the chat panel moved from the bottom panel to the right
  dock (slot `RIGHT_BL`, next to the Inspector) using Godot 4.7 `EditorPlugin.add_dock()`,
  with an `add_control_to_dock()` fallback for Godot < 4.7. Shortcut `Alt+Shift+C`.
- **Native Anthropic provider** (`CopilotAnthropicProvider`): real Messages API
  (`/messages`, `x-api-key`, `anthropic-version`, `max_tokens`, tool_use/tool_result).
- **New provider manager** (`CopilotProviderManager`): provider list with badges,
  Keys / Models / Advanced tabs, provider wizard, separate key & model editors,
  one-at-a-time key testing with stop, model import from `/models`, and an
  **Active model** picker in the Models tab.
- **Inline permission card** (`CopilotPermissionCard`): replaces the modal overlay +
  separate "always allow" dialog; scope options, "Remember" checkbox.
- **Settings dialog** (`CopilotSettingsDialog`): Permissions / Memory / Agent tabs.
- **New tools**: `http_request` (replaces `execute_url`), `search_available_tools`
  (JIT activation, already present in v1 but cleaned up), `CopilotEditorTools`.
- **`CopilotShellTools`**: non-blocking `execute_command` via `OS.create_process()`
  + temp-file output + polling (v1 called a function that never existed, so the
  terminal tool always failed).
- **Automatic v1→v2 configuration migration** + merging of old sessions.
- **Explicit multi-key strategies**: `round_robin` / `sticky_count`.
- **Native tooltips & icons** across the UI; provider logo badges moved to
  `assets/providers/`.
- **Material 3 reference** (`docs/MATERIAL3.md`): consolidated design-system data
  (color roles and palettes, type scale, shape, elevation, motion, states, component
  specifications, accessibility) compiled as the foundation for the plugin's own UI
  component library.

### Changed

- **Addon folder renamed**: `addons/godot_copilot/` → `addons/godot-copilot/`.
- **Storage root renamed**: `user://godot_copilot/` → `user://godot-copilot/`, with
  automatic migration from the previous v2 location (`user://godot_copilot/settings.json`,
  `settings.backup.json`, `sessions/`) and from the v1 location (`res://.godot/.copilot/`).
- **English-only documentation**: all documentation, code comments, and user-facing
  UI strings are now in English.
- **Emoji-free Markdown**: all Markdown documents use plain-text labels instead of emoji.
- **Folder structure**: the old `core/`, `providers/`, `tools/`, `ui/` are replaced by
  `src/{config,chat,providers,security,tools,ui}` with `copilot_*.gd` naming.
- **Class naming**: `CopilotSettings` → `CopilotConfig`; `CopilotSessionManager` →
  `CopilotSessionStore`; `CopilotToolRegistry` → `CopilotToolRouter` +
  `CopilotToolCatalog`; `CopilotBaseProvider` → `CopilotProvider`;
  `ProviderDialog` → `CopilotProviderManager`; etc. (see CONVENTIONS.md).
- **Configuration location**: `res://.godot/.copilot/config/settings.json` →
  `user://godot-copilot/settings.json`; sessions →
  `user://godot-copilot/sessions/`.
- **Config schema v2**: `provider` → `providers`, `options.*` flattened
  (`base_url`, `api_type`, `model_prefix`), `apiKeys` → `keys[{label,value,enabled}]`,
  `round_robin`/`sticky_limit` → `key_strategy`/`sticky_count`,
  `compaction.*` → `memory.*`, `agent.<name>` → `agent.subagents.<name>`,
  `mcpServers` → `mcp.servers`.
- **Permission presets**: `default`/`request_review`/`turbo` → `sandbox`/`review`/`turbo`.
- **Permission actions**: `execute_url` → `http_request`; verdicts replace decisions
  (`ALLOW`/`ASK`/`DENY`).
- **UI built 100% in code**; all `.tscn` (and `.tscn.bak`) files removed.
- **Dock toolbar**: compact header with tooltipped icon buttons replacing the old
  settings panel inside the dock.
- **System prompt**: updated (new permission actions, new tools,
  `search_available_tools` instructions).
- **User-Agent**: `GodotCopilot/1.0` → `GodotCopilot/2.0`.

### Fixed

- **Security**: `full_access` subagents no longer auto-allow ASK decisions; permission
  requests are forwarded to the main agent (v1: ASK permissions inside subagents were
  executed immediately without user approval).
- **Terminal tool**: `execute_command` used to call a `script_tools.execute_command()`
  that never existed (always failed); it now works and does not block the editor.
- **Tool result truncation** in `build_messages()` truncated by raw JSON character
  length (now it happens only while pruning is enabled and with a clear message).
- **BBCode injection**: model/user content is inserted via `add_text()` in separate
  message cards, no longer raw `append_text()` into one big RichTextLabel.
- **Sticky/round-robin**: sticky applies only when multiple keys are enabled, and the
  counter does not leak between providers.
- **Godot 4.7.2 compatibility** (found by the first smoke test):
  - `HTTPRequest.request()` calls (key tester, model import, `read_url`/`http_request`,
    MCP over HTTP) used the `HTTPClient` argument order; they now pass
    `(url, headers, method, body)`.
  - `Shortcut.add_event()` and `RichTextLabel.push_italic()` are not real APIs; the
    dock shortcut now sets `events` and notices use `push_italics()`.
  - `CopilotTheme` accessors accept any `Node` and look up theme values dynamically, so
    `AcceptDialog`-based dialogs (`Window`, not `Control`) no longer fail to compile.
  - Explicit types for Variant ternaries (`write_file`, `http_request` body) and for
    `PackedScene.instantiate()` (`instantiate_scene`), fixing GDScript inference errors.

### Removed

- `.tscn` files for all UI (`copilot_dock.tscn`, `provider_dialog.tscn`,
  `add_provider_dialog.tscn`, `api_key_dialog.tscn`, `model_dialog.tscn`,
  `provider_item.tscn`, `api_key_item.tscn`, `model_item.tscn`) along with `.bak` files.
- Old scripts: `core/agent.gd`, `core/settings.gd`, `core/session_manager.gd`,
  `core/permission_manager.gd`, `core/tool_registry.gd`, `core/subagent.gd`,
  `core/context_collector.gd`, `providers/base_provider.gd`,
  `providers/openai_provider.gd`, `tools/*.gd`, `ui/*.gd`.
- The `checkApiKey` concept (a separate test key outside the key list).
- The `execute_url` tool (replaced by `http_request`).
- All stale `.uid` files for deleted scripts (Godot regenerates them automatically).

---

## [1.0.0] — 2026-05 (legacy version)

Initial bottom-panel-based version:

- Chat dock in the bottom panel (`add_control_to_bottom_panel`).
- `.tscn`-based provider manager + nested dialogs.
- Multi-provider OpenAI-compatible (Gemini, OpenRouter, DeepSeek, Groq, Ollama, etc)
  with multi-key round-robin and model import.
- Permission manager with `default`/`request_review`/`turbo` presets and a modal
  permission dialog.
- Tools: file, search, web, scene/node, MCP, subagent.
- Context compaction & pruning.

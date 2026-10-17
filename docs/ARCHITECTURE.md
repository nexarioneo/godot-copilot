# ARCHITECTURE.md — Godot Copilot Architecture

This document covers the technical architecture **exclusively**: folder structure,
classes, data flow, configuration schema, and contracts between modules.
For visual design see [DESIGN.md](DESIGN.md); for naming see [CONVENTIONS.md](CONVENTIONS.md);
for the provider catalog see [PROVIDERS.md](PROVIDERS.md).

Target: **Godot 4.7+** (uses `EditorDock`), still runs on 4.4–4.6 via fallback APIs.

---

## 1. Big Picture

```
EditorPlugin (plugin.gd)
│
├── EditorDock "Copilot"                                   [right, next to Inspector]
│   └── CopilotDock (VBoxContainer, built in code)
│       ├── header: sessions + Tools/CryptoKey/Clear buttons
│       ├── CopilotChatView       ← renders messages & tool rows
│       ├── CopilotPermissionCard ← inline permission decision
│       ├── composer (TextEdit + Send/Stop)
│       └── status bar
│
├── CopilotAgent (Node, ReAct loop brain)
│   ├── CopilotConfig            (settings.json v2)
│   ├── CopilotSessionStore      (trajectory + persistence)
│   ├── CopilotPermissions       (rule engine: ALLOW/ASK/DENY)
│   ├── CopilotToolRouter        (tool execution + JIT activation)
│   │   ├── CopilotFileTools      read/write/edit/patch/delete/list
│   │   ├── CopilotSearchTools    glob/grep
│   │   ├── CopilotShellTools     execute_command (non-blocking)
│   │   ├── CopilotWebTools       read_url/http_request
│   │   ├── CopilotSceneTools     node & scene editor ops (undo/redo)
│   │   ├── CopilotEditorTools    project settings, script editor, rescan
│   │   └── CopilotMcpTools       MCP list/call
│   ├── CopilotProvider (active, created by factory)
│   │   ├── CopilotOpenAiProvider     chat_completions | responses
│   │   └── CopilotAnthropicProvider  messages API
│   └── CopilotSubagent          (isolated ReAct loop, optional)
│
├── CopilotProviderManager (dialog)  ← from dock / Tools menu
├── CopilotSettingsDialog  (dialog)  ← from dock / Tools menu
└── CopilotTheme, preset catalog, paths (static utilities)
```

Separation of responsibilities:

- **plugin.gd** handles editor integration only (dock, menus, lifecycle).
- **CopilotAgent** drives the conversation flow; it knows nothing about the UI.
- **UI (dock and dialogs)** only renders state and calls agent methods; it never touches storage.
- **Providers** handle HTTP/streaming only; they know nothing about tools or permissions.
- **Tools** handle execution only; permissions are checked in the agent (single choke point).

---

## 2. Folder Structure

```
addons/godot-copilot/
├── plugin.cfg
├── plugin.gd
├── README.md
├── assets/
│   ├── icons/copilot.svg          (optional, plugin icon)
│   └── providers/*.svg            (provider logos)
└── src/
    ├── config/
    │   ├── copilot_paths.gd       CopilotPaths    — paths & file IO utilities
    │   └── copilot_config.gd      CopilotConfig   — settings.json v2
    ├── chat/
    │   ├── copilot_agent.gd       CopilotAgent        — main ReAct loop
    │   ├── copilot_session_store.gd CopilotSessionStore — sessions & trajectory
    │   ├── copilot_subagent.gd    CopilotSubagent     — isolated loop
    │   └── copilot_editor_context.gd CopilotEditorContext — editor context
    ├── providers/
    │   ├── copilot_provider.gd            CopilotProvider (abstract)
    │   ├── copilot_openai_provider.gd     CopilotOpenAiProvider
    │   ├── copilot_anthropic_provider.gd  CopilotAnthropicProvider
    │   ├── copilot_provider_factory.gd    CopilotProviderFactory
    │   └── copilot_provider_presets.gd    CopilotProviderPresets (preset data)
    ├── security/
    │   └── copilot_permissions.gd CopilotPermissions — rule engine
    ├── tools/
    │   ├── copilot_tool_catalog.gd CopilotToolCatalog — schemas & action mapping
    │   ├── copilot_tool_router.gd  CopilotToolRouter  — dispatch + JIT
    │   ├── copilot_file_tools.gd   CopilotFileTools
    │   ├── copilot_search_tools.gd CopilotSearchTools
    │   ├── copilot_shell_tools.gd  CopilotShellTools
    │   ├── copilot_web_tools.gd    CopilotWebTools
    │   ├── copilot_scene_tools.gd  CopilotSceneTools
    │   ├── copilot_editor_tools.gd CopilotEditorTools
    │   └── copilot_mcp_tools.gd    CopilotMcpTools
    └── ui/
        ├── md3/                        Material 3 design system (tokens, scheme,
        │                               motion, icons, components)
        ├── copilot_theme.gd            CopilotTheme (static helpers)
        ├── copilot_dock.gd             CopilotDock
        ├── copilot_chat_view.gd        CopilotChatView
        ├── copilot_permission_card.gd  CopilotPermissionCard
        ├── copilot_provider_manager.gd CopilotProviderManager
        ├── copilot_provider_row.gd     CopilotProviderRow
        ├── copilot_provider_wizard.gd  CopilotProviderWizard
        ├── copilot_key_row.gd          CopilotKeyRow
        ├── copilot_key_editor.gd       CopilotKeyEditor
        ├── copilot_model_row.gd        CopilotModelRow
        ├── copilot_model_editor.gd     CopilotModelEditor
        └── copilot_settings_dialog.gd  CopilotSettingsDialog
```

All UI is built **in code** (no `.tscn` files) so there is no scene/script mismatch
as in the old version. `*.gd.uid` files are not committed manually (Godot generates
them automatically).

---

## 3. Data Flow of One Turn

```
User presses Send
  └─ CopilotDock → agent.send_user_message(text)
       ├─ (if needed) compaction → provider.complete() → store.apply_summary()
       ├─ editor_context.build() → appended to the user content
       ├─ store.record_user() + emit user_message_added
       └─ ReAct loop (max config.agent.max_steps):
            ├─ store.build_messages(system_prompt) + active tool schemas
            ├─ provider.stream_chat(...)  [non-blocking, await]
            │     ├─ stream_delta → emit assistant_delta (UI typing)
            │     └─ stream_finished(result) → content + tool_calls
            ├─ no tool_calls → final message: record, emit assistant_message_completed, DONE
            └─ with tool_calls:
                 ├─ record_assistant_step
                 └─ for each tool_call:
                      ├─ catalog.action_and_target(tool, args) → action, target
                      ├─ permissions.check(action, target) → verdict
                      │    ├─ DENY  → error result, emit notice
                      │    ├─ ASK   → emit permission_requested (full dict)
                      │    │          await permission_resolved (dict)
                      │    │          → allow: store session/persist rule if requested
                      │    │          → deny: error result
                      │    └─ ALLOW → pass through
                      ├─ emit tool_started
                      ├─ spawn_subagent → CopilotSubagent.run() (children use agent permissions)
                      │  otherwise      → await tool_router.execute(tool, args)
                      ├─ emit tool_finished
                      └─ store.record_tool()
```

Contracts worth noting:

- One turn = one "generation" (`_generation: int`). `cancel_turn()` increments the
  counter; provider callbacks arriving afterwards are ignored (stale guard).
- Only one `permission_requested` may be pending at a time (the loop blocks while waiting).
- `tool_router.execute()` is a **coroutine** (it contains `await` for shell/MCP), so
  callers must `await` it — even for tools that are synchronous.
- All file changes go through `CopilotPaths`/the tools; the agent never touches
  `FileAccess` directly.

### CopilotAgent signals (UI contract)

| Signal | Arguments | When |
| --- | --- | --- |
| `state_changed` | `state: String` | On every state transition |
| `user_message_added` | `text: String` | After the user step is recorded |
| `assistant_delta` | `delta: String` | Per streamed token |
| `assistant_message_added` | `text: String` | Non-streamed/instant assistant message |
| `assistant_message_completed` | `text: String` | Streaming finished (final text) |
| `tool_started` | `name: String, args: Dictionary` | Before execution |
| `tool_finished` | `name: String, result: Dictionary` | After execution |
| `permission_requested` | `request: Dictionary` | ASK verdict (see §6) |
| `permission_resolved` | `resolution: Dictionary` | User decided; the agent awaits this signal |
| `notice` | `message: String` | Non-fatal info/error, shown in the chat |
| `session_changed` | `id: String, title: String` | Session created or loaded |
| `turn_finished` | — | Turn finished/failed/canceled; UI reset |
| `memory_compacted` | `summary: String` | After a successful compaction |

States: `idle`, `thinking`, `streaming`, `running_tools`, `waiting_permission`, `compacting`.

---

## 4. Configuration (settings.json v2)

New location: **`user://godot-copilot/settings.json`**.
Rationale for moving from `res://.godot/.copilot/config/settings.json`: `user://` is
not committed to version control, is stable on all platforms (including Android),
and is not deleted when `.godot/` is cleaned. Automatic migration is performed by
`CopilotConfig._migrate_legacy()`.

When no settings file exists at the new location, the loader tries the legacy
locations in this order:

1. `user://godot_copilot/settings.json` (legacy v2, pre-rename)
2. `user://godot_copilot/settings.backup.json` (legacy v2 backup)
3. `res://.godot/.copilot/config/settings.json` (legacy v1)

```jsonc
{
  "schema": 2,
  "active_model": "OpenAI/gpt-4o",           // "provider/model_key"
  "providers": {
    "OpenAI": {
      "kind": "openai",                       // openai | anthropic
      "base_url": "https://api.openai.com/v1",
      "api_type": "chat_completions",         // chat_completions | responses
      "model_prefix": "",                     // optional, prepended to the model name
      "key_strategy": "round_robin",          // round_robin | sticky_count
      "sticky_count": 3,                      // only for sticky_count
      "keys": [
        { "label": "Key 1", "value": "sk-...", "enabled": true }
      ],
      "models": {
        "gpt-4o": {
          "name": "GPT-4o",
          "modalities": { "input": ["text", "image"], "output": ["text"] },
          "reasoning": true,                  // optional
          "disabled": true                    // optional, enabled by default
        }
      }
    }
  },
  "permissions": {
    "preset": "sandbox",                      // sandbox | review | turbo
    "deny":  ["read_file(res://.godot/*)"],
    "ask":   [],
    "allow": ["read_file(res://)"]
  },
  "memory": {
    "auto": true, "prune": true, "mode": "text",
    "model": "",                              // empty = active model
    "max_steps": 12, "tail_size": 4
  },
  "agent": {
    "max_steps": 8,
    "subagents": { "explorer": { "model": "", "mode": "read_only" } }
  },
  "mcp": { "servers": {} }
}
```

Compatibility notes (read and converted during v1→v2 migration):

- `provider` → `providers`; `options.baseURL` → `base_url`; `options.apiKeys[]` →
  `keys[]` (`active` → `enabled`); `options.round_robin`/`sticky_limit` →
  `key_strategy`/`sticky_count`; `options.prefix` → `model_prefix`;
  `options.checkApiKey` **removed** (converted into a regular key if present).
- `enableTerminalSandbox: true` → `permissions.preset = "sandbox"`; `false` → `"review"`.
- `compaction.*` → `memory.*`; `max_react_steps` → `agent.max_steps`;
  `agent.<name>` (v1 subagent) → `agent.subagents.<name>`.
- `mcpServers` → `mcp.servers`.

Session storage: **`user://godot-copilot/sessions/<session_id>.json`**.
Legacy sessions are migrated when the new sessions directory is empty:

1. `user://godot_copilot/sessions/` (legacy v2, pre-rename)
2. `res://.godot/.copilot/conversations/` (legacy v1)

Files are copied, not moved, so old data survives an addon downgrade.

### CopilotPaths (utility API)

```gdscript
CopilotPaths.USER_ROOT       # "user://godot-copilot"
CopilotPaths.SETTINGS_FILE
CopilotPaths.SETTINGS_BACKUP_FILE
CopilotPaths.SESSIONS_DIR
CopilotPaths.TEMP_DIR
CopilotPaths.LEGACY_V2_ROOT                    # "user://godot_copilot" (pre-rename)
CopilotPaths.LEGACY_V2_SETTINGS_FILE
CopilotPaths.LEGACY_V2_SETTINGS_BACKUP_FILE
CopilotPaths.LEGACY_V2_SESSIONS_DIR
CopilotPaths.LEGACY_V1_SETTINGS_FILE           # "res://.godot/.copilot/config/settings.json"
CopilotPaths.LEGACY_V1_SESSIONS_DIR            # "res://.godot/.copilot/conversations"
CopilotPaths.ensure_dir(path) -> bool
CopilotPaths.read_text(path) -> String              # "" on failure
CopilotPaths.write_text(path, text) -> Error        # creates directories automatically
CopilotPaths.temp_dir() -> String                   # for shell/MCP output
```

---

## 5. Providers

`CopilotProvider` (abstract, extends `Node`) is the single gateway to HTTP.

```gdscript
signal stream_delta(text: String)
signal stream_finished(result: Dictionary)
# result = { success: bool, content: String, tool_calls: Array, error: String }

func setup(config: CopilotConfig, provider_name: String) -> void
func stream_chat(messages: Array, tools: Array, model_override := "") -> void
func complete(messages: Array, tools: Array = [], model_override := "") -> Dictionary
func cancel() -> void
```

- Internal message format = OpenAI chat format (`role/content/tool_calls/tool_call_id/name`).
  Providers are responsible for converting it to their own API format.
- `CopilotOpenAiProvider`: `chat_completions` (messages passed through) and `responses`
  (converted to input items + function tools). Tolerant stream parser: plain SSE `data:`,
  Ollama NDJSON, `response.*` events from the Responses API, Anthropic `delta.text`
  (legacy format).
- `CopilotAnthropicProvider`: native Messages API — `x-api-key` + `anthropic-version`,
  `max_tokens` required (default 8192), system prompt split into the `system` parameter,
  tool schema `{name, description, input_schema}`, tool results converted into
  `tool_result` blocks inside `user` messages.
- `CopilotProviderFactory.create(config, provider_name) -> CopilotProvider` picks the
  implementation from `providers.<name>.kind`.
- Key selection per request: `config.next_api_key(provider_name)` — round-robin with
  `sticky_count`, or the first enabled key for the sticky strategy.
- Non-2xx error detection already produces clean messages (`HTTP <code>: <provider message>`).

Catalog details and troubleshooting live in [PROVIDERS.md](PROVIDERS.md).

---

## 6. Permission Engine (CopilotPermissions)

Verdicts: `ALLOW`, `ASK`, `DENY`. Evaluation precedence: **DENY > ASK > ALLOW**.

```
check(action, target) -> { "verdict": int, "rule": String, "reason": String }
```

1. `deny` rules are checked first; on match → DENY.
   Implicit: denying `read_file` also blocks `write_file` on the same target.
2. `ask` rules → ASK.
3. `allow` rules + session grants → ALLOW.
   Implicit: allowing `write_file` also allows `read_file`.
4. Preset fallback:
   - `turbo` → ALLOW everything.
   - `sandbox` → inside the project ALLOW, outside the project ASK.
   - `review` → ASK everything.

Known actions: `read_file`, `write_file`, `command`, `read_url`, `http_request`,
`mcp`, `subagent`. Rule format: `action(target)`. `command` rules support prefixes
(`git` matches `git status`) and `regex:<pattern>`; commands containing dangerous
shell constructs (`|`, `&&`, `;`, `$(` …) match only exactly.

`CopilotPermissions` also provides the following for the UI:

- `describe(action, target) -> {title, question, badge, outside}` — permission card text.
- `scope_options(action, target) -> Array[Dictionary]` — "always allow" options
  (exact target → directory/prefix/domain → `(*)`), each option `{label, rule, description}`.
- Session grants: `add_session_grant(rule)` / `clear_session_grants()`
  (reset when switching/creating a session).

`permission_requested` carries this dict:

```gdscript
{
  "id": String,            # unique per request
  "action": String,
  "target": String,
  "tool_name": String,
  "args": Dictionary,
  "title": String,
  "question": String,
  "outside": bool,
  "scope_options": Array[Dictionary]
}
```

The UI responds with `agent.resolve_permission(id, allowed, remember, scope_index)`.

---

## 7. Tool System

- `CopilotToolCatalog` holds the JSON-schema definitions of all tools plus two static
  helpers: `core_names()` and `action_and_target(tool_name, args) -> {action, target}`.
- `CopilotToolRouter` holds the tool instances, executes them, and manages
  **JIT activation**: only `core_names()` + already activated tools are sent to the
  model. The `search_available_tools(query)` tool searches the catalog and activates
  matching tools for the next step (saves tokens on small models).
- Core tools: `read_file`, `write_file`, `list_files`, `glob_files`, `grep_search`,
  `execute_command`, `read_url`, `mcp_call_tool`, `search_available_tools`.
- JIT tools: `edit_file_lines`, `patch_file`, `delete_file`, `http_request`,
  `inspect_scene_tree`, `get_selected_nodes`, `add_node`, `delete_node`,
  `instantiate_scene`, `set_node_property`, `attach_script`, `get_project_setting`,
  `set_project_setting`, `get_open_scripts`, `rescan_filesystem`, `mcp_list_tools`,
  `spawn_subagent`.

Key implementation points:

- **Non-blocking shell.** `execute_command` uses `OS.create_process()` (not
  `OS.execute`, which blocks the editor); output is redirected to a temp file
  (`CopilotPaths.temp_dir()`), then polled with `OS.is_process_running()` per frame
  with a timeout; the exit code is taken from a `__EXIT_CODE__` marker echoed after
  the command. Output is truncated to ±20,000 characters.
- **Web**: `read_url` = simple GET; `http_request` = method + headers + body
  (used for APIs/webhooks). Timeout 15 seconds, body truncated to 10,000 characters.
- **Scene tools** use `EditorUndoRedoManager` (`editor_plugin.get_undo_redo()`) so all
  node changes can be undone by the user.
- **`spawn_subagent`** is not executed by the router; the agent handles it itself (see §8).

Default action mapping (used by the permission engine):

| Tool | action | target |
| --- | --- | --- |
| `read_file`, `list_files`, `glob_files`, `grep_search` | `read_file` | path/dir |
| `write_file`, `edit_file_lines`, `patch_file`, `delete_file` | `write_file` | path |
| `execute_command` | `command` | command line |
| `read_url` | `read_url` | domain |
| `http_request` | `http_request` | domain |
| `mcp_list_tools`, `mcp_call_tool` | `mcp` | `server/tool` |
| `spawn_subagent` | `subagent` | `name:mode` |
| scene/editor ops | `write_file` / `read_file` | `res://` |

---

## 8. Subagent

`CopilotSubagent` runs an isolated ReAct loop (its own history, non-streaming).

- `read_only` mode: read-only tools only — it never raises a permission prompt.
  If evaluation yields ASK, the subagent immediately receives a "permission required"
  error and continues (it does not hang).
- `full_access` mode: permission requests are **forwarded to the main agent** through
  the `permission_requester` callable (the agent awaits the user's permission as
  usual). This fixes the security hole in the old version that auto-allowed ASK.
- The `spawn_subagent` tool is unavailable to subagents (no recursion).
- Model: `agent.subagents.<name>.model` when set, otherwise the active model.
- Result: `{success, agent_name, type, steps_taken, tools_used, result|error}`.

---

## 9. Session & Memory

`CopilotSessionStore` manages `user://godot-copilot/sessions/`.

- One session = one JSON file: `{id, title, created_at, updated_at, model, summary,
  compaction: {compacted_up_to_step, total_compactions}, trajectory: [...]}`.
- Trajectory steps: `user` (with `display` for the UI), `assistant` (with `tool_calls`),
  `tool` (with `tool_call_id`, `name`, `result`).
- The title is generated automatically from the first 32 characters of the first user message.
- **Compaction**: when the active trajectory >= `memory.max_steps`, old steps
  (outside `tail_size`) are summarized by the model (summarizer prompt, `text` mode);
  the summary is stored in `summary` and the steps are marked `compacted`. `native`
  mode = no summary (let the provider handle the context window).
- **Pruning**: old tool outputs are replaced with `[Old tool result content cleared]`
  and very large outputs are truncated to 1,500 characters while `memory.prune` is
  enabled — only when building LLM messages; the original data stays in the trajectory.
- `build_messages(system_prompt)` assembles: system prompt → summary (if any) →
  messages after `compacted_up_to_step`.
- `trim_after_last_user()` drops the trailing exchange (the last `user` step and
  everything after it) and returns its display text — used by Retry; it refuses
  when that step is already covered by compaction.
- Legacy session migration (`user://godot_copilot/sessions/` from v2 and
  `res://.godot/.copilot/conversations/` from v1) is copied to the new location the
  first time `CopilotConfig` is loaded and the new directory is still empty.

---

## 10. Editor Integration

`plugin.gd` (`@tool extends EditorPlugin`):

1. `_enter_tree()`:
   - `CopilotConfig.new()` (runs migration when needed).
   - Build `CopilotDock`, attach it to the right dock:
     - **Godot 4.7+**: `ClassDB.class_exists("EditorDock")` → instantiate `EditorDock`
       via `ClassDB.instantiate("EditorDock")`, set `title/icon_name/default_slot/
       available_layouts/dock_shortcut`, add the dock as a child, then call `add_dock(dock)`.
       All properties are set through the `_apply_if_supported()` helper to stay safe
       across versions.
     - **Fallback (<4.7)**: `add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)`.
   - `Project > Tools >` menu:
     `"Godot Copilot: Provider Manager…"`, `"Godot Copilot: Settings…"`,
     `"Godot Copilot: Focus Chat"`.
2. `_exit_tree()`: remove menus, detach the dock (`remove_dock` / `remove_control_from_docks`),
   `queue_free()` all child dialogs.
3. `_get_plugin_icon()`: `assets/icons/copilot.svg` if present, else the `Terminal` icon.

The dialogs (Provider Manager & Settings) are created lazily on first open and attached
to `EditorInterface.get_base_control()` so they can overlay the entire editor.

---

## 11. Error Handling, Cancel, & Robustness

- Provider error → `stream_finished` (success `false`) → the agent emits `notice` +
  `turn_finished`; the state returns to `idle`.
- `cancel_turn()`:
  - cancels the provider (`provider.cancel()`), increments `_generation`,
  - resolves the pending permission as "denied" so the `await` does not hang,
  - emits `turn_finished`.
- `retry_last_turn()`: trims the trailing exchange via
  `store.trim_after_last_user()` and re-sends the user text through
  `send_user_message()`; the dock rebuilds the chat from the trajectory.
- All async callbacks check `_generation` before changing state.
- All UI node accesses from signals use at least an `is_instance_valid()` guard.
- No `push_error` that could kill the plugin; errors are shown as notices or returned
  as `{"success": false, "error": ...}` from the tool.

---

## 12. Verification (Without Running Godot)

Because the development environment has no Godot binary, quality is maintained with:

1. **Symbol consistency grep** across files (`CopilotConfig.`, `CopilotTheme.`,
   `CopilotPaths.`, signal names) before finishing.
2. **API checklist** for every 4.7 API used (`EditorDock`, `add_dock`,
   `remove_dock`, `ClassDB.instantiate`, `OS.create_process`, `RichTextLabel.add_text`).
3. **Manual smoke test by the user** in Godot 4.7:
   - Enable the plugin → the dock appears on the right; `Alt+Shift+C` focuses it.
   - Provider Manager: add preset + custom providers, add a key, test the key,
     import models, select the active model.
   - Send a prompt → streaming appears; the `read_file` tool runs; `write_file` triggers
     the permission card; "Allow + Remember" persists the rule.
   - Disable the plugin → the dock disappears without errors; enable it again → the
     config persists.
   - Check that `user://godot-copilot/settings.json` and `sessions/` contain data.

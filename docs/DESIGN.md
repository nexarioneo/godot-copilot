# DESIGN.md — Godot Copilot Visual Design

This document covers **visual/UI design exclusively**: appearance, layout, colors, icons, and interaction patterns.
For the technical architecture (classes, data flow, config schema) see [ARCHITECTURE.md](ARCHITECTURE.md).
For file/class naming rules see [CONVENTIONS.md](CONVENTIONS.md).

Core principle: **"GodotStyle"** — the plugin must look and feel like a native part of the Godot Editor,
not a foreign application layered on top of it.

---

## 1. Design Principles

1. **Native first.** All colors, icons, and styleboxes come from the editor theme
   (`EditorInterface.get_editor_theme()`), not from a hardcoded palette.
   Theme type names used: `"Editor"` (colors) and `"EditorIcons"` (icons).
2. **No custom look.** No custom fonts, no custom skins, no excessive animations.
   Use stock `Button`, `OptionButton`, `PanelContainer`, `Tree`, `ItemList` as they are.
3. **Consistent with the editor.** Dialogs use `AcceptDialog`/`ConfirmationDialog`
   (native title, OK/Cancel buttons); popups use `PopupMenu`.
4. **Icons first, text as support.** Action buttons use `EditorIcons` icons with
   `tooltip_text`; when an icon is unavailable (different Godot versions), fall back
   to a text label.
5. **Version differences are tolerated.** All color/icon access must have a fallback
   (see `CopilotTheme`), because icon/theme names can differ between Godot versions.

---

## 2. Dock Location: Right Side, Next to the Inspector

The chat panel is **no longer** a bottom panel. The panel lives in the right dock:

| `EditorDock` property | Value | Rationale |
| --- | --- | --- |
| `title` | `"Copilot"` | Dock tab name |
| `icon_name` | `&"Terminal"` | Tab icon from `EditorIcons` |
| `default_slot` | `DOCK_SLOT_RIGHT_BL` (5) | Empty in the default layout, directly below the Inspector |
| `available_layouts` | `DOCK_LAYOUT_ALL` (7) | The user can move it freely (vertical/horizontal/floating) |
| `dock_shortcut` | `Alt+Shift+C` | Opens/focuses the dock; consistent with Godot's bottom-panel shortcut convention (Alt modifier) |

The editor remembers the dock position across sessions automatically (stored in the editor layout).
On Godot < 4.7 (no `EditorDock`) the plugin falls back to `add_control_to_dock(DOCK_SLOT_RIGHT_BL, panel)`.

---

## 3. Copilot Dock Layout

```
┌──────────────────────────────────────────────────────┐
│ [Sessions ▾] [+] [−]    [Tools] [CryptoKey] [Clear]  │  header row
├──────────────────────────────────────────────────────┤
│                                                      │
│  You                                                 │  message card (user)
│  ┌────────────────────────────────────────────────┐  │
│  │ please create player.gd with basic movement    │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  Copilot                                             │  message card (assistant)
│  ┌────────────────────────────────────────────────┐  │
│  │ Sure, I will create the script...              │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  [Config] read_file res://project.godot           OK │  tool row
│  [Config] write_file res://player.gd              OK │  tool row
│                                                      │  ← CopilotChatView (scroll)
├──────────────────────────────────────────────────────┤
│  [Lock] Permission required: write_file(res://...)   │  permission card
│  [Scope ▾]  [ ] Remember this choice                 │
│  [Allow] [Deny]                                      │
├──────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────┐  │
│  │ Type a message... (Enter send, Shift+Enter)    │  │
│  └────────────────────────────────────────────────┘  │
│  [Send] [Stop]                                       │
├──────────────────────────────────────────────────────┤
│  ● Ready                         [provider/model]    │  status bar
└──────────────────────────────────────────────────────┘
```

Components (all built in GDScript code, no `.tscn`):

- **Header row** — `CopilotSessionBar` (part of `copilot_dock.gd`):
  - `OptionButton` session list (title + step count).
  - `Add` icon button (new session) and `Remove` icon button (delete the active
    session), with tooltips.
  - Spacer, then icon buttons: `Tools` (Settings dialog), `CryptoKey` (Provider
    Manager), `Clear` (clear the chat view).
- **CopilotChatView** — `ScrollContainer` holding a `VBoxContainer` of message cards.
- **CopilotPermissionCard** — inline card above the composer (not a modal overlay).
- **Composer** — `TextEdit` (min 3 lines) + text buttons `"Send"` / `"Stop"`.
- **Status bar** — left status label (agent state + color) and right model label.

---

## 4. Message Cards (CopilotChatView)

Each message is its own widget (`PanelContainer` > `VBoxContainer`), not one big
`RichTextLabel`. The goals: per-card streaming, stable auto-scroll, and model/user
content that is **never** parsed as BBCode (anti-injection).

Structure of one card:

```
PanelContainer (StyleBoxFlat: bg "dark_color_2", radius 4, thin border)
└─ VBoxContainer
   ├─ Label        — role header ("You" / "Copilot" / tool name), small font, role color
   └─ RichTextLabel — message body (fit_content = true, bbcode_enabled for internal markup only)
```

Role coloring rules (all from the Editor theme, fallback to Godot default colors):

| Role | Color source | Fallback |
| --- | --- | --- |
| User | `accent_color` | `#5b9bd5` |
| Copilot | `font_color` | `#e0e0e0` |
| Tool | `warning_color` for the name, `success_color`/`error_color` for the status | `#d4a24c` |
| Notice/system | `font_placeholder_color`, italic | `#8a8f98` |
| Permission (permission card) | `warning_color` border | `#d4a24c` |

Dynamic content (user text, model text, tool output) is inserted via `add_text()`
so characters such as `[b]` in model output render literally.
Internal markup (tool names, status) uses safe BBCode tags: `color`, `b`, `i`, `code`, `lb`.

### Tool row

One compact line per tool call, created inline by `CopilotChatView`:

```
[icon] tool_name(brief args)  •  status
```

- Tool name: `warning_color`; arguments truncated to ~60 characters with `…`.
- Status: `running` (indeterminate `ProgressBar` spinner), `OK` (`success_color`),
  `Failed` (`error_color`).
- Output details are not shown in full; tooltips/click-through are not required (YAGNI).
- Tool rows from a subagent are prefixed with `agent_name → tool_name`.

### Auto-scroll

Scrolls to the bottom automatically **only if** the user is at the bottom (pinned to bottom).
If the user scrolls up during streaming, the view does not force downward scrolling;
once the user returns to the bottom, auto-scroll resumes.

---

## 5. Permission Card (CopilotPermissionCard)

Replaces the modal overlay + separate "always allow" dialog. One card, one decision:

```
┌───────────────────────────────────────────────────┐
│ [Lock] Permission required: write_file            │
│    File: res://scripts/player.gd [Outside Project]│
│    Scope:  [This target only ▾]                   │
│    [ ] Remember for this session                  │
│    [ Allow ]  [ Deny ]                            │
└───────────────────────────────────────────────────┘
```

Design details:

- Badge `[Workspace]` (`success_color`) or `[Outside Project]` (`error_color`) marks
  the target position relative to the project.
- The "Scope" `OptionButton` is filled from `CopilotPermissions.scope_options()`; the
  first choice is always "this target only", followed by prefix/directory/domain
  scopes, and finally `(*)`.
- "Remember" checkbox → when checked, the rule is stored permanently in the config
  (`allow` list); otherwise the rule applies only to the active session (session grant).
- Header icon: `Lock` (fallback `Lock`), no separate dialog.
- The card is hidden by default; it appears only while the agent waits for a decision.
  When `permission_resolved` is received, the card is hidden again.
- Button text uses explicit actions: "Allow" / "Deny" (not "OK/Cancel").

---

## 6. Composer & Status Bar

- `PlaceholderText`: "Type a message... (Enter to send, Shift+Enter for a new line)".
- Enter sends (unless Shift is held); the event is passed to `accept_event()`.
- The Send button is disabled while the agent is busy; the Stop button is enabled
  only while busy.
- Focus returns to the composer automatically after a turn finishes.
- Status: `● <state>` with color — Ready (`success_color`), Thinking/Running
  (`warning_color`), Waiting for permission (`warning_color`), Streaming
  (`accent_color`), Error (`error_color`), Canceled (`font_disabled_color`).
- The right label shows the active `provider/model` (e.g. `OpenAI/gpt-4o`) with
  `font_placeholder_color`.

---

## 7. Provider Manager (dialog)

Large `AcceptDialog` (± 900×560), opened from the `CryptoKey` button in the dock and
from the menu `Project > Tools > Godot Copilot: Provider Manager...`.

```
┌───────────────────────────────────────────────────────────────┐
│ Godot Copilot — Provider Manager                              │
├──────────────────────┬────────────────────────────────────────┤
│ [+ Add ▾] [Delete]   │  [Icon] OpenAI                         │
│                      │  https://api.openai.com/v1   [↗ Key]   │
│ ┌──────────────────┐ │ ┌────────────────────────────────────┐ │
│ │ [O] OpenAI       │ │ │ Keys │ Models │ Advanced           │ │
│ │     2 keys OK    │ │ ├────────────────────────────────────┤ │
│ ├──────────────────┤ │ │ [x] Key 1  [Test]  [↑][↓][Edit][✕] │ │
│ │ [●] Anthropic    │ │ │ [x] Key 2  [Test]  ...             │ │
│ ├──────────────────┤ │ │ [+ Add Key]                        │ │
│ │ [D] DeepSeek     │ │ └────────────────────────────────────┘ │
│ └──────────────────┘ │ (provider detail, TabContainer)        │
│ (provider list)      │                                        │
├──────────────────────┴────────────────────────────────────────┤
│                                            [Close]            │
└───────────────────────────────────────────────────────────────┘
```

Design details:

- **Provider list on the left**: `CopilotProviderRow` (not an `ItemList`) so it can
  host icon badges. Badge rules:
  - Mono logo (OpenAI, Anthropic, Groq, etc.) → rounded white badge 28×28 (black icon).
  - Colored logo → `TextureRect` directly.
  - No logo → initial-letter badge (first 2 letters, uppercase).
  - Small status under the name: number of enabled keys (`2 keys`), or `No keys yet`
    with `font_placeholder_color`.
- **Add button**: `MenuButton` with preset items (from `CopilotProviderPresets`) then
  a separator + "Custom Provider…" (opens `CopilotProviderWizard`).
- **Provider delete button**: `Remove` icon, small `ConfirmationDialog` confirmation;
  the active provider cannot be deleted without an explicit warning.
- **Right pane** uses a 3-tab `TabContainer`:
  1. **Keys** — list of `CopilotKeyRow`: enabled checkbox, label, masked value
     (`sk-…abc1`; `ShowPassword` eye button to reveal), `Reload` (test) button,
     test status label, `ArrowUp`/`ArrowDown` for ordering, `Edit`, `Remove`.
     Below the list: `+ Add Key`, `Test All`, `Stop`, and key strategy controls
     (round-robin `CheckButton` + "sticky count" `SpinBox` shown only while enabled).
  2. **Models** — list of `CopilotModelRow`: model key label, enabled/disabled toggle,
     delete button; a header with `Import from /models`, `+ Add Model`,
     `Disable All`, `Enable All`. Above the list there is an **Active model** picker
     (`OptionButton`) that selects the chat model. Disabled models are rendered last
     and dimmed.
  3. **Advanced** — read-only `kind` (openai/anthropic), `base_url`, `api_type`
     (`chat_completions`/`responses`, kind openai only), `model_prefix`, and an
     "Open API key page" button (`ExternalLink`).
- **Wizard** (`CopilotProviderWizard`, `ConfirmationDialog`): fields Name, Kind
  (OptionButton), Base URL, API Type, Model Prefix, first API Key (optional), first
  Model ID (optional), "Get API Key" link. Validation: name required and unique,
  base URL required.
- **Key/model editors** (`CopilotKeyEditor`, `CopilotModelEditor`): small add/edit
  dialogs instead of inline editing, to keep list state simple.
- Per-key test result indicators: `Failed` (`error_color`), `OK` (`success_color`),
  `…` while testing (`accent_color`), `queued` (`font_placeholder_color`).

---

## 8. Settings Dialog

`CopilotSettingsDialog` (`AcceptDialog`, minimum ± 560×480) with a `TabContainer`:

1. **Permissions** — preset choice (`OptionButton`):
   - `Sandbox` — free inside the project, permission required outside the project.
   - `Review` — always ask for permission.
   - `Turbo` — automatic unless a Deny rule matches.
   Below it the rule editor: a `OptionButton` list selector (`Deny` / `Ask` / `Allow`,
   with rule counts), a list of `action(target)` rules + an add-rule input + a delete
   button per rule.
2. **Memory** — auto-compact checkbox, prune tool output, mode choice (text/native),
   compaction model (LineEdit, empty = active model), max steps, tail size (SpinBox).
3. **Agent** — max ReAct steps (SpinBox) and the subagent override list (name + model
   choice + delete button).

All controls use native widgets; there is no custom styling besides the accent colors.

---

## 9. Icons (EditorIcons) & Fallback

All icons and colors are fetched through `CopilotTheme`, which queries the editor
theme first, then the context node's theme via dynamic `has_theme_icon()` /
`get_theme_icon()` checks (any `Node` works — both `Control` and `Window` callers),
and finally falls back to plain text. Icon names used (verified present in Godot 4.7):

| Need | Icon | Fallback |
| --- | --- | --- |
| Dock tab | `Terminal` | — |
| Settings | `Tools` | text `Config` |
| Provider manager | `CryptoKey` | `Key` → text `Key` |
| New session | `Add` | `+` |
| Delete session/item | `Remove` | `✕` |
| Clear chat | `Clear` (then `Eraser`) | text `⌫` |
| Send | — (text button "Send") | — |
| Stop | `Stop` | text `■` |
| Test/reload | `Reload` | text `↻` |
| Edit | `Edit` | text `✎` |
| Reveal key | `ShowPassword` | text `Show` |
| Move up/down | `ArrowUp` / `ArrowDown` | text `↑` / `↓` |
| Permission | `Lock` | — (icon omitted when unavailable) |
| Update/import | `Download` | text `Import` |
| Tool/key status | `StatusSuccess` / `StatusError` | text `OK` / `Failed` |
| Info | `Info` | text `Info` |
| Open external | `ExternalLink` | text `↗` |

`CopilotTheme.icon(control, names: PackedStringArray, fallback_label: String)` handles
the ordered lookup; buttons without an icon use the fallback text instead of a broken glyph.

---

## 10. Interaction & Accessibility

- All icon buttons **must** have `tooltip_text`.
- Status must not be conveyed by color alone: always pair it with text/icon.
- Dialogs must not lock the dock: the inline permission card stays visible while the
  user opens other dialogs.
- `focus_mode = FOCUS_NONE` for decorative icon buttons in the chat (so Tab keeps
  focusing the input), but `FOCUS_ALL` for form controls in dialogs.
- Composer minimum height 64 px; dock minimum width is not forced (follows the editor layout).
- When a session is reloaded, the chat view is rebuilt from the trajectory (no animation).

---

## 11. Visual Review Checklist

- [ ] No hardcoded colors except fallbacks in `CopilotTheme`.
- [ ] All icons go through `CopilotTheme.icon()` (with fallback).
- [ ] The dock appears on the right (slot `RIGHT_BL`), can be moved, and the `Alt+Shift+C` shortcut works.
- [ ] User vs Copilot message cards are easy to distinguish; model content is not executed as BBCode.
- [ ] Tool rows have a success/failure status + theme colors.
- [ ] The permission card appears inline, scope options match the action, Allow/Deny buttons are clear.
- [ ] Provider manager: add/delete/test for keys & models works, statuses are user-friendly.
- [ ] Auto-scroll only while pinned to the bottom.

# DESIGN.md — Godot Copilot Visual Design

Status: this document specifies the **new design system** (Material 3 based, own
components). Implementation rolls out in `src/ui/md3/` and the existing UI classes
are migrated progressively. Token data (colors, type, shape, motion, component
specs) lives in [MATERIAL3.md](MATERIAL3.md).

For technical architecture (classes, data flow, config schema) see
[ARCHITECTURE.md](ARCHITECTURE.md). For naming rules see [CONVENTIONS.md](CONVENTIONS.md).

---

## 1. Design Concept

### 1.1 Core principle

**Own design language, implemented as standalone components.** The plugin no longer
tries to mimic the Godot editor theme. Instead it ships its own design system:

1. **Standalone components derived from built-in controls.** Every visible widget is
   a dedicated class derived from a stock Godot control (`extends Button`,
   `extends PanelContainer`, `extends LineEdit`, ...) that styles and animates itself.
   The plugin UI is composed only of these components.
2. **Material 3 as the reference.** Component geometry, colors, typography, shape,
   elevation, motion, and states follow the M3 specs in [MATERIAL3.md](MATERIAL3.md).
   The chosen configuration is fixed in section 2.
3. **Self-contained styling.** Components compute styleboxes, fonts, colors, and
   state layers from the plugin's own scheme object. They never read design values
   from the editor theme, so the look is identical in every editor theme and Godot
   version.
4. **Tokens over raw values.** Components consume named tokens
   (`CopilotMd3Tokens`, `CopilotMd3Scheme`); raw hex values appear only in the token
   tables. This keeps the system consistent and re-themable.
5. **Editor integration kept to the minimum.** The plugin still integrates with the
   editor for: light/dark detection (2.1), keyboard shortcuts, dock placement, and
   fallback glyphs when an icon asset is missing. Nothing else.
6. **Desktop density.** M3 measurements in `dp` map 1:1 to pixels; a small set of
   compact adjustments applies to the narrow dock (section 3.8). Dialogs use regular
   M3 sizes.
7. **Accessibility by default.** Contrast, target sizes, state visibility, and
   no-color-only status follow section 13.
8. **Safety rules carried over.** Model/user content is inserted with `add_text()`
   (never parsed as BBCode); auto-scroll stays pinned-to-bottom aware.

### 1.2 What "own components" means in practice

- New library folder: `src/ui/md3/` with token, scheme, motion, and component files
  (`CopilotMd3Button`, `CopilotMd3Card`, ...). See section 4 for the catalog.
- Existing UI classes (`copilot_dock.gd`, `copilot_chat_view.gd`,
  `copilot_permission_card.gd`, dialogs) are rewritten to **use** the library; they
  keep their responsibilities and signals, not their styling code.
- All UI remains built in GDScript (no `.tscn`).
- `CopilotTheme` (editor-theme color/icon accessors) is retired during rollout; only
  the light/dark detection helper and the icon fallback remain (section 14).

---

## 2. Decided Configuration

Decided 2026-10-17:

| Aspect | Decision | Notes |
| --- | --- | --- |
| Theme mode | **Follow the editor light/dark theme** | Auto-detect at dock creation; manual override planned in Settings. |
| Color scheme | **Material 3 baseline** (purple), light and dark | Values in MATERIAL3.md §3; no runtime palette generation. |
| Font | **Bundle Roboto** (Regular 400 + Medium 500) | UI text only; code/arguments use the editor monospace font. |
| Expressiveness | **Baseline M3 + expressive springs for key moments** | Key moments: message send settle, permission card appearing; everything else uses standard M3 curves. |
| Icons | **Curated Material Symbols (Rounded)** | ~40 symbols, bundled as single-color SVGs, tinted by token colors; editor icons as fallback. |

---

## 3. Foundation Usage

### 3.1 Modules (design-side contract)

| Module | Responsibility |
| --- | --- |
| `CopilotMd3Tokens` | Raw constants: color roles (light/dark + fixed), type scale, shape, elevation, states, motion, spacing |
| `CopilotMd3Scheme` | Resolves role names to `Color`; `light()` / `dark()` builders; detects editor light/dark; extension roles |
| `CopilotMd3Motion` | Durations, easings, spring curves, cubic-bezier sampler, tween helpers |
| `CopilotMd3Icons` | Bundled Material Symbols loader; editor-icon and text fallbacks |
| `CopilotMd3StateLayer` | Hover/focus/pressed/dragged overlay shared by interactive components |

Components must not hardcode colors, fonts, radii, or durations; they ask the
scheme/motion modules.

### 3.2 Color roles used by the plugin

| Area | Role |
| --- | --- |
| Dock background | `surface` |
| Header bar, status strip | `surface`, text `on-surface` / `on-surface-variant` |
| Message card (assistant) | `surface-container-high`, text `on-surface` |
| Message bubble (user) | `primary-container`, text `on-primary-container` |
| Tool row | `surface-container-low` + `outline-variant` border, title `on-surface`, meta `on-surface-variant` |
| Code / raw output block | `surface-container-lowest`, text `on-surface`, mono font |
| Permission card | `surface-container-low` + elevation 1; icon badge `tertiary-container` / `on-tertiary-container` |
| Scope chips | unselected: `outline-variant` border / `on-surface-variant`; selected: `secondary-container` / `on-secondary-container` |
| Buttons | per variant (MATERIAL3.md §9.1); destructive = `error` / `on-error` |
| Primary selection | `secondary-container` / `on-secondary-container` |
| Dividers | `outline-variant` |
| Dialogs | `surface-container-high`, text `on-surface` |
| Menus | `surface-container`, text `on-surface` |
| Snackbar | `inverse-surface` / `inverse-on-surface`, action `inverse-primary` |
| Tooltips (plain) | `inverse-surface` / `inverse-on-surface` |
| Disabled | content 38%, container 12% |

Semantic extension roles (not part of M3; same tone discipline as M3 roles, values
fixed in `CopilotMd3Tokens`):

| Role | Family | Used for |
| --- | --- | --- |
| `status-success` (+ container) | green | Ready state, tool OK, test passed |
| `status-warning` (+ container) | amber | Thinking/running, waiting for permission, outside-project chip is `error-container` instead |
| `status-info` (+ container) | blue | Neutral notices |
| `error` roles (M3) | red | Failures, destructive actions |

Status text never relies on color alone: a state dot or icon accompanies every
colored label (section 13).

### 3.3 Typography usage

| Element | Style |
| --- | --- |
| Dialog titles | headline-small (24) |
| Provider name (detail header), settings section titles | title-large (22) / title-medium (16) |
| Dock header title | title-small (14, medium) |
| List primary label (keys, models, sessions) | body-large (16) |
| List supporting text, provider URL, card meta | body-small (12) |
| Message body | body-medium (14) |
| Code, file paths inside meta lines, tool arguments | editor mono font, 12-13 |
| Buttons, chips, menu items | label-large (14, medium) |
| Tabs | title-small (14, medium) |
| Tooltips, badges, status strip, timestamps | label-medium / label-small |
| Permission card title | title-medium; body body-medium |

Tooltips and dense dock rows may step down one size (label-medium instead of
label-large) to fit the narrow dock; dialog contents always use the table above.

### 3.4 Shape usage

| Element | Corner |
| --- | --- |
| Buttons, icon buttons | full |
| Chips, segmented buttons | full / 8 (filter chips use 8 per spec, pill for segmented) |
| Text fields (outlined) | 4 |
| Composer input | full when single line; 24 when multi-line |
| Cards (message, permission, panels) | 12 |
| Message bubbles | 16, with 4 at the bottom corner nearest the sender edge |
| Dialogs | 28 |
| Menus | 4 |
| Snackbar, tooltips | 4 |
| Checkbox | 2 |

### 3.5 Elevation usage

| Element | Level |
| --- | --- |
| Dock, header, status strip, message cards, tool rows | 0 (flat, container tones carry depth) |
| Permission card | 1 |
| Menus | 2 |
| Dialogs, snackbar | 3 |

In dark mode, depth is expressed primarily through `surface` vs
`surface-container-*` tones; shadows stay subtle in both modes.

### 3.6 Motion usage

| Interaction | Motion |
| --- | --- |
| State layers (hover/focus/pressed) | fade 100ms short2, standard curve |
| Button press / shape feedback | 100ms standard |
| Message appears (send / receive) | fade + 8px rise, 300ms emphasized-decelerate |
| **Message send settle (key moment)** | expressive default spatial spring, 500ms (subtle overshoot) |
| Thinking indicator | circular progress, 4px stroke, ~1.4s continuous rotation |
| Streaming caret | 2x14 primary bar, 800ms opacity pulse |
| Tool row state change | 200ms standard (icon swap + label color) |
| **Permission card appear (key moment)** | fade + 12px rise + scale 0.98 to 1, expressive default spatial spring, 500ms |
| Dialog open | fade + scale 0.98 to 1, 300ms emphasized-decelerate |
| Menu open | fade + scale 0.95 to 1, 200ms emphasized-decelerate (M3 menus) |
| Snackbar enter / exit | enter: rise 300ms standard-decelerate; exit: fade+fall 200ms standard-accelerate |
| Scroll to bottom (auto-follow) | 200ms standard when user is pinned to bottom |

All key-moment springs degrade to the baseline curve when a reduce-motion setting
is enabled (planned in Settings).

### 3.7 State layers and focus

- Interactive components show a state layer in the component content color:
  hover 8%, focus 10%, pressed 10%, dragged 16% (MATERIAL3.md §8).
- Keyboard focus additionally draws a 2px primary ring with 2px offset; focus is
  always visible on form controls, and the chat composer keeps a visible focus
  state.
- Disabled components: no state layers, content 38%, container 12%, skipped by
  keyboard navigation.

### 3.8 Density and sizing

- `dp = px`, 1:1. No global scale factor in the first rollout.
- Compact adjustments for the dock: header bar 48px (M3 small app bar is 64px,
  reduced to fit dock tabs), chat message body body-medium, list rows inside the
  dock 48px one-line / 64px two-line (dialogs keep 56/72).
- Minimum interactive target 40x40px in the dock, 48x48px in dialogs; icon-only
  controls expose tooltips.

---

## 4. Component Library (`src/ui/md3/`)

General rules for every component in the library:

- Derived from a stock control; owns its styleboxes, fonts, and state layers.
- Scheme injected via a single `apply_scheme(scheme)` entry point (called by the
  parent UI when the dock builds or when light/dark changes).
- Emits the standard Godot signals of its base class; no custom signal contract
  changes for existing consumers.
- Keyboard accessible (focus mode, focus ring), tooltip-capable, RTL-ready layout
  (mirrored paddings via container properties where cheap).

### 4.1 CopilotMd3Button

- Base: `Button`. Variants: filled, tonal, outlined, text, danger (filled with
  `error`), elevated.
- Sizes: S default (40px, padding 16-24, icon 18), M (48px) for dialog primary
  actions; pill shape (corner full).
- States per MATERIAL3.md §9.1 + state layers §3.7.
- Used for: Send (filled, icon), Stop (tonal, icon), dialog actions (text inside
  dialogs per M3 dialog spec, filled for wizard primary), "Add key/model"
  (outlined), destructive confirm (danger), "Open API key page" (outlined + icon).

### 4.2 CopilotMd3IconButton

- Base: `Button`. Variants: standard (default), filled, tonal, outlined.
  Container 40x40, icon 24 (20 in dense rows).
- Used for: dock header actions (sessions, new session, settings, providers,
  clear), row actions (edit, delete, move up/down, reload, reveal, close), model
  import, stop testing.

### 4.3 CopilotMd3Chip

- Base: `Button` (toggle for filter chips). Assist and filter variants; height
  32, corner 8, label-large, optional leading icon 18.
- Used for: permission scope options (single-select filter chips), outside/inside
  project indicator (assist chip, error-container when outside), key/model status
  tags where text is needed.

### 4.4 CopilotMd3TextField

- Base: `LineEdit` with M3 geometry: outlined (`outline-variant` 1px border,
  2px primary on focus, corner 4) or filled (surface-container-highest with a
  bottom indicator turning primary/2dp on focus); fixed height (56 default, 48 in
  dialogs, 40 in menus), 16px horizontal padding, body-large text, placeholder.
- Used for: provider wizard fields, key/model editors, rule input, compaction
  model, search fields.

### 4.5 CopilotMd3Card

- Base: `PanelContainer`. Variants: elevated (container-low + level 1), filled
  (container-highest), outlined (surface + 1px outline-variant).
- Reusable composites override roles without new classes: `set_roles(fill_role,
  border_role, border_width, shadow_level)`, `set_padding(left, top, right,
  bottom)` and `set_corner_radii(top_left, top_right, bottom_right, bottom_left)`.
- Used for: permission card (elevated, via subclass), chat surfaces (user bubble,
  assistant card, notices), panel sections in dialogs.

### 4.6 CopilotMd3ListItem

- Base: `Button` (flat, full-row). Supports 1-line (48/56) and 2-line (64/72)
  layouts; leading visual (icon 24 or logo 28), title, supporting text, trailing
  widgets (icon buttons, switch, badge).
- States: hover/focus/pressed state layer on-surface; selected =
  `secondary-container` (also used to mark the active provider/model/session),
  disabled 38%.
- Used for: provider list, key rows, model rows, session list (menu), rule list,
  subagent list.

### 4.7 CopilotMd3Menu

- Base: `PopupPanel` with a `surface-container-high` panel (corner 4, elevation 2,
  8px padding) holding dense 48px `CopilotMd3ListItem` rows, an optional 40px
  outlined search field (searchable menus), `primary` check_circle for the current
  item, error-colored danger items, and 1px `outline-variant` separators with 8px
  margins. Keyboard: up/down/escape; the search field takes focus when present.
- The sessions menu lists `title  (N steps)` rows, checks the current session and
  appends a danger "Delete current session" item when a session is active.
- Used for: sessions menu, add-provider preset menu, active-model picker,
  subagent model picker, context menus.

### 4.8 CopilotMd3Tabs

- Base: `TabContainer` with per-instance overrides: transparent tab bar, 48px
  tab height, title-small labels, primary label on selected / on-surface-variant
  otherwise, 3px primary indicator along the bottom of the selected tab, 1px
  `outline-variant` line under the whole bar.
- Switching animates: the indicator slides between tab positions (250ms,
  emphasized-decelerate) and the incoming page fades in (200ms,
  standard-decelerate). The indicator is drawn by the component (the selected
  tab stylebox carries no bottom border so the two do not double up).
- Used for: provider manager (Keys / Models / Advanced), settings (Permissions /
  Memory / Agent).

### 4.9 CopilotMd3Dialog

- Base: borderless embedded `AcceptDialog`: the window frame is disabled and the
  dialog draws a single `surface-container-high` panel (corner 28, elevation 3,
  24px padding) with an in-panel title (headline-small, on-surface) at the
  top-left, content margins per M3 dialog (title-to-body 16, body-to-actions
  24), actions as text buttons (label-large, primary) with 8px gaps,
  right-aligned.
- Note: with `borderless = true` the editor's square window decoration
  (embedded border and title bar) is gone; there is no close icon in the frame,
  the dialog closes through its action buttons (and Escape).
- The dialog re-resolves the theme mode when shown and rebuilds its content when
  the editor switches light/dark while the instance is alive.
- `CopilotMd3Confirm` (implemented) is the companion: `CopilotMd3Dialog` with a
  360px message label (`set_message`); `set_danger(true)` switches the confirm
  button to the danger variant (used for delete confirmations).
- Used for: provider manager, settings, wizard, key/model editors, confirmations.

### 4.10 CopilotMd3Switch

- Base: `Button` with custom drawing: 52x32 track (corner full), 2px
  outline when off, handle 16 (off) to 24 (on) with 28 pressed swell, 200ms
  motion; colors per MATERIAL3.md §9.12; label on-surface, 16px gap.
- State layer: a 40px `on-surface` halo under the handle, shown while the
  button is held (10%). Pointer devices also show it on hover/focus (8%);
  touch devices never show hover/focus halos, which would otherwise linger
  after a tap as a stray circle.
- Used for: auto-compact, prune tool output, key strategy round-robin, model
  enabled toggles, per-list enable switches.

### 4.11 CopilotMd3Checkbox / CopilotMd3Radio

- `CopilotMd3Checkbox` (implemented): `Button` toggle with custom drawing — 18px
  box, corner 2, primary fill with an on-primary tick when checked, 2px
  on-surface-variant border otherwise, 40px circular state layer, label on the
  right; disabled uses 38% content / 12% container.
- `CopilotMd3Radio` (implemented): `Button` row with a 20px radio circle
  (10px primary dot when selected), body-large title + optional body-small
  supporting text; exclusivity is managed by the caller.
- Used for: "Remember for this session", permissions preset selection (three
  radios with supporting text), model rows in dense lists (checkbox).

### 4.12 CopilotMd3Progress (circular + linear)

- `CopilotMd3Spinner` (implemented): circular indeterminate indicator drawn with
  `draw_arc`, 24px (thinking row) and 16px (tool rows) with scaled stroke width,
  ~1.33s rotation.
- `CopilotMd3LinearProgress` (implemented): 4px track with a sliding segment
  (`start()` / `stop()` / `set_value()` for determinate use), shown while
  importing models.
- Used for: thinking indicator, tool running state, model import, key testing.

### 4.13 CopilotMd3Snackbar

- `CopilotMd3Snackbar` (implemented): a `Control` hosting an inner panel
  (inverse-surface, corner 4, shadow level 3) inline above the composer; the
  control animates its reserved height for the rise/fall reveal (300ms
  standard-decelerate in, 200ms standard-accelerate out) — 48px single line,
  16px padding, body-medium text, optional text-button action
  (inverse-primary), 4s auto-dismiss.
- Used for: clipboard confirmation, settings saved, import finished, background
  errors (with a short action such as "Retry" when applicable).

### 4.14 CopilotMd3Tooltip

- Native tooltips restyled via instance overrides of `TooltipPanel` /
  `TooltipLabel`: inverse-surface, corner 4, 8px horizontal padding, label-medium,
  max width 240px.
- Used for: all icon-only controls.

### 4.15 CopilotMd3Badge

- Small 6px status dot (with tooltip text) and large count badge (16px height,
  corner 8). Count badge uses `primary` container tone (not error) to avoid an
  alarm look; status dot colors follow §3.2.
- Used for: agent state dot in the status strip, tool-run count occasionally.

### 4.16 CopilotMd3Divider

- Base: `Control` with a custom-drawn 1px `outline-variant` line (horizontal or
  vertical, optional insets); full width in strips, inset 16px inside lists and
  dialogs.
- Used for: composer separation, status strip separation, list section breaks,
  menu separators.

### 4.17 CopilotMd3EmptyState

- Custom `VBoxContainer`: 48px primary icon, headline-small title, body-medium
  hint, filled action button; used when the chat is empty (onboarding: open
  provider manager, start a session) and when a list is empty (no keys, no
  models, no rules).

### 4.18 CopilotMd3SegmentedButtons

- Base: `PanelContainer` hosting an `HBoxContainer` of toggle `Button`s sharing a
  1px outline, 40px height, full (pill) outer corners, 1px `outline-variant`
  dividers between segments, selected segment `secondary-container` /
  `on-secondary-container`; second tap on the selected index does not re-emit.
- Used for: permission rule mode (Deny / Ask / Allow), memory mode (Text /
  Native), provider kind (OpenAI / Anthropic), API type (chat_completions /
  responses).

### 4.19 CopilotMd3ToolRow

- `PanelContainer` with `surface-container-low` fill, 1px `outline-variant`,
  corner 12 and 36px collapsed height. Header: chevron toggle, tool icon 18,
  optional subagent prefix in `status-info`, tool name label-large, truncated
  args body-small, status glyph (spinner 16 while running, check_circle
  status-success or error on completion) and elapsed label-small.
- Expanded: output block in `surface-container-lowest` (corner 8, 12px padding,
  editor mono font) truncated to a readable length with a "Show more" text
  button.
- Used for: one row per tool call in the chat view.

### 4.20 CopilotMd3Composer

- VBox with a `surface-container-highest` pill (corner 24, shadow level 1)
  around a flat multiline `TextEdit`, plus a supporting hint label. Grows from
  48px to 120px with the line count; Enter sends, Shift+Enter inserts a newline.
- Trailing action: one `CopilotMd3IconButton` inset 4px from the pill's trailing
  edge — Send (filled, primary; disabled => 12% container / 38% icon) while idle,
  swapping to Stop (tonal) while the agent is busy. The hint "Enter to send,
  Shift+Enter for a new line" shows while focused.
- Used for: the dock composer only.

### 4.21 CopilotMd3SpinField

- Stepped numeric field: 40px outlined `CopilotMd3TextField` (min 96px wide) with
  a stacked chevron stepper (expand_less / expand_more, 20px each) on the trailing
  edge. Values clamp to `[min, max]` with a step; commits on stepper press, Enter
  or focus loss and emits `value_changed` only when the value actually changes.
- Used for: sticky key count, memory max steps / tail size, agent max steps.

---

## 5. Dock Layout

```
+------------------------------------------------------+
| Copilot          [Sessions] [New] [Tools] [Keys] [Clear] |  header 48px
+------------------------------------------------------+
|                                                      |
|                       +--------------------------+   |
|                       | user message bubble      |   |  primary-container
|                       +--------------------------+   |
|  +----------------------------------------------+    |
|  | assistant message card                       |    |  surface-container-high
|  +----------------------------------------------+    |
|  > [icon] read_file  res://project.godot     OK      |  tool row
|  > [icon] write_file res://player.gd      (spin)     |  tool row
|                                                      |
|  ( CopilotChatView scroll area )                     |
|                                                      |
+------------------------------------------------------+
| permission card (when waiting)                       |  elevated, level 1
+------------------------------------------------------+
| +--------------------------------------------------+ |
| | Message Copilot...                      (send)   | |  composer pill
| +--------------------------------------------------+ |
+------------------------------------------------------+
| (dot) Ready                            OpenAI/gpt-4o |  status strip 28px
+------------------------------------------------------+
```

- Dock background: `surface`; header and status strip sit on `surface` with
  1px `outline-variant` separators (status strip only).
- Header title `Copilot` (title-small); when the dock is narrower than 320px the
  title hides and buttons keep 40px targets.
- All header buttons are `CopilotMd3IconButton` (standard variant) with tooltips:
  Sessions (opens menu), New session, Tools (Settings dialog), Keys (Provider
  manager), Clear (clears the view).
- Dock tab icon: `Terminal` editor icon for now; a bundled 16px `copilot.svg`
  (Material Symbols `smart_toy`) is planned.

---

## 6. Chat View

### 6.1 Message cards

| Role | Container | Shape | Align | Header |
| --- | --- | --- | --- | --- |
| User | `primary-container` | corner 16, 4 at bottom-right | right, width between 96px and 85% of the viewport | none (bubble only) |
| Assistant | `surface-container-high` | corner 16, 4 at bottom-left | left, full width minus 8px | role row: auto_awesome icon 16 + `Copilot` label-medium on-surface-variant |
| Notice/system | `surface-container-low` | corner 12 | left | info icon + label per severity |
| Tool row | `surface-container-low` + 1px `outline-variant` | corner 12, 36px min height | left, indented 8px | leading tool icon 18, tool name label-large on-surface, args body-small on-surface-variant, status chip |

- Message body: body-medium, selectable; user text may be selectable too. The
  editor theme's filled `RichTextLabel` box is cleared, so text sits directly on
  the card surface.
- User bubble padding is 16x10; the assistant card uses the same vertical padding
  with 24px trailing room for the streaming caret. The bubble is sized from a
  measured text width (clamped to the 96px..85% range) and re-measured when the
  view is laid out, so it never collapses into a one-letter-per-line column.
- Code blocks inside messages: `surface-container-lowest`, corner 12, 12px
  padding, editor mono font; inline code uses a tinted run, no background box.
- Hovering a message shows a small trailing action row: Copy (always), Retry
  (assistant only, when idle). Actions are `CopilotMd3IconButton` size 24-32.
- Subagent tool rows prefix the name with the agent's display name in
  `status-info` color: `agent_name > tool_name`.

### 6.2 Streaming and thinking

- Thinking: a compact row under the last message: circular progress 24px +
  label-large "Thinking..." (streaming animations per 3.6).
- Streaming: assistant card grows with content; a 2x14 primary caret pulses at
  the end while text arrives; caret disappears when done.
- Errors: error-container notice card with `error` icon; if retryable a text
  button "Retry" appears inside the card.

### 6.3 Tool rows

- One row per tool call, collapsible (chevron). Collapsed shows: icon, name,
  truncated args (~60 chars), status.
- Expanded shows an output block (code block style) with the result summary,
  truncated to a readable height with "Show more" text button.
- Status: running (circular progress 16px), OK (check_circle, status-success),
  Failed (error, error), plus elapsed time label-small on the right when done.

### 6.4 Empty state and auto-scroll

- Empty chat: `CopilotMd3EmptyState` with auto_awesome icon, title "Start a
  conversation", hint "Connect a provider and ask Copilot to work on your
  project.", actions: filled "Open provider manager" (or "New session" when a
  provider exists).
- Auto-scroll: only while pinned to bottom; a "Jump to latest" tonal chip
  appears above the composer when the user has scrolled up during streaming.

---

## 7. Permission Card

`CopilotPermissionCard` is rebuilt as an elevated `CopilotMd3Card` above the
composer:

```
+--------------------------------------------------------------+
| (shield in tertiary badge)  Permission required    [chip]    |
| write_file                                                   |
| res://scripts/player.gd                                      |
| [This target only] [Directory] [Project] [*]                 |
| [ ] Remember for this session                                |
|                              [Deny] [Always allow] [Allow]   |
+--------------------------------------------------------------+
```

- Icon badge: 28px circle, `tertiary-container` / `on-tertiary-container`, shield
  symbol; the badge replaces the old lock emoji-free label.
- Title: title-medium; action + target rendered as two lines: action
  label-large on-surface, target body-small on-surface-variant (mono for paths).
- Location chip: assist chip, right-aligned in the header row: "In project"
  (`secondary-container`) or "Outside project" (`error-container` +
  `on-error-container`).
- Scope row: single-select filter chips from `CopilotPermissions.scope_options()`
  (first = this target only, then prefix/directory/domain scopes, then `*`);
  selected chip = `secondary-container`.
- Remember: `CopilotMd3Checkbox` + label-medium "Remember for this session"
  (permanent rule vs session grant unchanged).
- Actions: Deny (text button), Always allow (tonal), Allow once (filled).
  Order keeps the safest action left; the filled action performs the immediate
  allow.
- Appear/disappear motion per 3.6; the card is visible only while the agent waits
  for a decision and stays usable while dialogs are open (no modal overlay).

---

## 8. Composer and Status Strip

- Composer: `CopilotMd3Composer` (section 4.20): `surface-container-highest`
  fill, corner full (24 when multi-line), 48px collapsed height growing to 120px,
  16px padding, body-medium; placeholder "Message Copilot...".
- Trailing in-pill action: a single `CopilotMd3IconButton` — Send (filled,
  primary; disabled => 12% container / 38% icon) while idle, swapping to Stop
  (tonal) while the agent is busy; inset 4px from the pill's trailing edge.
- Enter sends, Shift+Enter inserts a newline; the hint "Enter to send,
  Shift+Enter for a new line" shows as supporting text under the composer while
  it is focused (body-small, on-surface-variant).
- Focus returns to the composer after a turn finishes.
- Status strip (28px): left = 6px state dot + label-small state text; right =
  active `provider/model` label-small on-surface-variant. The state text keeps
  its full width; the model label expands into the leftover space, aligns right
  and ellipsizes first on a narrow dock (full text in its tooltip). States: Ready
  (`status-success`), Thinking/Running (`status-warning`), Streaming (`primary`),
  Waiting for permission (`status-warning`), Error (`error`), Canceled
  (`on-surface-variant`).

---

## 9. Provider Manager (dialog)

Layout unchanged (list left, detail right) with M3 components:

- Dialog: `CopilotMd3Dialog`, min 780x480 (initial 900x560), title "Provider
  Manager", headline-small.
- Left: `CopilotMd3ListItem` rows (56px): logo badge 28 (mono logos on a rounded
  white badge, colored logos as-is, fallback = initial letters), title = provider
  name (body-large), supporting = "3 active keys" / "No keys yet" (body-small).
  Selected row = `secondary-container`; active provider shows a check_circle icon
  in primary on the trailing edge.
- Left header: "Add" = `CopilotMd3Button` tonal with expand_more, opening
  `CopilotMd3Menu` (presets + "Custom provider..."); "Delete" = icon button
  (delete) with a `CopilotMd3Confirm` confirmation.
- Right header: provider name (title-large) + base URL (body-small, mono for the
  host part); "Open API key page" outlined button with open_in_new.
- Tabs: `CopilotMd3Tabs` (Keys / Models / Advanced).
- Keys tab: list of `CopilotMd3ListItem` (2-line): leading switch (enabled),
  title = key label (body-large), supporting = masked value (`sk-...abc1`, mono,
  body-small), trailing = test status chip (Valid / Failed / queued / testing
  spinner) + icon buttons (reveal visibility, reload, arrow_up, arrow_down, edit,
  delete). Below: tonal "Add key", outlined "Test all", text "Stop" (stop icon,
  only while testing); key strategy row: `CopilotMd3Switch` (round robin) + sticky
  count (`CopilotMd3SpinField`, visible when round robin is off).
- Models tab: "Active model" row = outlined select button showing the current
  model, opening `CopilotMd3Menu` (search field inside the menu when the list is
  long). Model rows: `CopilotMd3ListItem` with leading switch (enabled; disabled
  rows rendered last and dimmed), title = model id (mono), supporting = display
  name plus `[vision, reasoning]` hints, trailing delete. Header actions: import
  (tonal, download icon; a `CopilotMd3LinearProgress` shows while importing),
  "Add model" (outlined), "Enable all" / "Disable all" (text, done_all /
  remove_done icons).
- Advanced tab: kind as a read-only label row; Base URL and Model Prefix as
  outlined text fields; API Type as 2-segment `SegmentedButtons` (disabled for the
  Anthropic kind). All fields save automatically; a body-small hint states this.
- Wizard: `CopilotMd3Dialog` with outlined text fields (Name, Base URL, Model
  prefix, first key, first model), Kind as 2-segment `SegmentedButtons`
  (OpenAI / Anthropic), API type as 2-segment (chat completions / responses,
  disabled for the Anthropic kind), "Get API key" text button with open_in_new,
  actions Cancel (text) / Create (filled). Validation errors use an error-colored
  supporting label.
- Key / model editors: small `CopilotMd3Dialog`s with outlined fields and
  switches, Cancel (text) / Save (filled); errors use an error-colored label.

---

## 10. Settings Dialog

`CopilotMd3Dialog`, min 560x480, tabs via `CopilotMd3Tabs`:

1. **Permissions** — preset selection as three `CopilotMd3Radio` options with
   supporting text (Sandbox / Review / Turbo), plus a hint line that follows the
   selected preset. Rule editor: segmented control (Deny / Ask / Allow) with
   counts, rule list (`CopilotMd3ListItem`, trailing delete), and an add-rule row:
   outlined text field + filled icon button (add).
2. **Memory** — switches (`CopilotMd3Switch`): auto-compact, prune tool output;
   mode choice as segmented control (Text / Native); compaction model as outlined
   text field (empty = active model); max steps and tail size as labeled
   `CopilotMd3SpinField`s.
3. **Agent** — max ReAct steps (`CopilotMd3SpinField`), subagent override list rows
   (name + model select button opening `CopilotMd3Menu` + delete icon button),
   empty state when no overrides ("No subagent overrides yet."), and an add row
   (name field + model select + add icon button) with inline validation.

Dangerous actions (if added later, e.g. reset settings) use the danger button
variant and a confirmation `CopilotMd3Confirm`.

---

## 11. Icons

Curated Material Symbols (Rounded), bundled as 24px single-color SVGs and tinted
by token colors; FILL=1 for selected/active states where applicable. Fallback
chain: bundled symbol -> Godot editor icon -> text label (unchanged rule from
v2, but now second priority).

| Need | Symbol |
| --- | --- |
| Dock tab (planned asset) | smart_toy |
| Sessions / history | history |
| New session / add | add |
| Settings | settings |
| Provider manager | key |
| Clear chat | delete_sweep |
| Send | send |
| Stop | stop |
| Copy | content_copy |
| Retry / reload / test | refresh |
| Chevron expand/collapse | expand_more / expand_less |
| List chevron | chevron_right |
| Check / selected | check |
| Success | check_circle |
| Error / failed | error |
| Warning | warning |
| Info / notice | info |
| Thinking / running | progress_activity |
| Assistant role | auto_awesome |
| Subagent | account_tree |
| Tool: file | description |
| Tool: search | search |
| Tool: shell | terminal |
| Tool: web / http | language |
| Tool: scene | widgets |
| Tool: editor | edit_note |
| Tool: MCP | hub |
| Permission | shield |
| Reveal key | visibility / visibility_off |
| Edit | edit |
| Delete | delete |
| Move up / down | arrow_upward / arrow_downward |
| Import / download | download |
| Enable all / disable all | done_all / remove_done |
| Open external | open_in_new |
| Close | close |
| Active check | check_circle |
| Empty state (chat) | auto_awesome |

Rules: 24px standard, 18px inside buttons/chips/tool rows, 16px inside switches;
icons never carry color alone (always paired with text or tooltip).

---

## 12. Light/Dark Behavior

- The dock detects the editor theme (base color brightness) at creation and picks
  `CopilotMd3Scheme.light()` or `dark()`. Dialogs and menus resolve the mode from
  the editor theme via `EditorInterface` (Window nodes do not inherit the editor
  theme through a Control parent) and re-resolve it whenever they are shown again.
- Both schemes use the full role set from MATERIAL3.md §3; extension roles have
  light/dark pairs in `CopilotMd3Tokens`.
- Provider logos: mono logos render black on the white badge in both modes;
  colored logos are used as-is (verified contrast on both surface tones). The
  badge itself is always white, not `surface-container-lowest`.
- Shadows are softened in dark mode; containers carry depth instead.
- Live switching: the dock re-applies the new scheme to its whole tree; the
  provider manager and settings dialog rebuild their content when the mode
  changes; other dialogs pick the new mode up when reopened.

---

## 13. Accessibility & Interaction

- Contrast follows MATERIAL3.md §10 (4.5:1 text, 3:1 large text/UI boundaries).
- Every icon-only control has a tooltip; every status has text or an icon next to
  its color.
- Targets: 40x40 dock minimum, 48x48 dialogs; 8px spacing between adjacent
  targets.
- Keyboard: focus rings 2px primary (2px offset); Tab order follows visual order;
  the composer keeps Enter-to-send; decorative rows are skipped by navigation.
- Motion: all key-moment animations degrade to baseline curves when reduce-motion
  is enabled (planned setting).
- The inline permission card never blocks the dock; dialogs do not lock the chat
  view.
- Rebuilding a session from the trajectory (reload) renders final states without
  entry animations.

---

## 14. Rollout Plan

1. **Foundation** (implemented): `CopilotMd3Tokens`, `CopilotMd3Scheme`,
   `CopilotMd3Motion`, `CopilotMd3Icons`, bundled Roboto (Regular/Medium +
   Apache-2.0 license), curated Material Symbols SVGs.
2. **Base components** (implemented): state layer, button, icon button, card,
   text field, chip, list item, divider, badge, tooltip.
3. **Dock and chat** (implemented): header with the sessions menu
   (`CopilotMd3Menu`), chat view (bubbles, cards, tool rows, streaming caret,
   hover copy/retry), empty state, composer, status strip, snackbar, checkbox,
   circular spinner; permission card rebuilt per section 7.
4. **Dialogs** (implemented): dialog base (`CopilotMd3Dialog`), confirm
   (`CopilotMd3Confirm`), tabs, menu, switch, radio, segmented buttons, linear
   progress, spin field; provider manager (rows, tabs, menus, wizard, editors),
   settings dialog (radios, switches, segmented controls), dock sessions menu and
   delete confirmation.
5. **Polish** (planned): message entrance motion (fade + rise), live light/dark
   re-apply for already rendered cards, overlay tooltips, visual checklist,
   retire `CopilotTheme` styling (keep light/dark detection + icon fallback).

Until each phase lands, existing UI keeps working; classes are migrated one by one
and no `.tscn` is introduced.

---

## 15. Visual Review Checklist

- [ ] No raw colors/radii/durations in components outside the token modules.
- [ ] All dialogs and the dock use the same scheme object; light and dark both
      verified.
- [ ] Buttons/icon buttons/chips show hover/focus/pressed states with the correct
      opacities; focus rings are visible.
- [ ] Message bubbles (user) and cards (assistant) are clearly distinct;
      tool rows show icon, status, and collapsible output.
- [ ] Permission card: scope chips, location chip, remember checkbox, and the
      three action buttons behave and read clearly; the card never blocks the dock.
- [ ] Composer pill grows for multi-line input; Enter sends; the single trailing
      action turns into Stop while busy and sits flush with the pill's edge.
- [ ] Status strip shows state text + dot and the active provider/model.
- [ ] Provider manager: list selection, tabs, key/model rows, wizard validation,
      and confirmations all use the new components.
- [ ] Settings: radio presets, rule editor, switches, and segmented controls.
- [ ] Snackbar appears for copy/save/import events and auto-dismisses.
- [ ] Icons render from the bundled set; every icon-only control has a tooltip.
- [ ] Auto-scroll stays pinned-to-bottom aware; "jump to latest" appears when
      scrolled up during streaming.

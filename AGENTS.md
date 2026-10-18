# AGENTS.md — Godot Copilot

Entry index for this repository. Find the block that matches the task, then open
the document it points at: the documents carry the detail, this file only routes.
Rule of thumb: `docs/DESIGN.md` is visual, `docs/ARCHITECTURE.md` is technical;
never mix their contents.

<!-- BEGIN:overview -->
## Overview

Godot Copilot is a Godot 4.7+ editor plugin: an AI agent chat in the editor's
right dock, multi-provider (OpenAI-compatible and Anthropic), tool execution
(file, shell, web, scene, editor, MCP), subagents, and an `action(target)`
permission system. Current version: 2.0.0 (full rebuild).

- User-facing overview and install: `README.md`, `addons/godot-copilot/README.md`.
- What changed and when: `docs/CHANGELOG.md`.
<!-- END:overview -->

<!-- BEGIN:documents -->
## Documents

| Task | Document |
| --- | --- |
| Visual design: components, layouts, motion, review checklist | `docs/DESIGN.md` |
| Material 3 reference values (color, type, shape, elevation) | `docs/MATERIAL3.md` |
| Architecture: folders, classes, turn flow, config, tools, permissions | `docs/ARCHITECTURE.md` |
| Code style, naming, config access, paths, git rules | `docs/CONVENTIONS.md` |
| Providers: kinds, presets, keys, streaming, troubleshooting | `docs/PROVIDERS.md` |
| Version history and breaking changes | `docs/CHANGELOG.md` |
<!-- END:documents -->

<!-- BEGIN:layout -->
## Layout

- `addons/godot-copilot/` — the plugin: `plugin.gd` (EditorPlugin entry),
  `src/config`, `src/chat`, `src/providers`, `src/security`, `src/tools`,
  `src/ui` (dock, chat view, dialogs, `md3/` design system), `assets/`.
- `docs/` — the documents above.
- `project.godot` — throwaway test project that enables the plugin.
- No `.tscn` files: the whole UI is built in code.
<!-- END:layout -->

<!-- BEGIN:invariants -->
## Invariants

- Right dock via `EditorDock`/`add_dock()` (slot `RIGHT_BL`) with an
  `add_control_to_dock()` fallback for older Godot.
- Storage in `user://godot-copilot/`; config schema v2. Legacy
  `godot_copilot` / `res://.godot/.copilot/` names appear only in migration code.
- Colors and icons come from the editor theme through `CopilotTheme`; Material 3
  components resolve roles through `CopilotMd3Scheme`.
- Dynamic text into a `RichTextLabel` goes through `add_text()` (never BBCode);
  chat auto-scroll stays pinned to the bottom.
- Permissions have one choke point in `CopilotAgent` (ALLOW/ASK/DENY, rules are
  `action(target)`; presets sandbox/review/turbo).
- Tools never block the editor and always return `{success, error?, ...}`.
<!-- END:invariants -->

<!-- BEGIN:workflow -->
## Workflow

1. Read the document for the task; check `git status` before editing.
2. Follow `docs/CONVENTIONS.md`; when a new convention is needed, update it there.
3. Run the checks below; update `docs/CHANGELOG.md` when behavior changes.
4. Commit per work item with an English imperative message.
<!-- END:workflow -->

<!-- BEGIN:checks -->
## Required checks

- Stale v1 symbols: `CopilotSettings`, `CopilotToolRegistry`,
  `CopilotBaseProvider`, `execute_url`, `checkApiKey`, `provider_dialog`,
  `bottom_panel`, `.tscn`.
- `godot_copilot` (underscore) must not appear outside documented migration code.
- No Indonesian text in code, UI, or docs; no emoji in Markdown.
- After renames, grep `CopilotConfig.`, `CopilotTheme.`, `CopilotPaths.` and
  signal names for leftover references.
<!-- END:checks -->

<!-- BEGIN:environment -->
## Environment

- No Godot binary: verification is static review plus a manual smoke test by the
  user (`docs/ARCHITECTURE.md` section 12).
- Linux/Termux-style paths; use `/tmp/opencode` for files outside the project.
- Git: public GitHub remote `origin` (`nexarioneo/godot-copilot`); commits use
  the repo identity `Nexarioneo`. Run the checks above before pushing.
<!-- END:environment -->

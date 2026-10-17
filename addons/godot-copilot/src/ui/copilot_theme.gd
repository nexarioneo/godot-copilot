@tool
class_name CopilotTheme
extends RefCounted
# The single source of UI colors and icons. Every accessor uses a fallback to stay
# safe across Godot versions and while a control is not yet inside the tree.

const FALLBACK_ACCENT := Color("#5b9bd5")
const FALLBACK_FONT := Color("#e0e0e0")
const FALLBACK_PLACEHOLDER := Color("#8a8f98")
const FALLBACK_DISABLED := Color("#7f7f7f")
const FALLBACK_WARNING := Color("#d4a24c")
const FALLBACK_SUCCESS := Color("#45cc65")
const FALLBACK_ERROR := Color("#ff6b6b")
const FALLBACK_DARK_1 := Color("#2b2b2b")
const FALLBACK_DARK_2 := Color("#242424")
const FALLBACK_DARK_3 := Color("#1e1e1e")
const FALLBACK_SEPARATOR := Color("#3a3a3a")

static func color(context: Control, names: PackedStringArray, fallback: Color) -> Color:
	var theme := EditorInterface.get_editor_theme()
	if theme != null:
		for name in names:
			if theme.has_color(name, "Editor"):
				return theme.get_color(name, "Editor")
	if context != null and context.is_inside_tree():
		for name in names:
			if context.has_theme_color(name, "Editor"):
				return context.get_theme_color(name, "Editor")
	return fallback

static func icon(context: Control, names: PackedStringArray) -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	if theme != null:
		for name in names:
			if theme.has_icon(name, "EditorIcons"):
				return theme.get_icon(name, "EditorIcons")
	if context != null and context.is_inside_tree():
		for name in names:
			if context.has_theme_icon(name, "EditorIcons"):
				return context.get_theme_icon(name, "EditorIcons")
	return null

# Mirrors the DESIGN.md §9 pattern: icon first, fallback text when the icon is missing.
static func apply_icon(button: Button, names: PackedStringArray, fallback_text: String) -> void:
	var texture := icon(button, names)
	if texture != null:
		button.icon = texture
		button.text = ""
	elif not fallback_text.is_empty():
		button.text = fallback_text

# --- Semantic colors ---

static func accent_color(context: Control) -> Color:
	return color(context, PackedStringArray(["accent_color"]), FALLBACK_ACCENT)

static func font_color(context: Control) -> Color:
	return color(context, PackedStringArray(["font_color"]), FALLBACK_FONT)

static func font_placeholder_color(context: Control) -> Color:
	return color(context, PackedStringArray(["font_placeholder_color"]), FALLBACK_PLACEHOLDER)

static func font_disabled_color(context: Control) -> Color:
	return color(context, PackedStringArray(["font_disabled_color"]), FALLBACK_DISABLED)

static func warning_color(context: Control) -> Color:
	return color(context, PackedStringArray(["warning_color"]), FALLBACK_WARNING)

static func success_color(context: Control) -> Color:
	return color(context, PackedStringArray(["success_color"]), FALLBACK_SUCCESS)

static func error_color(context: Control) -> Color:
	return color(context, PackedStringArray(["error_color"]), FALLBACK_ERROR)

static func separator_color(context: Control) -> Color:
	return color(context, PackedStringArray(["separator_color"]), FALLBACK_SEPARATOR)

static func dark_color(context: Control, level := 2) -> Color:
	var name := "dark_color_" + str(level)
	var fallback := FALLBACK_DARK_2
	match level:
		1:
			fallback = FALLBACK_DARK_1
		3:
			fallback = FALLBACK_DARK_3
	return color(context, PackedStringArray([name]), fallback)

static func status_color(context: Control, agent_state: String) -> Color:
	match agent_state:
		"idle":
			return success_color(context)
		"thinking", "running_tools", "waiting_permission", "compacting":
			return warning_color(context)
		"streaming":
			return accent_color(context)
		_:
			return font_placeholder_color(context)

static func status_text(context: Control, agent_state: String) -> String:
	match agent_state:
		"idle":
			return "Ready"
		"thinking":
			return "Thinking…"
		"streaming":
			return "Replying…"
		"running_tools":
			return "Running tools…"
		"waiting_permission":
			return "Waiting for permission…"
		"compacting":
			return "Compacting memory…"
		_:
			return agent_state

# --- StyleBox ---

static func card_style(context: Control, border_color: Color = Color(0, 0, 0, 0), border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = dark_color(context, 2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.border_color = border_color
	return style

static func row_style(context: Control, selected := false) -> StyleBoxFlat:
	var style := card_style(context)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	if selected:
		style.border_width_left = 2
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = accent_color(context)
	return style

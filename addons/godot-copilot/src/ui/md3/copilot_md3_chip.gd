@tool
class_name CopilotMd3Chip
extends Button
# Material 3 chip. Variants: filter (default, toggleable), assist, suggestion,
# input. Height 32, corner 8, label-large, optional 18px leading icon.
# Selected filter chips use secondary-container / on-secondary-container.

const VARIANT_FILTER := "filter"
const VARIANT_ASSIST := "assist"
const VARIANT_SUGGESTION := "suggestion"
const VARIANT_INPUT := "input"

const HEIGHT := 32
const ICON_SIZE := 18
const PAD_TEXT := 16
const PAD_ICON := 8
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10

var variant: String = VARIANT_FILTER
var _scheme: CopilotMd3Scheme = null

func configure(scheme: CopilotMd3Scheme, chip_variant: String = VARIANT_FILTER, label: String = "", icon_name: String = "", editor_fallback: String = "") -> void:
	_scheme = scheme
	variant = chip_variant
	text = label
	if not icon_name.is_empty():
		CopilotMd3Icons.apply_to_button(self, icon_name, editor_fallback)
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_selected(selected: bool) -> void:
	button_pressed = selected
	_apply()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	_apply()

func _on_toggled(_pressed: bool) -> void:
	_apply()

func _apply() -> void:
	if _scheme == null:
		return
	custom_minimum_size.y = HEIGHT
	CopilotMd3Tokens.apply_text(self, "label-large")
	add_theme_constant_override("icon_max_width", ICON_SIZE)
	add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("s"))

	var selected := toggle_mode and button_pressed
	var fill_role := ""
	var border_role := "outline-variant"
	var border_width := 1
	var content_role := "on-surface-variant"
	match variant:
		VARIANT_ASSIST, VARIANT_SUGGESTION:
			border_role = "outline"
			content_role = "on-surface"
		VARIANT_INPUT:
			content_role = "on-surface-variant"
		_:
			if selected:
				fill_role = "secondary-container"
				border_role = ""
				border_width = 0
				content_role = "on-secondary-container"

	var radius := CopilotMd3Tokens.corner_radius("small", Vector2(HEIGHT, HEIGHT))
	var fill_color := Color(0.0, 0.0, 0.0, 0.0)
	if not fill_role.is_empty():
		fill_color = _scheme.color(fill_role)
	var content_color := _scheme.color(content_role)
	var border_color := Color(0.0, 0.0, 0.0, 0.0)
	if border_width > 0:
		border_color = _scheme.color(border_role)
	var pad: int = PAD_ICON if icon != null else PAD_TEXT

	var disabled_fill := Color(0.0, 0.0, 0.0, 0.0)
	if not fill_role.is_empty():
		disabled_fill = _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTAINER_OPACITY)
	var disabled_border := Color(0.0, 0.0, 0.0, 0.0)
	if border_width > 0:
		disabled_border = _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTAINER_OPACITY)
	var disabled_content := _scheme.disabled_content("on-surface")

	add_theme_stylebox_override("normal", _chip_box(fill_color, radius, border_color, border_width, pad))
	add_theme_stylebox_override("hover", _chip_box(_scheme.state_fill(fill_color, content_color, HOVER_OPACITY), radius, border_color, border_width, pad))
	add_theme_stylebox_override("pressed", _chip_box(_scheme.state_fill(fill_color, content_color, PRESSED_OPACITY), radius, border_color, border_width, pad))
	add_theme_stylebox_override("focus", _focus_box(radius))
	add_theme_stylebox_override("disabled", _chip_box(disabled_fill, radius, disabled_border, border_width, pad))

	add_theme_color_override("font_color", content_color)
	add_theme_color_override("font_hover_color", content_color)
	add_theme_color_override("font_pressed_color", content_color)
	add_theme_color_override("font_focus_color", content_color)
	add_theme_color_override("font_disabled_color", disabled_content)
	add_theme_color_override("icon_normal_color", content_color)
	add_theme_color_override("icon_hover_color", content_color)
	add_theme_color_override("icon_pressed_color", content_color)
	add_theme_color_override("icon_focus_color", content_color)
	add_theme_color_override("icon_disabled_color", disabled_content)

func _chip_box(fill_color: Color, radius: int, border_color: Color, border_width: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = CopilotMd3Tokens.spacing("xs")
	sb.content_margin_bottom = CopilotMd3Tokens.spacing("xs")
	if border_width > 0 and border_color.a > 0.0:
		sb.set_border_width_all(border_width)
		sb.border_color = border_color
	return sb

func _focus_box(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(CopilotMd3Tokens.FOCUS_RING_WIDTH)
	sb.border_color = _scheme.color("primary")
	sb.set_corner_radius_all(radius)
	return sb

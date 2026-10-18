@tool
class_name CopilotMd3Button
extends Button
# Material 3 button. Variants: elevated, filled (default), tonal, outlined,
# text, plus a plugin-only danger variant (error roles). Height 40, fully
# rounded, label-large text, optional 18px leading icon.

const VARIANT_ELEVATED := "elevated"
const VARIANT_FILLED := "filled"
const VARIANT_TONAL := "tonal"
const VARIANT_OUTLINED := "outlined"
const VARIANT_TEXT := "text"
const VARIANT_DANGER := "danger"

const HEIGHT := 40
const ICON_SIZE := 18
const PAD_H := 16
# State layer opacities per MATERIAL3.md section 8.1.
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10

var variant: String = VARIANT_FILLED
var _scheme: CopilotMd3Scheme = null

func configure(scheme: CopilotMd3Scheme, button_variant: String = VARIANT_FILLED, label: String = "", icon_name: String = "", editor_fallback: String = "") -> void:
	_scheme = scheme
	variant = button_variant
	text = label
	if not icon_name.is_empty():
		CopilotMd3Icons.apply_to_button(self, icon_name, editor_fallback)
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_variant(button_variant: String) -> void:
	variant = button_variant
	_apply()

func set_icon(symbol_name: String, editor_fallback: String = "") -> void:
	CopilotMd3Icons.apply_to_button(self, symbol_name, editor_fallback)

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_apply()

func _apply() -> void:
	if _scheme == null:
		return
	custom_minimum_size.y = HEIGHT
	CopilotMd3Tokens.apply_text(self, "label-large")
	add_theme_constant_override("icon_max_width", ICON_SIZE)
	add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("s"))

	var fill_role := ""
	var border_role := "outline"
	var border_width := 0
	var content_role := "on-primary"
	var shadow := 0
	match variant:
		VARIANT_ELEVATED:
			fill_role = "surface-container-low"
			border_role = ""
			content_role = "primary"
			shadow = 1
		VARIANT_TONAL:
			fill_role = "secondary-container"
			border_role = ""
			content_role = "on-secondary-container"
		VARIANT_OUTLINED:
			fill_role = ""
			border_role = "outline"
			border_width = 1
			content_role = "primary"
		VARIANT_TEXT:
			fill_role = ""
			border_role = ""
			content_role = "primary"
		VARIANT_DANGER:
			fill_role = "error"
			border_role = ""
			content_role = "on-error"
		_:
			fill_role = "primary"
			border_role = ""
			content_role = "on-primary"

	var radius := CopilotMd3Tokens.corner_radius("full", Vector2(HEIGHT, HEIGHT))
	var fill_color := Color(0.0, 0.0, 0.0, 0.0)
	if not fill_role.is_empty():
		fill_color = _scheme.color(fill_role)
	var content_color := _scheme.color(content_role)
	var border_color := Color(0.0, 0.0, 0.0, 0.0)
	if border_width > 0 and not border_role.is_empty():
		border_color = _scheme.color(border_role)

	var disabled_fill := Color(0.0, 0.0, 0.0, 0.0)
	if not fill_role.is_empty():
		disabled_fill = _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTAINER_OPACITY)
	var disabled_border := Color(0.0, 0.0, 0.0, 0.0)
	if border_width > 0:
		disabled_border = _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTAINER_OPACITY)
	var disabled_content := _scheme.disabled_content("on-surface")

	add_theme_stylebox_override("normal", _build_box(fill_color, radius, border_color, border_width, shadow))
	add_theme_stylebox_override("hover", _build_box(_scheme.state_fill(fill_color, content_color, HOVER_OPACITY), radius, border_color, border_width, shadow))
	add_theme_stylebox_override("pressed", _build_box(_scheme.state_fill(fill_color, content_color, PRESSED_OPACITY), radius, border_color, border_width, shadow))
	add_theme_stylebox_override("focus", _focus_box(radius))
	add_theme_stylebox_override("disabled", _build_box(disabled_fill, radius, disabled_border, border_width, 0))

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

func _build_box(fill_color: Color, radius: int, border_color: Color, border_width: int, shadow: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = PAD_H
	sb.content_margin_right = PAD_H
	sb.content_margin_top = CopilotMd3Tokens.spacing("xs")
	sb.content_margin_bottom = CopilotMd3Tokens.spacing("xs")
	if border_width > 0 and border_color.a > 0.0:
		sb.set_border_width_all(border_width)
		sb.border_color = border_color
	if shadow > 0:
		CopilotMd3Tokens.apply_shadow(sb, shadow)
	return sb

func _focus_box(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	if not CopilotMd3Tokens.focus_ring_visible():
		return sb
	sb.set_border_width_all(CopilotMd3Tokens.FOCUS_RING_WIDTH)
	sb.border_color = _scheme.color("primary")
	sb.set_corner_radius_all(radius)
	return sb

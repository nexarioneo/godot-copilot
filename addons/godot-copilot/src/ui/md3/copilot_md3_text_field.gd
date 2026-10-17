@tool
class_name CopilotMd3TextField
extends LineEdit
# Material 3 single-line text field. Filled (default): surface-container-highest
# with a 1dp bottom indicator that turns primary/2dp on focus. Outlined: 1dp
# outline border that turns primary/2dp on focus. Height 56 by default.

const VARIANT_FILLED := "filled"
const VARIANT_OUTLINED := "outlined"

const HEIGHT := 56
const PAD_H := 16
const PAD_V := 8
const SELECTION_OPACITY := 0.30

var variant: String = VARIANT_FILLED
var field_height: int = HEIGHT
var _scheme: CopilotMd3Scheme = null

func configure(scheme: CopilotMd3Scheme, placeholder: String = "", field_variant: String = VARIANT_FILLED, height: int = HEIGHT) -> void:
	_scheme = scheme
	placeholder_text = placeholder
	variant = field_variant
	field_height = height
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_apply()

func _apply() -> void:
	if _scheme == null:
		return
	custom_minimum_size.y = field_height
	CopilotMd3Tokens.apply_text(self, "body-large")
	add_theme_constant_override("caret_width", 2)

	var radius := CopilotMd3Tokens.corner_radius("extra-small", size)
	var normal := _field_box(radius)
	var focus := _field_box(radius)
	var read_only := _field_box(radius)
	if variant == VARIANT_OUTLINED:
		normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		normal.set_border_width_all(1)
		normal.border_color = _scheme.color("outline")
		focus.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		focus.set_border_width_all(2)
		focus.border_color = _scheme.color("primary")
		read_only.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		read_only.set_border_width_all(1)
		read_only.border_color = _scheme.color("outline-variant")
	else:
		normal.bg_color = _scheme.color("surface-container-highest")
		normal.set_border_width(SIDE_BOTTOM, 1)
		normal.border_color = _scheme.color("on-surface-variant")
		focus.bg_color = _scheme.color("surface-container-highest")
		focus.set_border_width(SIDE_BOTTOM, 2)
		focus.border_color = _scheme.color("primary")
		read_only.bg_color = _scheme.color("surface-container")
		read_only.set_border_width(SIDE_BOTTOM, 1)
		read_only.border_color = _scheme.color("outline-variant")

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("focus", focus)
	add_theme_stylebox_override("read_only", read_only)

	add_theme_color_override("font_color", _scheme.color("on-surface"))
	add_theme_color_override("font_placeholder_color", _scheme.color("on-surface-variant"))
	add_theme_color_override("font_selected_color", _scheme.color("on-surface"))
	add_theme_color_override("caret_color", _scheme.color("primary"))
	add_theme_color_override("selection_color", _scheme.alpha("primary", SELECTION_OPACITY))

func _field_box(radius: int) -> StyleBoxFlat:
	var box := _scheme.box("", radius, "", 0)
	box.content_margin_left = PAD_H
	box.content_margin_right = PAD_H
	box.content_margin_top = PAD_V
	box.content_margin_bottom = PAD_V
	return box

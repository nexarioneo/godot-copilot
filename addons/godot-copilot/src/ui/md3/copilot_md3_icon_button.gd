@tool
class_name CopilotMd3IconButton
extends CopilotMd3Button
# Material 3 icon button: 40x40 container, 24px icon, fully rounded.
# Variants: filled (default), tonal, outlined, standard. Supports toggle mode;
# the selected state follows MATERIAL3.md section 9.2.

const VARIANT_STANDARD := "standard"

const SIZE := 40
const SIZE_COMPACT := 32
const BUTTON_ICON_SIZE := 24
const ICON_SIZE_COMPACT := 20

var _compact := false

func _ready() -> void:
	super._ready()
	_connect_toggle()

func set_toggle(toggle: bool) -> void:
	toggle_mode = toggle
	_apply()

func set_compact(compact: bool) -> void:
	_compact = compact
	_apply()

func _apply() -> void:
	if _scheme == null:
		return
	var target_size := SIZE_COMPACT if _compact else SIZE
	var icon_size := ICON_SIZE_COMPACT if _compact else BUTTON_ICON_SIZE
	custom_minimum_size = Vector2(target_size, target_size)
	add_theme_constant_override("icon_max_width", icon_size)
	_connect_toggle()

	var selected := toggle_mode and button_pressed
	var fill_role := ""
	var border_role := ""
	var border_width := 0
	var content_role := "on-surface-variant"
	var shadow := 0
	match variant:
		VARIANT_FILLED:
			fill_role = "primary"
			content_role = "on-primary"
		VARIANT_TONAL:
			if selected:
				fill_role = "secondary"
				content_role = "on-secondary"
			else:
				fill_role = "secondary-container"
				content_role = "on-secondary-container"
		VARIANT_OUTLINED:
			if selected:
				fill_role = "inverse-surface"
				content_role = "inverse-on-surface"
			else:
				border_role = "outline-variant"
				border_width = 1
				content_role = "on-surface-variant"
		_:
			if selected:
				content_role = "primary"
			else:
				content_role = "on-surface-variant"

	var radius := CopilotMd3Tokens.corner_radius("full", Vector2(target_size, target_size))
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

	add_theme_stylebox_override("normal", _icon_box(fill_color, radius, border_color, border_width, shadow))
	add_theme_stylebox_override("hover", _icon_box(_scheme.state_fill(fill_color, content_color, HOVER_OPACITY), radius, border_color, border_width, shadow))
	add_theme_stylebox_override("pressed", _icon_box(_scheme.state_fill(fill_color, content_color, PRESSED_OPACITY), radius, border_color, border_width, shadow))
	add_theme_stylebox_override("focus", _focus_box(radius))
	add_theme_stylebox_override("disabled", _icon_box(disabled_fill, radius, disabled_border, border_width, 0))

	add_theme_color_override("icon_normal_color", content_color)
	add_theme_color_override("icon_hover_color", content_color)
	add_theme_color_override("icon_pressed_color", content_color)
	add_theme_color_override("icon_focus_color", content_color)
	add_theme_color_override("icon_disabled_color", disabled_content)

func _connect_toggle() -> void:
	if toggle_mode and not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)

func _on_toggled(_pressed: bool) -> void:
	_apply()

func _icon_box(fill_color: Color, radius: int, border_color: Color, border_width: int, shadow: int) -> StyleBoxFlat:
	var sb := _build_box(fill_color, radius, border_color, border_width, shadow)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

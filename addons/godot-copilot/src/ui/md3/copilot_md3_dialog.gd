@tool
class_name CopilotMd3Dialog
extends AcceptDialog
# Material 3 dialog base: surface-container-high container (extra-large 28
# corner, elevation 3), 24px body padding, Roboto type and restyled actions:
# the OK button becomes an M3 filled (or danger) button, an optional cancel
# button becomes a text button. Callers add content through body().

const RADIUS := 28
const PAD := 24
const ACTION_HEIGHT := 40
const ACTION_MIN_WIDTH := 72
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10

var _scheme: CopilotMd3Scheme = null
var _body: VBoxContainer = null
var _ok_variant := CopilotMd3Button.VARIANT_FILLED
var _ok_label := "Close"

func configure(scheme: CopilotMd3Scheme, title_text: String, ok_text: String = "Close", cancel_text: String = "") -> void:
	_scheme = scheme
	_ok_label = ok_text
	title = title_text
	ok_button_text = ok_text
	_build_body()
	if not cancel_text.is_empty():
		add_cancel_button(cancel_text)
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func body() -> VBoxContainer:
	_build_body()
	return _body

func set_ok_variant(button_variant: String) -> void:
	_ok_variant = button_variant
	_apply()

func set_hide_on_ok(enabled: bool) -> void:
	dialog_hide_on_ok = enabled

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_build_body()
	_apply()

func _build_body() -> void:
	if _body != null:
		return
	_body = VBoxContainer.new()
	_body.name = "md3_body"
	_body.custom_minimum_size.x = 400
	_body.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("l"))
	add_child(_body)

func _apply() -> void:
	if _scheme == null:
		return
	var panel := _scheme.box("surface-container-high", RADIUS, "", 0, 3)
	panel.content_margin_left = PAD
	panel.content_margin_right = PAD
	panel.content_margin_bottom = PAD
	panel.content_margin_top = CopilotMd3Tokens.spacing("s")
	add_theme_stylebox_override("panel", panel)
	var title_font := CopilotMd3Tokens.font_regular()
	if title_font != null:
		add_theme_font_override("title_font", title_font)
	add_theme_font_size_override("title_font_size", CopilotMd3Tokens.type_size("headline-small"))
	add_theme_color_override("title_color", _scheme.color("on-surface"))
	ok_button_text = _ok_label
	_style_action(get_ok_button(), _ok_variant)
	_style_action(get_cancel_button(), CopilotMd3Button.VARIANT_TEXT)

func _style_action(button: Button, variant: String) -> void:
	if button == null:
		return
	var fill_role := ""
	var content_role := "primary"
	match variant:
		CopilotMd3Button.VARIANT_DANGER:
			fill_role = "error"
			content_role = "on-error"
		CopilotMd3Button.VARIANT_TEXT:
			fill_role = ""
			content_role = "primary"
		_:
			fill_role = "primary"
			content_role = "on-primary"
	var radius := CopilotMd3Tokens.corner_radius("full", Vector2(ACTION_HEIGHT, ACTION_HEIGHT))
	var fill_color := Color(0.0, 0.0, 0.0, 0.0)
	if not fill_role.is_empty():
		fill_color = _scheme.color(fill_role)
	var content_color := _scheme.color(content_role)
	var disabled_fill := Color(0.0, 0.0, 0.0, 0.0)
	if not fill_role.is_empty():
		disabled_fill = _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTAINER_OPACITY)
	button.custom_minimum_size = Vector2(ACTION_MIN_WIDTH, ACTION_HEIGHT)
	button.add_theme_constant_override("icon_max_width", 18)
	button.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("s"))
	CopilotMd3Tokens.apply_text(button, "label-large")
	button.add_theme_stylebox_override("normal", _action_box(fill_color, radius))
	button.add_theme_stylebox_override("hover", _action_box(_scheme.state_fill(fill_color, content_color, HOVER_OPACITY), radius))
	button.add_theme_stylebox_override("pressed", _action_box(_scheme.state_fill(fill_color, content_color, PRESSED_OPACITY), radius))
	button.add_theme_stylebox_override("focus", _action_focus_box(radius))
	button.add_theme_stylebox_override("disabled", _action_box(disabled_fill, radius))
	button.add_theme_color_override("font_color", content_color)
	button.add_theme_color_override("font_hover_color", content_color)
	button.add_theme_color_override("font_pressed_color", content_color)
	button.add_theme_color_override("font_focus_color", content_color)
	button.add_theme_color_override("font_disabled_color", _scheme.disabled_content("on-surface"))

func _action_box(fill_color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = CopilotMd3Tokens.spacing("l")
	sb.content_margin_right = CopilotMd3Tokens.spacing("l")
	sb.content_margin_top = CopilotMd3Tokens.spacing("xs")
	sb.content_margin_bottom = CopilotMd3Tokens.spacing("xs")
	return sb

func _action_focus_box(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(CopilotMd3Tokens.FOCUS_RING_WIDTH)
	sb.border_color = _scheme.color("primary")
	sb.set_corner_radius_all(radius)
	return sb

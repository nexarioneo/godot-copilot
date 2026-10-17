@tool
class_name CopilotMd3Checkbox
extends Button
# Material 3 checkbox: 18px box, corner 2, primary fill with a check tick when
# checked, 2px on-surface-variant border otherwise. The 40px target carries a
# circular state layer; the label sits to the right in body-large.

const TARGET := 40
const BOX := 18
const BOX_GAP := 8
const LAYER_RADIUS := 20.0
const RADIUS := 2
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10

var _scheme: CopilotMd3Scheme = null
var _held := false

var _unchecked_box: StyleBoxFlat = null
var _unchecked_hover_box: StyleBoxFlat = null
var _checked_box: StyleBoxFlat = null
var _disabled_box: StyleBoxFlat = null
var _focus_box: StyleBoxFlat = null
var _layout_box: StyleBoxEmpty = null
var _tick_texture: Texture2D = null

func configure(scheme: CopilotMd3Scheme, label: String = "", checked: bool = false) -> void:
	_scheme = scheme
	text = label
	button_pressed = checked
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func _ready() -> void:
	toggle_mode = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	if not toggled.is_connected(_on_toggled):
		toggled.connect(_on_toggled)
	if not button_down.is_connected(_on_button_down):
		button_down.connect(_on_button_down)
	if not button_up.is_connected(_on_button_up):
		button_up.connect(_on_button_up)
	if not mouse_entered.is_connected(_on_visual_changed):
		mouse_entered.connect(_on_visual_changed)
	if not mouse_exited.is_connected(_on_visual_changed):
		mouse_exited.connect(_on_visual_changed)
	if not focus_entered.is_connected(_on_visual_changed):
		focus_entered.connect(_on_visual_changed)
	if not focus_exited.is_connected(_on_visual_changed):
		focus_exited.connect(_on_visual_changed)
	_apply()

func _apply() -> void:
	if _scheme == null:
		return
	custom_minimum_size.y = TARGET
	CopilotMd3Tokens.apply_text(self, "body-large")

	_unchecked_box = _box(_scheme.color("on-surface-variant"), Color(0.0, 0.0, 0.0, 0.0))
	_unchecked_hover_box = _box(_scheme.color("on-surface"), Color(0.0, 0.0, 0.0, 0.0))
	_checked_box = _box(_scheme.color("primary"), _scheme.color("primary"))
	var disabled_fill := _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTAINER_OPACITY)
	var disabled_border := _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTENT_OPACITY)
	var disabled_checked := _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTENT_OPACITY)
	_disabled_box = StyleBoxFlat.new()
	_disabled_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_disabled_box.set_corner_radius_all(RADIUS)
	_disabled_box.set_border_width_all(2)
	if button_pressed:
		_disabled_box.bg_color = disabled_checked
		_disabled_box.border_color = disabled_checked
		# Tick color stays on-primary; the box itself fades with the disabled alpha.
	else:
		_disabled_box.border_color = disabled_fill
	_focus_box = StyleBoxFlat.new()
	_focus_box.draw_center = false
	_focus_box.set_corner_radius_all(RADIUS + 4)
	_focus_box.set_border_width_all(CopilotMd3Tokens.FOCUS_RING_WIDTH)
	_focus_box.border_color = _scheme.color("primary")

	_layout_box = StyleBoxEmpty.new()
	_layout_box.content_margin_left = TARGET + BOX_GAP
	_layout_box.content_margin_right = 0
	_layout_box.content_margin_top = 0
	_layout_box.content_margin_bottom = 0
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, _layout_box)

	var font_color := _scheme.color("on-surface")
	add_theme_color_override("font_color", font_color)
	add_theme_color_override("font_hover_color", font_color)
	add_theme_color_override("font_pressed_color", font_color)
	add_theme_color_override("font_focus_color", font_color)
	add_theme_color_override("font_disabled_color", _scheme.disabled_content("on-surface"))

	if _tick_texture == null:
		_tick_texture = CopilotMd3Icons.symbol("check")
	queue_redraw()

func _box(border_color: Color, fill_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill_color
	box.set_corner_radius_all(RADIUS)
	box.set_border_width_all(2)
	box.border_color = border_color
	return box

func _on_toggled(_pressed: bool) -> void:
	queue_redraw()

func _on_button_down() -> void:
	_held = true
	queue_redraw()

func _on_button_up() -> void:
	_held = false
	queue_redraw()

func _on_visual_changed() -> void:
	queue_redraw()

func _draw() -> void:
	if _scheme == null or _layout_box == null:
		return
	var box_pos := Vector2(float(TARGET - BOX) * 0.5, (size.y - float(BOX)) * 0.5)
	var box_rect := Rect2(box_pos, Vector2(BOX, BOX))

	# Circular state layer behind the box.
	var layer_alpha := 0.0
	if not disabled:
		if _held:
			layer_alpha = PRESSED_OPACITY
		elif is_hovered():
			layer_alpha = HOVER_OPACITY
	var layer_role := "on-surface"
	if button_pressed:
		layer_role = "primary"
	if layer_alpha > 0.0:
		draw_circle(Vector2(TARGET * 0.5, size.y * 0.5), LAYER_RADIUS, _scheme.alpha(layer_role, layer_alpha))

	var box: StyleBoxFlat = _unchecked_box
	if disabled:
		box = _disabled_box
	elif button_pressed:
		box = _checked_box
	elif is_hovered():
		box = _unchecked_hover_box
	draw_style_box(box, box_rect)

	if button_pressed and _tick_texture != null:
		draw_texture_rect(_tick_texture, box_rect, false, _scheme.color("surface") if disabled else _scheme.color("on-primary"))

	if has_focus():
		draw_style_box(_focus_box, box_rect.grow(float(CopilotMd3Tokens.FOCUS_RING_OFFSET)))

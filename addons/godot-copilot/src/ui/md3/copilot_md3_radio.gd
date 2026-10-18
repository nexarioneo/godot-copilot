@tool
class_name CopilotMd3Radio
extends Button
# Material 3 radio option row: 20px radio circle + title (body-large) and
# optional supporting text (body-small) in a clickable row. Exclusivity is
# managed by the caller through set_selected().

const CIRCLE := 20.0
const DOT := 10.0
const PAD_H := 12
const PAD_V := 8
const GAP := 16
const HEIGHT_ONE_LINE := 48
const HEIGHT_TWO_LINE := 64
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10

var _scheme: CopilotMd3Scheme = null
var _title := ""
var _supporting := ""
var _selected := false
var _hovered := false
var _held := false
var _touch_device := false

var _text_column: VBoxContainer = null
var _title_label: Label = null
var _supporting_label: Label = null

func configure(scheme: CopilotMd3Scheme, title: String, supporting: String = "", selected: bool = false) -> void:
	_scheme = scheme
	_title = title
	_supporting = supporting
	_selected = selected
	if is_node_ready():
		_build_ui()
		_refresh_ui()
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_selected(selected: bool) -> void:
	_selected = selected
	_apply()
	queue_redraw()

func is_selected() -> bool:
	return _selected

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	# Touch devices keep the pressed state layer (shown while the finger is
	# down) but never show a hover or focus halo, which would linger after a
	# tap and stack extra circles onto the radio.
	_touch_device = DisplayServer.is_touchscreen_available()
	_build_ui()
	_refresh_ui()
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw()
	)
	button_down.connect(func() -> void:
		_held = true
		queue_redraw()
	)
	button_up.connect(func() -> void:
		_held = false
		queue_redraw()
	)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_apply()

func _build_ui() -> void:
	if _text_column != null:
		return
	_text_column = VBoxContainer.new()
	_text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text_column.offset_left = PAD_H + int(CIRCLE) + GAP
	_text_column.offset_right = -PAD_H
	_text_column.offset_top = PAD_V
	_text_column.offset_bottom = -PAD_V
	_text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_text_column.add_theme_constant_override("separation", 0)
	add_child(_text_column)

	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text_column.add_child(_title_label)

	_supporting_label = Label.new()
	_supporting_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_supporting_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text_column.add_child(_supporting_label)

func _refresh_ui() -> void:
	if _title_label == null:
		return
	_title_label.text = _title
	_supporting_label.text = _supporting
	_supporting_label.visible = not _supporting.is_empty()
	custom_minimum_size.y = HEIGHT_TWO_LINE if _supporting_label.visible else HEIGHT_ONE_LINE
	CopilotMd3Tokens.apply_text(_title_label, "body-large")
	CopilotMd3Tokens.apply_text(_supporting_label, "body-small")

func _apply() -> void:
	if _scheme == null:
		return
	if _title_label != null:
		var title_color := _scheme.color("on-surface")
		var supporting_color := _scheme.color("on-surface-variant")
		if disabled:
			title_color = _scheme.disabled_content("on-surface")
			supporting_color = _scheme.disabled_content("on-surface")
		_title_label.add_theme_color_override("font_color", title_color)
		_supporting_label.add_theme_color_override("font_color", supporting_color)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	queue_redraw()

func _draw() -> void:
	if _scheme == null:
		return
	var center := Vector2(PAD_H + CIRCLE * 0.5, size.y * 0.5)
	if not disabled:
		var layer_alpha := 0.0
		if _held:
			layer_alpha = PRESSED_OPACITY
		elif not _touch_device and (_hovered or has_focus()):
			layer_alpha = HOVER_OPACITY
		if layer_alpha > 0.0:
			draw_circle(center, CIRCLE * 0.5 + 8.0, _scheme.alpha("primary", layer_alpha))
	var ring_color := _scheme.color("primary") if _selected else _scheme.color("on-surface-variant")
	if disabled:
		ring_color = _scheme.disabled_content("on-surface")
	draw_arc(center, CIRCLE * 0.5 - 1.0, 0.0, TAU, 32, ring_color, 2.0, true)
	if _selected:
		draw_circle(center, DOT * 0.5, ring_color)
	if has_focus() and CopilotMd3Tokens.focus_ring_visible():
		draw_arc(center, CIRCLE * 0.5 + 4.0, 0.0, TAU, 32, _scheme.color("primary"), 2.0, true)

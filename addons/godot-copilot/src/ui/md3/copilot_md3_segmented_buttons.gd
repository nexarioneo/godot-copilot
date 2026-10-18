@tool
class_name CopilotMd3SegmentedButtons
extends PanelContainer
# Material 3 segmented button: an outlined group (full round shape, 40 high)
# split by 1px dividers; the selected segment fills with secondary-container.
# Segments are plain Buttons styled from the scheme; selection is owned by the
# component and reported through item_selected.

signal item_selected(index: int)

const HEIGHT := 40
const PAD_H := 16
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10

var _scheme: CopilotMd3Scheme = null
var _items: PackedStringArray = PackedStringArray()
var _selected := 0
var _row: HBoxContainer = null
var _buttons: Array[Button] = []
var _dividers: Array[CopilotMd3Divider] = []
var _boxes: Array[Dictionary] = []
var _content_colors: Array[Color] = []

func configure(scheme: CopilotMd3Scheme, items: PackedStringArray, selected: int = 0) -> void:
	_scheme = scheme
	_items = items
	_selected = clampi(selected, 0, maxi(items.size() - 1, 0))
	_build_ui()
	_rebuild_segments()
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	for divider in _dividers:
		divider.set_scheme(scheme)
	_apply()

func set_items(items: PackedStringArray, selected: int = 0) -> void:
	_items = items
	_selected = clampi(selected, 0, maxi(items.size() - 1, 0))
	_build_ui()
	_rebuild_segments()
	_apply()

func select(index: int) -> void:
	_selected = clampi(index, 0, maxi(_items.size() - 1, 0))
	_update_segment_styles()

func get_selected() -> int:
	return _selected

func set_item_disabled(index: int, is_disabled: bool) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_buttons[index].disabled = is_disabled
	_update_segment_styles()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_build_ui()
	_rebuild_segments()
	_apply()

func _build_ui() -> void:
	if _row != null:
		return
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 0)
	_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_row)

func _rebuild_segments() -> void:
	if _row == null:
		return
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_dividers.clear()
	_boxes.clear()
	_content_colors.clear()
	for i in range(_items.size()):
		if i > 0:
			var divider := CopilotMd3Divider.new()
			divider.configure(_scheme, 8, 8, true)
			_row.add_child(divider)
			_dividers.append(divider)
		var segment := Button.new()
		segment.text = _items[i]
		segment.focus_mode = Control.FOCUS_ALL
		segment.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		segment.custom_minimum_size = Vector2(0, HEIGHT)
		segment.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("s"))
		segment.add_theme_constant_override("icon_max_width", 18)
		segment.pressed.connect(_on_segment_pressed.bind(i))
		CopilotMd3Tokens.apply_text(segment, "label-large")
		_row.add_child(segment)
		_buttons.append(segment)
		# Stylebox overrides are registered once per segment; selection changes
		# only mutate the cached boxes (recreating them on every tap churns the
		# theme cache and makes the group feel stuck).
		var boxes := _make_boxes(i, _items.size())
		_boxes.append(boxes)
		_content_colors.append(Color(0.0, 0.0, 0.0, 0.0))
		segment.add_theme_stylebox_override("normal", boxes["normal"])
		segment.add_theme_stylebox_override("hover", boxes["hover"])
		segment.add_theme_stylebox_override("pressed", boxes["pressed"])
		segment.add_theme_stylebox_override("focus", boxes["focus"])
		segment.add_theme_stylebox_override("disabled", boxes["disabled"])
	_update_segment_styles()

func _on_segment_pressed(index: int) -> void:
	if _selected == index:
		return
	_selected = index
	_update_segment_styles()
	item_selected.emit(index)

func _apply() -> void:
	if _scheme == null:
		return
	custom_minimum_size.y = HEIGHT
	var panel := _scheme.box("", HEIGHT / 2, "outline", 1)
	add_theme_stylebox_override("panel", panel)
	_update_segment_styles()

func _update_segment_styles() -> void:
	if _scheme == null or _boxes.size() != _buttons.size():
		return
	for i in range(_buttons.size()):
		var segment := _buttons[i]
		var boxes: Dictionary = _boxes[i]
		var is_selected := _selected == i
		var content_role := "on-secondary-container" if is_selected else "on-surface"
		var content_color := _scheme.color(content_role)
		var base_fill := _scheme.color("secondary-container") if is_selected else Color(0.0, 0.0, 0.0, 0.0)
		var disabled_fill := Color(0.0, 0.0, 0.0, 0.0)
		if is_selected:
			disabled_fill = _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTAINER_OPACITY)
		(boxes["normal"] as StyleBoxFlat).bg_color = base_fill
		(boxes["hover"] as StyleBoxFlat).bg_color = _scheme.state_fill(base_fill, content_color, HOVER_OPACITY)
		(boxes["pressed"] as StyleBoxFlat).bg_color = _scheme.state_fill(base_fill, content_color, PRESSED_OPACITY)
		(boxes["disabled"] as StyleBoxFlat).bg_color = disabled_fill
		(boxes["focus"] as StyleBoxFlat).border_color = _scheme.color("primary")
		# Only the colors of the cached boxes change here; mutating them and
		# asking for a redraw avoids rebuilding theme items on every tap.
		if _content_colors[i] != content_color:
			_content_colors[i] = content_color
			segment.add_theme_color_override("font_color", content_color)
			segment.add_theme_color_override("font_hover_color", content_color)
			segment.add_theme_color_override("font_pressed_color", content_color)
			segment.add_theme_color_override("font_focus_color", content_color)
			segment.add_theme_color_override("font_disabled_color", _scheme.disabled_content("on-surface"))
			segment.add_theme_color_override("icon_normal_color", content_color)
			segment.add_theme_color_override("icon_hover_color", content_color)
			segment.add_theme_color_override("icon_pressed_color", content_color)
			segment.add_theme_color_override("icon_focus_color", content_color)
			segment.add_theme_color_override("icon_disabled_color", _scheme.disabled_content("on-surface"))
		segment.queue_redraw()
	for i in range(_dividers.size()):
		var divider := _dividers[i]
		divider.visible = _selected != i and _selected != i + 1

func _make_boxes(index: int, count: int) -> Dictionary:
	var radius_left := HEIGHT / 2 if index == 0 else 0
	var radius_right := HEIGHT / 2 if index == count - 1 else 0
	return {
		"normal": _segment_box(radius_left, radius_right),
		"hover": _segment_box(radius_left, radius_right),
		"pressed": _segment_box(radius_left, radius_right),
		"focus": _focus_box(radius_left, radius_right),
		"disabled": _segment_box(radius_left, radius_right),
	}

func _segment_box(radius_left: int, radius_right: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	sb.corner_radius_top_left = radius_left
	sb.corner_radius_bottom_left = radius_left
	sb.corner_radius_top_right = radius_right
	sb.corner_radius_bottom_right = radius_right
	sb.content_margin_left = PAD_H
	sb.content_margin_right = PAD_H
	sb.content_margin_top = CopilotMd3Tokens.spacing("xs")
	sb.content_margin_bottom = CopilotMd3Tokens.spacing("xs")
	return sb

func _focus_box(radius_left: int, radius_right: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	if not CopilotMd3Tokens.focus_ring_visible():
		return sb
	sb.set_border_width_all(CopilotMd3Tokens.FOCUS_RING_WIDTH)
	sb.border_color = _scheme.color("primary")
	sb.corner_radius_top_left = radius_left
	sb.corner_radius_bottom_left = radius_left
	sb.corner_radius_top_right = radius_right
	sb.corner_radius_bottom_right = radius_right
	return sb

@tool
class_name CopilotMd3Menu
extends PopupPanel
# Material 3 menu: surface-container-high panel (extra-small corner, elevation
# 2, 8px padding) with dense 48px list items, an optional 40px search field
# when the list is long, an optional check indicator for the current item,
# danger items (error color), separators, and keyboard navigation
# (up/down/escape). Items are addressed by integer id; pass id -1 to
# auto-assign the next one.

signal item_selected(id: int)

const PAD := 8
const MIN_WIDTH := 200
const MAX_LIST_HEIGHT := 320
const SEPARATOR_INSET := 8

var _scheme: CopilotMd3Scheme = null
var _searchable := false
var _next_id := 1
var _root: VBoxContainer = null
var _search: CopilotMd3TextField = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _rows: Dictionary = {}
var _order: Array[int] = []
var _separators: Array[Control] = []
var _checks: Dictionary = {}

func configure(scheme: CopilotMd3Scheme, searchable: bool = false) -> void:
	_scheme = scheme
	_searchable = searchable
	_build_ui()
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	if _search != null:
		_search.set_scheme(scheme)
	for id in _order:
		var row: Variant = _rows.get(id, {}).get("row")
		if row != null and is_instance_valid(row):
			row.set_scheme(scheme)
	for separator in _separators:
		if is_instance_valid(separator):
			(separator as CopilotMd3Divider).set_scheme(scheme)
	for id in _checks.keys():
		var check: Variant = _checks[id]
		if check != null and is_instance_valid(check):
			(check as TextureRect).modulate = scheme.color("primary")
	_apply()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_build_ui()
	_apply()

func clear_items() -> void:
	for id in _order:
		var row: Variant = _rows.get(id, {}).get("row")
		if row != null and is_instance_valid(row):
			(row as Node).queue_free()
	_rows.clear()
	_order.clear()
	for id in _checks.keys():
		var check: Variant = _checks[id]
		if check != null and is_instance_valid(check):
			(check as Node).queue_free()
	_checks.clear()
	for separator in _separators:
		if is_instance_valid(separator):
			separator.queue_free()
	_separators.clear()
	_next_id = 1
	_update_scroll_cap()

func add_item(label: String, id: int = -1, icon_name: String = "", editor_fallback: String = "", danger: bool = false) -> int:
	_build_ui()
	if id < 0:
		id = _next_id
	_next_id = maxi(_next_id, id + 1)
	var row := CopilotMd3ListItem.new()
	_list.add_child(row)
	row.configure(_scheme, label, "", icon_name, editor_fallback)
	row.set_dense(true)
	if danger:
		row.set_content_role("error")
	row.tooltip_text = label
	row.pressed.connect(_on_row_pressed.bind(id))
	row.gui_input.connect(_on_row_input.bind(id))
	_rows[id] = {"row": row, "label": label}
	_order.append(id)
	_update_scroll_cap()
	return id

func add_separator() -> void:
	_build_ui()
	var divider := CopilotMd3Divider.new()
	_list.add_child(divider)
	divider.configure(_scheme, SEPARATOR_INSET, SEPARATOR_INSET)
	_separators.append(divider)
	_update_scroll_cap()

func set_checked_id(id: int) -> void:
	for other_id in _checks.keys():
		if other_id == id:
			continue
		var old_check: Variant = _checks[other_id]
		if old_check != null and is_instance_valid(old_check):
			(old_check as Node).queue_free()
		_checks.erase(other_id)
	if id < 0 or not _rows.has(id) or _checks.has(id):
		return
	var check := TextureRect.new()
	check.texture = CopilotMd3Icons.symbol("check_circle")
	check.custom_minimum_size = Vector2(18, 18)
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _scheme != null:
		check.modulate = _scheme.color("primary")
	var row: Variant = _rows[id].get("row")
	if row != null:
		(row as CopilotMd3ListItem).add_trailing(check)
	_checks[id] = check

func popup_on(anchor: Control) -> void:
	if anchor == null:
		return
	_build_ui()
	_update_scroll_cap()
	var needed := _root.get_combined_minimum_size() + Vector2(float(PAD * 2), float(PAD * 2))
	var target := Vector2i(maxi(int(ceilf(needed.x)), MIN_WIDTH), int(ceilf(needed.y)))
	var anchor_pos := anchor.get_global_position()
	var pos := anchor_pos + Vector2(0.0, anchor.size.y + 4.0)
	var bounds := Rect2(Vector2.ZERO, anchor.get_viewport().get_visible_rect().size)
	pos.x = clampf(pos.x, bounds.position.x + 4.0, maxf(bounds.position.x + 4.0, bounds.end.x - float(target.x) - 4.0))
	if pos.y + float(target.y) > bounds.end.y - 4.0:
		pos.y = anchor_pos.y - float(target.y) - 4.0
	pos.y = clampf(pos.y, bounds.position.y + 4.0, maxf(bounds.position.y + 4.0, bounds.end.y - float(target.y) - 4.0))
	popup(Rect2i(Vector2i(pos), target))
	_focus_first.call_deferred()

func _build_ui() -> void:
	if _root != null:
		return
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	add_child(_root)
	if _searchable:
		_search = CopilotMd3TextField.new()
		if _scheme != null:
			_search.configure(_scheme, "Search", CopilotMd3TextField.VARIANT_OUTLINED, 40)
		_search.text_changed.connect(_on_search_changed)
		_search.gui_input.connect(_on_search_input)
		_root.add_child(_search)
	_scroll = ScrollContainer.new()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	_scroll.add_child(_list)

func _apply() -> void:
	if _scheme == null or _root == null:
		return
	var panel := _scheme.box("surface-container-high", CopilotMd3Tokens.corner_radius("extra-small", Vector2.ZERO), "", 0, 2)
	panel.content_margin_left = PAD
	panel.content_margin_right = PAD
	panel.content_margin_top = PAD
	panel.content_margin_bottom = PAD
	add_theme_stylebox_override("panel", panel)
	_root.custom_minimum_size.x = MIN_WIDTH

func _update_scroll_cap() -> void:
	if _scroll == null or _list == null:
		return
	var needed := _list.get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = minf(needed, float(MAX_LIST_HEIGHT))

func _visible_row_ids() -> Array:
	var result: Array = []
	for id in _order:
		var row: Variant = _rows.get(id, {}).get("row")
		if row != null and is_instance_valid(row) and (row as Control).visible:
			result.append(id)
	return result

func _focus_first() -> void:
	if _search != null and _search.visible:
		_search.grab_focus()
		return
	var ids := _visible_row_ids()
	if ids.is_empty():
		return
	var row: Variant = _rows[ids[0]].get("row")
	if row != null:
		(row as CopilotMd3ListItem).grab_focus()

func _move_focus(id: int, delta: int) -> void:
	var ids := _visible_row_ids()
	var index := ids.find(id)
	if index < 0:
		return
	var next := clampi(index + delta, 0, ids.size() - 1)
	var row: Variant = _rows[ids[next]].get("row")
	if row != null:
		(row as CopilotMd3ListItem).grab_focus()

func _on_row_pressed(id: int) -> void:
	hide()
	item_selected.emit(id)

func _on_row_input(event: InputEvent, id: int) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var handled := true
	match key_event.keycode:
		KEY_DOWN:
			_move_focus(id, 1)
		KEY_UP:
			_move_focus(id, -1)
		KEY_ESCAPE:
			hide()
		_:
			handled = false
	if handled:
		var row: Variant = _rows.get(id, {}).get("row")
		if row != null:
			(row as Control).accept_event()

func _on_search_changed(text: String) -> void:
	var query := text.strip_edges().to_lower()
	for id in _order:
		var entry: Dictionary = _rows.get(id, {})
		var row: Variant = entry.get("row")
		if row == null or not is_instance_valid(row):
			continue
		var label := str(entry.get("label", "")).to_lower()
		(row as Control).visible = query.is_empty() or label.contains(query)
	for separator in _separators:
		if is_instance_valid(separator):
			separator.visible = query.is_empty()
	_update_scroll_cap()
	if not query.is_empty():
		_focus_first.call_deferred()

func _on_search_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_DOWN:
			var ids := _visible_row_ids()
			if not ids.is_empty():
				var row: Variant = _rows[ids[0]].get("row")
				if row != null:
					(row as CopilotMd3ListItem).grab_focus()
				_search.accept_event()
		KEY_ESCAPE:
			hide()
			_search.accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			var ids := _visible_row_ids()
			if not ids.is_empty():
				_on_row_pressed(ids[0])
			_search.accept_event()

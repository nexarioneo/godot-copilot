@tool
class_name CopilotMd3Tabs
extends TabContainer
# Material 3 primary tabs: no container fill, a 3px primary bottom indicator
# on the selected tab, label-large text in on-surface-variant, and a small
# surface gap between the tab bar and the page content. The indicator slides
# between tabs and the incoming page fades in (250ms / 200ms). The indicator is
# drawn by this control at the bar's bottom, so tab rects are translated out of
# the internal container before use.

const INDICATOR_HEIGHT := 3.0

var _scheme: CopilotMd3Scheme = null
var _indicator_x := -1.0
var _indicator_width := 0.0
var _indicator_tween: Tween = null
var _page_tween: Tween = null

func configure(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	tab_changed.connect(_on_tab_changed)
	resized.connect(_snap_indicator)
	_apply()
	_snap_indicator.call_deferred()

func _apply() -> void:
	if _scheme == null:
		return
	var font := CopilotMd3Tokens.font_medium()
	if font != null:
		add_theme_font_override("font", font)
		add_theme_font_override("tab_font", font)
	var font_size := CopilotMd3Tokens.type_size("label-large")
	add_theme_font_size_override("font_size", font_size)
	add_theme_font_size_override("tab_font_size", font_size)
	add_theme_color_override("font_selected_color", _scheme.color("primary"))
	add_theme_color_override("font_unselected_color", _scheme.color("on-surface-variant"))
	add_theme_color_override("font_hovered_color", _scheme.color("on-surface"))
	add_theme_color_override("font_disabled_color", _scheme.disabled_content("on-surface"))
	add_theme_constant_override("side_margin", 0)
	if not CopilotMd3Tokens.focus_ring_visible():
		var no_focus := StyleBoxEmpty.new()
		add_theme_stylebox_override("focus", no_focus)
		add_theme_stylebox_override("tab_focus", no_focus)

	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	# No border on the selected tab: the indicator is drawn by this control so
	# it can animate between tabs.
	var selected := _tab_box(transparent)
	var unselected := _tab_box(transparent)
	var hovered := _tab_box(_scheme.alpha("on-surface", 0.08))
	hovered.corner_radius_top_left = 3
	hovered.corner_radius_top_right = 3
	var disabled := _tab_box(transparent)
	add_theme_stylebox_override("tab_selected", selected)
	add_theme_stylebox_override("tab_unselected", unselected)
	add_theme_stylebox_override("tab_hovered", hovered)
	add_theme_stylebox_override("tab_disabled", disabled)
	add_theme_stylebox_override("tabbar_background", _tab_box(transparent))
	var panel := StyleBoxEmpty.new()
	panel.content_margin_top = CopilotMd3Tokens.spacing("s")
	add_theme_stylebox_override("panel", panel)
	queue_redraw()

func _draw() -> void:
	if _scheme == null or _indicator_x < 0.0 or _indicator_width <= 0.0:
		return
	var bar := get_tab_bar()
	if bar == null:
		return
	var limit := _bar_offset().y + bar.size.y
	var rect := Rect2(
		Vector2(_indicator_x, limit - INDICATOR_HEIGHT),
		Vector2(_indicator_width, INDICATOR_HEIGHT)
	)
	draw_rect(rect, _scheme.color("primary"))

func _tab_rect(index: int) -> Rect2:
	var bar := get_tab_bar()
	if bar == null or index < 0 or index >= get_tab_count():
		return Rect2()
	var local := bar.get_tab_rect(index)
	local.position += _bar_offset()
	return local

func _bar_offset() -> Vector2:
	# The internal TabBar lives in an HBoxContainer that the container offsets by
	# the tabbar style margins (16 left, 12 top in this skin); the bar's own
	# position is relative to that container, so the ancestor offsets have to be
	# added before drawing in this control's local space.
	var bar := get_tab_bar()
	if bar == null:
		return Vector2()
	var offset := bar.position
	var node := bar.get_parent_control()
	while node != null and node != self:
		offset += node.position
		node = node.get_parent_control()
	return offset

func _snap_indicator() -> void:
	var target := _tab_rect(current_tab)
	if target.size.x <= 0.0:
		return
	_indicator_x = target.position.x
	_indicator_width = target.size.x
	queue_redraw()

func _on_tab_changed(_tab: int) -> void:
	_animate_indicator()
	_fade_in_current_page()

func _animate_indicator() -> void:
	var target := _tab_rect(current_tab)
	if target.size.x <= 0.0:
		return
	if _indicator_x < 0.0:
		_snap_indicator()
		return
	if not is_inside_tree():
		_snap_indicator()
		return
	if _indicator_tween != null and _indicator_tween.is_valid():
		_indicator_tween.kill()
	var from := Vector2(_indicator_x, _indicator_width)
	var to := Vector2(target.position.x, target.size.x)
	var apply := func(weight: float) -> void:
		var current := from.lerp(to, weight)
		_indicator_x = current.x
		_indicator_width = current.y
		queue_redraw()
	_indicator_tween = create_tween()
	CopilotMd3Motion.animate_eased(
		_indicator_tween,
		apply,
		0.0,
		1.0,
		CopilotMd3Motion.duration_seconds("medium1"),
		"emphasized-decelerate"
	)

func _fade_in_current_page() -> void:
	var page := get_current_tab_control()
	if page == null or not is_inside_tree():
		return
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	page.modulate.a = 0.0
	var apply := func(weight: float) -> void:
		page.modulate.a = weight
	_page_tween = create_tween()
	CopilotMd3Motion.animate_eased(
		_page_tween,
		apply,
		0.0,
		1.0,
		CopilotMd3Motion.duration_seconds("short4"),
		"standard-decelerate"
	)

func _tab_box(fill_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill_color
	box.content_margin_left = CopilotMd3Tokens.spacing("l")
	box.content_margin_right = CopilotMd3Tokens.spacing("l")
	box.content_margin_top = CopilotMd3Tokens.spacing("m")
	box.content_margin_bottom = CopilotMd3Tokens.spacing("s") + int(INDICATOR_HEIGHT)
	return box

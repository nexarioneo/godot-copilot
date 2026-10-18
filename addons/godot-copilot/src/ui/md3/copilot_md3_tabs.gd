@tool
class_name CopilotMd3Tabs
extends TabContainer
# Material 3 primary tabs: no container fill, a 3px primary bottom indicator
# on the selected tab, label-large text in on-surface-variant, and a small
# surface gap between the tab bar and the page content. The indicator slides
# between tabs and the incoming page fades in (250ms / 200ms). Tab labels are
# drawn by this control, centered above the indicator; the engine text is kept
# for width measurement only so squeezed bars cannot sink the labels.

const INDICATOR_HEIGHT := 3.0

var _scheme: CopilotMd3Scheme = null
var _indicator_x := -1.0
var _indicator_width := 0.0
var _indicator_tween: Tween = null
var _page_tween: Tween = null
var _label_font: Font = null
var _label_font_size := 14

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
	if font == null:
		font = get_theme_default_font()
	_label_font = font
	_label_font_size = CopilotMd3Tokens.type_size("label-large")
	if font != null:
		add_theme_font_override("font", font)
		add_theme_font_override("tab_font", font)
	add_theme_font_size_override("font_size", _label_font_size)
	add_theme_font_size_override("tab_font_size", _label_font_size)
	# The engine keeps the tab text for width measurement only: the labels are
	# drawn by this control so they stay centered above the indicator instead of
	# sinking into it when the bar is squeezed.
	var invisible := Color(0.0, 0.0, 0.0, 0.0)
	add_theme_color_override("font_selected_color", invisible)
	add_theme_color_override("font_unselected_color", invisible)
	add_theme_color_override("font_hovered_color", invisible)
	add_theme_color_override("font_disabled_color", invisible)
	add_theme_color_override("font_outline_color", invisible)
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
	if _scheme == null:
		return
	_draw_tab_labels()
	if _indicator_x < 0.0 or _indicator_width <= 0.0:
		return
	var bar := get_tab_bar()
	if bar == null:
		return
	var limit := bar.position.y + bar.size.y
	var rect := Rect2(
		Vector2(_indicator_x, limit - INDICATOR_HEIGHT),
		Vector2(_indicator_width, INDICATOR_HEIGHT)
	)
	draw_rect(rect, _scheme.color("primary"))

func _draw_tab_labels() -> void:
	var bar := get_tab_bar()
	if bar == null or _label_font == null:
		return
	for i in range(get_tab_count()):
		if bar.is_tab_hidden(i):
			continue
		var text := bar.get_tab_title(i)
		if text.is_empty():
			continue
		var rect := _tab_rect(i)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var color := _scheme.color("on-surface-variant")
		if bar.is_tab_disabled(i):
			color = _scheme.disabled_content("on-surface")
		elif i == current_tab:
			color = _scheme.color("primary")
		# Center the label in the area above the indicator; the engine baseline
		# (stylebox margins) is not stable once the bar gets squeezed.
		var usable := maxf(rect.size.y - INDICATOR_HEIGHT, 0.0)
		var text_height := _label_font.get_height(_label_font_size)
		var baseline := rect.position.y + maxf((usable - text_height) * 0.5, 0.0)
		baseline += _label_font.get_ascent(_label_font_size)
		draw_string(
			_label_font,
			Vector2(rect.position.x, baseline),
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			_label_font_size,
			color
		)

func _tab_rect(index: int) -> Rect2:
	var bar := get_tab_bar()
	if bar == null or index < 0 or index >= get_tab_count():
		return Rect2()
	var local := bar.get_tab_rect(index)
	local.position += bar.position
	return local

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

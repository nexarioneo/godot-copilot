@tool
class_name CopilotMd3Tabs
extends TabContainer
# Material 3 primary tabs: no container fill, a 3px primary bottom indicator
# on the selected tab, label-large text in on-surface-variant, and a small
# surface gap between the tab bar and the page content.

var _scheme: CopilotMd3Scheme = null

func configure(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
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

	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	var selected := _tab_box(transparent)
	selected.border_width_bottom = 3
	selected.border_color = _scheme.color("primary")
	selected.corner_radius_top_left = 3
	selected.corner_radius_top_right = 3
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

func _tab_box(fill_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill_color
	box.content_margin_left = CopilotMd3Tokens.spacing("l")
	box.content_margin_right = CopilotMd3Tokens.spacing("l")
	box.content_margin_top = CopilotMd3Tokens.spacing("m")
	box.content_margin_bottom = CopilotMd3Tokens.spacing("s") + 3
	return box

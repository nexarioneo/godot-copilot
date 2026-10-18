@tool
class_name CopilotMd3ListItem
extends Button
# Material 3 list item: optional 24px leading icon, title (body-large) with
# optional supporting text (body-medium), and a trailing widget slot. One-line
# height 56, two-line 72. Selected rows use secondary-container (plugin
# selection convention). Trailing controls keep their own input handling.

const HEIGHT_ONE_LINE := 56
const HEIGHT_TWO_LINE := 72
const HEIGHT_DENSE := 48
const PAD_H := 16
const PAD_V := 8
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10

var _scheme: CopilotMd3Scheme = null
var _title := ""
var _subtitle := ""
var _icon_name := ""
var _editor_fallback := ""
var _selected := false
var _dense := false
var _content_role := ""
var _leading: Control = null
var _subtitle_style := "body-medium"
var _title_mono := false
var _subtitle_mono := false

var _row: HBoxContainer = null
var _icon_rect: TextureRect = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _trailing: HBoxContainer = null

func configure(scheme: CopilotMd3Scheme, title: String, subtitle: String = "", icon_name: String = "", editor_fallback: String = "") -> void:
	_scheme = scheme
	_title = title
	_subtitle = subtitle
	_icon_name = icon_name
	_editor_fallback = editor_fallback
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

func set_dense(dense: bool) -> void:
	_dense = dense
	_refresh_ui()
	_apply()

func set_content_role(role: String) -> void:
	_content_role = role
	_apply()

func set_title(title: String) -> void:
	_title = title
	_refresh_ui()

func set_subtitle(subtitle: String) -> void:
	_subtitle = subtitle
	_refresh_ui()

func set_subtitle_style(style: String) -> void:
	_subtitle_style = style
	_refresh_ui()

func set_title_mono(mono: bool) -> void:
	_title_mono = mono
	_refresh_ui()

func set_subtitle_mono(mono: bool) -> void:
	_subtitle_mono = mono
	_refresh_ui()

func set_leading(control: Control) -> void:
	# Replaces the leading icon slot with a custom control (switch, badge, ...).
	_build_ui()
	if _leading != null and is_instance_valid(_leading):
		_leading.queue_free()
	_leading = control
	_row.add_child(control)
	_row.move_child(control, 0)
	_icon_rect.visible = false

func add_trailing(control: Control) -> void:
	_build_ui()
	_trailing.add_child(control)

func get_text_column() -> VBoxContainer:
	_build_ui()
	return _title_label.get_parent() as VBoxContainer

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_build_ui()
	_refresh_ui()
	_apply()

func _build_ui() -> void:
	if _row != null:
		return
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("l"))
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row.offset_left = PAD_H
	_row.offset_right = -PAD_H
	_row.offset_top = PAD_V
	_row.offset_bottom = -PAD_V

	_icon_rect = TextureRect.new()
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon_rect.custom_minimum_size = Vector2(24, 24)
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_icon_rect)

	var text_column := VBoxContainer.new()
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.add_theme_constant_override("separation", 0)
	_row.add_child(text_column)

	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_column.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_column.add_child(_subtitle_label)

	_trailing = HBoxContainer.new()
	_trailing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trailing.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	_row.add_child(_trailing)

func _refresh_ui() -> void:
	if _title_label == null:
		return
	_title_label.text = _title
	_subtitle_label.text = _subtitle
	_subtitle_label.visible = not _subtitle.is_empty()
	if _dense:
		custom_minimum_size.y = HEIGHT_DENSE
	elif _subtitle_label.visible:
		custom_minimum_size.y = HEIGHT_TWO_LINE
	else:
		custom_minimum_size.y = HEIGHT_ONE_LINE
	CopilotMd3Tokens.apply_text(_title_label, "body-large")
	CopilotMd3Tokens.apply_text(_subtitle_label, _subtitle_style)
	var mono := CopilotMd3Tokens.font_mono()
	if mono != null:
		if _title_mono:
			_title_label.add_theme_font_override("font", mono)
		if _subtitle_mono:
			_subtitle_label.add_theme_font_override("font", mono)
	if _scheme != null:
		_title_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
		_subtitle_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	var texture := CopilotMd3Icons.symbol(_icon_name) if not _icon_name.is_empty() else null
	if texture == null and not _editor_fallback.is_empty() and has_theme_icon(_editor_fallback, "EditorIcons"):
		texture = get_theme_icon(_editor_fallback, "EditorIcons")
	_icon_rect.texture = texture
	_icon_rect.visible = texture != null and _leading == null

func _apply() -> void:
	if _scheme == null:
		return
	if _row != null:
		_refresh_ui()
	var radius := CopilotMd3Tokens.corner_radius("small", size)
	var fill_color := Color(0.0, 0.0, 0.0, 0.0)
	var content_role := "on-surface"
	if _selected:
		fill_color = _scheme.color("secondary-container")
		content_role = "on-secondary-container"
	var content_color := _scheme.color(content_role)
	var title_color := content_color
	if not _content_role.is_empty():
		title_color = _scheme.color(_content_role)
	var disabled_content := _scheme.disabled_content("on-surface")

	add_theme_stylebox_override("normal", _row_box(fill_color, radius))
	add_theme_stylebox_override("hover", _row_box(_scheme.state_fill(fill_color, content_color, HOVER_OPACITY), radius))
	add_theme_stylebox_override("pressed", _row_box(_scheme.state_fill(fill_color, content_color, PRESSED_OPACITY), radius))
	add_theme_stylebox_override("focus", _focus_box(radius))
	add_theme_stylebox_override("disabled", _row_box(fill_color, radius))

	add_theme_color_override("font_disabled_color", disabled_content)

	if _title_label != null:
		_title_label.add_theme_color_override("font_color", title_color)
		_subtitle_label.add_theme_color_override("font_color", content_color if _selected else _scheme.color("on-surface-variant"))
	if _icon_rect != null and _icon_rect.texture != null:
		_icon_rect.modulate = _scheme.color(content_role) if _selected else _scheme.color("on-surface-variant")

func _row_box(fill_color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = PAD_H
	sb.content_margin_right = PAD_H
	sb.content_margin_top = PAD_V
	sb.content_margin_bottom = PAD_V
	return sb

func _focus_box(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	if not CopilotMd3Tokens.focus_ring_visible():
		return sb
	sb.set_border_width_all(CopilotMd3Tokens.FOCUS_RING_WIDTH)
	sb.border_color = _scheme.color("primary")
	sb.set_corner_radius_all(radius)
	return sb

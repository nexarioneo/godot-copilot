@tool
class_name CopilotProviderRow
extends PanelContainer
# Provider list row: logo/initials badge + name + key status. Click = select.

signal pressed(provider_name: String)

var provider_name := ""

var _badge_box: PanelContainer
var _badge_icon: TextureRect
var _badge_label: Label
var _name_label: Label
var _status_label: Label
var _selected := false

func _ready() -> void:
	_build_ui()
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(p_provider_name: String, kind: String, status_text: String, has_keys: bool, icon_path: String, selected: bool) -> void:
	_build_ui()
	provider_name = p_provider_name
	_selected = selected
	_name_label.text = p_provider_name
	_status_label.text = status_text
	_status_label.add_theme_color_override(
		"font_color",
		CopilotTheme.font_placeholder_color(self) if not has_keys else CopilotTheme.success_color(self)
	)
	tooltip_text = p_provider_name + " (" + kind + ")"
	_update_badge(icon_path)
	_update_style()

func _build_ui() -> void:
	if _name_label != null:
		return
	add_theme_stylebox_override("panel", CopilotTheme.row_style(self, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	_badge_box = PanelContainer.new()
	_badge_box.custom_minimum_size = Vector2(28, 28)
	_badge_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#ffffff")
	badge_style.corner_radius_top_left = 4
	badge_style.corner_radius_top_right = 4
	badge_style.corner_radius_bottom_left = 4
	badge_style.corner_radius_bottom_right = 4
	_badge_box.add_theme_stylebox_override("panel", badge_style)
	row.add_child(_badge_box)

	_badge_icon = TextureRect.new()
	_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge_icon.custom_minimum_size = Vector2(20, 20)
	_badge_box.add_child(_badge_icon)

	_badge_label = Label.new()
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_label.add_theme_color_override("font_color", Color("#1a1a1a"))
	_badge_box.add_child(_badge_label)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	_name_label = Label.new()
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(_name_label)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 10)
	text_box.add_child(_status_label)

func _update_badge(icon_path: String) -> void:
	_badge_icon.texture = null
	_badge_label.text = ""
	var texture: Texture2D = null
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var loaded := ResourceLoader.load(icon_path)
		if loaded is Texture2D:
			texture = loaded
	if texture != null:
		_badge_icon.texture = texture
		_badge_box.tooltip_text = ""
	else:
		# No logo: use an initials badge.
		_badge_label.text = _initials(provider_name)
		_badge_box.tooltip_text = provider_name

func _initials(text: String) -> String:
	var clean := text.strip_edges()
	if clean.is_empty():
		return "?"
	var pieces := clean.split(" ", false)
	if pieces.is_empty():
		return clean.substr(0, 1).to_upper()
	if pieces.size() == 1:
		return pieces[0].substr(0, mini(2, pieces[0].length())).to_upper()
	return (pieces[0].substr(0, 1) + pieces[1].substr(0, 1)).to_upper()

func _update_style() -> void:
	add_theme_stylebox_override("panel", CopilotTheme.row_style(self, _selected))

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(provider_name)

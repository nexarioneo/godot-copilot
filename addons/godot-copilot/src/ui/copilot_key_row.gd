@tool
class_name CopilotKeyRow
extends PanelContainer
# Single API key row: enabled, label, masked value, test status, actions.

signal enabled_toggled(index: int, enabled: bool)
signal test_requested(index: int)
signal move_requested(index: int, delta: int)
signal edit_requested(index: int)
signal remove_requested(index: int)

var key_index := -1

var _enabled_check: CheckBox
var _label_label: Label
var _value_label: Label
var _status_label: Label
var _reveal_button: Button
var _value := ""
var _revealed := false

func _ready() -> void:
	_build_ui()

func setup(index: int, label: String, value: String, enabled: bool, status: String) -> void:
	_build_ui()
	key_index = index
	_value = value
	_revealed = false
	_enabled_check.set_pressed_no_signal(enabled)
	_label_label.text = label if not label.is_empty() else "Key " + str(index + 1)
	_update_value_text()
	set_status(status)

func set_status(status: String) -> void:
	match status:
		"queued":
			_status_label.text = "queued"
			_status_label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
		"testing":
			_status_label.text = "testing…"
			_status_label.add_theme_color_override("font_color", CopilotTheme.accent_color(self))
		"success":
			_status_label.text = "Valid"
			_status_label.add_theme_color_override("font_color", CopilotTheme.success_color(self))
		"failed":
			_status_label.text = "Failed"
			_status_label.add_theme_color_override("font_color", CopilotTheme.error_color(self))
		_:
			_status_label.text = ""

static func mask_value(value: String) -> String:
	if value.length() <= 8:
		return "••••••"
	return value.substr(0, 3) + "…" + value.substr(value.length() - 4)

func _build_ui() -> void:
	if _enabled_check != null:
		return
	add_theme_stylebox_override("panel", CopilotTheme.card_style(self))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_enabled_check = CheckBox.new()
	_enabled_check.tooltip_text = "Enable/disable this key for rotation"
	_enabled_check.toggled.connect(func(pressed: bool) -> void: enabled_toggled.emit(key_index, pressed))
	row.add_child(_enabled_check)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	_label_label = Label.new()
	_label_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(_label_label)

	var value_row := HBoxContainer.new()
	value_row.add_theme_constant_override("separation", 4)
	text_box.add_child(value_row)
	_value_label = Label.new()
	_value_label.add_theme_font_size_override("font_size", 11)
	_value_label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
	value_row.add_child(_value_label)
	_reveal_button = Button.new()
	_reveal_button.focus_mode = Control.FOCUS_NONE
	_reveal_button.tooltip_text = "Show/hide the key value"
	CopilotTheme.apply_icon(_reveal_button, PackedStringArray(["ShowPassword"]), "Show")
	_reveal_button.pressed.connect(_on_reveal_pressed)
	value_row.add_child(_reveal_button)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 11)
	value_row.add_child(_status_label)

	row.add_child(_icon_button(PackedStringArray(["Reload"]), "↻", "Test this key", _on_test_pressed))
	row.add_child(_icon_button(PackedStringArray(["ArrowUp"]), "↑", "Move this key up", func() -> void: move_requested.emit(key_index, -1)))
	row.add_child(_icon_button(PackedStringArray(["ArrowDown"]), "↓", "Move this key down", func() -> void: move_requested.emit(key_index, 1)))
	row.add_child(_icon_button(PackedStringArray(["Edit"]), "✎", "Edit key", _on_edit_pressed))
	row.add_child(_icon_button(PackedStringArray(["Remove"]), "✕", "Delete key", _on_remove_pressed))

func _icon_button(names: PackedStringArray, fallback: String, tooltip: String, handler: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	CopilotTheme.apply_icon(button, names, fallback)
	button.pressed.connect(handler)
	return button

func _update_value_text() -> void:
	_value_label.text = _value if _revealed else mask_value(_value)

func _on_reveal_pressed() -> void:
	_revealed = not _revealed
	_update_value_text()

func _on_test_pressed() -> void:
	test_requested.emit(key_index)

func _on_edit_pressed() -> void:
	edit_requested.emit(key_index)

func _on_remove_pressed() -> void:
	remove_requested.emit(key_index)

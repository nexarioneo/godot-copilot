@tool
class_name CopilotModelRow
extends PanelContainer
# Provider model row: active toggle + name + badges + delete.

signal active_toggled(model_key: String, active: bool)
signal remove_requested(model_key: String)

var model_key := ""

var _active_check: CheckBox
var _key_label: Label
var _name_label: Label

func _ready() -> void:
	_build_ui()

func setup(p_model_key: String, display_name: String, disabled: bool, vision: bool, reasoning: bool) -> void:
	_build_ui()
	model_key = p_model_key
	_key_label.text = p_model_key
	var badges := PackedStringArray()
	if vision:
		badges.append("vision")
	if reasoning:
		badges.append("reasoning")
	var suffix := "" if badges.is_empty() else "  [" + ", ".join(badges) + "]"
	_name_label.text = display_name + suffix
	_active_check.set_pressed_no_signal(not disabled)
	modulate = Color(1, 1, 1, 0.55) if disabled else Color(1, 1, 1, 1)

func _build_ui() -> void:
	if _active_check != null:
		return
	add_theme_stylebox_override("panel", CopilotTheme.card_style(self))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_active_check = CheckBox.new()
	_active_check.tooltip_text = "Enable/disable this model in the model picker"
	_active_check.toggled.connect(func(pressed: bool) -> void: active_toggled.emit(model_key, pressed))
	row.add_child(_active_check)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)
	_key_label = Label.new()
	_key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(_key_label)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(_name_label)

	var remove_button := Button.new()
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.tooltip_text = "Remove the model from the list"
	CopilotTheme.apply_icon(remove_button, PackedStringArray(["Remove"]), "✕")
	remove_button.pressed.connect(func() -> void: remove_requested.emit(model_key))
	row.add_child(remove_button)

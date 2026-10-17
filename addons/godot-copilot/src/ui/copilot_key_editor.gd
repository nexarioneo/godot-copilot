@tool
class_name CopilotKeyEditor
extends AcceptDialog
# Small dialog to add/edit a single API key.

signal submitted(index: int, label: String, value: String, enabled: bool)

var _label_edit: LineEdit
var _value_edit: LineEdit
var _enabled_check: CheckBox
var _error_label: Label

var _index := -1

func _ready() -> void:
	dialog_hide_on_ok = false
	title = "API Key"
	ok_button_text = "Save"
	_build_ui()
	confirmed.connect(_on_confirmed)

func open_for(index: int, entry: Dictionary) -> void:
	_index = index
	title = "Add API Key" if index < 0 else "Edit API Key"
	_label_edit.text = str(entry.get("label", ""))
	_value_edit.text = str(entry.get("value", ""))
	_enabled_check.button_pressed = bool(entry.get("enabled", true))
	_error_label.text = ""
	popup_centered()

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.name = "key_editor_box"
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	grid.add_child(_form_label("Label"))
	_label_edit = LineEdit.new()
	_label_edit.placeholder_text = "e.g. Primary key"
	grid.add_child(_label_edit)

	grid.add_child(_form_label("Key Value"))
	_value_edit = LineEdit.new()
	_value_edit.secret = true
	_value_edit.placeholder_text = "sk-..."
	grid.add_child(_value_edit)

	grid.add_child(_form_label("Status"))
	_enabled_check = CheckBox.new()
	_enabled_check.text = "Enabled for requests"
	grid.add_child(_enabled_check)

	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", CopilotTheme.error_color(box))
	box.add_child(_error_label)

func _form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(label))
	return label

func _on_confirmed() -> void:
	var value := _value_edit.text.strip_edges()
	if value.is_empty():
		_error_label.text = "Key value is required."
		show()
		return
	submitted.emit(_index, _label_edit.text.strip_edges(), value, _enabled_check.button_pressed)
	hide()

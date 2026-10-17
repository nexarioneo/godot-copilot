@tool
class_name CopilotModelEditor
extends AcceptDialog
# Small dialog to add/edit a model manually.

signal submitted(model_key: String, display_name: String, flags: Dictionary)

var _id_edit: LineEdit
var _name_edit: LineEdit
var _vision_check: CheckBox
var _reasoning_check: CheckBox
var _error_label: Label

var _editing_key := ""

func _ready() -> void:
	dialog_hide_on_ok = false
	title = "Model"
	ok_button_text = "Save"
	_build_ui()
	confirmed.connect(_on_confirmed)

func open_for(model_key: String, display_name: String, flags: Dictionary) -> void:
	_editing_key = model_key
	title = "Add Model" if model_key.is_empty() else "Edit Model"
	_id_edit.text = model_key
	_id_edit.editable = model_key.is_empty()
	_name_edit.text = display_name
	_vision_check.button_pressed = bool(flags.get("vision", true))
	_reasoning_check.button_pressed = bool(flags.get("reasoning", false))
	_error_label.text = ""
	popup_centered()

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.name = "model_editor_box"
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	grid.add_child(_form_label("Model ID"))
	_id_edit = LineEdit.new()
	_id_edit.placeholder_text = "e.g. gpt-4o"
	grid.add_child(_id_edit)

	grid.add_child(_form_label("Display Name"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "(optional)"
	grid.add_child(_name_edit)

	grid.add_child(_form_label("Capabilities"))
	var caps_box := VBoxContainer.new()
	grid.add_child(caps_box)
	_vision_check = CheckBox.new()
	_vision_check.text = "Vision (image input)"
	caps_box.add_child(_vision_check)
	_reasoning_check = CheckBox.new()
	_reasoning_check.text = "Reasoning"
	caps_box.add_child(_reasoning_check)

	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", CopilotTheme.error_color(box))
	box.add_child(_error_label)

func _form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(label))
	return label

func _on_confirmed() -> void:
	var model_key := _id_edit.text.strip_edges()
	if model_key.is_empty():
		_error_label.text = "Model ID is required."
		show()
		return
	submitted.emit(model_key, _name_edit.text.strip_edges(), {
		"vision": _vision_check.button_pressed,
		"reasoning": _reasoning_check.button_pressed
	})
	hide()

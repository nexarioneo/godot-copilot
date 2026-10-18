@tool
class_name CopilotModelEditor
extends CopilotMd3Dialog
# Small dialog to add/edit a model manually; M3 outlined fields with inline
# validation. The dialog only closes when the input is valid.

signal submitted(model_key: String, display_name: String, flags: Dictionary)

var _id_edit: CopilotMd3TextField = null
var _name_edit: CopilotMd3TextField = null
var _vision_switch: CopilotMd3Switch = null
var _reasoning_switch: CopilotMd3Switch = null
var _error_label: Label = null

var _editing_key := ""

func _ready() -> void:
	super._ready()
	configure(_scheme, "Model", "Save", "Cancel")
	dialog_hide_on_ok = false
	confirmed.connect(_on_confirmed)
	_build_fields()

func open_for(model_key: String, display_name: String, flags: Dictionary) -> void:
	_build_fields()
	_editing_key = model_key
	title = "Add Model" if model_key.is_empty() else "Edit Model"
	_id_edit.text = model_key
	_id_edit.editable = model_key.is_empty()
	_name_edit.text = display_name
	_vision_switch.set_checked(bool(flags.get("vision", true)))
	_reasoning_switch.set_checked(bool(flags.get("reasoning", false)))
	_error_label.text = ""
	popup_centered()

func _build_fields() -> void:
	if _id_edit != null:
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("m"))
	grid.add_theme_constant_override("v_separation", CopilotMd3Tokens.spacing("m"))
	body().add_child(grid)

	grid.add_child(_field_label("Model ID"))
	_id_edit = CopilotMd3TextField.new()
	_id_edit.configure(_scheme, "e.g. gpt-4o", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_id_edit)

	grid.add_child(_field_label("Display Name"))
	_name_edit = CopilotMd3TextField.new()
	_name_edit.configure(_scheme, "(optional)", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_name_edit)

	grid.add_child(_field_label("Capabilities"))
	var caps_box := VBoxContainer.new()
	caps_box.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	grid.add_child(caps_box)
	_vision_switch = _capability_row(caps_box, "Vision (image input)", true)
	_reasoning_switch = _capability_row(caps_box, "Reasoning", false)

	_error_label = Label.new()
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CopilotMd3Tokens.apply_text(_error_label, "body-small")
	if _scheme != null:
		_error_label.add_theme_color_override("font_color", _scheme.color("error"))
	body().add_child(_error_label)

func _capability_row(parent: Control, text: String, checked: bool) -> CopilotMd3Switch:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	parent.add_child(row)
	var toggle := CopilotMd3Switch.new()
	toggle.configure(_scheme, checked)
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(toggle)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CopilotMd3Tokens.apply_text(label, "body-medium")
	if _scheme != null:
		label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	row.add_child(label)
	return toggle

func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(label, "body-medium")
	if _scheme != null:
		label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	return label

func _on_confirmed() -> void:
	var model_key := _id_edit.text.strip_edges()
	if model_key.is_empty():
		_error_label.text = "Model ID is required."
		return
	submitted.emit(model_key, _name_edit.text.strip_edges(), {
		"vision": _vision_switch.is_checked(),
		"reasoning": _reasoning_switch.is_checked(),
	})
	hide()

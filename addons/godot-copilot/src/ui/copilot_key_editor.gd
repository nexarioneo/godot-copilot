@tool
class_name CopilotKeyEditor
extends CopilotMd3Dialog
# Small dialog to add/edit a single API key; M3 outlined fields with inline
# validation. The dialog only closes when the input is valid.

signal submitted(index: int, label: String, value: String, enabled: bool)

var _label_edit: CopilotMd3TextField = null
var _value_edit: CopilotMd3TextField = null
var _enabled_switch: CopilotMd3Switch = null
var _error_label: Label = null

var _index := -1

func _ready() -> void:
	super._ready()
	configure(_scheme, "API Key", "Save", "Cancel")
	dialog_hide_on_ok = false
	confirmed.connect(_on_confirmed)
	_build_fields()

func open_for(index: int, entry: Dictionary) -> void:
	_build_fields()
	_index = index
	title = "Add API Key" if index < 0 else "Edit API Key"
	_label_edit.text = str(entry.get("label", ""))
	_value_edit.text = str(entry.get("value", ""))
	_enabled_switch.set_checked(bool(entry.get("enabled", true)))
	_error_label.text = ""
	popup_centered()

func _build_fields() -> void:
	if _label_edit != null:
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("m"))
	grid.add_theme_constant_override("v_separation", CopilotMd3Tokens.spacing("m"))
	body().add_child(grid)

	grid.add_child(_field_label("Label"))
	_label_edit = CopilotMd3TextField.new()
	_label_edit.configure(_scheme, "e.g. Primary key", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_label_edit)

	grid.add_child(_field_label("Key Value"))
	_value_edit = CopilotMd3TextField.new()
	_value_edit.secret = true
	_value_edit.configure(_scheme, "sk-...", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_value_edit)

	grid.add_child(_field_label("Status"))
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	grid.add_child(status_row)
	_enabled_switch = CopilotMd3Switch.new()
	_enabled_switch.configure(_scheme, true)
	_enabled_switch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	status_row.add_child(_enabled_switch)
	var enabled_label := Label.new()
	enabled_label.text = "Enabled for requests"
	enabled_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CopilotMd3Tokens.apply_text(enabled_label, "body-medium")
	if _scheme != null:
		enabled_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	status_row.add_child(enabled_label)

	_error_label = Label.new()
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CopilotMd3Tokens.apply_text(_error_label, "body-small")
	if _scheme != null:
		_error_label.add_theme_color_override("font_color", _scheme.color("error"))
	body().add_child(_error_label)

func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(label, "body-medium")
	if _scheme != null:
		label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	return label

func _on_confirmed() -> void:
	var value := _value_edit.text.strip_edges()
	if value.is_empty():
		_error_label.text = "Key value is required."
		return
	submitted.emit(_index, _label_edit.text.strip_edges(), value, _enabled_switch.is_checked())
	hide()

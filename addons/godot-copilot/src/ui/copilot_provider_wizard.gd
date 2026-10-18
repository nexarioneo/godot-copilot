@tool
class_name CopilotProviderWizard
extends CopilotMd3Dialog
# Custom provider dialog (M3). Validation runs on `confirmed`; the dialog only
# closes when the input is valid.

signal submitted(data: Dictionary)

var _name_edit: CopilotMd3TextField = null
var _kind_segments: CopilotMd3SegmentedButtons = null
var _base_url_edit: CopilotMd3TextField = null
var _api_type_segments: CopilotMd3SegmentedButtons = null
var _prefix_edit: CopilotMd3TextField = null
var _api_key_edit: CopilotMd3TextField = null
var _model_id_edit: CopilotMd3TextField = null
var _key_url_button: CopilotMd3Button = null
var _error_label: Label = null

var _taken_names: Array = []
var _key_url := ""

func _ready() -> void:
	super._ready()
	configure(_scheme, "Add Provider", "Create", "Cancel")
	dialog_hide_on_ok = false
	confirmed.connect(_on_confirmed)
	_build_fields()

func setup(_config: CopilotConfig, preset: Dictionary, taken_names: Array) -> void:
	_build_fields()
	_taken_names = taken_names
	_key_url = str(preset.get("key_url", ""))
	_key_url_button.visible = not _key_url.is_empty()
	if not preset.is_empty():
		_name_edit.text = _unique_name(str(preset.get("name", "")))
		_kind_segments.select(1 if str(preset.get("kind", "openai")) == "anthropic" else 0)
		_base_url_edit.text = str(preset.get("base_url", ""))
		_api_type_segments.select(1 if str(preset.get("api_type", "")) == "responses" else 0)
	_update_api_type_state()
	_error_label.text = ""

func get_data() -> Dictionary:
	return {
		"name": _name_edit.text.strip_edges(),
		"kind": "anthropic" if _kind_segments.get_selected() == 1 else "openai",
		"base_url": _base_url_edit.text.strip_edges(),
		"api_type": "responses" if _api_type_segments.get_selected() == 1 else "chat_completions",
		"model_prefix": _prefix_edit.text.strip_edges(),
		"api_key": _api_key_edit.text.strip_edges(),
		"model_id": _model_id_edit.text.strip_edges()
	}

func _build_fields() -> void:
	if _name_edit != null:
		return
	body().custom_minimum_size.x = 460
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("m"))
	grid.add_theme_constant_override("v_separation", CopilotMd3Tokens.spacing("m"))
	body().add_child(grid)

	grid.add_child(_field_label("Provider Name"))
	_name_edit = CopilotMd3TextField.new()
	_name_edit.configure(_scheme, "e.g. MyServer", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_name_edit)

	grid.add_child(_field_label("Kind"))
	_kind_segments = CopilotMd3SegmentedButtons.new()
	_kind_segments.configure(_scheme, PackedStringArray(["OpenAI-compatible", "Anthropic Messages API"]))
	_kind_segments.item_selected.connect(func(_index: int) -> void: _update_api_type_state())
	grid.add_child(_kind_segments)

	grid.add_child(_field_label("Base URL"))
	_base_url_edit = CopilotMd3TextField.new()
	_base_url_edit.configure(_scheme, "https://api.example.com/v1", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_base_url_edit)

	grid.add_child(_field_label("API Type"))
	_api_type_segments = CopilotMd3SegmentedButtons.new()
	_api_type_segments.configure(_scheme, PackedStringArray(["chat_completions", "responses"]))
	grid.add_child(_api_type_segments)

	grid.add_child(_field_label("Model Prefix"))
	_prefix_edit = CopilotMd3TextField.new()
	_prefix_edit.configure(_scheme, "(optional) prepended to model names", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_prefix_edit)

	grid.add_child(_field_label("API Key"))
	_api_key_edit = CopilotMd3TextField.new()
	_api_key_edit.secret = true
	_api_key_edit.configure(_scheme, "(optional) first key", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_api_key_edit)

	grid.add_child(_field_label("Model ID"))
	_model_id_edit = CopilotMd3TextField.new()
	_model_id_edit.configure(_scheme, "(optional) e.g. gpt-4o", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	grid.add_child(_model_id_edit)

	_error_label = Label.new()
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CopilotMd3Tokens.apply_text(_error_label, "body-small")
	if _scheme != null:
		_error_label.add_theme_color_override("font_color", _scheme.color("error"))
	body().add_child(_error_label)

	_key_url_button = CopilotMd3Button.new()
	_key_url_button.configure(_scheme, CopilotMd3Button.VARIANT_TEXT, "Get API key", "open_in_new")
	_key_url_button.tooltip_text = "Opens the provider's API key page in the browser"
	_key_url_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_key_url_button.pressed.connect(func() -> void:
		if not _key_url.is_empty():
			OS.shell_open(_key_url)
	)
	body().add_child(_key_url_button)

func _update_api_type_state() -> void:
	var is_anthropic := _kind_segments.get_selected() == 1
	_api_type_segments.set_item_disabled(0, is_anthropic)
	_api_type_segments.set_item_disabled(1, is_anthropic)

func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(label, "body-medium")
	if _scheme != null:
		label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	return label

func _unique_name(base: String) -> String:
	var clean := base.strip_edges()
	if clean.is_empty():
		clean = "Provider"
	if not _taken_names.has(clean):
		return clean
	var index := 2
	while _taken_names.has(clean + " " + str(index)):
		index += 1
	return clean + " " + str(index)

func _on_confirmed() -> void:
	var data := get_data()
	if str(data["name"]).is_empty():
		_error_label.text = "Provider name is required."
		return
	if _taken_names.has(str(data["name"])):
		_error_label.text = "Provider name is already in use."
		return
	if str(data["base_url"]).is_empty():
		_error_label.text = "Base URL is required."
		return
	submitted.emit(data)
	hide()

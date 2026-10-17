@tool
class_name CopilotProviderWizard
extends ConfirmationDialog
# Custom provider dialog. Validation runs on `confirmed`; it only closes when valid.

signal submitted(data: Dictionary)

var _name_edit: LineEdit
var _kind_option: OptionButton
var _base_url_edit: LineEdit
var _api_type_option: OptionButton
var _prefix_edit: LineEdit
var _api_key_edit: LineEdit
var _model_id_edit: LineEdit
var _key_url_button: Button
var _error_label: Label

var _taken_names: Array = []
var _key_url := ""

func _ready() -> void:
	dialog_hide_on_ok = false
	title = "Add Provider"
	ok_button_text = "Save"
	_build_ui()
	confirmed.connect(_on_confirmed)

func setup(_config: CopilotConfig, preset: Dictionary, taken_names: Array) -> void:
	_taken_names = taken_names
	_key_url = str(preset.get("key_url", ""))
	_key_url_button.visible = not _key_url.is_empty()
	if not preset.is_empty():
		_name_edit.text = _unique_name(str(preset.get("name", "")))
		_kind_option.selected = 1 if str(preset.get("kind", "openai")) == "anthropic" else 0
		_base_url_edit.text = str(preset.get("base_url", ""))
		_api_type_option.selected = 1 if str(preset.get("api_type", "")) == "responses" else 0
	_error_label.text = ""

func get_data() -> Dictionary:
	return {
		"name": _name_edit.text.strip_edges(),
		"kind": "anthropic" if _kind_option.selected == 1 else "openai",
		"base_url": _base_url_edit.text.strip_edges(),
		"api_type": "responses" if _api_type_option.selected == 1 else "chat_completions",
		"model_prefix": _prefix_edit.text.strip_edges(),
		"api_key": _api_key_edit.text.strip_edges(),
		"model_id": _model_id_edit.text.strip_edges()
	}

func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.name = "wizard_box"
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	grid.add_child(_form_label("Provider Name"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "e.g. MyServer"
	grid.add_child(_name_edit)

	grid.add_child(_form_label("Kind"))
	_kind_option = OptionButton.new()
	_kind_option.add_item("OpenAI-compatible")
	_kind_option.add_item("Anthropic Messages API")
	grid.add_child(_kind_option)

	grid.add_child(_form_label("Base URL"))
	_base_url_edit = LineEdit.new()
	_base_url_edit.placeholder_text = "https://api.example.com/v1"
	grid.add_child(_base_url_edit)

	grid.add_child(_form_label("API Type"))
	_api_type_option = OptionButton.new()
	_api_type_option.add_item("chat_completions")
	_api_type_option.add_item("responses")
	grid.add_child(_api_type_option)

	grid.add_child(_form_label("Model Prefix"))
	_prefix_edit = LineEdit.new()
	_prefix_edit.placeholder_text = "(optional) prepended to model names"
	grid.add_child(_prefix_edit)

	grid.add_child(_form_label("API Key"))
	_api_key_edit = LineEdit.new()
	_api_key_edit.secret = true
	_api_key_edit.placeholder_text = "(optional) first key"
	grid.add_child(_api_key_edit)

	grid.add_child(_form_label("Model ID"))
	_model_id_edit = LineEdit.new()
	_model_id_edit.placeholder_text = "(optional) e.g. gpt-4o"
	grid.add_child(_model_id_edit)

	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", CopilotTheme.error_color(box))
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_error_label)

	_key_url_button = Button.new()
	_key_url_button.text = "Open API key page"
	CopilotTheme.apply_icon(_key_url_button, PackedStringArray(["ExternalLink"]), "↗")
	_key_url_button.tooltip_text = "Opens the provider's API key page in the browser"
	_key_url_button.pressed.connect(func() -> void:
		if not _key_url.is_empty():
			OS.shell_open(_key_url)
	)
	box.add_child(_key_url_button)

func _form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(label))
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
		show()
		return
	if _taken_names.has(str(data["name"])):
		_error_label.text = "Provider name is already in use."
		show()
		return
	if str(data["base_url"]).is_empty():
		_error_label.text = "Base URL is required."
		show()
		return
	submitted.emit(data)
	hide()

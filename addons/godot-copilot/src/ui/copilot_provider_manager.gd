@tool
class_name CopilotProviderManager
extends AcceptDialog
# Provider manager dialog: provider list (left) + Keys/Models/Advanced tabs (right).

signal providers_changed()

var config: CopilotConfig

var _selected := ""

var _add_provider_menu: MenuButton
var _remove_provider_button: Button
var _provider_list: VBoxContainer
var _provider_rows: Dictionary = {}

var _detail_title: Label
var _detail_url: Label
var _detail_key_url_button: Button
var _tabs: TabContainer

# Keys tab
var _keys_list: VBoxContainer
var _round_robin_check: CheckBox
var _sticky_spin: SpinBox
var _sticky_box: HBoxContainer
var _test_all_button: Button
var _stop_test_button: Button

# Models tab
var _active_model_option: OptionButton
var _models_list: VBoxContainer

# Advanced tab
var _kind_label: Label
var _base_url_edit: LineEdit
var _api_type_option: OptionButton
var _prefix_edit: LineEdit

var _key_status: Dictionary = {}
var _test_queue: Array = []
var _testing := false
var _stop_testing := false
var _testing_import := false

func _ready() -> void:
	title = "Godot Copilot — Provider Manager"
	ok_button_text = "Close"
	min_size = Vector2i(780, 480)
	size = Vector2i(900, 560)
	_build_ui()
	get_ok_button().pressed.connect(func() -> void: hide())

func setup(p_config: CopilotConfig) -> void:
	config = p_config
	_build_ui()
	_refresh_providers()

# --- Build UI ---

func _build_ui() -> void:
	if _tabs != null:
		return
	var split := HSplitContainer.new()
	split.name = "provider_split"
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.custom_minimum_size = Vector2(760, 460)
	add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(240, 0)
	left.add_theme_constant_override("separation", 4)
	split.add_child(left)

	var left_header := HBoxContainer.new()
	left_header.add_theme_constant_override("separation", 4)
	left.add_child(left_header)
	_add_provider_menu = MenuButton.new()
	_add_provider_menu.text = "Add"
	_add_provider_menu.tooltip_text = "Add a provider from a preset or a custom one"
	left_header.add_child(_add_provider_menu)
	_remove_provider_button = Button.new()
	_remove_provider_button.focus_mode = Control.FOCUS_NONE
	_remove_provider_button.tooltip_text = "Delete the selected provider"
	CopilotTheme.apply_icon(_remove_provider_button, PackedStringArray(["Remove"]), "✕")
	_remove_provider_button.pressed.connect(_on_remove_provider_pressed)
	left_header.add_child(_remove_provider_button)
	_populate_add_menu()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	_provider_list = VBoxContainer.new()
	_provider_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_provider_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_provider_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	split.add_child(right)

	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", 6)
	right.add_child(detail_header)
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 0)
	detail_header.add_child(detail_box)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 15)
	detail_box.add_child(_detail_title)
	_detail_url = Label.new()
	_detail_url.add_theme_font_size_override("font_size", 11)
	_detail_url.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
	_detail_url.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_box.add_child(_detail_url)
	_detail_key_url_button = Button.new()
	_detail_key_url_button.focus_mode = Control.FOCUS_NONE
	_detail_key_url_button.tooltip_text = "Open this provider's API key page"
	CopilotTheme.apply_icon(_detail_key_url_button, PackedStringArray(["ExternalLink"]), "↗")
	_detail_key_url_button.pressed.connect(_on_open_key_url_pressed)
	detail_header.add_child(_detail_key_url_button)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_tabs)
	_build_keys_tab()
	_build_models_tab()
	_build_advanced_tab()

func _populate_add_menu() -> void:
	var popup := _add_provider_menu.get_popup()
	popup.clear()
	for preset in CopilotProviderPresets.get_presets():
		popup.add_item("Preset: " + str(preset.get("name", "")))
		popup.set_item_metadata(popup.item_count - 1, {"mode": "preset", "preset": preset})
	popup.add_separator()
	popup.add_item("Custom Provider…")
	popup.set_item_metadata(popup.item_count - 1, {"mode": "custom"})
	popup.id_pressed.connect(_on_add_menu_pressed)

func _build_keys_tab() -> void:
	var keys_tab := VBoxContainer.new()
	keys_tab.name = "Keys"
	keys_tab.add_theme_constant_override("separation", 4)
	_tabs.add_child(keys_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keys_tab.add_child(scroll)
	_keys_list = VBoxContainer.new()
	_keys_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_keys_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	keys_tab.add_child(actions)
	var add_key_button := Button.new()
	add_key_button.text = "Add Key"
	CopilotTheme.apply_icon(add_key_button, PackedStringArray(["Add"]), "+")
	add_key_button.tooltip_text = "Add a new API key"
	add_key_button.pressed.connect(_on_add_key_pressed)
	actions.add_child(add_key_button)
	_test_all_button = Button.new()
	_test_all_button.text = "Test All"
	_test_all_button.tooltip_text = "Tests every key one by one"
	_test_all_button.pressed.connect(_on_test_all_pressed)
	actions.add_child(_test_all_button)
	_stop_test_button = Button.new()
	_stop_test_button.focus_mode = Control.FOCUS_NONE
	_stop_test_button.tooltip_text = "Stop the test queue"
	CopilotTheme.apply_icon(_stop_test_button, PackedStringArray(["Stop"]), "■")
	_stop_test_button.disabled = true
	_stop_test_button.pressed.connect(_on_stop_test_pressed)
	actions.add_child(_stop_test_button)

	var strategy_row := HBoxContainer.new()
	strategy_row.add_theme_constant_override("separation", 6)
	keys_tab.add_child(strategy_row)
	_round_robin_check = CheckBox.new()
	_round_robin_check.text = "Round-robin (rotate on every request)"
	_round_robin_check.tooltip_text = "When off, a single key is reused for 'sticky count' requests in a row"
	_round_robin_check.toggled.connect(_on_round_robin_toggled)
	strategy_row.add_child(_round_robin_check)
	_sticky_box = HBoxContainer.new()
	_sticky_box.add_theme_constant_override("separation", 4)
	strategy_row.add_child(_sticky_box)
	var sticky_label := Label.new()
	sticky_label.text = "Sticky count"
	sticky_label.add_theme_font_size_override("font_size", 11)
	_sticky_box.add_child(sticky_label)
	_sticky_spin = SpinBox.new()
	_sticky_spin.min_value = 1
	_sticky_spin.max_value = 100
	_sticky_spin.tooltip_text = "Number of requests per key before switching"
	_sticky_spin.value_changed.connect(_on_sticky_count_changed)
	_sticky_box.add_child(_sticky_spin)

func _build_models_tab() -> void:
	var models_tab := VBoxContainer.new()
	models_tab.name = "Models"
	models_tab.add_theme_constant_override("separation", 4)
	_tabs.add_child(models_tab)

	var active_row := HBoxContainer.new()
	active_row.add_theme_constant_override("separation", 6)
	models_tab.add_child(active_row)
	var active_label := Label.new()
	active_label.text = "Active model"
	active_label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
	active_row.add_child(active_label)
	_active_model_option = OptionButton.new()
	_active_model_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_model_option.tooltip_text = "Model Copilot uses for chat"
	_active_model_option.item_selected.connect(_on_active_model_selected)
	active_row.add_child(_active_model_option)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	models_tab.add_child(scroll)
	_models_list = VBoxContainer.new()
	_models_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_models_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_models_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	models_tab.add_child(actions)
	var import_button := Button.new()
	import_button.text = "Import from /models"
	import_button.tooltip_text = "Fetch the model list from the provider endpoint"
	CopilotTheme.apply_icon(import_button, PackedStringArray(["Download"]), "Import")
	import_button.pressed.connect(_on_import_models_pressed)
	actions.add_child(import_button)
	var add_model_button := Button.new()
	add_model_button.text = "Add Model"
	CopilotTheme.apply_icon(add_model_button, PackedStringArray(["Add"]), "+")
	add_model_button.tooltip_text = "Add a model manually"
	add_model_button.pressed.connect(_on_add_model_pressed)
	actions.add_child(add_model_button)
	var disable_all_button := Button.new()
	disable_all_button.text = "Disable All"
	disable_all_button.tooltip_text = "Hide all models from the picker"
	disable_all_button.pressed.connect(func() -> void:
		config.set_all_models_disabled(_selected, true)
		_refresh_models()
		providers_changed.emit()
	)
	actions.add_child(disable_all_button)
	var enable_all_button := Button.new()
	enable_all_button.text = "Enable All"
	enable_all_button.tooltip_text = "Show all models in the picker"
	enable_all_button.pressed.connect(func() -> void:
		config.set_all_models_disabled(_selected, false)
		_refresh_models()
		providers_changed.emit()
	)
	actions.add_child(enable_all_button)

func _build_advanced_tab() -> void:
	var advanced_tab := VBoxContainer.new()
	advanced_tab.name = "Advanced"
	advanced_tab.add_theme_constant_override("separation", 6)
	_tabs.add_child(advanced_tab)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	advanced_tab.add_child(grid)

	grid.add_child(_form_label("Kind"))
	_kind_label = Label.new()
	grid.add_child(_kind_label)

	grid.add_child(_form_label("Base URL"))
	_base_url_edit = LineEdit.new()
	_base_url_edit.placeholder_text = "https://api.example.com/v1"
	_base_url_edit.text_submitted.connect(func(_text: String) -> void: _save_base_url())
	_base_url_edit.focus_exited.connect(_save_base_url)
	grid.add_child(_base_url_edit)

	grid.add_child(_form_label("API Type"))
	_api_type_option = OptionButton.new()
	_api_type_option.add_item("chat_completions")
	_api_type_option.add_item("responses")
	_api_type_option.item_selected.connect(_on_api_type_selected)
	grid.add_child(_api_type_option)

	grid.add_child(_form_label("Model Prefix"))
	_prefix_edit = LineEdit.new()
	_prefix_edit.placeholder_text = "(optional)"
	_prefix_edit.text_submitted.connect(func(_text: String) -> void: _save_prefix())
	_prefix_edit.focus_exited.connect(_save_prefix)
	grid.add_child(_prefix_edit)

	var hint := Label.new()
	hint.text = "Base URL / API Type / Prefix changes are saved automatically."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
	advanced_tab.add_child(hint)

func _form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(label))
	return label

# --- Provider list ---

func _refresh_providers() -> void:
	if _provider_list == null:
		return
	for child in _provider_list.get_children():
		child.queue_free()
	_provider_rows.clear()
	var names := config.get_provider_names()
	names.sort()
	for provider_name_var in names:
		var provider_name := str(provider_name_var)
		var key_count := config.get_enabled_key_count(provider_name)
		var row := CopilotProviderRow.new()
		_provider_list.add_child(row)
		row.setup(
			provider_name,
			config.get_provider_kind(provider_name),
			str(key_count) + " active keys" if key_count > 0 else "No keys yet",
			key_count > 0,
			CopilotProviderPresets.icon_path_for(provider_name),
			provider_name == _selected
		)
		row.pressed.connect(_on_provider_row_pressed)
		_provider_rows[provider_name] = row
	if _selected.is_empty() or not config.has_provider(_selected):
		var active_provider := config.get_active_provider_name()
		_selected = active_provider if config.has_provider(active_provider) else (str(names[0]) if not names.is_empty() else "")
	_refresh_detail()

func _on_provider_row_pressed(provider_name: String) -> void:
	if provider_name == _selected:
		return
	_selected = provider_name
	_refresh_providers()

func _refresh_detail() -> void:
	if _selected.is_empty() or not config.has_provider(_selected):
		_detail_title.text = "No providers yet"
		_detail_url.text = "Add a provider with the Add button."
		_detail_key_url_button.visible = false
		_clear_list(_keys_list)
		_clear_list(_models_list)
		_kind_label.text = "-"
		_round_robin_check.disabled = true
		return
	_round_robin_check.disabled = false
	_detail_title.text = _selected
	var base_url := config.get_base_url(_selected)
	_detail_url.text = base_url if not base_url.is_empty() else "(base URL not set yet)"
	var key_url := CopilotProviderPresets.key_url_for(_selected)
	_detail_key_url_button.visible = not key_url.is_empty()
	_refresh_keys()
	_refresh_models()
	_refresh_advanced()

func _refresh_keys() -> void:
	if _keys_list == null:
		return
	_clear_list(_keys_list)
	var keys := config.get_api_keys(_selected)
	for i in range(keys.size()):
		var entry: Dictionary = keys[i] if keys[i] is Dictionary else {}
		var row := CopilotKeyRow.new()
		_keys_list.add_child(row)
		row.setup(
			i,
			str(entry.get("label", "")),
			str(entry.get("value", "")),
			bool(entry.get("enabled", true)),
			str(_key_status.get(str(i), ""))
		)
		row.enabled_toggled.connect(_on_key_enabled_toggled)
		row.test_requested.connect(_on_key_test_requested)
		row.move_requested.connect(_on_key_move_requested)
		row.edit_requested.connect(_on_key_edit_requested)
		row.remove_requested.connect(_on_key_remove_requested)
	_round_robin_check.set_pressed_no_signal(config.get_key_strategy(_selected) == CopilotConfig.STRATEGY_ROUND_ROBIN)
	_sticky_spin.set_value_no_signal(config.get_sticky_count(_selected))
	_update_sticky_visibility()
	_update_test_buttons()

func _refresh_models() -> void:
	if _models_list == null:
		return
	_clear_list(_models_list)
	var active_keys: Array = []
	var disabled_keys: Array = []
	for model_key_var in config.get_model_keys(_selected):
		var model_key := str(model_key_var)
		if config.is_model_disabled(_selected, model_key):
			disabled_keys.append(model_key)
		else:
			active_keys.append(model_key)
	active_keys.sort()
	disabled_keys.sort()
	for model_key in active_keys + disabled_keys:
		var caps := config.get_model_caps(_selected, str(model_key))
		var row := CopilotModelRow.new()
		_models_list.add_child(row)
		row.setup(
			str(model_key),
			config.get_model_display_name(_selected, str(model_key)),
			config.is_model_disabled(_selected, str(model_key)),
			bool(caps.get("vision", false)),
			bool(caps.get("reasoning", false))
		)
		row.active_toggled.connect(_on_model_active_toggled)
		row.remove_requested.connect(_on_model_remove_requested)
	_refresh_active_model_options()

func _refresh_active_model_options() -> void:
	if _active_model_option == null:
		return
	_active_model_option.clear()
	var current := config.get_active_model_id()
	var available := config.get_available_models()
	var selected_index := -1
	for entry in available:
		var model_id := str(entry.get("id", ""))
		_active_model_option.add_item(str(entry.get("display_name", model_id)))
		_active_model_option.set_item_metadata(_active_model_option.item_count - 1, model_id)
		if model_id == current:
			selected_index = _active_model_option.item_count - 1
	if available.is_empty():
		_active_model_option.add_item("(no active model yet)")
	if selected_index >= 0:
		_active_model_option.selected = selected_index

func _refresh_advanced() -> void:
	_kind_label.text = config.get_provider_kind(_selected)
	_base_url_edit.text = config.get_base_url(_selected)
	_prefix_edit.text = config.get_model_prefix(_selected)
	var is_anthropic := config.get_provider_kind(_selected) == "anthropic"
	_api_type_option.selected = 1 if config.get_api_type(_selected) == "responses" else 0
	_api_type_option.disabled = is_anthropic

func _clear_list(list: VBoxContainer) -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()

# --- Add/remove provider ---

func _on_add_menu_pressed(id: int) -> void:
	var popup := _add_provider_menu.get_popup()
	var metadata = popup.get_item_metadata(id)
	if metadata is Dictionary and str(metadata.get("mode", "")) == "preset":
		var preset: Dictionary = metadata["preset"]
		var provider_name := _unique_provider_name(str(preset.get("name", "")))
		config.add_provider(
			provider_name,
			str(preset.get("kind", "openai")),
			str(preset.get("base_url", "")),
			str(preset.get("api_type", "chat_completions"))
		)
		_selected = provider_name
		_refresh_providers()
		providers_changed.emit()
	else:
		_open_wizard({})

func _open_wizard(preset: Dictionary) -> void:
	var wizard := CopilotProviderWizard.new()
	add_child(wizard)
	wizard.setup(config, preset, config.get_provider_names())
	wizard.submitted.connect(func(data: Dictionary) -> void:
		var provider_name := str(data.get("name", "")).strip_edges()
		if not config.add_provider(
			provider_name,
			str(data.get("kind", "openai")),
			str(data.get("base_url", "")),
			str(data.get("api_type", "chat_completions"))
		):
			provider_name = _unique_provider_name(provider_name)
			config.add_provider(
				provider_name,
				str(data.get("kind", "openai")),
				str(data.get("base_url", "")),
				str(data.get("api_type", "chat_completions"))
			)
		var model_prefix := str(data.get("model_prefix", "")).strip_edges()
		if not model_prefix.is_empty():
			config.set_model_prefix(provider_name, model_prefix)
		var api_key := str(data.get("api_key", "")).strip_edges()
		if not api_key.is_empty():
			config.add_api_key(provider_name, api_key, "Key 1")
		var model_id := str(data.get("model_id", "")).strip_edges()
		if not model_id.is_empty():
			config.add_or_update_model(provider_name, model_id)
		_selected = provider_name
		_refresh_providers()
		providers_changed.emit()
		wizard.queue_free()
	)
	wizard.canceled.connect(func() -> void: wizard.queue_free())
	wizard.popup_centered()

func _unique_provider_name(base: String) -> String:
	var clean := base.strip_edges()
	if clean.is_empty():
		clean = "Provider"
	if not config.has_provider(clean):
		return clean
	var index := 2
	while config.has_provider(clean + " " + str(index)):
		index += 1
	return clean + " " + str(index)

func _on_remove_provider_pressed() -> void:
	if _selected.is_empty():
		return
	var provider_to_remove := _selected
	var confirm := ConfirmationDialog.new()
	confirm.title = "Delete Provider"
	confirm.dialog_text = "Delete provider '" + provider_to_remove + "' along with its keys and models?"
	confirm.ok_button_text = "Delete"
	add_child(confirm)
	confirm.confirmed.connect(func() -> void:
		config.remove_provider(provider_to_remove)
		_selected = ""
		_refresh_providers()
		providers_changed.emit()
		confirm.queue_free()
	)
	confirm.canceled.connect(func() -> void: confirm.queue_free())
	confirm.popup_centered()

func _on_open_key_url_pressed() -> void:
	var key_url := CopilotProviderPresets.key_url_for(_selected)
	if not key_url.is_empty():
		OS.shell_open(key_url)

# --- Keys ---

func _on_key_enabled_toggled(index: int, enabled: bool) -> void:
	config.set_api_key_enabled(_selected, index, enabled)
	_refresh_providers()
	providers_changed.emit()

func _on_key_move_requested(index: int, delta: int) -> void:
	if config.move_api_key(_selected, index, index + delta):
		_key_status.clear()
		_refresh_keys()

func _on_key_edit_requested(index: int) -> void:
	var keys := config.get_api_keys(_selected)
	if index < 0 or index >= keys.size():
		return
	var editor := CopilotKeyEditor.new()
	add_child(editor)
	editor.submitted.connect(func(edit_index: int, label: String, value: String, enabled: bool) -> void:
		config.update_api_key(_selected, edit_index, value, label)
		config.set_api_key_enabled(_selected, edit_index, enabled)
		_key_status.clear()
		_refresh_keys()
		_refresh_providers()
		editor.queue_free()
	)
	editor.canceled.connect(func() -> void: editor.queue_free())
	editor.open_for(index, keys[index])

func _on_key_remove_requested(index: int) -> void:
	config.remove_api_key(_selected, index)
	_key_status.clear()
	_refresh_keys()
	_refresh_providers()

func _on_add_key_pressed() -> void:
	var editor := CopilotKeyEditor.new()
	add_child(editor)
	editor.submitted.connect(func(_index: int, label: String, value: String, enabled: bool) -> void:
		config.add_api_key(_selected, value, label, enabled)
		_refresh_keys()
		_refresh_providers()
		editor.queue_free()
	)
	editor.canceled.connect(func() -> void: editor.queue_free())
	editor.open_for(-1, {})

func _on_round_robin_toggled(pressed: bool) -> void:
	if _selected.is_empty():
		return
	config.set_key_strategy(_selected, CopilotConfig.STRATEGY_ROUND_ROBIN if pressed else CopilotConfig.STRATEGY_STICKY_COUNT)
	_update_sticky_visibility()

func _on_sticky_count_changed(value: float) -> void:
	if not _selected.is_empty():
		config.set_sticky_count(_selected, int(value))

func _update_sticky_visibility() -> void:
	if _sticky_box != null:
		_sticky_box.visible = not _round_robin_check.button_pressed

# --- Test key ---

func _on_key_test_requested(index: int) -> void:
	_start_tests([index])

func _on_test_all_pressed() -> void:
	var indices: Array = []
	for i in range(config.get_api_keys(_selected).size()):
		indices.append(i)
	_start_tests(indices)

func _start_tests(indices: Array) -> void:
	if _selected.is_empty() or _testing:
		return
	_test_queue = indices.duplicate()
	_stop_testing = false
	_testing = true
	for index in _test_queue:
		_key_status[str(index)] = "queued"
	_refresh_keys()
	_update_test_buttons()
	_run_test_queue()

func _run_test_queue() -> void:
	while not _test_queue.is_empty() and not _stop_testing:
		var index := int(_test_queue.pop_front())
		_key_status[str(index)] = "testing"
		_refresh_keys()
		var success := await _test_key(index)
		if _stop_testing:
			_key_status[str(index)] = ""
			break
		_key_status[str(index)] = "success" if success else "failed"
		_refresh_keys()
	_testing = false
	_stop_testing = false
	_update_test_buttons()

func _test_key(index: int) -> bool:
	var keys := config.get_api_keys(_selected)
	if index < 0 or index >= keys.size():
		return false
	var entry: Dictionary = keys[index] if keys[index] is Dictionary else {}
	var api_key := str(entry.get("value", "")).strip_edges()
	if api_key.is_empty():
		return false
	var base := config.get_base_url(_selected).trim_suffix("/")
	if base.is_empty():
		return false

	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	var err := OK
	if config.get_provider_kind(_selected) == "anthropic":
		if base.ends_with("/messages"):
			base = base.trim_suffix("/messages")
		var headers := PackedStringArray([
			"Content-Type: application/json",
			"x-api-key: " + api_key,
			"anthropic-version: 2023-06-01",
			"User-Agent: GodotCopilot/2.0"
		])
		var model_keys := config.get_model_keys(_selected)
		var probe_model := str(model_keys[0]) if not model_keys.is_empty() else "claude-3-5-haiku-latest"
		var body := JSON.stringify({
			"model": probe_model,
			"max_tokens": 1,
			"messages": [{"role": "user", "content": "ping"}]
		})
		err = request.request(base + "/messages", headers, HTTPClient.METHOD_POST, body)
	else:
		if base.ends_with("/chat/completions"):
			base = base.trim_suffix("/chat/completions")
		elif base.ends_with("/responses"):
			base = base.trim_suffix("/responses")
		var headers := PackedStringArray([
			"Authorization: Bearer " + api_key,
			"User-Agent: GodotCopilot/2.0"
		])
		err = request.request(base + "/models", headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		request.queue_free()
		return false
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return false
	var status := int(response[1])
	return status >= 200 and status < 300

func _on_stop_test_pressed() -> void:
	_stop_testing = true
	_update_test_buttons()

func _update_test_buttons() -> void:
	if _test_all_button == null:
		return
	_test_all_button.disabled = _testing
	_stop_test_button.disabled = not _testing

# --- Models ---

func _on_active_model_selected(index: int) -> void:
	var model_id := str(_active_model_option.get_item_metadata(index))
	if model_id.is_empty():
		return
	config.set_active_model_id(model_id)
	providers_changed.emit()

func _on_model_active_toggled(model_key: String, active: bool) -> void:
	config.set_model_disabled(_selected, model_key, not active)
	_refresh_models()
	providers_changed.emit()

func _on_model_remove_requested(model_key: String) -> void:
	config.remove_model(_selected, model_key)
	_refresh_models()
	providers_changed.emit()

func _on_add_model_pressed() -> void:
	if _selected.is_empty():
		return
	var editor := CopilotModelEditor.new()
	add_child(editor)
	editor.submitted.connect(func(model_key: String, display_name: String, flags: Dictionary) -> void:
		config.add_or_update_model(_selected, model_key, display_name, flags)
		_refresh_models()
		providers_changed.emit()
		editor.queue_free()
	)
	editor.canceled.connect(func() -> void: editor.queue_free())
	editor.open_for("", "", {})

func _on_import_models_pressed() -> void:
	if _selected.is_empty() or _testing_import:
		return
	_import_models()

func _import_models() -> void:
	_testing_import = true
	_detail_url.text = "Importing models from /models…"
	var base := config.get_base_url(_selected).trim_suffix("/")
	if base.ends_with("/chat/completions"):
		base = base.trim_suffix("/chat/completions")
	if base.ends_with("/responses"):
		base = base.trim_suffix("/responses")
	if base.ends_with("/messages"):
		base = base.trim_suffix("/messages")
	var api_key := config.peek_api_key(_selected)
	var request := HTTPRequest.new()
	request.timeout = 20.0
	add_child(request)
	var headers := PackedStringArray(["User-Agent: GodotCopilot/2.0"])
	if config.get_provider_kind(_selected) == "anthropic":
		headers.append("x-api-key: " + api_key)
		headers.append("anthropic-version: 2023-06-01")
	else:
		headers.append("Authorization: Bearer " + api_key)
	var err := request.request(base + "/models", headers, HTTPClient.METHOD_GET, "")
	if err != OK:
		request.queue_free()
		_testing_import = false
		_refresh_detail()
		return
	var response: Array = await request.request_completed
	request.queue_free()
	_testing_import = false
	var imported := 0
	if int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) >= 200 and int(response[1]) < 300:
		var json := JSON.new()
		var body := (response[3] as PackedByteArray).get_string_from_utf8()
		if json.parse(body) == OK and json.data is Dictionary:
			var list_value = json.data.get("data", json.data.get("models", []))
			if list_value is Array:
				for item in list_value:
					if not (item is Dictionary):
						continue
					var model_key := str(item.get("id", item.get("name", ""))).strip_edges()
					if model_key.is_empty():
						continue
					var display_name := str(item.get("display_name", item.get("name", "")))
					if display_name == model_key:
						display_name = ""
					config.add_or_update_model(_selected, model_key, display_name)
					imported += 1
	_refresh_detail()
	if imported > 0:
		providers_changed.emit()
	else:
		_detail_url.text = "Import failed: no models were returned by the endpoint."

# --- Advanced ---

func _save_base_url() -> void:
	if _selected.is_empty():
		return
	config.set_base_url(_selected, _base_url_edit.text)
	var base_url := config.get_base_url(_selected)
	_detail_url.text = base_url if not base_url.is_empty() else "(base URL not set yet)"

func _save_prefix() -> void:
	if _selected.is_empty():
		return
	config.set_model_prefix(_selected, _prefix_edit.text)

func _on_api_type_selected(index: int) -> void:
	if _selected.is_empty():
		return
	config.set_api_type(_selected, "responses" if index == 1 else "chat_completions")

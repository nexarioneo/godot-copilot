@tool
class_name CopilotProviderManager
extends CopilotMd3Dialog
# Provider manager dialog: provider list (left) + Keys/Models/Advanced tabs
# (right), built entirely from the M3 component library.

signal providers_changed()

const CUSTOM_PROVIDER_ID := 9999

var config: CopilotConfig

var _selected := ""

var _add_button: CopilotMd3Button
var _add_menu: CopilotMd3Menu
var _remove_provider_button: CopilotMd3IconButton
var _provider_list: VBoxContainer

var _detail_title: Label
var _detail_url: Label
var _detail_key_url_button: CopilotMd3Button
var _tabs: CopilotMd3Tabs

# Keys tab
var _keys_list: VBoxContainer
var _round_robin_switch: CopilotMd3Switch
var _sticky_spin: CopilotMd3SpinField
var _sticky_box: HBoxContainer
var _test_all_button: CopilotMd3Button
var _stop_test_button: CopilotMd3Button

# Models tab
var _active_model_button: CopilotMd3Button
var _model_menu: CopilotMd3Menu
var _model_menu_ids: Dictionary = {}
var _models_list: VBoxContainer
var _import_progress: CopilotMd3LinearProgress
var _import_button: CopilotMd3Button
var _models_status: Label

# Advanced tab
var _kind_value: Label
var _base_url_edit: CopilotMd3TextField
var _api_type_segments: CopilotMd3SegmentedButtons
var _prefix_edit: CopilotMd3TextField

var _key_status: Dictionary = {}
var _test_queue: Array = []
var _testing := false
var _stop_testing := false
var _testing_import := false

func _ready() -> void:
	super._ready()
	configure(_scheme, "Provider Manager", "Close")
	min_size = Vector2i(780, 480)
	size = Vector2i(900, 560)
	_build_ui()

func setup(p_config: CopilotConfig) -> void:
	config = p_config
	_build_ui()
	_refresh_providers()

func refresh() -> void:
	# Called by the plugin right before the dialog is shown again, so the
	# lists pick up changes made elsewhere (e.g. the active model picker).
	_refresh_providers()

# --- Build UI ---

func _build_ui() -> void:
	if _tabs != null:
		return
	var split := HSplitContainer.new()
	split.name = "provider_split"
	split.custom_minimum_size = Vector2(760, 460)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body().add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(240, 0)
	left.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	split.add_child(left)

	var left_header := HBoxContainer.new()
	left_header.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	left.add_child(left_header)
	_add_button = CopilotMd3Button.new()
	_add_button.configure(_scheme, CopilotMd3Button.VARIANT_TONAL, "Add", "expand_more")
	_add_button.tooltip_text = "Add a provider from a preset or a custom one"
	_add_button.pressed.connect(_on_add_pressed)
	left_header.add_child(_add_button)
	_remove_provider_button = CopilotMd3IconButton.new()
	_remove_provider_button.configure(_scheme, CopilotMd3IconButton.VARIANT_STANDARD, "", "delete")
	_remove_provider_button.tooltip_text = "Delete the selected provider"
	_remove_provider_button.pressed.connect(_on_remove_provider_pressed)
	left_header.add_child(_remove_provider_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_provider_list = VBoxContainer.new()
	_provider_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_provider_list.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	scroll.add_child(_provider_list)

	_add_menu = CopilotMd3Menu.new()
	add_child(_add_menu)
	_add_menu.configure(_scheme)
	_add_menu.item_selected.connect(_on_add_menu_selected)
	_populate_add_menu()

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	split.add_child(right)

	var detail_header := HBoxContainer.new()
	detail_header.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	right.add_child(detail_header)
	var detail_box := VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 0)
	detail_header.add_child(detail_box)
	_detail_title = Label.new()
	_detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	CopilotMd3Tokens.apply_text(_detail_title, "title-large")
	_detail_title.add_theme_color_override("font_color", _scheme.color("on-surface"))
	detail_box.add_child(_detail_title)
	_detail_url = Label.new()
	_detail_url.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	CopilotMd3Tokens.apply_text(_detail_url, "body-small")
	_detail_url.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	var mono := CopilotMd3Tokens.font_mono()
	if mono != null:
		_detail_url.add_theme_font_override("font", mono)
	detail_box.add_child(_detail_url)
	_detail_key_url_button = CopilotMd3Button.new()
	_detail_key_url_button.configure(_scheme, CopilotMd3Button.VARIANT_OUTLINED, "Open API key page", "open_in_new")
	_detail_key_url_button.tooltip_text = "Open this provider's API key page"
	_detail_key_url_button.pressed.connect(_on_open_key_url_pressed)
	detail_header.add_child(_detail_key_url_button)

	_tabs = CopilotMd3Tabs.new()
	_tabs.configure(_scheme)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_tabs)
	_build_keys_tab()
	_build_models_tab()
	_build_advanced_tab()

func _populate_add_menu() -> void:
	_add_menu.clear_items()
	var presets := CopilotProviderPresets.get_presets()
	for i in range(presets.size()):
		_add_menu.add_item("Preset: " + str(presets[i].get("name", "")), i)
	_add_menu.add_separator()
	_add_menu.add_item("Custom provider…", CUSTOM_PROVIDER_ID)

func _build_keys_tab() -> void:
	var keys_tab := VBoxContainer.new()
	keys_tab.name = "Keys"
	keys_tab.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	_tabs.add_child(keys_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	keys_tab.add_child(scroll)
	_keys_list = VBoxContainer.new()
	_keys_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys_list.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	scroll.add_child(_keys_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	keys_tab.add_child(actions)
	var add_key_button := CopilotMd3Button.new()
	add_key_button.configure(_scheme, CopilotMd3Button.VARIANT_TONAL, "Add key", "add")
	add_key_button.tooltip_text = "Add a new API key"
	add_key_button.pressed.connect(_on_add_key_pressed)
	actions.add_child(add_key_button)
	_test_all_button = CopilotMd3Button.new()
	_test_all_button.configure(_scheme, CopilotMd3Button.VARIANT_OUTLINED, "Test all")
	_test_all_button.tooltip_text = "Tests every key one by one"
	_test_all_button.pressed.connect(_on_test_all_pressed)
	actions.add_child(_test_all_button)
	_stop_test_button = CopilotMd3Button.new()
	_stop_test_button.configure(_scheme, CopilotMd3Button.VARIANT_TEXT, "Stop", "stop")
	_stop_test_button.tooltip_text = "Stop the test queue"
	_stop_test_button.visible = false
	_stop_test_button.pressed.connect(_on_stop_test_pressed)
	actions.add_child(_stop_test_button)

	var strategy_row := HBoxContainer.new()
	strategy_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	keys_tab.add_child(strategy_row)
	_round_robin_switch = CopilotMd3Switch.new()
	_round_robin_switch.configure(_scheme, false)
	_round_robin_switch.tooltip_text = "When off, a single key is reused for 'sticky count' requests in a row"
	_round_robin_switch.toggled.connect(_on_round_robin_toggled)
	strategy_row.add_child(_round_robin_switch)
	var strategy_label := Label.new()
	strategy_label.text = "Round-robin (rotate on every request)"
	strategy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CopilotMd3Tokens.apply_text(strategy_label, "body-medium")
	strategy_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	strategy_row.add_child(strategy_label)
	_sticky_box = HBoxContainer.new()
	_sticky_box.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	strategy_row.add_child(_sticky_box)
	var sticky_label := Label.new()
	sticky_label.text = "Sticky count"
	sticky_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(sticky_label, "body-medium")
	sticky_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	_sticky_box.add_child(sticky_label)
	_sticky_spin = CopilotMd3SpinField.new()
	_sticky_spin.configure(_scheme, 1, 1, 100)
	_sticky_spin.tooltip_text = "Number of requests per key before switching"
	_sticky_spin.value_changed.connect(_on_sticky_count_changed)
	_sticky_box.add_child(_sticky_spin)

func _build_models_tab() -> void:
	var models_tab := VBoxContainer.new()
	models_tab.name = "Models"
	models_tab.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	_tabs.add_child(models_tab)

	var active_row := HBoxContainer.new()
	active_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	models_tab.add_child(active_row)
	var active_label := Label.new()
	active_label.text = "Active model"
	active_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(active_label, "body-medium")
	active_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	active_row.add_child(active_label)
	_active_model_button = CopilotMd3Button.new()
	_active_model_button.configure(_scheme, CopilotMd3Button.VARIANT_OUTLINED)
	_active_model_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_active_model_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_model_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_active_model_button.tooltip_text = "Model Copilot uses for chat"
	_active_model_button.pressed.connect(_on_active_model_pressed)
	active_row.add_child(_active_model_button)

	_import_progress = CopilotMd3LinearProgress.new()
	_import_progress.configure(_scheme)
	_import_progress.visible = false
	models_tab.add_child(_import_progress)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	models_tab.add_child(scroll)
	_models_list = VBoxContainer.new()
	_models_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_models_list.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	scroll.add_child(_models_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	models_tab.add_child(actions)
	_import_button = CopilotMd3Button.new()
	_import_button.configure(_scheme, CopilotMd3Button.VARIANT_TONAL, "Import", "download")
	_import_button.tooltip_text = "Fetch the model list from the provider endpoint"
	_import_button.pressed.connect(_on_import_models_pressed)
	actions.add_child(_import_button)
	var add_model_button := CopilotMd3Button.new()
	add_model_button.configure(_scheme, CopilotMd3Button.VARIANT_OUTLINED, "Add model", "add")
	add_model_button.tooltip_text = "Add a model manually"
	add_model_button.pressed.connect(_on_add_model_pressed)
	actions.add_child(add_model_button)
	var disable_all_button := CopilotMd3Button.new()
	disable_all_button.configure(_scheme, CopilotMd3Button.VARIANT_TEXT, "Disable all", "remove_done")
	disable_all_button.tooltip_text = "Hide all models from the picker"
	disable_all_button.pressed.connect(func() -> void:
		config.set_all_models_disabled(_selected, true)
		_refresh_models()
		providers_changed.emit()
	)
	actions.add_child(disable_all_button)
	var enable_all_button := CopilotMd3Button.new()
	enable_all_button.configure(_scheme, CopilotMd3Button.VARIANT_TEXT, "Enable all", "done_all")
	enable_all_button.tooltip_text = "Show all models in the picker"
	enable_all_button.pressed.connect(func() -> void:
		config.set_all_models_disabled(_selected, false)
		_refresh_models()
		providers_changed.emit()
	)
	actions.add_child(enable_all_button)

	_models_status = Label.new()
	_models_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CopilotMd3Tokens.apply_text(_models_status, "body-small")
	_models_status.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	models_tab.add_child(_models_status)

	_model_menu = CopilotMd3Menu.new()
	add_child(_model_menu)
	_model_menu.configure(_scheme, true)
	_model_menu.item_selected.connect(_on_model_menu_selected)

func _build_advanced_tab() -> void:
	var advanced_tab := VBoxContainer.new()
	advanced_tab.name = "Advanced"
	advanced_tab.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("m"))
	_tabs.add_child(advanced_tab)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("m"))
	grid.add_theme_constant_override("v_separation", CopilotMd3Tokens.spacing("m"))
	advanced_tab.add_child(grid)

	grid.add_child(_form_label("Kind"))
	_kind_value = Label.new()
	_kind_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(_kind_value, "body-medium")
	_kind_value.add_theme_color_override("font_color", _scheme.color("on-surface"))
	grid.add_child(_kind_value)

	grid.add_child(_form_label("Base URL"))
	_base_url_edit = CopilotMd3TextField.new()
	_base_url_edit.configure(_scheme, "https://api.example.com/v1", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	_base_url_edit.text_submitted.connect(func(_text: String) -> void: _save_base_url())
	_base_url_edit.focus_exited.connect(_save_base_url)
	grid.add_child(_base_url_edit)

	grid.add_child(_form_label("API Type"))
	_api_type_segments = CopilotMd3SegmentedButtons.new()
	_api_type_segments.configure(_scheme, PackedStringArray(["chat_completions", "responses"]))
	_api_type_segments.item_selected.connect(_on_api_type_selected)
	grid.add_child(_api_type_segments)

	grid.add_child(_form_label("Model Prefix"))
	_prefix_edit = CopilotMd3TextField.new()
	_prefix_edit.configure(_scheme, "(optional)", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	_prefix_edit.text_submitted.connect(func(_text: String) -> void: _save_prefix())
	_prefix_edit.focus_exited.connect(_save_prefix)
	grid.add_child(_prefix_edit)

	var hint := Label.new()
	hint.text = "Base URL / API Type / Prefix changes are saved automatically."
	CopilotMd3Tokens.apply_text(hint, "body-small")
	hint.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	advanced_tab.add_child(hint)

func _form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(label, "label-medium")
	label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	return label

# --- Provider list ---

func _refresh_providers() -> void:
	if _provider_list == null or config == null:
		return
	for child in _provider_list.get_children():
		child.queue_free()
	var names := config.get_provider_names()
	names.sort()
	if _selected.is_empty() or not config.has_provider(_selected):
		var active_provider := config.get_active_provider_name()
		_selected = active_provider if config.has_provider(active_provider) else (str(names[0]) if not names.is_empty() else "")
	for provider_name_var in names:
		var provider_name := str(provider_name_var)
		var key_count := config.get_enabled_key_count(provider_name)
		var row := CopilotProviderRow.new()
		_provider_list.add_child(row)
		row.setup(
			_scheme,
			provider_name,
			str(key_count) + " active keys" if key_count > 0 else "No keys yet",
			CopilotProviderPresets.icon_path_for(provider_name),
			provider_name == _selected,
			provider_name == config.get_active_provider_name()
		)
		row.pressed.connect(_on_provider_row_pressed.bind(provider_name))
	_refresh_detail()

func _on_provider_row_pressed(provider_name: String) -> void:
	if provider_name == _selected:
		return
	_selected = provider_name
	_refresh_providers()

func _refresh_detail() -> void:
	_models_status.text = ""
	if _selected.is_empty() or config == null or not config.has_provider(_selected):
		_detail_title.text = "No providers yet"
		_detail_url.text = "Add a provider with the Add button."
		_detail_key_url_button.visible = false
		_clear_list(_keys_list)
		_clear_list(_models_list)
		_kind_value.text = "-"
		_round_robin_switch.disabled = true
		_base_url_edit.text = ""
		_prefix_edit.text = ""
		_api_type_segments.set_item_disabled(0, true)
		_api_type_segments.set_item_disabled(1, true)
		_active_model_button.text = "(no active model yet)"
		_active_model_button.disabled = true
		return
	_round_robin_switch.disabled = false
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
			_scheme,
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
	_round_robin_switch.set_checked(config.get_key_strategy(_selected) == CopilotConfig.STRATEGY_ROUND_ROBIN)
	_sticky_spin.set_value(config.get_sticky_count(_selected))
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
			_scheme,
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
	if _active_model_button == null:
		return
	var current := config.get_active_model_id()
	var available := config.get_available_models()
	var label := "(no active model yet)"
	if not current.is_empty():
		label = current
		for entry in available:
			if str(entry.get("id", "")) == current:
				label = str(entry.get("display_name", current))
				break
	_active_model_button.text = label
	_active_model_button.disabled = available.is_empty()

func _refresh_advanced() -> void:
	_kind_value.text = config.get_provider_kind(_selected)
	_base_url_edit.text = config.get_base_url(_selected)
	_prefix_edit.text = config.get_model_prefix(_selected)
	var is_anthropic := config.get_provider_kind(_selected) == "anthropic"
	_api_type_segments.select(1 if config.get_api_type(_selected) == "responses" else 0)
	_api_type_segments.set_item_disabled(0, is_anthropic)
	_api_type_segments.set_item_disabled(1, is_anthropic)

func _clear_list(list: VBoxContainer) -> void:
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()

# --- Add/remove provider ---

func _on_add_pressed() -> void:
	_add_menu.popup_on(_add_button)

func _on_add_menu_selected(id: int) -> void:
	if id == CUSTOM_PROVIDER_ID:
		_open_wizard({})
		return
	var presets := CopilotProviderPresets.get_presets()
	if id < 0 or id >= presets.size():
		return
	var preset: Dictionary = presets[id]
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
	var confirm := CopilotMd3Confirm.new()
	add_child(confirm)
	confirm.configure(_scheme, "Delete Provider", "Delete", "Cancel")
	confirm.set_message("Delete provider '" + provider_to_remove + "' along with its keys and models?")
	confirm.set_danger(true)
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

func _on_sticky_count_changed(value: int) -> void:
	if not _selected.is_empty():
		config.set_sticky_count(_selected, value)

func _update_sticky_visibility() -> void:
	if _sticky_box != null:
		_sticky_box.visible = not _round_robin_switch.is_checked()

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
	_stop_test_button.visible = _testing

# --- Models ---

func _on_active_model_pressed() -> void:
	if _selected.is_empty():
		return
	_model_menu.clear_items()
	_model_menu_ids.clear()
	var current := config.get_active_model_id()
	var checked_id := -1
	for entry in config.get_available_models():
		var model_id := str(entry.get("id", ""))
		var item_id := _model_menu.add_item(str(entry.get("display_name", model_id)))
		_model_menu_ids[item_id] = model_id
		if model_id == current:
			checked_id = item_id
	if not current.is_empty() and checked_id < 0:
		var extra_id := _model_menu.add_item(current + " (current)")
		_model_menu_ids[extra_id] = current
		checked_id = extra_id
	if checked_id >= 0:
		_model_menu.set_checked_id(checked_id)
	_model_menu.popup_on(_active_model_button)

func _on_model_menu_selected(id: int) -> void:
	var model_id := str(_model_menu_ids.get(id, ""))
	if model_id.is_empty():
		return
	config.set_active_model_id(model_id)
	_refresh_active_model_options()
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
	_import_button.disabled = true
	_import_progress.visible = true
	_import_progress.start()
	_models_status.text = "Importing models from /models…"
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
		_finish_import()
		_models_status.text = "Import failed: the request could not be started."
		return
	var response: Array = await request.request_completed
	request.queue_free()
	_finish_import()
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
		_models_status.text = "Imported " + str(imported) + " models."
		providers_changed.emit()
	else:
		_models_status.text = "Import failed: no models were returned by the endpoint."

func _finish_import() -> void:
	_testing_import = false
	_import_button.disabled = false
	_import_progress.stop()
	_import_progress.visible = false

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

@tool
class_name CopilotSettingsDialog
extends CopilotMd3Dialog
# Three-tab settings dialog: Permissions (preset + rules), Memory (context
# compaction), Agent (max steps + subagent model overrides). All changes are
# saved immediately.

signal settings_changed()

const RULE_LIST_NAMES: Array[String] = ["deny", "ask", "allow"]
const PRESET_ENTRIES := [
	["Sandbox — free inside the project", "Actions outside the project ask for permission."],
	["Review — always asks for permission", "Every action asks unless an Allow rule already grants it."],
	["Turbo — automatic", "Every action is allowed automatically unless a Deny rule blocks it."],
]

var config: CopilotConfig

# Permissions
var _preset_radios: Array[CopilotMd3Radio] = []
var _preset_hint: Label
var _rule_list_segments: CopilotMd3SegmentedButtons
var _rules_list: VBoxContainer
var _rule_edit: CopilotMd3TextField
var _rule_error_label: Label

# Memory
var _memory_auto_switch: CopilotMd3Switch
var _memory_prune_switch: CopilotMd3Switch
var _memory_mode_segments: CopilotMd3SegmentedButtons
var _memory_model_edit: CopilotMd3TextField
var _memory_steps_spin: CopilotMd3SpinField
var _memory_tail_spin: CopilotMd3SpinField

# Agent
var _agent_steps_spin: CopilotMd3SpinField
var _subagent_list: VBoxContainer
var _subagent_name_edit: CopilotMd3TextField
var _subagent_model_button: CopilotMd3Button
var _subagent_model_id := ""
var _subagent_error_label: Label

# Shared model select menu for subagent overrides.
var _model_menu: CopilotMd3Menu
var _model_menu_ids: Dictionary = {}
var _model_menu_target := ""

func _ready() -> void:
	super._ready()
	configure(_scheme, "Settings", "Close")
	min_size = Vector2i(560, 480)
	size = Vector2i(620, 540)
	_build_ui()

func setup(p_config: CopilotConfig) -> void:
	config = p_config
	_build_ui()
	refresh()

func refresh() -> void:
	if sync_scheme():
		return
	if config == null or _preset_radios.is_empty():
		return
	_refresh_permissions()
	_refresh_memory()
	_refresh_agent()

func _on_scheme_changed() -> void:
	# The editor theme switched mode: rebuild every widget with the new
	# palette (the dialog is a long-lived instance).
	_rebuild_content()

func _rebuild_content() -> void:
	if _preset_radios.is_empty():
		return
	_preset_radios.clear()
	_preset_hint = null
	_rule_list_segments = null
	_rules_list = null
	_rule_edit = null
	_rule_error_label = null
	_memory_auto_switch = null
	_memory_prune_switch = null
	_memory_mode_segments = null
	_memory_model_edit = null
	_memory_steps_spin = null
	_memory_tail_spin = null
	_agent_steps_spin = null
	_subagent_list = null
	_subagent_name_edit = null
	_subagent_model_button = null
	_subagent_error_label = null
	_model_menu_ids.clear()
	if _model_menu != null and is_instance_valid(_model_menu):
		_model_menu.queue_free()
	_model_menu = null
	for child in body().get_children():
		if child == _title_label:
			continue
		child.queue_free()
	_build_ui()
	refresh()

# --- Build UI ---

func _build_ui() -> void:
	if not _preset_radios.is_empty():
		return
	var tabs := CopilotMd3Tabs.new()
	tabs.name = "settings_tabs"
	tabs.custom_minimum_size = Vector2(540, 420)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body().add_child(tabs)
	_build_permissions_tab(tabs)
	_build_memory_tab(tabs)
	_build_agent_tab(tabs)

func _build_permissions_tab(tabs: CopilotMd3Tabs) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Permissions"
	tab.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	tabs.add_child(tab)

	tab.add_child(_form_label("Preset"))
	for i in range(PRESET_ENTRIES.size()):
		var radio := CopilotMd3Radio.new()
		tab.add_child(radio)
		radio.configure(_scheme, str(PRESET_ENTRIES[i][0]), str(PRESET_ENTRIES[i][1]))
		radio.pressed.connect(_on_preset_pressed.bind(i))
		_preset_radios.append(radio)

	_preset_hint = _hint_label("")
	tab.add_child(_preset_hint)
	tab.add_child(_divider())

	var rules_row := HBoxContainer.new()
	rules_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	tab.add_child(rules_row)
	var rules_label := _form_label("Rule list")
	rules_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rules_row.add_child(rules_label)
	_rule_list_segments = CopilotMd3SegmentedButtons.new()
	_rule_list_segments.configure(_scheme, PackedStringArray(["Deny (0)", "Ask (0)", "Allow (0)"]))
	_rule_list_segments.tooltip_text = "Choose which rule list is shown"
	_rule_list_segments.item_selected.connect(func(_index: int) -> void: _refresh_rules())
	rules_row.add_child(_rule_list_segments)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)
	_rules_list = VBoxContainer.new()
	_rules_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rules_list.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	scroll.add_child(_rules_list)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	tab.add_child(add_row)
	_rule_edit = CopilotMd3TextField.new()
	_rule_edit.configure(_scheme, "read_file(res://scripts/)", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	_rule_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rule_edit.tooltip_text = "Format: action(target). Example: command(git), http_request(godotengine.org)"
	_rule_edit.text_submitted.connect(func(_text: String) -> void: _on_rule_add_pressed())
	add_row.add_child(_rule_edit)
	var add_button := CopilotMd3IconButton.new()
	add_button.configure(_scheme, CopilotMd3Button.VARIANT_FILLED, "", "add")
	add_button.tooltip_text = "Add a rule to the selected list"
	add_button.pressed.connect(_on_rule_add_pressed)
	add_row.add_child(add_button)

	tab.add_child(_hint_label("Format: action(target). Example: read_file(res://scripts/), command(git)."))
	_rule_error_label = _hint_label("")
	_rule_error_label.add_theme_color_override("font_color", _scheme.color("error"))
	tab.add_child(_rule_error_label)

func _build_memory_tab(tabs: CopilotMd3Tabs) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Memory"
	tab.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	tabs.add_child(tab)

	_memory_auto_switch = _toggle_row(tab, "Automatically compact the conversation as the context grows", "Runs compaction once the number of new steps exceeds the limit")
	_memory_auto_switch.toggled.connect(func(pressed: bool) -> void: _save_memory_value("auto", pressed))
	_memory_prune_switch = _toggle_row(tab, "Prune old tool output", "Replaces old tool output with a placeholder to save context")
	_memory_prune_switch.toggled.connect(func(pressed: bool) -> void: _save_memory_value("prune", pressed))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("m"))
	grid.add_theme_constant_override("v_separation", CopilotMd3Tokens.spacing("m"))
	tab.add_child(grid)

	grid.add_child(_form_label("Compaction mode"))
	_memory_mode_segments = CopilotMd3SegmentedButtons.new()
	_memory_mode_segments.configure(_scheme, PackedStringArray(["Text — summary", "Native — provider"]))
	_memory_mode_segments.tooltip_text = "How long context is handled"
	_memory_mode_segments.item_selected.connect(_on_memory_mode_selected)
	grid.add_child(_memory_mode_segments)

	grid.add_child(_form_label("Compaction model"))
	_memory_model_edit = CopilotMd3TextField.new()
	_memory_model_edit.configure(_scheme, "(empty = active model)", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	_memory_model_edit.tooltip_text = "Model used to create the summary"
	_memory_model_edit.text_submitted.connect(func(_text: String) -> void: _save_memory_model())
	_memory_model_edit.focus_exited.connect(_save_memory_model)
	grid.add_child(_memory_model_edit)

	grid.add_child(_form_label("Compact after"))
	_memory_steps_spin = CopilotMd3SpinField.new()
	_memory_steps_spin.configure(_scheme, 10, 2, 50)
	_memory_steps_spin.tooltip_text = "Number of new steps before a summary is created"
	_memory_steps_spin.value_changed.connect(func(value: int) -> void: _save_memory_value("max_steps", value))
	grid.add_child(_memory_steps_spin)

	grid.add_child(_form_label("Keep last"))
	_memory_tail_spin = CopilotMd3SpinField.new()
	_memory_tail_spin.configure(_scheme, 4, 1, 30)
	_memory_tail_spin.tooltip_text = "Number of trailing steps kept out of compaction and pruning"
	_memory_tail_spin.value_changed.connect(func(value: int) -> void: _save_memory_value("tail_size", value))
	grid.add_child(_memory_tail_spin)

	tab.add_child(_hint_label("The 'native' mode never builds manual summaries; the provider fully manages the context."))

func _build_agent_tab(tabs: CopilotMd3Tabs) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Agent"
	tab.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	tabs.add_child(tab)

	var steps_row := HBoxContainer.new()
	steps_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	tab.add_child(steps_row)
	var steps_label := _form_label("Max ReAct steps")
	steps_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	steps_row.add_child(steps_label)
	_agent_steps_spin = CopilotMd3SpinField.new()
	_agent_steps_spin.configure(_scheme, 10, 1, 50)
	_agent_steps_spin.tooltip_text = "Limit of model → tool rounds before the turn stops"
	_agent_steps_spin.value_changed.connect(_on_agent_steps_changed)
	steps_row.add_child(_agent_steps_spin)

	tab.add_child(_divider())

	var subagent_title := Label.new()
	subagent_title.text = "Sub-agents (model overrides)"
	CopilotMd3Tokens.apply_text(subagent_title, "title-small")
	subagent_title.add_theme_color_override("font_color", _scheme.color("on-surface"))
	tab.add_child(subagent_title)
	tab.add_child(_hint_label("Names of sub-agents recognized by the 'spawn_subagent' tool. An empty model follows the active model."))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab.add_child(scroll)
	_subagent_list = VBoxContainer.new()
	_subagent_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subagent_list.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	scroll.add_child(_subagent_list)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	tab.add_child(add_row)
	_subagent_name_edit = CopilotMd3TextField.new()
	_subagent_name_edit.configure(_scheme, "New sub-agent name", CopilotMd3TextField.VARIANT_OUTLINED, 48)
	_subagent_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subagent_name_edit.tooltip_text = "Add a name the model may call as a sub-agent"
	_subagent_name_edit.text_submitted.connect(func(_text: String) -> void: _on_subagent_add_pressed())
	add_row.add_child(_subagent_name_edit)
	_subagent_model_button = CopilotMd3Button.new()
	_subagent_model_button.configure(_scheme, CopilotMd3Button.VARIANT_OUTLINED)
	_subagent_model_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subagent_model_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subagent_model_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subagent_model_button.tooltip_text = "Model for the new sub-agent (optional)"
	_subagent_model_button.pressed.connect(_on_subagent_model_pressed)
	add_row.add_child(_subagent_model_button)
	var add_button := CopilotMd3IconButton.new()
	add_button.configure(_scheme, CopilotMd3Button.VARIANT_FILLED, "", "add")
	add_button.tooltip_text = "Add sub-agent"
	add_button.pressed.connect(_on_subagent_add_pressed)
	add_row.add_child(add_button)

	_subagent_error_label = _hint_label("")
	_subagent_error_label.add_theme_color_override("font_color", _scheme.color("error"))
	tab.add_child(_subagent_error_label)

	_model_menu = CopilotMd3Menu.new()
	add_child(_model_menu)
	_model_menu.configure(_scheme, true)
	_model_menu.item_selected.connect(_on_model_menu_selected)

# --- Refresh data ---

func _refresh_permissions() -> void:
	var preset := config.get_permission_preset()
	var index := 0
	match preset:
		CopilotConfig.PRESET_REVIEW:
			index = 1
		CopilotConfig.PRESET_TURBO:
			index = 2
	_select_preset_index(index)
	_preset_hint.text = _preset_hint_text(preset)
	_refresh_rule_list_options()
	_refresh_rules()

func _select_preset_index(index: int) -> void:
	for i in range(_preset_radios.size()):
		_preset_radios[i].set_selected(i == index)

func _refresh_rule_list_options() -> void:
	var labels := PackedStringArray()
	var short_names := ["Deny", "Ask", "Allow"]
	for i in range(short_names.size()):
		var count := config.get_permission_rules(RULE_LIST_NAMES[i]).size()
		labels.append(short_names[i] + " (" + str(count) + ")")
	_rule_list_segments.set_items(labels, _rule_list_segments.get_selected())

func _refresh_rules() -> void:
	if _rules_list == null:
		return
	_clear_children(_rules_list)
	var list_name := _current_rule_list()
	var rules := config.get_permission_rules(list_name)
	if rules.is_empty():
		_rules_list.add_child(_hint_label("No rules in this list yet."))
		return
	for rule_var in rules:
		var rule := str(rule_var)
		var row := CopilotMd3ListItem.new()
		_rules_list.add_child(row)
		row.configure(_scheme, rule)
		row.set_dense(true)
		row.set_title_mono(true)
		row.tooltip_text = rule
		var remove_button := CopilotMd3IconButton.new()
		remove_button.configure(_scheme, CopilotMd3IconButton.VARIANT_STANDARD, "", "delete")
		remove_button.set_compact(true)
		remove_button.tooltip_text = "Delete rule " + rule
		remove_button.pressed.connect(func() -> void: _on_rule_remove_pressed(list_name, rule))
		row.add_trailing(remove_button)

func _refresh_memory() -> void:
	_memory_auto_switch.set_checked(config.is_memory_auto())
	_memory_prune_switch.set_checked(config.is_memory_prune())
	_memory_mode_segments.select(1 if config.get_memory_mode() == "native" else 0)
	_memory_model_edit.text = config.get_memory_model()
	_memory_steps_spin.set_value(config.get_memory_max_steps())
	_memory_tail_spin.set_value(config.get_memory_tail_size())

func _refresh_agent() -> void:
	_agent_steps_spin.set_value(config.get_agent_max_steps())
	_update_subagent_model_button()
	_refresh_subagents()

func _refresh_subagents() -> void:
	if _subagent_list == null:
		return
	_clear_children(_subagent_list)
	var names := config.get_subagent_names()
	names.sort()
	if names.is_empty():
		_subagent_list.add_child(_hint_label("No subagent overrides yet."))
		return
	for name_var in names:
		var subagent_name := str(name_var)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
		_subagent_list.add_child(row)
		var label := Label.new()
		label.text = subagent_name
		label.tooltip_text = subagent_name
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size = Vector2(110, 0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		CopilotMd3Tokens.apply_text(label, "body-medium")
		label.add_theme_color_override("font_color", _scheme.color("on-surface"))
		row.add_child(label)
		var current_model := str(config.get_subagent_config(subagent_name).get("model", ""))
		var model_button := CopilotMd3Button.new()
		model_button.configure(_scheme, CopilotMd3Button.VARIANT_OUTLINED)
		model_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		model_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		model_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		model_button.text = _model_label(current_model)
		model_button.tooltip_text = "Model override for sub-agent '" + subagent_name + "'"
		model_button.pressed.connect(_on_subagent_row_model_pressed.bind(subagent_name, model_button))
		row.add_child(model_button)
		var remove_button := CopilotMd3IconButton.new()
		remove_button.configure(_scheme, CopilotMd3IconButton.VARIANT_STANDARD, "", "delete")
		remove_button.set_compact(true)
		remove_button.tooltip_text = "Delete sub-agent " + subagent_name
		remove_button.pressed.connect(func() -> void: _on_subagent_remove_pressed(subagent_name))
		row.add_child(remove_button)

func _update_subagent_model_button() -> void:
	if _subagent_model_button != null:
		_subagent_model_button.text = _model_label(_subagent_model_id)

func _model_label(model_id: String) -> String:
	if model_id.is_empty():
		return "(Active model)"
	for entry in config.get_available_models():
		if str(entry.get("id", "")) == model_id:
			return str(entry.get("display_name", model_id))
	return model_id

# --- Permissions handlers ---

func _on_preset_pressed(index: int) -> void:
	var presets := [CopilotConfig.PRESET_SANDBOX, CopilotConfig.PRESET_REVIEW, CopilotConfig.PRESET_TURBO]
	if index < 0 or index >= presets.size():
		return
	config.set_permission_preset(presets[index])
	_select_preset_index(index)
	_preset_hint.text = _preset_hint_text(presets[index])
	settings_changed.emit()

func _preset_hint_text(preset: String) -> String:
	match preset:
		CopilotConfig.PRESET_REVIEW:
			return "Every action asks for permission unless an Allow rule already grants it."
		CopilotConfig.PRESET_TURBO:
			return "Every action is allowed automatically unless a Deny rule blocks it."
		_:
			return "Free inside the project; actions outside the project ask for permission."

func _on_rule_add_pressed() -> void:
	var rule := _rule_edit.text.strip_edges()
	if rule.is_empty():
		return
	var parsed := CopilotPermissions.new(config).parse_rule(rule)
	var action := str(parsed.get("action", ""))
	var target := str(parsed.get("target", ""))
	if action.is_empty() or target.is_empty():
		_rule_error_label.text = "Invalid rule format. Use action(target)."
		return
	config.add_permission_rule(_current_rule_list(), rule)
	_rule_edit.clear()
	_rule_error_label.text = ""
	_refresh_rule_list_options()
	_refresh_rules()
	settings_changed.emit()

func _on_rule_remove_pressed(list_name: String, rule: String) -> void:
	config.remove_permission_rule(list_name, rule)
	_rule_error_label.text = ""
	_refresh_rule_list_options()
	_refresh_rules()
	settings_changed.emit()

# --- Memory handlers ---

func _on_memory_mode_selected(index: int) -> void:
	_save_memory_value("mode", "native" if index == 1 else "text")

func _save_memory_value(key: String, value: Variant) -> void:
	config.set_memory_value(key, value)
	settings_changed.emit()

func _save_memory_model() -> void:
	var model_id := _memory_model_edit.text.strip_edges()
	if model_id == config.get_memory_model():
		return
	config.set_memory_value("model", model_id)
	settings_changed.emit()

# --- Agent handlers ---

func _on_agent_steps_changed(value: int) -> void:
	config.set_agent_max_steps(value)
	settings_changed.emit()

func _on_subagent_add_pressed() -> void:
	var subagent_name := _subagent_name_edit.text.strip_edges()
	if subagent_name.is_empty():
		_subagent_error_label.text = "Sub-agent name is required."
		return
	if config.get_subagent_names().has(subagent_name):
		_subagent_error_label.text = "Sub-agent '" + subagent_name + "' already exists."
		return
	config.set_subagent_model(subagent_name, _subagent_model_id)
	_subagent_name_edit.clear()
	_subagent_model_id = ""
	_update_subagent_model_button()
	_subagent_error_label.text = ""
	_refresh_subagents()
	settings_changed.emit()

func _on_subagent_remove_pressed(subagent_name: String) -> void:
	config.remove_subagent(subagent_name)
	_subagent_error_label.text = ""
	_refresh_subagents()
	settings_changed.emit()

func _on_subagent_model_pressed() -> void:
	_open_model_menu(_subagent_model_button, _subagent_model_id, "")

func _on_subagent_row_model_pressed(subagent_name: String, button: Button) -> void:
	_open_model_menu(button, str(config.get_subagent_config(subagent_name).get("model", "")), subagent_name)

func _open_model_menu(anchor: Control, current_id: String, target: String) -> void:
	_model_menu.clear_items()
	_model_menu_ids.clear()
	var none_id := _model_menu.add_item("(Active model)")
	_model_menu_ids[none_id] = ""
	var checked_id := none_id
	for entry in config.get_available_models():
		var model_id := str(entry.get("id", ""))
		if model_id.is_empty():
			continue
		var item_id := _model_menu.add_item(str(entry.get("display_name", model_id)))
		_model_menu_ids[item_id] = model_id
		if model_id == current_id:
			checked_id = item_id
	if not current_id.is_empty() and checked_id == none_id:
		# Saved model is unavailable (e.g. disabled): still show it so it does not get lost.
		var extra_id := _model_menu.add_item(current_id + " (unavailable)")
		_model_menu_ids[extra_id] = current_id
		checked_id = extra_id
	_model_menu.set_checked_id(checked_id)
	_model_menu_target = target
	_model_menu.popup_on(anchor)

func _on_model_menu_selected(id: int) -> void:
	var model_id := str(_model_menu_ids.get(id, ""))
	if _model_menu_target.is_empty():
		_subagent_model_id = model_id
		_update_subagent_model_button()
		return
	config.set_subagent_model(_model_menu_target, model_id)
	_refresh_subagents()
	settings_changed.emit()

# --- Helper ---

func _current_rule_list() -> String:
	var index := _rule_list_segments.get_selected()
	return RULE_LIST_NAMES[index] if index >= 0 and index < RULE_LIST_NAMES.size() else "deny"

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _divider() -> CopilotMd3Divider:
	var divider := CopilotMd3Divider.new()
	divider.configure(_scheme)
	return divider

func _toggle_row(parent: Control, text: String, tooltip: String) -> CopilotMd3Switch:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	parent.add_child(row)
	var toggle := CopilotMd3Switch.new()
	toggle.configure(_scheme, false)
	toggle.tooltip_text = tooltip
	toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(toggle)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(label, "body-medium")
	label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	row.add_child(label)
	return toggle

func _form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	CopilotMd3Tokens.apply_text(label, "label-medium")
	label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	return label

func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CopilotMd3Tokens.apply_text(label, "body-small")
	label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	return label

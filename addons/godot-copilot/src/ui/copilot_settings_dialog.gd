@tool
class_name CopilotSettingsDialog
extends AcceptDialog
# Three-tab settings dialog: Permissions (preset + rules), Memory (context compaction),
# Agent (max steps + sub-agent model overrides). All changes are saved immediately.

signal settings_changed()

const RULE_LIST_NAMES: Array[String] = ["deny", "ask", "allow"]

var config: CopilotConfig

# Permissions
var _preset_option: OptionButton
var _preset_hint: Label
var _rule_list_option: OptionButton
var _rules_list: VBoxContainer
var _rule_edit: LineEdit
var _rule_error_label: Label

# Memory
var _memory_auto_check: CheckBox
var _memory_prune_check: CheckBox
var _memory_mode_option: OptionButton
var _memory_model_edit: LineEdit
var _memory_steps_spin: SpinBox
var _memory_tail_spin: SpinBox

# Agent
var _agent_steps_spin: SpinBox
var _subagent_list: VBoxContainer
var _subagent_name_edit: LineEdit
var _subagent_model_option: OptionButton
var _subagent_error_label: Label

func _ready() -> void:
	title = "Godot Copilot — Settings"
	ok_button_text = "Close"
	min_size = Vector2i(560, 480)
	size = Vector2i(620, 540)
	_build_ui()
	get_ok_button().pressed.connect(func() -> void: hide())

func setup(p_config: CopilotConfig) -> void:
	config = p_config
	_build_ui()
	refresh()

func refresh() -> void:
	if config == null or _preset_option == null:
		return
	_refresh_permissions()
	_refresh_memory()
	_refresh_agent()

# --- Build UI ---

func _build_ui() -> void:
	if _preset_option != null:
		return
	var tabs := TabContainer.new()
	tabs.name = "settings_tabs"
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.custom_minimum_size = Vector2(540, 420)
	add_child(tabs)
	_build_permissions_tab(tabs)
	_build_memory_tab(tabs)
	_build_agent_tab(tabs)

func _build_permissions_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Permissions"
	tab.add_theme_constant_override("separation", 6)
	tabs.add_child(tab)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	tab.add_child(preset_row)
	preset_row.add_child(_form_label("Preset"))
	_preset_option = OptionButton.new()
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_option.tooltip_text = "Base permission preset for all tools"
	_preset_option.add_item("Sandbox — free inside the project")
	_preset_option.add_item("Review — always asks for permission")
	_preset_option.add_item("Turbo — automatic")
	_preset_option.item_selected.connect(_on_preset_selected)
	preset_row.add_child(_preset_option)

	_preset_hint = _hint_label("")
	tab.add_child(_preset_hint)

	tab.add_child(HSeparator.new())

	var rules_row := HBoxContainer.new()
	rules_row.add_theme_constant_override("separation", 6)
	tab.add_child(rules_row)
	rules_row.add_child(_form_label("Rule list"))
	_rule_list_option = OptionButton.new()
	_rule_list_option.tooltip_text = "Choose which rule list is shown"
	_rule_list_option.add_item("Deny")
	_rule_list_option.add_item("Ask")
	_rule_list_option.add_item("Allow")
	_rule_list_option.item_selected.connect(func(_index: int) -> void: _refresh_rules())
	rules_row.add_child(_rule_list_option)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)
	_rules_list = VBoxContainer.new()
	_rules_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rules_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_rules_list)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	tab.add_child(add_row)
	_rule_edit = LineEdit.new()
	_rule_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rule_edit.placeholder_text = "read_file(res://scripts/)"
	_rule_edit.tooltip_text = "Format: action(target). Example: command(git), http_request(godotengine.org)"
	_rule_edit.text_submitted.connect(func(_text: String) -> void: _on_rule_add_pressed())
	add_row.add_child(_rule_edit)
	var add_button := Button.new()
	add_button.tooltip_text = "Add a rule to the selected list"
	CopilotTheme.apply_icon(add_button, PackedStringArray(["Add"]), "+")
	add_button.pressed.connect(_on_rule_add_pressed)
	add_row.add_child(add_button)

	tab.add_child(_hint_label("Format: action(target). Example: read_file(res://scripts/), command(git)."))
	_rule_error_label = _hint_label("")
	_rule_error_label.add_theme_color_override("font_color", CopilotTheme.error_color(self))
	tab.add_child(_rule_error_label)

func _build_memory_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Memory"
	tab.add_theme_constant_override("separation", 8)
	tabs.add_child(tab)

	_memory_auto_check = CheckBox.new()
	_memory_auto_check.text = "Automatically compact the conversation as the context grows"
	_memory_auto_check.tooltip_text = "Runs compaction once the number of new steps exceeds the limit"
	_memory_auto_check.toggled.connect(func(pressed: bool) -> void: _save_memory_value("auto", pressed))
	tab.add_child(_memory_auto_check)

	_memory_prune_check = CheckBox.new()
	_memory_prune_check.text = "Prune old tool output"
	_memory_prune_check.tooltip_text = "Replaces old tool output with a placeholder to save context"
	_memory_prune_check.toggled.connect(func(pressed: bool) -> void: _save_memory_value("prune", pressed))
	tab.add_child(_memory_prune_check)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	tab.add_child(grid)

	grid.add_child(_form_label("Compaction mode"))
	_memory_mode_option = OptionButton.new()
	_memory_mode_option.tooltip_text = "How long context is handled"
	_memory_mode_option.add_item("text — conversation summary")
	_memory_mode_option.add_item("native — delegate to the provider")
	_memory_mode_option.item_selected.connect(_on_memory_mode_selected)
	grid.add_child(_memory_mode_option)

	grid.add_child(_form_label("Compaction model"))
	_memory_model_edit = LineEdit.new()
	_memory_model_edit.placeholder_text = "(empty = active model)"
	_memory_model_edit.tooltip_text = "Model used to create the summary"
	_memory_model_edit.text_submitted.connect(func(_text: String) -> void: _save_memory_model())
	_memory_model_edit.focus_exited.connect(_save_memory_model)
	grid.add_child(_memory_model_edit)

	grid.add_child(_form_label("Compact after"))
	_memory_steps_spin = SpinBox.new()
	_memory_steps_spin.min_value = 2
	_memory_steps_spin.max_value = 50
	_memory_steps_spin.suffix = " steps"
	_memory_steps_spin.tooltip_text = "Number of new steps before a summary is created"
	_memory_steps_spin.value_changed.connect(func(value: float) -> void: _save_memory_value("max_steps", int(value)))
	grid.add_child(_memory_steps_spin)

	grid.add_child(_form_label("Keep last"))
	_memory_tail_spin = SpinBox.new()
	_memory_tail_spin.min_value = 1
	_memory_tail_spin.max_value = 30
	_memory_tail_spin.suffix = " steps"
	_memory_tail_spin.tooltip_text = "Number of trailing steps kept out of compaction and pruning"
	_memory_tail_spin.value_changed.connect(func(value: float) -> void: _save_memory_value("tail_size", int(value)))
	grid.add_child(_memory_tail_spin)

	tab.add_child(_hint_label("The 'native' mode never builds manual summaries; the provider fully manages the context."))

func _build_agent_tab(tabs: TabContainer) -> void:
	var tab := VBoxContainer.new()
	tab.name = "Agent"
	tab.add_theme_constant_override("separation", 8)
	tabs.add_child(tab)

	var steps_row := HBoxContainer.new()
	steps_row.add_theme_constant_override("separation", 6)
	tab.add_child(steps_row)
	steps_row.add_child(_form_label("Max ReAct steps"))
	_agent_steps_spin = SpinBox.new()
	_agent_steps_spin.min_value = 1
	_agent_steps_spin.max_value = 50
	_agent_steps_spin.suffix = " steps"
	_agent_steps_spin.tooltip_text = "Limit of model → tool rounds before the turn stops"
	_agent_steps_spin.value_changed.connect(_on_agent_steps_changed)
	steps_row.add_child(_agent_steps_spin)

	tab.add_child(HSeparator.new())

	var subagent_title := Label.new()
	subagent_title.text = "Sub-agents (model overrides)"
	tab.add_child(subagent_title)
	tab.add_child(_hint_label("Names of sub-agents recognized by the 'spawn_subagent' tool. An empty model follows the active model."))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)
	_subagent_list = VBoxContainer.new()
	_subagent_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subagent_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_subagent_list)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	tab.add_child(add_row)
	_subagent_name_edit = LineEdit.new()
	_subagent_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subagent_name_edit.placeholder_text = "New sub-agent name"
	_subagent_name_edit.tooltip_text = "Add a name the model may call as a sub-agent"
	_subagent_name_edit.text_submitted.connect(func(_text: String) -> void: _on_subagent_add_pressed())
	add_row.add_child(_subagent_name_edit)
	_subagent_model_option = OptionButton.new()
	_subagent_model_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subagent_model_option.tooltip_text = "Model for the new sub-agent (optional)"
	add_row.add_child(_subagent_model_option)
	var add_button := Button.new()
	add_button.tooltip_text = "Add sub-agent"
	CopilotTheme.apply_icon(add_button, PackedStringArray(["Add"]), "+")
	add_button.pressed.connect(_on_subagent_add_pressed)
	add_row.add_child(add_button)

	_subagent_error_label = _hint_label("")
	_subagent_error_label.add_theme_color_override("font_color", CopilotTheme.error_color(self))
	tab.add_child(_subagent_error_label)

# --- Refresh data ---

func _refresh_permissions() -> void:
	var preset := config.get_permission_preset()
	var index := 0
	match preset:
		CopilotConfig.PRESET_REVIEW:
			index = 1
		CopilotConfig.PRESET_TURBO:
			index = 2
	_preset_option.selected = index
	_update_preset_hint(preset)
	_refresh_rule_list_options()
	_refresh_rules()

func _refresh_rule_list_options() -> void:
	var labels := ["Deny", "Ask", "Allow"]
	for i in range(labels.size()):
		var count := config.get_permission_rules(RULE_LIST_NAMES[i]).size()
		_rule_list_option.set_item_text(i, labels[i] + " (" + str(count) + ")")

func _refresh_rules() -> void:
	if _rules_list == null:
		return
	_clear_children(_rules_list)
	var list_name := _current_rule_list()
	var rules := config.get_permission_rules(list_name)
	if rules.is_empty():
		var empty := _hint_label("No rules in this list yet.")
		_rules_list.add_child(empty)
		return
	for rule_var in rules:
		var rule := str(rule_var)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_rules_list.add_child(row)
		var label := Label.new()
		label.text = rule
		label.tooltip_text = rule
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove_button := Button.new()
		remove_button.focus_mode = Control.FOCUS_NONE
		remove_button.tooltip_text = "Delete rule " + rule
		CopilotTheme.apply_icon(remove_button, PackedStringArray(["Remove"]), "✕")
		remove_button.pressed.connect(func() -> void: _on_rule_remove_pressed(list_name, rule))
		row.add_child(remove_button)

func _refresh_memory() -> void:
	_memory_auto_check.set_pressed_no_signal(config.is_memory_auto())
	_memory_prune_check.set_pressed_no_signal(config.is_memory_prune())
	_memory_mode_option.selected = 1 if config.get_memory_mode() == "native" else 0
	_memory_model_edit.text = config.get_memory_model()
	_memory_steps_spin.set_value_no_signal(config.get_memory_max_steps())
	_memory_tail_spin.set_value_no_signal(config.get_memory_tail_size())

func _refresh_agent() -> void:
	_agent_steps_spin.set_value_no_signal(config.get_agent_max_steps())
	_fill_model_option(_subagent_model_option, "")
	_refresh_subagents()

func _refresh_subagents() -> void:
	if _subagent_list == null:
		return
	_clear_children(_subagent_list)
	var names := config.get_subagent_names()
	names.sort()
	if names.is_empty():
		_subagent_list.add_child(_hint_label("No sub-agents registered yet."))
		return
	for name_var in names:
		var subagent_name := str(name_var)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_subagent_list.add_child(row)
		var label := Label.new()
		label.text = subagent_name
		label.tooltip_text = subagent_name
		label.clip_text = true
		label.custom_minimum_size = Vector2(110, 0)
		row.add_child(label)
		var model_option := OptionButton.new()
		model_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		model_option.tooltip_text = "Model override for sub-agent '" + subagent_name + "'"
		_fill_model_option(model_option, str(config.get_subagent_config(subagent_name).get("model", "")))
		model_option.item_selected.connect(func(index: int) -> void:
			_on_subagent_model_selected(subagent_name, model_option, index)
		)
		row.add_child(model_option)
		var remove_button := Button.new()
		remove_button.focus_mode = Control.FOCUS_NONE
		remove_button.tooltip_text = "Delete sub-agent " + subagent_name
		CopilotTheme.apply_icon(remove_button, PackedStringArray(["Remove"]), "✕")
		remove_button.pressed.connect(func() -> void: _on_subagent_remove_pressed(subagent_name))
		row.add_child(remove_button)

func _fill_model_option(option: OptionButton, current_id: String) -> void:
	option.clear()
	option.add_item("(Active model)")
	option.set_item_metadata(0, "")
	var selected_index := 0
	for entry in config.get_available_models():
		var model_id := str(entry.get("id", ""))
		if model_id.is_empty():
			continue
		option.add_item(str(entry.get("display_name", model_id)))
		option.set_item_metadata(option.item_count - 1, model_id)
		if model_id == current_id:
			selected_index = option.item_count - 1
	if not current_id.is_empty() and selected_index == 0:
		# Saved model is unavailable (e.g. disabled): still show it so it does not get lost.
		option.add_item(current_id + " (unavailable)")
		option.set_item_metadata(option.item_count - 1, current_id)
		selected_index = option.item_count - 1
	option.selected = selected_index

# --- Permissions handlers ---

func _on_preset_selected(index: int) -> void:
	var presets := [CopilotConfig.PRESET_SANDBOX, CopilotConfig.PRESET_REVIEW, CopilotConfig.PRESET_TURBO]
	if index < 0 or index >= presets.size():
		return
	config.set_permission_preset(presets[index])
	_update_preset_hint(presets[index])
	settings_changed.emit()

func _update_preset_hint(preset: String) -> void:
	match preset:
		CopilotConfig.PRESET_REVIEW:
			_preset_hint.text = "Every action asks for permission unless an Allow rule already grants it."
		CopilotConfig.PRESET_TURBO:
			_preset_hint.text = "Every action is allowed automatically unless a Deny rule blocks it."
		_:
			_preset_hint.text = "Free inside the project; actions outside the project ask for permission."

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

func _on_agent_steps_changed(value: float) -> void:
	config.set_agent_max_steps(int(value))
	settings_changed.emit()

func _on_subagent_add_pressed() -> void:
	var subagent_name := _subagent_name_edit.text.strip_edges()
	if subagent_name.is_empty():
		_subagent_error_label.text = "Sub-agent name is required."
		return
	if config.get_subagent_names().has(subagent_name):
		_subagent_error_label.text = "Sub-agent '" + subagent_name + "' already exists."
		return
	var model_id := str(_subagent_model_option.get_item_metadata(_subagent_model_option.selected))
	config.set_subagent_model(subagent_name, model_id)
	_subagent_name_edit.clear()
	_subagent_error_label.text = ""
	_fill_model_option(_subagent_model_option, "")
	_refresh_subagents()
	settings_changed.emit()

func _on_subagent_model_selected(subagent_name: String, option: OptionButton, index: int) -> void:
	config.set_subagent_model(subagent_name, str(option.get_item_metadata(index)))
	settings_changed.emit()

func _on_subagent_remove_pressed(subagent_name: String) -> void:
	config.remove_subagent(subagent_name)
	_subagent_error_label.text = ""
	_refresh_subagents()
	settings_changed.emit()

# --- Helper ---

func _current_rule_list() -> String:
	var index := _rule_list_option.selected
	return RULE_LIST_NAMES[index] if index >= 0 and index < RULE_LIST_NAMES.size() else "deny"

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _form_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(label))
	return label

func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(label))
	return label

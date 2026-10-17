@tool
extends EditorPlugin
# Plugin entry point: installs CopilotDock in the right dock area, brings up
# CopilotAgent, opens the Provider Manager / Settings dialogs, and provides the
# Tools menu entries.
# Godot 4.7+ uses EditorDock (the dock can be moved/floated); older versions fall
# back to add_control_to_dock(). All 4.7-only API calls are made dynamically via
# ClassDB/call() so this file still parses on Godot 4.4-4.6.

const DOCK_TITLE := "Copilot"
const DOCK_LAYOUT_KEY := "Copilot"
const MENU_PREFIX := "Godot Copilot: "
const PLUGIN_ICON_PATH := "res://addons/godot-copilot/assets/icons/copilot.svg"

const MENU_PROVIDER_MANAGER := MENU_PREFIX + "Provider Manager…"
const MENU_SETTINGS := MENU_PREFIX + "Settings…"
const MENU_FOCUS_CHAT := MENU_PREFIX + "Focus Chat"

var _config: CopilotConfig
var _agent: CopilotAgent
var _dock: CopilotDock = null

# EditorDock (Godot 4.7+) wrapper around _dock; null when the fallback is used.
var _dock_wrapper: Node = null

var _provider_manager: CopilotProviderManager = null
var _settings_dialog: CopilotSettingsDialog = null

func _enter_tree() -> void:
	_config = CopilotConfig.new()

	_agent = CopilotAgent.new()
	_agent.name = "CopilotAgent"
	_agent.setup(_config, self)
	add_child(_agent)

	_dock = CopilotDock.new()
	_dock.name = "CopilotDock"
	_dock.setup(_agent)
	_dock.provider_manager_requested.connect(_on_open_provider_manager)
	_dock.settings_requested.connect(_on_open_settings)
	_install_dock()

	add_tool_menu_item(MENU_PROVIDER_MANAGER, _on_open_provider_manager)
	add_tool_menu_item(MENU_SETTINGS, _on_open_settings)
	add_tool_menu_item(MENU_FOCUS_CHAT, _on_focus_chat)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_PROVIDER_MANAGER)
	remove_tool_menu_item(MENU_SETTINGS)
	remove_tool_menu_item(MENU_FOCUS_CHAT)

	if _provider_manager != null and is_instance_valid(_provider_manager):
		_provider_manager.queue_free()
	_provider_manager = null

	if _settings_dialog != null and is_instance_valid(_settings_dialog):
		_settings_dialog.queue_free()
	_settings_dialog = null

	if _dock_wrapper != null and is_instance_valid(_dock_wrapper):
		call("remove_dock", _dock_wrapper)
		_dock_wrapper.queue_free()
		_dock_wrapper = null
	elif _dock != null and is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null

	if _agent != null and is_instance_valid(_agent):
		_agent.queue_free()
	_agent = null

	_config = null

func _get_plugin_icon() -> Texture2D:
	if FileAccess.file_exists(PLUGIN_ICON_PATH):
		return load(PLUGIN_ICON_PATH) as Texture2D
	return CopilotTheme.icon(null, PackedStringArray(["Terminal"]))

# --- Dock ---

func _install_dock() -> void:
	var editor_dock = _create_editor_dock()
	if editor_dock != null:
		editor_dock.add_child(_dock)
		_dock_wrapper = editor_dock
		call("add_dock", editor_dock)
		return
	add_control_to_dock(_dock_slot(), _dock, _create_dock_shortcut())

func _create_editor_dock():
	if not ClassDB.class_exists("EditorDock") or not has_method("add_dock"):
		return null
	var editor_dock = ClassDB.instantiate("EditorDock")
	if editor_dock == null:
		return null
	_set_property_if_supported(editor_dock, "title", DOCK_TITLE)
	_set_property_if_supported(editor_dock, "layout_key", DOCK_LAYOUT_KEY)
	_set_property_if_supported(editor_dock, "icon_name", &"Terminal")
	_set_property_if_supported(editor_dock, "default_slot", _dock_slot())
	_set_property_if_supported(editor_dock, "available_layouts", _dock_layouts_all())
	_set_property_if_supported(editor_dock, "dock_shortcut", _create_dock_shortcut())
	return editor_dock

func _dock_slot() -> int:
	for class_name_value in ["EditorDock", "EditorPlugin"]:
		if ClassDB.class_has_integer_constant(class_name_value, "DOCK_SLOT_RIGHT_BL"):
			return ClassDB.class_get_integer_constant(class_name_value, "DOCK_SLOT_RIGHT_BL")
	return 5

func _dock_layouts_all() -> int:
	if ClassDB.class_has_integer_constant("EditorDock", "DOCK_LAYOUT_ALL"):
		return ClassDB.class_get_integer_constant("EditorDock", "DOCK_LAYOUT_ALL")
	return 7

func _create_dock_shortcut() -> Shortcut:
	var shortcut := Shortcut.new()
	var event := InputEventKey.new()
	event.keycode = KEY_C
	event.alt_pressed = true
	event.shift_pressed = true
	var events: Array[InputEvent] = [event]
	shortcut.events = events
	return shortcut

func _set_property_if_supported(object: Object, property: StringName, value: Variant) -> void:
	for property_info in object.get_property_list():
		if property_info.get("name", "") == property:
			object.set(property, value)
			return

# --- Menu & dialog ---

func _on_open_provider_manager() -> void:
	if _provider_manager == null or not is_instance_valid(_provider_manager):
		_provider_manager = CopilotProviderManager.new()
		EditorInterface.get_base_control().add_child(_provider_manager)
		_provider_manager.setup(_config)
		_provider_manager.providers_changed.connect(_refresh_dock)
	_provider_manager.popup_centered()

func _on_open_settings() -> void:
	if _settings_dialog == null or not is_instance_valid(_settings_dialog):
		_settings_dialog = CopilotSettingsDialog.new()
		EditorInterface.get_base_control().add_child(_settings_dialog)
		_settings_dialog.setup(_config)
		_settings_dialog.settings_changed.connect(_refresh_dock)
	_settings_dialog.popup_centered()

func _on_focus_chat() -> void:
	if _dock_wrapper != null and is_instance_valid(_dock_wrapper):
		_dock_wrapper.call("make_visible")
	if _dock != null and is_instance_valid(_dock):
		_dock.focus_composer()

func _refresh_dock() -> void:
	if _dock != null and is_instance_valid(_dock):
		_dock.refresh()

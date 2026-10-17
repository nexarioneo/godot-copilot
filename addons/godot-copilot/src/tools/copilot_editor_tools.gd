@tool
class_name CopilotEditorTools
extends RefCounted
# Editor-related tools: Project Settings, script editor, filesystem rescan.

func get_project_setting(args: Dictionary) -> Dictionary:
	var setting := str(args.get("setting", "")).strip_edges()
	if setting.is_empty():
		return _error("Parameter 'setting' is required.")
	if not ProjectSettings.has_setting(setting):
		return _error("Project setting not found: " + setting)
	return {"success": true, "setting": setting, "value": _json_safe(ProjectSettings.get_setting(setting))}

func set_project_setting(args: Dictionary) -> Dictionary:
	var setting := str(args.get("setting", "")).strip_edges()
	if setting.is_empty():
		return _error("Parameter 'setting' is required.")
	if not args.has("value"):
		return _error("Parameter 'value' is required.")
	if not ProjectSettings.has_setting(setting):
		return _error("Project setting not found: " + setting)
	var converted = _convert_for_setting(ProjectSettings.get_setting(setting), args.get("value"))
	ProjectSettings.set_setting(setting, converted)
	var err := ProjectSettings.save()
	if err != OK:
		return _error("Failed to save project.godot (code " + str(err) + ").")
	return {"success": true, "setting": setting, "value": _json_safe(converted)}

func get_open_scripts(_args: Dictionary) -> Dictionary:
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return _error("Script editor is not available.")
	var scripts: Array = []
	for script in script_editor.get_open_scripts():
		if script is Script:
			scripts.append({
				"path": script.resource_path,
				"global_name": str(script.get_global_name()),
				"is_current": script == script_editor.get_current_script()
			})
	return {"success": true, "scripts": scripts, "count": scripts.size()}

func rescan_filesystem(_args: Dictionary) -> Dictionary:
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem == null:
		return _error("Filesystem dock is not available.")
	filesystem.scan()
	return {"success": true, "message": "Filesystem rescan started."}

func _convert_for_setting(current, raw_value):
	if raw_value is String and not (current is String):
		var parsed = str_to_var(raw_value)
		if parsed != null:
			return parsed
	if current is float and (raw_value is int or raw_value is float):
		return float(raw_value)
	if current is int and (raw_value is int or raw_value is float):
		return int(raw_value)
	if current is bool and raw_value is String:
		return raw_value.strip_edges().to_lower() in ["true", "1", "yes", "on"]
	return raw_value

func _json_safe(value):
	if value == null or value is String or value is bool or value is int or value is float:
		return value
	if value is Array:
		var array_out: Array = []
		for item in value:
			array_out.append(_json_safe(item))
		return array_out
	if value is Dictionary:
		var dict_out: Dictionary = {}
		for key in value.keys():
			dict_out[str(key)] = _json_safe(value[key])
		return dict_out
	return str(value)

func _error(message: String) -> Dictionary:
	return {"success": false, "error": message}

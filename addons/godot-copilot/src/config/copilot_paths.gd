@tool
class_name CopilotPaths
extends RefCounted
# Path and IO utilities for the whole addon. This is the only place allowed to
# contain literal user:// and res://.godot paths (including migration sources).

const USER_ROOT := "user://godot-copilot"
const SETTINGS_FILE := USER_ROOT + "/settings.json"
const SETTINGS_BACKUP_FILE := USER_ROOT + "/settings.backup.json"
const SESSIONS_DIR := USER_ROOT + "/sessions"
const TEMP_DIR := USER_ROOT + "/tmp"

# Version 2 storage used before the addon folder rename
# (addons/godot_copilot -> addons/godot-copilot). Migration source only.
const LEGACY_V2_ROOT := "user://godot_copilot"
const LEGACY_V2_SETTINGS_FILE := LEGACY_V2_ROOT + "/settings.json"
const LEGACY_V2_SETTINGS_BACKUP_FILE := LEGACY_V2_ROOT + "/settings.backup.json"
const LEGACY_V2_SESSIONS_DIR := LEGACY_V2_ROOT + "/sessions"

# Version 1 storage (only read by migration code, never written again).
const LEGACY_V1_SETTINGS_FILE := "res://.godot/.copilot/config/settings.json"
const LEGACY_V1_SESSIONS_DIR := "res://.godot/.copilot/conversations"

static func ensure_dir(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return true
	return DirAccess.make_dir_recursive_absolute(path) == OK

static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)

static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

static func write_text(path: String, text: String) -> Error:
	var dir_path := path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		var dir_err := DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_err != OK:
			return dir_err
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK

static func remove_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK

static func list_json_files(dir_path: String) -> PackedStringArray:
	var results: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with(".") and entry.ends_with(".json"):
			results.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return results

static func temp_dir() -> String:
	ensure_dir(TEMP_DIR)
	return TEMP_DIR

static func copy_file(from_path: String, to_path: String) -> bool:
	var source := FileAccess.open(from_path, FileAccess.READ)
	if source == null:
		return false
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var target := FileAccess.open(to_path, FileAccess.WRITE)
	if target == null:
		return false
	target.store_buffer(bytes)
	target.close()
	return true

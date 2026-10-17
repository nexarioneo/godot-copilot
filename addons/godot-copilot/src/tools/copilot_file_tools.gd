@tool
class_name CopilotFileTools
extends RefCounted
# Text file read/write/edit tools. Does not check permissions itself — the check lives in CopilotAgent.

const MAX_READ_CHARS := 131072
const MAX_LIST_ENTRIES := 500
const MAX_TEXT_FILE_BYTES := 2097152
const SNIFF_BYTES := 4096

# --- Path helpers (also used by CopilotSearchTools) ---

static func resolve_path(path: String) -> String:
	var clean := path.strip_edges().replace("\\", "/")
	if clean.is_empty():
		return ""
	if clean.begins_with("res://") or clean.begins_with("user://") or clean.begins_with("/"):
		return clean
	if clean.length() > 1 and clean.substr(1, 1) == ":":
		return clean
	return "res://" + clean

static func read_text_file(path: String, max_bytes := MAX_TEXT_FILE_BYTES) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File not found: " + path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Failed to open file (code " + str(FileAccess.get_open_error()) + ")."}
	var length := file.get_length()
	if length > max_bytes:
		file.close()
		return {"success": false, "error": "File too large (" + str(length) + " bytes; limit " + str(max_bytes) + ")."}
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() > 0 and bytes.slice(0, mini(bytes.size(), SNIFF_BYTES)).find(0) != -1:
		return {"success": false, "error": "Binary file cannot be read as text: " + path}
	return {"success": true, "content": bytes.get_string_from_utf8()}

static func collect_files(base_path: String, max_entries := MAX_LIST_ENTRIES) -> Array[String]:
	var files: Array[String] = []
	_collect_files_recursive(base_path, files, max_entries)
	return files

static func _collect_files_recursive(dir_path: String, files: Array[String], max_entries: int) -> void:
	if files.size() >= max_entries:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_files_recursive(full_path, files, max_entries)
		else:
			files.append(full_path)
			if files.size() >= max_entries:
				break
		entry = dir.get_next()
	dir.list_dir_end()

static func glob_match(pattern: String, relative_path: String) -> bool:
	if relative_path.match(pattern):
		return true
	if pattern.begins_with("**/"):
		# "**/*.gd" must match at any depth regardless of how '*' matches '/'.
		var rest := pattern.substr(3)
		if relative_path.match(rest) or relative_path.get_file().match(rest):
			return true
		var parts := relative_path.split("/")
		for i in range(1, parts.size()):
			if "/".join(parts.slice(i)).match(rest):
				return true
		return false
	var double_star := pattern.find("/**/")
	if double_star != -1:
		var prefix := pattern.substr(0, double_star)
		var rest := pattern.substr(double_star + 4)
		if relative_path.begins_with(prefix + "/"):
			return glob_match(rest, relative_path.substr(prefix.length() + 1))
	return false

# --- Tool: read ---

func read_file(args: Dictionary) -> Dictionary:
	var path := resolve_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Parameter 'path' is required.")
	var loaded := read_text_file(path)
	if not loaded.get("success", false):
		return loaded
	var text: String = loaded["content"]
	var lines := text.split("\n")
	var total_lines := maxi(1, lines.size())
	var start_line := clampi(int(args.get("start_line", 1)), 1, total_lines)
	var end_line := clampi(int(args.get("end_line", total_lines)), start_line, total_lines)
	var content := "\n".join(lines.slice(start_line - 1, end_line))
	var truncated := false
	if content.length() > MAX_READ_CHARS:
		content = content.substr(0, MAX_READ_CHARS)
		truncated = true
	return {
		"success": true,
		"path": path,
		"content": content,
		"start_line": start_line,
		"end_line": end_line,
		"total_lines": total_lines,
		"truncated": truncated
	}

func list_files(args: Dictionary) -> Dictionary:
	var base := resolve_path(str(args.get("path", "res://")))
	if base.is_empty():
		base = "res://"
	if not DirAccess.dir_exists_absolute(base):
		return _error("Directory not found: " + base)
	var files := collect_files(base, MAX_LIST_ENTRIES)
	files.sort()
	return {
		"success": true,
		"path": base,
		"files": files,
		"count": files.size(),
		"truncated": files.size() >= MAX_LIST_ENTRIES
	}

# --- Tool: write ---

func write_file(args: Dictionary) -> Dictionary:
	var path := resolve_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Parameter 'path' is required.")
	if not args.has("content"):
		return _error("Parameter 'content' is required.")
	var content_value = args.get("content", "")
	var content := content_value if content_value is String else JSON.stringify(content_value)
	var err := CopilotPaths.write_text(path, content)
	if err != OK:
		return _error("Failed to write file (code " + str(err) + ").")
	return {"success": true, "path": path, "chars": content.length()}

func edit_file_lines(args: Dictionary) -> Dictionary:
	var path := resolve_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Parameter 'path' is required.")
	var loaded := read_text_file(path)
	if not loaded.get("success", false):
		return loaded
	var lines: PackedStringArray = str(loaded["content"]).replace("\r\n", "\n").split("\n")
	if not (args.has("start_line") and args.has("end_line") and args.has("new_content")):
		return _error("Parameters 'start_line', 'end_line' and 'new_content' are required.")
	var start_line := int(args.get("start_line", 1))
	var end_line := int(args.get("end_line", start_line))
	if start_line < 1 or end_line < start_line or start_line > lines.size():
		return _error("Invalid line range (" + str(start_line) + "-" + str(end_line) + "; file has " + str(lines.size()) + " lines).")
	end_line = mini(end_line, lines.size())
	var replacement: PackedStringArray = str(args.get("new_content", "")).replace("\r\n", "\n").split("\n")
	var new_lines := PackedStringArray()
	new_lines.append_array(lines.slice(0, start_line - 1))
	new_lines.append_array(replacement)
	new_lines.append_array(lines.slice(end_line))
	var err := CopilotPaths.write_text(path, "\n".join(new_lines))
	if err != OK:
		return _error("Failed to write file (code " + str(err) + ").")
	return {"success": true, "path": path, "start_line": start_line, "end_line": end_line, "total_lines": new_lines.size()}

func patch_file(args: Dictionary) -> Dictionary:
	var path := resolve_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Parameter 'path' is required.")
	var old_text := str(args.get("old_text", ""))
	if old_text.is_empty():
		return _error("Parameter 'old_text' is required and must not be empty.")
	var new_text := str(args.get("new_text", ""))
	var loaded := read_text_file(path)
	if not loaded.get("success", false):
		return loaded
	var text: String = loaded["content"]
	var index := text.find(old_text)
	if index == -1:
		return _error("Old text not found in " + path + ". Re-read the file and adjust 'old_text'.")
	var updated := text.substr(0, index) + new_text + text.substr(index + old_text.length())
	var err := CopilotPaths.write_text(path, updated)
	if err != OK:
		return _error("Failed to write file (code " + str(err) + ").")
	return {"success": true, "path": path, "replaced_at": index}

func delete_file(args: Dictionary) -> Dictionary:
	var path := resolve_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Parameter 'path' is required.")
	if not FileAccess.file_exists(path):
		return _error("File not found: " + path)
	if DirAccess.remove_absolute(path) != OK:
		return _error("Failed to delete file: " + path)
	return {"success": true, "path": path}

func _error(message: String) -> Dictionary:
	return {"success": false, "error": message}

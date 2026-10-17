@tool
class_name CopilotSearchTools
extends RefCounted
# Search tools: glob_files & grep_search.

const MAX_GLOB_RESULTS := 300
const MAX_GREP_RESULTS := 200
const MAX_SCAN_FILES := 2000
const MAX_LINE_LENGTH := 300

func glob_files(args: Dictionary) -> Dictionary:
	var pattern := str(args.get("pattern", "")).strip_edges()
	if pattern.is_empty():
		return _error("Parameter 'pattern' is required.")
	var base := CopilotFileTools.resolve_path(str(args.get("path", "res://")))
	if base.is_empty():
		base = "res://"
	if not DirAccess.dir_exists_absolute(base):
		return _error("Directory not found: " + base)

	var matches: Array = []
	for file_path in CopilotFileTools.collect_files(base, MAX_SCAN_FILES):
		var relative := file_path.trim_prefix(base).trim_prefix("/")
		if CopilotFileTools.glob_match(pattern, relative):
			matches.append(file_path)
			if matches.size() >= MAX_GLOB_RESULTS:
				break
	matches.sort()
	return {
		"success": true,
		"pattern": pattern,
		"path": base,
		"files": matches,
		"count": matches.size(),
		"truncated": matches.size() >= MAX_GLOB_RESULTS
	}

func grep_search(args: Dictionary) -> Dictionary:
	var pattern := str(args.get("pattern", ""))
	if pattern.is_empty():
		return _error("Parameter 'pattern' is required.")
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return _error("Invalid regex pattern: " + pattern)
	var base := CopilotFileTools.resolve_path(str(args.get("path", "res://")))
	if base.is_empty():
		base = "res://"
	if not DirAccess.dir_exists_absolute(base):
		return _error("Directory not found: " + base)
	var file_filter := str(args.get("file_pattern", "")).strip_edges()
	var max_results := clampi(int(args.get("max_results", 50)), 1, MAX_GREP_RESULTS)

	var matches: Array = []
	for file_path in CopilotFileTools.collect_files(base, MAX_SCAN_FILES):
		if matches.size() >= max_results:
			break
		if not file_filter.is_empty() and not CopilotFileTools.glob_match(file_filter, file_path.get_file()):
			continue
		var loaded := CopilotFileTools.read_text_file(file_path)
		if not loaded.get("success", false):
			continue
		var lines: PackedStringArray = str(loaded["content"]).split("\n")
		for line_index in range(lines.size()):
			if matches.size() >= max_results:
				break
			var found := regex.search(lines[line_index])
			if found == null:
				continue
			matches.append({
				"file": file_path,
				"line": line_index + 1,
				"column": found.get_start() + 1,
				"text": _truncate_line(lines[line_index])
			})
	return {
		"success": true,
		"pattern": pattern,
		"path": base,
		"matches": matches,
		"count": matches.size(),
		"truncated": matches.size() >= max_results
	}

func _truncate_line(line: String) -> String:
	var clean := line.strip_edges(false, true)
	if clean.length() > MAX_LINE_LENGTH:
		return clean.substr(0, MAX_LINE_LENGTH) + "…"
	return clean

func _error(message: String) -> Dictionary:
	return {"success": false, "error": message}

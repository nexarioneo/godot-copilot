@tool
class_name CopilotSessionStore
extends RefCounted
# Chat session persistence: user://godot-copilot/sessions/<id>.json
# Stores the trajectory (user/assistant/tool), memory summaries, and session metadata.

var config: CopilotConfig
var current_session: Dictionary = {}
var _current_file: String = ""

func _init(p_config: CopilotConfig = null) -> void:
	config = p_config
	CopilotPaths.ensure_dir(CopilotPaths.SESSIONS_DIR)

# --- Lifecycle ---

func has_session() -> bool:
	return not current_session.is_empty()

func current_session_id() -> String:
	return str(current_session.get("id", ""))

func new_session(title := "New Conversation") -> Dictionary:
	var session_id := _generate_id()
	var now := Time.get_datetime_string_from_system()
	current_session = {
		"id": session_id,
		"title": title,
		"created_at": now,
		"updated_at": now,
		"model": config.get_active_model_id() if config else "",
		"summary": "",
		"compaction": {"compacted_up_to_step": 0, "total_compactions": 0},
		"trajectory": []
	}
	_current_file = CopilotPaths.SESSIONS_DIR.path_join(session_id + ".json")
	save_current()
	return current_session

func load_session(session_id: String) -> Dictionary:
	var path := session_id
	if not path.begins_with("user://"):
		path = CopilotPaths.SESSIONS_DIR.path_join(path)
	if not path.ends_with(".json"):
		path += ".json"
	var parsed := _read_session_file(path)
	if parsed.is_empty():
		return {}
	current_session = parsed
	_current_file = path
	return current_session

func save_current() -> void:
	if current_session.is_empty():
		return
	current_session["updated_at"] = Time.get_datetime_string_from_system()
	if _current_file.is_empty():
		var session_id := str(current_session.get("id", _generate_id()))
		current_session["id"] = session_id
		_current_file = CopilotPaths.SESSIONS_DIR.path_join(session_id + ".json")
	CopilotPaths.write_text(_current_file, JSON.stringify(current_session, "\t"))

func list_sessions() -> Array:
	var sessions: Array = []
	for path in CopilotPaths.list_json_files(CopilotPaths.SESSIONS_DIR):
		var parsed := _read_session_file(path)
		if parsed.is_empty():
			continue
		var trajectory = parsed.get("trajectory", [])
		sessions.append({
			"id": str(parsed.get("id", path.get_file().get_basename())),
			"title": str(parsed.get("title", "Untitled")),
			"updated_at": str(parsed.get("updated_at", "")),
			"step_count": trajectory.size() if trajectory is Array else 0,
			"file_path": path
		})
	sessions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("updated_at", "")) > str(b.get("updated_at", ""))
	)
	return sessions

func delete_session(session_id: String) -> bool:
	var path := session_id
	if not path.begins_with("user://"):
		path = CopilotPaths.SESSIONS_DIR.path_join(path)
	if not path.ends_with(".json"):
		path += ".json"
	var removed := CopilotPaths.remove_file(path)
	if path == _current_file:
		current_session = {}
		_current_file = ""
	return removed

# --- Trajectory ---

func record_user(content: String, display := "") -> Dictionary:
	if current_session.is_empty():
		new_session()
	var trajectory: Array = current_session["trajectory"]
	var step := {
		"step_index": trajectory.size(),
		"timestamp": Time.get_unix_time_from_system(),
		"role": "user",
		"content": content,
		"display": display if not display.is_empty() else content,
		"compacted": false
	}
	trajectory.append(step)
	if trajectory.size() == 1 and str(current_session.get("title", "")) == "New Conversation":
		current_session["title"] = _shorten_title(step["display"])
	save_current()
	return step

func record_assistant(content: String, tool_calls: Array = []) -> Dictionary:
	if current_session.is_empty():
		new_session()
	var trajectory: Array = current_session["trajectory"]
	var step := {
		"step_index": trajectory.size(),
		"timestamp": Time.get_unix_time_from_system(),
		"role": "assistant",
		"content": content,
		"tool_calls": tool_calls.duplicate(true),
		"compacted": false
	}
	trajectory.append(step)
	save_current()
	return step

func record_tool(tool_call_id: String, tool_name: String, result: Dictionary) -> Dictionary:
	if current_session.is_empty():
		new_session()
	var trajectory: Array = current_session["trajectory"]
	var step := {
		"step_index": trajectory.size(),
		"timestamp": Time.get_unix_time_from_system(),
		"role": "tool",
		"tool_call_id": tool_call_id,
		"name": tool_name,
		"result_raw": result.duplicate(true),
		"content": JSON.stringify(result),
		"pruned": false,
		"compacted": false
	}
	trajectory.append(step)
	save_current()
	return step

func _shorten_title(text: String) -> String:
	var clean := text.strip_edges().replace("\n", " ")
	if clean.length() > 32:
		return clean.substr(0, 32) + "..."
	return clean if not clean.is_empty() else "New Conversation"

# --- Memory: compaction & pruning ---

func needs_compaction() -> bool:
	if config == null or not config.is_memory_auto() or current_session.is_empty():
		return false
	if config.get_memory_mode() == "native":
		# Native mode: let the provider handle the context window; no summary.
		return false
	var trajectory: Array = current_session.get("trajectory", [])
	var compacted_up_to := _compacted_up_to()
	return trajectory.size() - compacted_up_to >= config.get_memory_max_steps()

func steps_to_compact() -> Array:
	var result: Array = []
	if current_session.is_empty():
		return result
	var trajectory: Array = current_session.get("trajectory", [])
	var start_index := _compacted_up_to()
	var tail_size := config.get_memory_tail_size() if config else 4
	var end_index := maxi(start_index, trajectory.size() - tail_size)
	for i in range(start_index, end_index):
		result.append(trajectory[i])
	return result

func apply_summary(summary_text: String, compacted_up_to_step: int) -> void:
	if current_session.is_empty():
		return
	var existing := str(current_session.get("summary", "")).strip_edges()
	current_session["summary"] = existing + "\n\n" + summary_text if not existing.is_empty() else summary_text
	var compaction: Dictionary = current_session.get("compaction", {})
	compaction["compacted_up_to_step"] = compacted_up_to_step
	compaction["total_compactions"] = int(compaction.get("total_compactions", 0)) + 1
	current_session["compaction"] = compaction
	var trajectory: Array = current_session.get("trajectory", [])
	for i in range(mini(compacted_up_to_step, trajectory.size())):
		trajectory[i]["compacted"] = true
	save_current()

func build_messages(system_prompt: String) -> Array:
	var messages: Array = [{"role": "system", "content": system_prompt}]
	if current_session.is_empty():
		return messages

	var summary := str(current_session.get("summary", "")).strip_edges()
	if not summary.is_empty():
		messages.append({"role": "system", "content": "[Summary of Earlier Conversation Context]:\n" + summary})

	var trajectory: Array = current_session.get("trajectory", [])
	var compacted_up_to := _compacted_up_to()
	var prune_enabled := config.is_memory_prune() if config else true
	var tail_size := config.get_memory_tail_size() if config else 4
	var prune_before_index := maxi(0, trajectory.size() - tail_size)

	for i in range(compacted_up_to, trajectory.size()):
		var step: Dictionary = trajectory[i]
		var role := str(step.get("role", "user"))
		var message: Dictionary = {"role": role}
		if role == "tool":
			message["tool_call_id"] = str(step.get("tool_call_id", ""))
			message["name"] = str(step.get("name", ""))
			var content := str(step.get("content", ""))
			if prune_enabled and i < prune_before_index:
				message["content"] = "[Old tool result content cleared]"
				step["pruned"] = true
			elif prune_enabled and content.length() > 2000:
				message["content"] = content.substr(0, 1500) + "\n...[Output truncated for efficiency]"
			else:
				message["content"] = content
		elif role == "assistant":
			var content := str(step.get("content", ""))
			if not content.is_empty():
				message["content"] = content
			var tool_calls: Array = step.get("tool_calls", [])
			if not tool_calls.is_empty():
				message["tool_calls"] = tool_calls
		else:
			message["content"] = str(step.get("content", ""))
		messages.append(message)
	return messages

func _compacted_up_to() -> int:
	var compaction = current_session.get("compaction", {})
	if compaction is Dictionary:
		return int(compaction.get("compacted_up_to_step", 0))
	return 0

func _read_session_file(path: String) -> Dictionary:
	var text := CopilotPaths.read_text(path)
	if text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return json.data

func _generate_id() -> String:
	const CHARS := "abcdefghijklmnopqrstuvwxyz0123456789"
	var session_id := "ses_"
	for i in range(8):
		session_id += CHARS.substr(randi() % CHARS.length(), 1)
	return session_id

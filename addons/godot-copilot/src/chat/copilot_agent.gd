@tool
class_name CopilotAgent
extends Node
# Plugin brain: drives the ReAct loop, permission choke point, sessions, memory, and subagents.
# The UI never touches storage/providers; everything goes through this class's signals & methods.

signal state_changed(state: String)
signal user_message_added(text: String)
signal assistant_delta(delta: String)
signal assistant_message_added(text: String)
signal assistant_message_completed(text: String)
signal tool_started(name: String, args: Dictionary)
signal tool_finished(name: String, result: Dictionary)
signal permission_requested(request: Dictionary)
signal permission_resolved(resolution: Dictionary)
signal notice(message: String)
signal session_changed(session_id: String, title: String)
signal turn_finished()
signal memory_compacted(summary: String)

const STATE_IDLE := "idle"
const STATE_THINKING := "thinking"
const STATE_STREAMING := "streaming"
const STATE_RUNNING_TOOLS := "running_tools"
const STATE_WAITING_PERMISSION := "waiting_permission"
const STATE_COMPACTING := "compacting"

var config: CopilotConfig
var store: CopilotSessionStore
var permissions: CopilotPermissions
var router: CopilotToolRouter

var _state := STATE_IDLE
var _generation := 0
var _stream_generation := -1
var _turn_active := false
var _pending_permission: Dictionary = {}
var _provider: CopilotProvider = null
var _streamed_delta := false

func setup(p_config: CopilotConfig, p_editor_plugin: EditorPlugin) -> void:
	config = p_config
	store = CopilotSessionStore.new(p_config)
	permissions = CopilotPermissions.new(p_config)
	router = CopilotToolRouter.new()
	add_child(router)
	router.setup(p_config, p_editor_plugin)

# --- State & info ---

func state() -> String:
	return _state

func is_busy() -> bool:
	return _turn_active

func active_model_label() -> String:
	var model_id := config.get_active_model_id()
	return model_id if not model_id.is_empty() else "no model"

func has_session() -> bool:
	return store.has_session()

func current_session_id() -> String:
	return store.current_session_id()

func current_session_title() -> String:
	return str(store.current_session.get("title", "New Conversation"))

func trajectory() -> Array:
	return store.current_session.get("trajectory", []).duplicate(true)

func list_sessions() -> Array:
	return store.list_sessions()

# --- Session ---

func new_session() -> void:
	if _turn_active:
		cancel_turn()
	permissions.clear_session_grants()
	store.new_session()
	session_changed.emit(store.current_session_id(), current_session_title())

func load_session(session_id: String) -> bool:
	if _turn_active:
		cancel_turn()
	permissions.clear_session_grants()
	if store.load_session(session_id).is_empty():
		notice.emit("Session not found: " + session_id)
		return false
	session_changed.emit(store.current_session_id(), current_session_title())
	return true

func delete_session(session_id: String) -> bool:
	var removed := store.delete_session(session_id)
	if removed and not store.has_session():
		session_changed.emit("", "New Conversation")
	return removed

func set_active_model(model_id: String) -> void:
	if model_id == config.get_active_model_id():
		return
	config.set_active_model_id(model_id)
	_release_provider()
	notice.emit("Active model: " + active_model_label())

# --- Send message & turn ---

func send_user_message(text: String) -> void:
	var user_text := text.strip_edges()
	if user_text.is_empty():
		return
	if _turn_active:
		notice.emit("A request is still running. Wait or press Stop.")
		return
	if not store.has_session():
		store.new_session()
		session_changed.emit(store.current_session_id(), current_session_title())
	_generation += 1
	var generation := _generation
	_turn_active = true
	_run_generation(user_text, generation)

func cancel_turn() -> void:
	if not _turn_active:
		return
	_generation += 1
	_turn_active = false
	_stream_generation = -1
	if _provider != null and is_instance_valid(_provider):
		_provider.cancel()
	if not _pending_permission.is_empty():
		var pending_id := str(_pending_permission.get("id", ""))
		_pending_permission = {}
		permission_resolved.emit({
			"id": pending_id,
			"allowed": false,
			"remember": false,
			"rule": "",
			"scope_index": 0
		})
	notice.emit("Request cancelled.")
	_set_state(STATE_IDLE)
	turn_finished.emit()

func retry_last_turn() -> bool:
	# Trims the last exchange and re-sends its user text. Returns true when a
	# regeneration was started; the dock rebuilds the view from the trajectory.
	if _turn_active or store == null:
		return false
	var text := store.trim_after_last_user()
	if text.strip_edges().is_empty():
		return false
	send_user_message(text)
	return true

func resolve_permission(request_id: String, allowed: bool, remember := false, scope_index := 0) -> void:
	if _pending_permission.is_empty() or str(_pending_permission.get("id", "")) != request_id:
		return
	var request := _pending_permission
	var options: Array = request.get("scope_options", [])
	var rule := ""
	if allowed and scope_index >= 0 and scope_index < options.size():
		rule = str(options[scope_index].get("rule", ""))
	permission_resolved.emit({
		"id": request_id,
		"allowed": allowed,
		"remember": remember,
		"rule": rule,
		"scope_index": scope_index,
		"action": str(request.get("action", "")),
		"target": str(request.get("target", ""))
	})

# --- Single turn flow ---

func _run_generation(user_text: String, generation: int) -> void:
	router.reset_jit_tools()
	if store.needs_compaction():
		_set_state(STATE_COMPACTING)
		await _compact_memory(generation)
		if generation != _generation:
			return

	store.record_user(user_text, user_text)
	user_message_added.emit(user_text)
	_set_state(STATE_THINKING)

	var max_steps := config.get_agent_max_steps()
	var stop_reason := "max_steps"
	for step in range(max_steps):
		if generation != _generation:
			return
		var messages := store.build_messages(_system_prompt())
		_inject_editor_context(messages)
		_set_state(STATE_STREAMING)
		var result := await _stream_once(generation, messages, _active_tool_schemas())
		if generation != _generation:
			return
		if not result.get("success", false):
			if not bool(result.get("cancelled", false)):
				notice.emit("Failed to process: " + str(result.get("error", "unknown error")))
			stop_reason = "error"
			break

		var content := str(result.get("content", ""))
		var tool_calls: Array = result.get("tool_calls", [])
		if content.strip_edges().is_empty() and tool_calls.is_empty():
			notice.emit("The model sent no answer.")
			stop_reason = "empty"
			break

		if tool_calls.is_empty():
			store.record_assistant(content)
			_emit_assistant_final(content)
			stop_reason = "final"
			break

		store.record_assistant(content, tool_calls)
		if not content.strip_edges().is_empty():
			_emit_assistant_final(content)
		_set_state(STATE_RUNNING_TOOLS)
		await _run_tool_calls(tool_calls, generation)
		if generation != _generation:
			return

	if stop_reason == "max_steps" and generation == _generation:
		notice.emit("Agent step limit reached (" + str(max_steps) + "). Send a follow-up instruction to continue.")
	_finish_turn()

func _stream_once(generation: int, messages: Array, tools: Array) -> Dictionary:
	var provider := _ensure_provider()
	if provider == null:
		return {"success": false, "error": "No active model yet. Select one in the Provider Manager."}
	_streamed_delta = false
	_stream_generation = generation
	provider.stream_chat(messages, tools)
	var result: Dictionary = await provider.stream_finished
	if generation != _generation:
		return {"success": false, "error": "Cancelled.", "cancelled": true}
	return result

func _run_tool_calls(tool_calls: Array, generation: int) -> void:
	for call in tool_calls:
		if generation != _generation:
			return
		if not (call is Dictionary):
			continue
		var call_id := str(call.get("id", ""))
		var function_entry = call.get("function", {})
		if not (function_entry is Dictionary):
			function_entry = {}
		var tool_name := str(function_entry.get("name", ""))
		var args := _parse_arguments(str(function_entry.get("arguments", "{}")))
		var tool_result := await _execute_tool_call(tool_name, args, generation)
		if generation != _generation:
			return
		tool_finished.emit(tool_name, tool_result)
		store.record_tool(call_id, tool_name, tool_result)

func _execute_tool_call(tool_name: String, args: Dictionary, generation: int) -> Dictionary:
	if tool_name.is_empty():
		return {"success": false, "error": "Empty tool name in tool_call."}
	if tool_name == "spawn_subagent":
		tool_started.emit(tool_name, args)
		return await _run_subagent(args)
	if CopilotToolCatalog.get_schema(tool_name).is_empty():
		tool_started.emit(tool_name, args)
		return {"success": false, "error": "Unknown tool: " + tool_name}

	var mapping := CopilotToolCatalog.action_and_target(tool_name, args)
	var action := str(mapping.get("action", ""))
	var target := str(mapping.get("target", ""))
	if action.is_empty():
		tool_started.emit(tool_name, args)
		return {"success": false, "error": "Unknown action for tool '" + tool_name + "'."}

	var verdict := permissions.check(action, target)
	var verdict_value := int(verdict.get("verdict", CopilotPermissions.Verdict.ASK))
	if verdict_value == CopilotPermissions.Verdict.DENY:
		tool_started.emit(tool_name, args)
		var deny_message := "Action blocked by permission rule: " + str(verdict.get("rule", ""))
		notice.emit(deny_message)
		return {"success": false, "error": deny_message}

	if verdict_value == CopilotPermissions.Verdict.ASK:
		var resolution := await _request_permission(action, target, tool_name, args)
		if generation != _generation:
			return {"success": false, "error": "Cancelled."}
		if not bool(resolution.get("allowed", false)):
			tool_started.emit(tool_name, args)
			return {"success": false, "error": "The user denied this action."}
		_apply_grant(resolution)

	tool_started.emit(tool_name, args)
	return await router.execute(tool_name, args)

# --- Permission ---

func _request_permission(action: String, target: String, tool_name: String, args: Dictionary) -> Dictionary:
	var generation := _generation
	var request_id := "perm_" + str(Time.get_ticks_usec())
	var info := permissions.describe(action, target)
	var request := {
		"id": request_id,
		"action": action,
		"target": target,
		"tool_name": tool_name,
		"args": args,
		"title": str(info.get("title", "")),
		"question": str(info.get("question", "")),
		"badge": str(info.get("badge", "")),
		"outside": bool(info.get("outside", false)),
		"scope_options": permissions.scope_options(action, target)
	}
	_pending_permission = request
	_set_state(STATE_WAITING_PERMISSION)
	permission_requested.emit(request)

	var resolution: Dictionary = {}
	while true:
		var incoming: Dictionary = await permission_resolved
		if str(incoming.get("id", "")) == request_id:
			resolution = incoming
			break
	_pending_permission = {}
	if generation == _generation:
		_set_state(STATE_RUNNING_TOOLS)
	return resolution

func _apply_grant(resolution: Dictionary) -> void:
	var rule := str(resolution.get("rule", "")).strip_edges()
	if rule.is_empty():
		return
	if bool(resolution.get("remember", false)):
		config.add_permission_rule("allow", rule)
	else:
		permissions.add_session_grant(rule)

# --- Subagent ---

func _run_subagent(args: Dictionary) -> Dictionary:
	var agent_name := str(args.get("agent_name", "")).strip_edges()
	var task := str(args.get("task", "")).strip_edges()
	var mode := str(args.get("mode", "read_only")).strip_edges().to_lower()
	if agent_name.is_empty() or task.is_empty():
		return {"success": false, "error": "Parameters 'agent_name' and 'task' are required."}
	if mode != "full_access":
		mode = "read_only"

	config.ensure_subagent(agent_name, mode)
	var subagent := CopilotSubagent.new()
	var permission_requester := Callable()
	if mode == "full_access":
		permission_requester = Callable(self, "_subagent_permission_request")
	subagent.setup(
		config,
		router,
		permissions,
		agent_name,
		mode,
		config.get_subagent_model(agent_name),
		Callable(self, "_complete_model"),
		permission_requester
	)
	subagent.tool_started.connect(_on_subagent_tool_started)
	subagent.tool_finished.connect(_on_subagent_tool_finished)
	subagent.notice.connect(func(message: String) -> void: notice.emit(message))
	notice.emit("Sub-agent '" + agent_name + "' (" + mode + ") started working…")
	var result: Dictionary = await subagent.run(task)
	notice.emit("Sub-agent '" + agent_name + "' finished.")
	return result

func _subagent_permission_request(subagent_name: String, action: String, target: String, tool_name: String, args: Dictionary) -> bool:
	var resolution := await _request_permission(action, target, subagent_name + " → " + tool_name, args)
	if bool(resolution.get("allowed", false)):
		_apply_grant(resolution)
		return true
	return false

func _on_subagent_tool_started(subagent_name: String, tool_name: String, args: Dictionary) -> void:
	tool_started.emit(subagent_name + " → " + tool_name, args)

func _on_subagent_tool_finished(subagent_name: String, tool_name: String, result: Dictionary) -> void:
	tool_finished.emit(subagent_name + " → " + tool_name, result)

# --- Provider ---

func _ensure_provider() -> CopilotProvider:
	var provider_name := config.get_active_provider_name()
	if provider_name.is_empty() or not config.has_provider(provider_name):
		return null
	if _provider != null and is_instance_valid(_provider) and _provider.provider_name == provider_name:
		return _provider
	_release_provider()
	_provider = CopilotProviderFactory.create(config, provider_name)
	add_child(_provider)
	_provider.stream_delta.connect(_on_stream_delta)
	return _provider

func _release_provider() -> void:
	if _provider != null and is_instance_valid(_provider):
		_provider.cancel()
		_provider.queue_free()
	_provider = null

func _on_stream_delta(delta: String) -> void:
	if _stream_generation != _generation:
		return
	_streamed_delta = true
	assistant_delta.emit(delta)

func _complete_model(model_id: String, messages: Array, tools: Array = []) -> Dictionary:
	var provider_name := config.get_active_provider_name()
	var model_override := ""
	if not model_id.is_empty():
		var split := config.split_model_id(model_id)
		var split_provider := str(split.get("provider", ""))
		if not split_provider.is_empty():
			provider_name = split_provider
		model_override = str(split.get("model_key", model_id))
	if provider_name.is_empty() or not config.has_provider(provider_name):
		return {"success": false, "error": "Provider not available for model '" + model_id + "'."}
	if provider_name == config.get_active_provider_name():
		var active := _ensure_provider()
		if active == null:
			return {"success": false, "error": "Active provider not available."}
		return await active.complete(messages, tools, model_override)
	var temp := CopilotProviderFactory.create(config, provider_name)
	add_child(temp)
	var result: Dictionary = await temp.complete(messages, tools, model_override)
	temp.queue_free()
	return result

# --- Memory ---

func _compact_memory(generation: int) -> void:
	var steps := store.steps_to_compact()
	if steps.is_empty():
		return
	var lines := PackedStringArray()
	for step in steps:
		var content := str(step.get("content", ""))
		if content.length() > 1500:
			content = content.substr(0, 1500) + "…"
		lines.append("[" + str(step.get("role", "")) + "] " + content)
	var prompt := "Summarize the following conversation into a compact context note for continuing the work (in the same language as the conversation). " \
		+ "Preserve important decisions, file paths, symbol/class names, and task status.\n\n" + "\n".join(lines)
	var result: Dictionary = await _complete_model(config.get_memory_model(), [{"role": "user", "content": prompt}], [])
	if generation != _generation:
		return
	if not result.get("success", false):
		notice.emit("Compaction failed: " + str(result.get("error", "unknown error")))
		return
	var summary := str(result.get("content", "")).strip_edges()
	if summary.is_empty():
		return
	var last_step: Dictionary = steps[steps.size() - 1]
	store.apply_summary(summary, int(last_step.get("step_index", 0)) + 1)
	memory_compacted.emit(summary)

# --- Helper ---

func _active_tool_schemas() -> Array:
	var schemas := router.active_schemas()
	if not config.get_subagent_names().is_empty():
		var subagent_schema := CopilotToolCatalog.get_schema("spawn_subagent")
		if not subagent_schema.is_empty():
			schemas.append(subagent_schema)
	return schemas

func _inject_editor_context(messages: Array) -> void:
	var context := CopilotEditorContext.build()
	if context.is_empty():
		return
	for i in range(messages.size() - 1, -1, -1):
		var message: Dictionary = messages[i]
		if str(message.get("role", "")) == "user":
			message["content"] = str(message.get("content", "")) + "\n\n" + context
			messages[i] = message
			return

func _emit_assistant_final(text: String) -> void:
	if _streamed_delta:
		assistant_message_completed.emit(text)
	else:
		assistant_message_added.emit(text)

func _parse_arguments(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(clean) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	if json.data is String:
		var inner := JSON.new()
		if inner.parse(str(json.data)) == OK and inner.data is Dictionary:
			return inner.data
	return {}

func _set_state(new_state: String) -> void:
	if _state == new_state:
		return
	_state = new_state
	state_changed.emit(new_state)

func _finish_turn() -> void:
	_pending_permission = {}
	_turn_active = false
	_set_state(STATE_IDLE)
	turn_finished.emit()

func _system_prompt() -> String:
	return "You are Godot Copilot, an AI assistant running inside the Godot Editor (Godot 4.7).\n" \
		+ "Help the user work on their Godot project: read/write scripts, edit scenes, run terminal commands, and search the web.\n" \
		+ "Rules:\n" \
		+ "- Answer concisely in the language the user writes in (English by default).\n" \
		+ "- Verify facts with tools; never invent file contents or scene structure.\n" \
		+ "- Extra tools (edit_file_lines, patch_file, scene/editor tools, MCP) can be discovered with search_available_tools; that tool becomes active on the next step.\n" \
		+ "- All file/scene changes go through tools; briefly explain what you changed.\n" \
		+ "- Actions that require permission are confirmed by the user through a permission card; once approved, continue the task without repeating the explanation."

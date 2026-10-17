@tool
class_name CopilotSubagent
extends RefCounted
# Sub-agent with an isolated ReAct loop (own history, non-streaming).
# read_only mode: read-only tools only; never triggers a permission prompt.
# full_access mode: ASK actions are forwarded to the main agent via permission_requester.

signal tool_started(subagent_name: String, tool_name: String, args: Dictionary)
signal tool_finished(subagent_name: String, tool_name: String, result: Dictionary)
signal notice(message: String)

const READ_ONLY_TOOLS: Array[String] = [
	"read_file",
	"list_files",
	"glob_files",
	"grep_search",
	"read_url",
	"inspect_scene_tree",
	"get_selected_nodes",
	"get_project_setting",
	"get_open_scripts"
]

const MAX_SUBAGENT_STEPS := 6

var config: CopilotConfig
var router: CopilotToolRouter
var permissions: CopilotPermissions
var agent_name := ""
var mode := "read_only"
var model_id := ""
var provider_completer: Callable
var permission_requester: Callable

func setup(
	p_config: CopilotConfig,
	p_router: CopilotToolRouter,
	p_permissions: CopilotPermissions,
	p_agent_name: String,
	p_mode: String,
	p_model_id: String,
	p_provider_completer: Callable,
	p_permission_requester: Callable
) -> void:
	config = p_config
	router = p_router
	permissions = p_permissions
	agent_name = p_agent_name
	mode = "full_access" if p_mode == "full_access" else "read_only"
	model_id = p_model_id
	provider_completer = p_provider_completer
	permission_requester = p_permission_requester

func run(task: String) -> Dictionary:
	var tool_names := _tool_names()
	var tools := CopilotToolCatalog.schemas_for(tool_names)
	var messages: Array = [
		{"role": "system", "content": _system_prompt()},
		{"role": "user", "content": task}
	]
	var max_steps := clampi(config.get_agent_max_steps(), 1, MAX_SUBAGENT_STEPS)
	var tools_used: Array[String] = []
	if not provider_completer.is_valid():
		return _failure("Provider completer is not available.", 0, tools_used)

	for step in range(max_steps):
		var result: Dictionary = await provider_completer.call(model_id, messages, tools)
		if not result.get("success", false):
			return _failure(str(result.get("error", "Failed to call the model.")), step, tools_used)
		var content := str(result.get("content", ""))
		var tool_calls: Array = result.get("tool_calls", [])
		if tool_calls.is_empty():
			return {
				"success": true,
				"agent_name": agent_name,
				"type": mode,
				"steps_taken": step + 1,
				"tools_used": tools_used,
				"result": content
			}
		messages.append({"role": "assistant", "content": content, "tool_calls": tool_calls})
		for call in tool_calls:
			if not (call is Dictionary):
				continue
			var call_id := str(call.get("id", ""))
			var function_entry = call.get("function", {})
			if not (function_entry is Dictionary):
				function_entry = {}
			var tool_name := str(function_entry.get("name", ""))
			var args := _parse_arguments(str(function_entry.get("arguments", "{}")))
			var tool_result := await _execute_tool(tool_name, args)
			if tool_result.get("success", false) and not tools_used.has(tool_name):
				tools_used.append(tool_name)
			messages.append({
				"role": "tool",
				"tool_call_id": call_id,
				"name": tool_name,
				"content": JSON.stringify(tool_result)
			})
	return {
		"success": true,
		"agent_name": agent_name,
		"type": mode,
		"steps_taken": max_steps,
		"tools_used": tools_used,
		"result": "Sub-agent reached the step limit without a final answer."
	}

func _execute_tool(tool_name: String, args: Dictionary) -> Dictionary:
	if not _tool_names().has(tool_name):
		return {"success": false, "error": "Tool '" + tool_name + "' is not available for sub-agent mode " + mode + "."}
	var mapping := CopilotToolCatalog.action_and_target(tool_name, args)
	var action := str(mapping.get("action", ""))
	var target := str(mapping.get("target", ""))
	if not action.is_empty():
		var verdict := permissions.check(action, target)
		var verdict_value := int(verdict.get("verdict", CopilotPermissions.Verdict.ASK))
		if verdict_value == CopilotPermissions.Verdict.DENY:
			return {"success": false, "error": "Denied by permission rule: " + str(verdict.get("rule", ""))}
		if verdict_value == CopilotPermissions.Verdict.ASK:
			if mode != "full_access" or not permission_requester.is_valid():
				return {"success": false, "error": "read_only mode: this action requires user permission and is not executed automatically."}
			var allowed: bool = await permission_requester.call(agent_name, action, target, tool_name, args)
			if not allowed:
				return {"success": false, "error": "The user denied this action."}
	tool_started.emit(agent_name, tool_name, args)
	var result: Dictionary = await router.execute(tool_name, args)
	tool_finished.emit(agent_name, tool_name, result)
	return result

# --- Helper ---

func _tool_names() -> Array[String]:
	if mode != "full_access":
		return READ_ONLY_TOOLS.duplicate()
	var names: Array[String] = READ_ONLY_TOOLS.duplicate()
	for tool_name in CopilotToolCatalog.all_names():
		if tool_name == "spawn_subagent" or tool_name == "search_available_tools":
			continue
		if not names.has(tool_name):
			names.append(tool_name)
	return names

func _system_prompt() -> String:
	var mode_text := "read_only (read-only; write actions are unavailable)" if mode == "read_only" else "full_access (write actions allowed with user confirmation)"
	return "You are the sub-agent '" + agent_name + "' inside Godot Copilot (Godot Editor 4.7).\n" \
		+ "Work on the given task in a focused and independent way, then finish with a concise report for the main agent.\n" \
		+ "Access mode: " + mode_text + ".\n" \
		+ "Use tools to verify facts (never invent file contents). Answer in the language the user writes in."

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

func _failure(message: String, steps: int, tools_used: Array) -> Dictionary:
	return {
		"success": false,
		"agent_name": agent_name,
		"type": mode,
		"steps_taken": steps,
		"tools_used": tools_used,
		"error": message
	}

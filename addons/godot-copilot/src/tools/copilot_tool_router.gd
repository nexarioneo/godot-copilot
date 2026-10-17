@tool
class_name CopilotToolRouter
extends Node
# Tool executor + JIT activation (extra tools are enabled via search_available_tools).
# execute() is a coroutine because some tools (shell/web/MCP) wait for processes —
# callers must `await` even when the tool is synchronous.

var config: CopilotConfig
var editor_plugin: EditorPlugin

var _file_tools: CopilotFileTools
var _search_tools: CopilotSearchTools
var _shell_tools: CopilotShellTools
var _web_tools: CopilotWebTools
var _scene_tools: CopilotSceneTools
var _editor_tools: CopilotEditorTools
var _mcp_tools: CopilotMcpTools
var _active_jit: Array[String] = []

func setup(p_config: CopilotConfig, p_editor_plugin: EditorPlugin) -> void:
	config = p_config
	editor_plugin = p_editor_plugin
	_file_tools = CopilotFileTools.new()
	_search_tools = CopilotSearchTools.new()
	_shell_tools = CopilotShellTools.new()
	_web_tools = CopilotWebTools.new()
	_scene_tools = CopilotSceneTools.new()
	_scene_tools.setup(p_editor_plugin)
	_editor_tools = CopilotEditorTools.new()
	_mcp_tools = CopilotMcpTools.new()
	_mcp_tools.setup(p_config, _shell_tools)

# --- Active schemas ---

func active_schemas() -> Array:
	var names: Array = []
	for tool_name in CopilotToolCatalog.core_names():
		names.append(tool_name)
	for tool_name in _active_jit:
		if not names.has(tool_name):
			names.append(tool_name)
	return CopilotToolCatalog.schemas_for(names)

func reset_jit_tools() -> void:
	_active_jit.clear()

func active_tool_names() -> Array[String]:
	var names: Array[String] = CopilotToolCatalog.core_names()
	for tool_name in _active_jit:
		if not names.has(tool_name):
			names.append(tool_name)
	return names

# --- Execution ---

func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read_file":
			return _file_tools.read_file(args)
		"write_file":
			return _file_tools.write_file(args)
		"edit_file_lines":
			return _file_tools.edit_file_lines(args)
		"patch_file":
			return _file_tools.patch_file(args)
		"delete_file":
			return _file_tools.delete_file(args)
		"list_files":
			return _file_tools.list_files(args)
		"glob_files":
			return _search_tools.glob_files(args)
		"grep_search":
			return _search_tools.grep_search(args)
		"execute_command":
			return await _shell_tools.execute(args, self)
		"read_url":
			return await _web_tools.read_url(args, self)
		"http_request":
			return await _web_tools.http_request(args, self)
		"inspect_scene_tree":
			return _scene_tools.inspect_scene_tree(args)
		"get_selected_nodes":
			return _scene_tools.get_selected_nodes(args)
		"add_node":
			return _scene_tools.add_node(args)
		"delete_node":
			return _scene_tools.delete_node(args)
		"instantiate_scene":
			return _scene_tools.instantiate_scene(args)
		"set_node_property":
			return _scene_tools.set_node_property(args)
		"attach_script":
			return _scene_tools.attach_script(args)
		"get_project_setting":
			return _editor_tools.get_project_setting(args)
		"set_project_setting":
			return _editor_tools.set_project_setting(args)
		"get_open_scripts":
			return _editor_tools.get_open_scripts(args)
		"rescan_filesystem":
			return _editor_tools.rescan_filesystem(args)
		"mcp_list_tools":
			return await _mcp_tools.list_tools(args, self)
		"mcp_call_tool":
			return await _mcp_tools.call_tool(args, self)
		"search_available_tools":
			return _search_available_tools(args)
		_:
			return {"success": false, "error": "Unknown tool: " + tool_name}

func _search_available_tools(args: Dictionary) -> Dictionary:
	var query := str(args.get("query", "")).strip_edges()
	if query.is_empty():
		return {"success": false, "error": "Parameter 'query' is required."}
	var activated: Array[String] = []
	for entry in CopilotToolCatalog.search(query):
		var tool_name := str(entry.get("name", ""))
		if tool_name.is_empty() or CopilotToolCatalog.is_core(tool_name):
			continue
		if tool_name == "spawn_subagent":
			# Handled by CopilotAgent itself (not the router).
			continue
		if not _active_jit.has(tool_name):
			_active_jit.append(tool_name)
		activated.append(tool_name)
	if activated.is_empty():
		return {
			"success": true,
			"activated": [],
			"message": "No extra tools match '" + query + "'."
		}
	return {
		"success": true,
		"activated": activated,
		"message": "Activated tools: " + ", ".join(PackedStringArray(activated)) + ". Call them in the next step."
	}

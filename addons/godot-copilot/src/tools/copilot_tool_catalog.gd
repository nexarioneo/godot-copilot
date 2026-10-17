@tool
class_name CopilotToolCatalog
extends RefCounted
# JSON-schema definitions for all tools + action-permission mapping.
# Kept separate from the router so the UI and subagents can use the schemas without executing anything.

static var _definitions: Dictionary = {}

const CORE_TOOLS: Array[String] = [
	"read_file",
	"write_file",
	"list_files",
	"glob_files",
	"grep_search",
	"execute_command",
	"read_url",
	"mcp_call_tool",
	"search_available_tools"
]

static func core_names() -> Array[String]:
	return CORE_TOOLS.duplicate()

static func all_names() -> Array[String]:
	var names: Array[String] = []
	for tool_name in get_definitions().keys():
		names.append(str(tool_name))
	return names

static func get_definitions() -> Dictionary:
	if _definitions.is_empty():
		_definitions = _build_definitions()
	return _definitions

static func get_schema(tool_name: String) -> Dictionary:
	return get_definitions().get(tool_name, {})

static func schemas_for(tool_names: Array) -> Array:
	var schemas: Array = []
	for tool_name in tool_names:
		var schema := get_schema(str(tool_name))
		if not schema.is_empty():
			schemas.append(schema)
	return schemas

static func is_core(tool_name: String) -> bool:
	return CORE_TOOLS.has(tool_name)

static func search(query: String) -> Array:
	var definitions := get_definitions()
	var terms := query.to_lower().strip_edges().split(" ", false)
	var scored: Array = []
	for tool_name_var in definitions.keys():
		var tool_name := str(tool_name_var)
		var description := str(definitions[tool_name]["function"].get("description", ""))
		var haystack := (tool_name + " " + description).to_lower()
		var score := 0
		for term in terms:
			if haystack.contains(term):
				score += 1
		if terms.is_empty() or score > 0:
			scored.append({"name": tool_name, "description": description, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0))
	)
	return scored

static func action_and_target(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read_file":
			return {"action": "read_file", "target": str(args.get("path", ""))}
		"list_files", "glob_files", "grep_search":
			var path := str(args.get("path", "")).strip_edges()
			return {"action": "read_file", "target": path if not path.is_empty() else "res://"}
		"write_file", "edit_file_lines", "patch_file", "delete_file":
			return {"action": "write_file", "target": str(args.get("path", ""))}
		"execute_command":
			return {"action": "command", "target": str(args.get("command", ""))}
		"read_url":
			return {"action": "read_url", "target": str(args.get("url", ""))}
		"http_request":
			return {"action": "http_request", "target": str(args.get("url", ""))}
		"mcp_call_tool":
			return {
				"action": "mcp",
				"target": str(args.get("server", "")) + "/" + str(args.get("tool", ""))
			}
		"mcp_list_tools":
			var server := str(args.get("server", "")).strip_edges()
			return {"action": "mcp", "target": (server if not server.is_empty() else "*") + "/*"}
		"spawn_subagent":
			return {
				"action": "subagent",
				"target": str(args.get("agent_name", "")) + ":" + str(args.get("mode", "read_only"))
			}
		"inspect_scene_tree", "get_selected_nodes", "get_project_setting", "get_open_scripts":
			return {"action": "read_file", "target": "res://"}
		"add_node", "delete_node", "instantiate_scene", "set_node_property", "attach_script", "set_project_setting", "rescan_filesystem":
			return {"action": "write_file", "target": "res://"}
		_:
			return {"action": "", "target": ""}

# --- Schema definitions ---

static func _build_definitions() -> Dictionary:
	return {
		"read_file": _function(
			"read_file",
			"Reads the contents of a text file. Use start_line/end_line to read part of a large file.",
			{
				"path": _string_property("File path, e.g. res://scripts/player.gd"),
				"start_line": _integer_property("Start line (1-based, optional)"),
				"end_line": _integer_property("End line (inclusive, optional)")
			},
			["path"]
		),
		"write_file": _function(
			"write_file",
			"Writes a text file (creates it or overwrites its contents). Directories are created automatically.",
			{
				"path": _string_property("Destination file path, e.g. res://scripts/player.gd"),
				"content": _string_property("Full file content")
			},
			["path", "content"]
		),
		"list_files": _function(
			"list_files",
			"Lists files in a project directory recursively.",
			{
				"path": _string_property("Starting directory; default res://")
			},
			[]
		),
		"glob_files": _function(
			"glob_files",
			"Finds files by glob pattern, e.g. '**/*.gd' or 'scenes/*.tscn'.",
			{
				"pattern": _string_property("Glob pattern, e.g. **/*.gd"),
				"path": _string_property("Base search directory; default res://")
			},
			["pattern"]
		),
		"grep_search": _function(
			"grep_search",
			"Searches a regex pattern in project text files. Returns the file, line number and line content.",
			{
				"pattern": _string_property("Regex pattern, e.g. 'func _ready'"),
				"path": _string_property("Base search directory; default res://"),
				"file_pattern": _string_property("File name glob filter, e.g. *.gd"),
				"max_results": _integer_property("Maximum number of results; default 50")
			},
			["pattern"]
		),
		"execute_command": _function(
			"execute_command",
			"Runs a terminal command (non-blocking) and returns its output. Example: 'git status'.",
			{
				"command": _string_property("Shell command to run"),
				"workdir": _string_property("Command working directory; default project folder"),
				"timeout": _integer_property("Timeout in seconds; default 60")
			},
			["command"]
		),
		"read_url": _function(
			"read_url",
			"Fetches an HTTP page or endpoint with the GET method and returns its text.",
			{
				"url": _string_property("Full URL address (https://...)"),
				"max_chars": _integer_property("Result character limit; default 10000")
			},
			["url"]
		),
		"mcp_call_tool": _function(
			"mcp_call_tool",
			"Calls a tool on an MCP server configured in settings.",
			{
				"server": _string_property("MCP server name; optional when only one server exists"),
				"tool": _string_property("MCP tool name"),
				"arguments": _object_property("Tool arguments matching the MCP schema")
			},
			["tool"]
		),
		"search_available_tools": _function(
			"search_available_tools",
			"Finds extra tools that are not yet active and enables them for the next step.",
			{
				"query": _string_property("Requirement keywords, e.g. 'edit file' or 'scene node'")
			},
			["query"]
		),
		"edit_file_lines": _function(
			"edit_file_lines",
			"Replaces a range of lines in a text file with new content (cheaper than write_file for small edits).",
			{
				"path": _string_property("File path"),
				"start_line": _integer_property("First line to replace (1-based)"),
				"end_line": _integer_property("Last line to replace (inclusive)"),
				"new_content": _string_property("Replacement text")
			},
			["path", "start_line", "end_line", "new_content"]
		),
		"patch_file": _function(
			"patch_file",
			"Replaces the first occurrence of a text in a file with new text.",
			{
				"path": _string_property("File path"),
				"old_text": _string_property("Old text to find (exact)"),
				"new_text": _string_property("Replacement text")
			},
			["path", "old_text", "new_text"]
		),
		"delete_file": _function(
			"delete_file",
			"Deletes a file from the project.",
			{
				"path": _string_property("Path of the file to delete")
			},
			["path"]
		),
		"http_request": _function(
			"http_request",
			"Runs a free-form HTTP request (method, headers, body) for APIs and webhooks.",
			{
				"url": _string_property("Full URL address"),
				"method": _string_property("HTTP method: GET/POST/PUT/PATCH/DELETE/HEAD; default GET"),
				"headers": _object_property("Extra headers as an object"),
				"body": _string_property("Request body content (optional)")
			},
			["url"]
		),
		"inspect_scene_tree": _function(
			"inspect_scene_tree",
			"Shows the node tree structure of the scene currently being edited in the editor.",
			{
				"root_path": _string_property("Starting node (optional; default scene root)"),
				"max_depth": _integer_property("Maximum depth; default 4")
			},
			[]
		),
		"get_selected_nodes": _function(
			"get_selected_nodes",
			"Returns the list of nodes currently selected in the Scene dock.",
			{},
			[]
		),
		"add_node": _function(
			"add_node",
			"Adds a new node to the scene being edited (undoable).",
			{
				"parent_path": _string_property("Parent node path, e.g. 'root/Player'"),
				"type": _string_property("Engine node type, e.g. Sprite2D"),
				"name": _string_property("New node name (optional)")
			},
			["parent_path", "type"]
		),
		"delete_node": _function(
			"delete_node",
			"Deletes a node from the scene being edited (undoable).",
			{
				"node_path": _string_property("Path of the node to delete")
			},
			["node_path"]
		),
		"instantiate_scene": _function(
			"instantiate_scene",
			"Adds a scene instance (.tscn) as a child of a node (undoable).",
			{
				"scene_path": _string_property("Scene file path, e.g. res://scenes/enemy.tscn"),
				"parent_path": _string_property("Parent node path"),
				"name": _string_property("Instance name (optional)")
			},
			["scene_path", "parent_path"]
		),
		"set_node_property": _function(
			"set_node_property",
			"Changes a node property value (undoable). Complex values are written as Godot strings, e.g. 'Vector2(10, 20)'.",
			{
				"node_path": _string_property("Node path"),
				"property": _string_property("Property name, e.g. position"),
				"value": _string_property("New value")
			},
			["node_path", "property", "value"]
		),
		"attach_script": _function(
			"attach_script",
			"Attaches a script to a node (undoable).",
			{
				"node_path": _string_property("Node path"),
				"script_path": _string_property("Script path, e.g. res://scripts/player.gd")
			},
			["node_path", "script_path"]
		),
		"get_project_setting": _function(
			"get_project_setting",
			"Reads a Project Setting value, e.g. 'application/config/name'.",
			{
				"setting": _string_property("Setting name")
			},
			["setting"]
		),
		"set_project_setting": _function(
			"set_project_setting",
			"Changes a Project Setting and saves project.godot.",
			{
				"setting": _string_property("Setting name"),
				"value": _string_property("New value")
			},
			["setting", "value"]
		),
		"get_open_scripts": _function(
			"get_open_scripts",
			"Returns the list of scripts currently open in the editor.",
			{},
			[]
		),
		"rescan_filesystem": _function(
			"rescan_filesystem",
			"Rescans the project filesystem so the editor detects new files.",
			{},
			[]
		),
		"mcp_list_tools": _function(
			"mcp_list_tools",
			"Lists the tools provided by an MCP server.",
			{
				"server": _string_property("Server name; optional, omit for all servers")
			},
			[]
		),
		"spawn_subagent": _function(
			"spawn_subagent",
			"Runs a sub-agent with an isolated task and returns its report.",
			{
				"agent_name": _string_property("Sub-agent name"),
				"task": _string_property("Detailed task for the sub-agent"),
				"mode": _string_property("Mode: read_only (default) or full_access")
			},
			["agent_name", "task"]
		)
	}

static func _function(name: String, description: String, properties: Dictionary, required: Array) -> Dictionary:
	var parameters := {"type": "object", "properties": properties}
	if not required.is_empty():
		parameters["required"] = required
	return {
		"type": "function",
		"function": {
			"name": name,
			"description": description,
			"parameters": parameters
		}
	}

static func _string_property(description: String) -> Dictionary:
	return {"type": "string", "description": description}

static func _integer_property(description: String) -> Dictionary:
	return {"type": "integer", "description": description}

static func _object_property(description: String) -> Dictionary:
	return {"type": "object", "description": description}

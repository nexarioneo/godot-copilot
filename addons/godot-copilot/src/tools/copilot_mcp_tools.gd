@tool
class_name CopilotMcpTools
extends RefCounted
# Minimal MCP client.
# - stdio: the server runs per request via CopilotShellTools (non-blocking),
#   the JSON-RPC payload is written to a temp file and piped as stdin.
# - HTTP: POST JSON-RPC to the server URL.
# Configuration: mcp.servers.<name> = {command, args, env} or {url, headers, token}.

const DEFAULT_TIMEOUT := 30.0
const MAX_RESULT_CHARS := 20000
const PROTOCOL_VERSION := "2024-11-05"
const REQUEST_ID := 2

var config: CopilotConfig
var shell_tools: CopilotShellTools

func setup(p_config: CopilotConfig, p_shell_tools: CopilotShellTools) -> void:
	config = p_config
	shell_tools = p_shell_tools

# --- API tool ---

func call_tool(args: Dictionary, host: Node) -> Dictionary:
	var tool_name := str(args.get("tool", "")).strip_edges()
	if tool_name.is_empty():
		return _error("Parameter 'tool' is required.")
	var server_lookup := _resolve_server(str(args.get("server", "")).strip_edges())
	if not server_lookup.get("success", false):
		return server_lookup
	var server_name := str(server_lookup["server"])
	var arguments_value = args.get("arguments", {})
	var tool_arguments: Dictionary = arguments_value if arguments_value is Dictionary else {}
	var response := await _send_request(
		server_name,
		server_lookup["config"],
		"tools/call",
		{"name": tool_name, "arguments": tool_arguments},
		host
	)
	if not response.get("success", false):
		return response
	var result = response.get("result", {})
	if not (result is Dictionary):
		return _error("Invalid MCP response from server '" + server_name + "'.")
	var texts: Array[String] = []
	for item in result.get("content", []):
		if item is Dictionary and str(item.get("type", "")) == "text":
			texts.append(str(item.get("text", "")))
	var text := "\n".join(PackedStringArray(texts))
	if text.length() > MAX_RESULT_CHARS:
		text = text.substr(0, MAX_RESULT_CHARS) + "\n... [result truncated]"
	if bool(result.get("isError", false)):
		return _error(text if not text.is_empty() else "MCP tool '" + tool_name + "' reported an error.")
	return {"success": true, "server": server_name, "tool": tool_name, "content": text}

func list_tools(args: Dictionary, host: Node) -> Dictionary:
	var servers := config.get_mcp_servers()
	if servers.is_empty():
		return _error("No MCP server is configured yet (Settings → MCP).")
	var requested := str(args.get("server", "")).strip_edges()
	var targets: Array[String] = []
	if requested.is_empty():
		for server_name in servers.keys():
			targets.append(str(server_name))
	elif servers.has(requested):
		targets.append(requested)
	else:
		return _error("Unknown MCP server: " + requested)

	var results: Dictionary = {}
	var errors: Array[String] = []
	for server_name in targets:
		var response := await _send_request(server_name, servers[server_name], "tools/list", {}, host)
		if not response.get("success", false):
			errors.append(server_name + ": " + str(response.get("error", "")))
			continue
		var result = response.get("result", {})
		var tools: Array = []
		if result is Dictionary and result.get("tools") is Array:
			for tool in result["tools"]:
				if tool is Dictionary:
					tools.append({
						"name": str(tool.get("name", "")),
						"description": str(tool.get("description", ""))
					})
		results[server_name] = tools
	if results.is_empty():
		return _error("Failed to fetch the MCP tool list. " + " | ".join(PackedStringArray(errors)))
	var out := {"success": true, "servers": results}
	if not errors.is_empty():
		out["errors"] = errors
	return out

# --- Transport ---

func _resolve_server(server_name: String) -> Dictionary:
	var servers := config.get_mcp_servers()
	if servers.is_empty():
		return _error("No MCP server is configured yet (Settings → MCP).")
	if server_name.is_empty():
		if servers.size() == 1:
			var only := str(servers.keys()[0])
			return {"success": true, "server": only, "config": servers[only]}
		return _error("Parameter 'server' is required. Available: " + ", ".join(PackedStringArray(servers.keys())))
	if not servers.has(server_name) or not (servers[server_name] is Dictionary):
		return _error("Unknown MCP server: " + server_name)
	return {"success": true, "server": server_name, "config": servers[server_name]}

func _send_request(server_name: String, server_config: Dictionary, method: String, params: Dictionary, host: Node) -> Dictionary:
	var request := {"jsonrpc": "2.0", "id": REQUEST_ID, "method": method}
	if not params.is_empty():
		request["params"] = params
	if server_config.has("url"):
		return await _send_http(server_config, request, host)
	if server_config.has("command"):
		return await _send_stdio(server_config, request, host)
	return _error("MCP server '" + server_name + "' has neither 'command' (stdio) nor 'url' (HTTP).")

func _send_stdio(server_config: Dictionary, request: Dictionary, host: Node) -> Dictionary:
	var command := str(server_config.get("command", "")).strip_edges()
	if command.is_empty():
		return _error("MCP server 'command' field is empty.")
	var stdin_file := CopilotPaths.temp_dir().path_join("mcp_stdin_" + str(Time.get_ticks_usec()) + ".jsonl")
	var payload_lines := PackedStringArray([
		JSON.stringify({
			"jsonrpc": "2.0",
			"id": 1,
			"method": "initialize",
			"params": {
				"protocolVersion": PROTOCOL_VERSION,
				"capabilities": {},
				"clientInfo": {"name": "GodotCopilot", "version": "2.0.0"}
			}
		}),
		JSON.stringify({"jsonrpc": "2.0", "method": "notifications/initialized"}),
		JSON.stringify(request)
	])
	CopilotPaths.write_text(stdin_file, "\n".join(payload_lines) + "\n")

	var command_parts := PackedStringArray()
	var env_config = server_config.get("env", {})
	var env_prefix := _env_prefix(env_config)
	if not env_prefix.is_empty():
		command_parts.append(env_prefix.trim_suffix(" "))
	command_parts.append(CopilotShellTools.quote_shell_arg(command))
	var args_value = server_config.get("args", [])
	if args_value is Array:
		for arg in args_value:
			command_parts.append(CopilotShellTools.quote_shell_arg(str(arg)))
	var script := " ".join(command_parts) + " < " + CopilotShellTools.quote_shell_arg(ProjectSettings.globalize_path(stdin_file))

	var timeout_seconds := clampf(float(server_config.get("timeout", DEFAULT_TIMEOUT)), 1.0, 300.0)
	var run_result := await shell_tools.run_script(script, timeout_seconds, host)
	CopilotPaths.remove_file(stdin_file)
	if bool(run_result.get("timed_out", false)):
		return _error("The MCP server did not respond within " + str(int(timeout_seconds)) + " seconds.")
	var output := str(run_result.get("output", ""))
	var parsed := _parse_stdio_output(output)
	if not parsed.get("success", false):
		var hint := output.strip_edges()
		if hint.length() > 500:
			hint = hint.substr(0, 500) + "…"
		return _error(str(parsed.get("error", "Failed to process MCP.")) + (" Output: " + hint if not hint.is_empty() else ""))
	return parsed

func _send_http(server_config: Dictionary, request: Dictionary, host: Node) -> Dictionary:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return _error("Request host is not available.")
	var url := str(server_config.get("url", "")).strip_edges()
	if url.is_empty():
		return _error("MCP server 'url' field is empty.")
	var http_request := HTTPRequest.new()
	http_request.timeout = clampf(float(server_config.get("timeout", DEFAULT_TIMEOUT)), 1.0, 300.0)
	host.add_child(http_request)

	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var headers_config = server_config.get("headers", {})
	if headers_config is Dictionary:
		for key in headers_config.keys():
			headers.append(str(key) + ": " + str(headers_config[key]))
	var token := str(server_config.get("token", "")).strip_edges()
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)

	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(request))
	if err != OK:
		http_request.queue_free()
		return _error("Failed to send the MCP request (code " + str(err) + ").")
	var response: Array = await http_request.request_completed
	http_request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return _error("MCP connection failed (transport code " + str(response[0]) + ").")

	var body := (response[3] as PackedByteArray).get_string_from_utf8()
	var json := JSON.new()
	if json.parse(body) != OK or not (json.data is Dictionary):
		return _error("MCP response is not valid JSON (status " + str(response[1]) + ").")
	return _extract_message(json.data)

func _parse_stdio_output(output: String) -> Dictionary:
	for line in output.split("\n"):
		var clean := line.strip_edges()
		if clean.is_empty() or not clean.begins_with("{"):
			continue
		var json := JSON.new()
		if json.parse(clean) != OK or not (json.data is Dictionary):
			continue
		var message: Dictionary = json.data
		if int(message.get("id", -1)) != REQUEST_ID:
			continue
		return _extract_message(message)
	return _error("No JSON-RPC response from the MCP server.")

func _extract_message(message: Dictionary) -> Dictionary:
	if message.has("error"):
		return _error(_rpc_error_text(message["error"]))
	var result = message.get("result", {})
	if not (result is Dictionary):
		return _error("MCP 'result' field is invalid.")
	return {"success": true, "result": result}

func _rpc_error_text(error_value) -> String:
	if error_value is Dictionary:
		var message := str(error_value.get("message", "")).strip_edges()
		var code := int(error_value.get("code", 0))
		if message.is_empty():
			message = JSON.stringify(error_value)
		return "MCP error " + str(code) + ": " + message if code != 0 else "MCP error: " + message
	return "MCP error: " + str(error_value)

func _env_prefix(env_config) -> String:
	if not (env_config is Dictionary) or env_config.is_empty():
		return ""
	var parts := PackedStringArray()
	if OS.get_name() == "Windows":
		for key in env_config.keys():
			parts.append("set \"" + str(key) + "=" + str(env_config[key]) + "\"")
		return " && ".join(parts) + " && "
	parts.append("env")
	for key in env_config.keys():
		parts.append(CopilotShellTools.quote_shell_arg(str(key) + "=" + str(env_config[key])))
	return " ".join(parts) + " "

func _error(message: String) -> Dictionary:
	return {"success": false, "error": message}

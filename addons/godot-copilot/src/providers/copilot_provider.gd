@tool
class_name CopilotProvider
extends Node
# Base class for LLM providers: handles HTTP, SSE streaming, and non-streaming requests.
# Subclasses only assemble the endpoint payload/headers and parse their stream format.

signal stream_delta(text: String)
signal stream_finished(result: Dictionary)
# result = {success: bool, content: String, tool_calls: Array, error: String}

var config: CopilotConfig
var provider_name: String = ""

var _http: HTTPClient = null
var _request_token := 0
var _request_active := false
var _aborted := false
var _error_message := ""
var _result_emitted := true
var _buffer := ""
var _content := ""
var _accumulated_tool_calls: Dictionary = {}

func setup(p_config: CopilotConfig, p_provider_name: String) -> void:
	config = p_config
	provider_name = p_provider_name

func cancel() -> void:
	_request_token += 1
	if not _request_active:
		return
	_request_active = false
	_aborted = true
	if _http:
		_http.close()
		_http = null
	if not _result_emitted:
		_result_emitted = true
		stream_finished.emit({
			"success": false,
			"content": _content,
			"tool_calls": [],
			"error": "Cancelled."
		})

func is_active() -> bool:
	return _request_active

# --- Public API ---

func stream_chat(messages: Array, tools: Array, model_override := "") -> void:
	if _request_active:
		cancel()
	_request_token += 1
	var token := _request_token
	_request_active = true
	_aborted = false
	_error_message = ""
	_result_emitted = false
	_buffer = ""
	_content = ""
	_accumulated_tool_calls.clear()
	_reset_stream_state()

	var key_value := _pick_key()
	if key_value.is_empty():
		_emit_result(token, false, "No API key set for provider '" + provider_name + "'.")
		return
	var model := _resolve_model(model_override)
	if model.is_empty():
		_emit_result(token, false, "No model selected for provider '" + provider_name + "'.")
		return
	var payload := _build_stream_payload(messages, tools, model)
	_run_stream(_endpoint_url(), _request_headers(key_value, true), payload, token)

func complete(messages: Array, tools: Array = [], model_override := "") -> Dictionary:
	var key_value := _pick_key()
	if key_value.is_empty():
		return {"success": false, "error": "No API key set for provider '" + provider_name + "'."}
	var model := _resolve_model(model_override)
	if model.is_empty():
		return {"success": false, "error": "No model selected for provider '" + provider_name + "'."}

	var payload := _build_complete_payload(messages, tools, model)
	var request := HTTPRequest.new()
	request.timeout = 120.0
	add_child(request)
	var err := request.request(_endpoint_url(), _request_headers(key_value, false), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		request.queue_free()
		return {"success": false, "error": "Failed to send the request (code " + str(err) + ")."}

	var response: Array = await request.request_completed
	request.queue_free()

	var transport_code := int(response[0])
	var status_code := int(response[1])
	var body_bytes: PackedByteArray = response[3]
	var body := body_bytes.get_string_from_utf8()
	if transport_code != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": "Connection to the server failed (code " + str(transport_code) + ")."}
	if status_code < 200 or status_code >= 300:
		return {"success": false, "error": _format_http_error(status_code, body)}

	var json := JSON.new()
	if json.parse(body) != OK or not (json.data is Dictionary):
		return {"success": false, "error": "The server response could not be parsed as JSON."}
	var parsed := _parse_complete_response(json.data)
	parsed["success"] = true
	return parsed

# --- Transport streaming ---

func _run_stream(url: String, headers: PackedStringArray, payload: Dictionary, token: int) -> void:
	var url_info := _parse_url(url)
	if url_info.is_empty():
		_fail("Invalid endpoint URL: " + url)
		_emit_result(token, false, _error_message)
		return

	_http = HTTPClient.new()
	var client := _http
	var tls_options: TLSOptions = TLSOptions.client() if bool(url_info.get("use_tls", true)) else null
	var err := client.connect_to_host(str(url_info.get("host", "")), int(url_info.get("port", 443)), tls_options)
	if err != OK:
		_fail("Failed to open a connection to " + str(url_info.get("host", "")) + " (code " + str(err) + ").")
		_emit_result(token, false, _error_message)
		return

	var elapsed_ms := 0
	while token == _request_token and not _aborted and (client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING):
		client.poll()
		await get_tree().process_frame
		elapsed_ms += 16
		if elapsed_ms > 10000:
			_fail("Timed out while contacting " + str(url_info.get("host", "")) + ".")
			break

	if token == _request_token and not _aborted and client.get_status() != HTTPClient.STATUS_CONNECTED:
		_fail("Could not connect to the server (status " + str(client.get_status()) + ").")

	if token == _request_token and not _aborted:
		err = client.request(HTTPClient.METHOD_POST, str(url_info.get("path", "/")), headers, JSON.stringify(payload))
		if err != OK:
			_fail("Failed to send the streaming request (code " + str(err) + ").")

	elapsed_ms = 0
	while token == _request_token and not _aborted and client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await get_tree().process_frame
		elapsed_ms += 16
		if elapsed_ms > 30000:
			_fail("Timed out while waiting for the server's initial response.")
			break

	if token == _request_token and not _aborted and client.get_status() != HTTPClient.STATUS_BODY:
		var status_code := client.get_response_code()
		if status_code < 200 or status_code >= 300:
			var error_body := await _read_pending_error_body(client)
			_fail(_format_http_error(status_code, error_body))

	while token == _request_token and not _aborted and client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			_consume_chunk(chunk.get_string_from_utf8())
		await get_tree().process_frame

	if token == _request_token and not _aborted and not _buffer.strip_edges().is_empty():
		_process_line(_buffer.strip_edges())
	_buffer = ""

	if client.get_status() != HTTPClient.STATUS_DISCONNECTED:
		client.close()
	if _http == client:
		_http = null

	if _aborted:
		_emit_result(token, false, _error_message if not _error_message.is_empty() else "Stream cancelled.")
	else:
		_emit_result(token, true, "")

func _read_pending_error_body(client: HTTPClient) -> String:
	var error_body := PackedByteArray()
	var waited_ms := 0
	while client.get_status() == HTTPClient.STATUS_BODY and waited_ms < 5000:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			error_body.append_array(chunk)
		await get_tree().process_frame
		waited_ms += 16
	return error_body.get_string_from_utf8()

func _consume_chunk(chunk_text: String) -> void:
	_buffer += chunk_text
	while _buffer.contains("\n"):
		var newline := _buffer.find("\n")
		var line := _buffer.substr(0, newline).strip_edges()
		_buffer = _buffer.substr(newline + 1)
		if not line.is_empty():
			_process_line(line)

func _process_line(line: String) -> void:
	if line.begins_with(":"):
		return
	var data := line
	if data.begins_with("data:"):
		data = data.substr(5).strip_edges()
	if data.is_empty() or data == "[DONE]":
		return
	var json := JSON.new()
	if json.parse(data) != OK or not (json.data is Dictionary):
		return
	_parse_stream_line(json.data)

func _emit_result(token: int, success: bool, error: String) -> void:
	if token != _request_token or _result_emitted:
		return
	_result_emitted = true
	_request_active = false
	stream_finished.emit({
		"success": success,
		"content": _content,
		"tool_calls": [] if not success else _final_tool_calls(),
		"error": error
	})

# --- Helpers for subclasses ---

func _pick_key() -> String:
	if config == null:
		return ""
	return str(config.next_api_key(provider_name).get("value", ""))

func _resolve_model(model_override: String) -> String:
	if config == null:
		return ""
	var model := model_override.strip_edges()
	if model.is_empty():
		model = config.get_active_model_key()
	if model.contains("/"):
		var split := config.split_model_id(model)
		if str(split.get("provider", "")) == provider_name:
			model = str(split.get("model_key", model))
	var prefix := config.get_model_prefix(provider_name)
	if not prefix.is_empty():
		model = prefix + model
	return model

func _emit_delta(text: String) -> void:
	if text.is_empty():
		return
	_content += text
	stream_delta.emit(text)

func _fail(message: String) -> void:
	if not _error_message.is_empty():
		return
	_error_message = message
	_aborted = true
	if _http:
		_http.close()

func _append_tool_call_delta(index: int, id_delta: String, name_delta: String, arguments_delta: String) -> void:
	if not _accumulated_tool_calls.has(index):
		_accumulated_tool_calls[index] = {
			"id": "",
			"type": "function",
			"function": {"name": "", "arguments": ""}
		}
	var entry: Dictionary = _accumulated_tool_calls[index]
	if not id_delta.is_empty():
		entry["id"] = str(entry["id"]) + id_delta
	var function_entry: Dictionary = entry["function"]
	if not name_delta.is_empty():
		function_entry["name"] = str(function_entry["name"]) + name_delta
	if not arguments_delta.is_empty():
		function_entry["arguments"] = str(function_entry["arguments"]) + arguments_delta

func _set_tool_call(index: int, call_id: String, function_name: String, arguments: String) -> void:
	_accumulated_tool_calls[index] = {
		"id": call_id,
		"type": "function",
		"function": {"name": function_name, "arguments": arguments}
	}

func _standard_tool_calls() -> Array:
	var final_calls: Array = []
	var indices := _accumulated_tool_calls.keys()
	indices.sort()
	for index in indices:
		final_calls.append(_accumulated_tool_calls[index])
	return final_calls

func _content_to_text(content) -> String:
	if content is String:
		return content
	if content is Array:
		var parts := PackedStringArray()
		for part in content:
			if part is Dictionary:
				if str(part.get("type", "")) in ["text", "input_text", "output_text"]:
					parts.append(str(part.get("text", "")))
			elif part is String:
				parts.append(part)
		return "".join(parts)
	if content == null:
		return ""
	return str(content)

func _parse_arguments_string(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(clean) == OK and json.data is Dictionary:
		return json.data
	return {}

func _format_http_error(status_code: int, body: String) -> String:
	var message := "HTTP " + str(status_code)
	var json := JSON.new()
	if json.parse(body) == OK and json.data is Dictionary:
		var error_value = json.data.get("error", null)
		if error_value is Dictionary and error_value.has("message"):
			message += ": " + str(error_value["message"])
		elif error_value != null:
			message += ": " + str(error_value)
		elif json.data.has("message"):
			message += ": " + str(json.data["message"])
	elif not body.strip_edges().is_empty():
		message += ": " + body.substr(0, 300)
	return message

func _parse_url(full_url: String) -> Dictionary:
	var use_tls := full_url.begins_with("https://")
	var clean := full_url
	if clean.begins_with("https://"):
		clean = clean.substr(8)
	elif clean.begins_with("http://"):
		clean = clean.substr(7)
	if clean.is_empty():
		return {}
	var slash_index := clean.find("/")
	var host_port := clean if slash_index == -1 else clean.substr(0, slash_index)
	var path := "/" if slash_index == -1 else clean.substr(slash_index)
	var host := host_port
	var port := 443 if use_tls else 80
	var colon_index := host_port.find(":")
	if colon_index != -1:
		host = host_port.substr(0, colon_index)
		port = int(host_port.substr(colon_index + 1))
	if host.is_empty():
		return {}
	return {"use_tls": use_tls, "host": host, "port": port, "path": path}

# --- Subclass contract ---

func _endpoint_url() -> String:
	return ""

func _request_headers(_api_key: String, _streaming: bool) -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "User-Agent: GodotCopilot/2.0"])

func _build_stream_payload(_messages: Array, _tools: Array, _model: String) -> Dictionary:
	return {}

func _build_complete_payload(_messages: Array, _tools: Array, _model: String) -> Dictionary:
	return {}

func _parse_complete_response(_json: Dictionary) -> Dictionary:
	return {"content": "", "tool_calls": []}

func _reset_stream_state() -> void:
	pass

func _parse_stream_line(_event: Dictionary) -> void:
	pass

func _final_tool_calls() -> Array:
	return _standard_tool_calls()

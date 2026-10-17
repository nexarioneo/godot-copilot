@tool
class_name CopilotOpenAiProvider
extends CopilotProvider
# OpenAI-compatible provider: /chat/completions (default) or /responses.
# The stream parser is deliberately tolerant: standard SSE, Ollama NDJSON, Responses API events,
# and the legacy Anthropic-style delta format used by some proxies.

var _responses_item_index: Dictionary = {}
var _responses_next_index := 0

func _endpoint_url() -> String:
	var base := config.get_base_url(provider_name).trim_suffix("/")
	if base.is_empty():
		base = "https://api.openai.com/v1"
	for known_suffix in ["/chat/completions", "/responses", "/messages"]:
		if base.ends_with(known_suffix):
			return base
	if config.get_api_type(provider_name) == "responses":
		return base + "/responses"
	return base + "/chat/completions"

func _request_headers(api_key: String, streaming: bool) -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
		"User-Agent: GodotCopilot/2.0",
		"Accept: " + ("text/event-stream" if streaming else "application/json")
	])

func _build_stream_payload(messages: Array, tools: Array, model: String) -> Dictionary:
	if config.get_api_type(provider_name) == "responses":
		return _build_responses_payload(messages, tools, model, true)
	var payload := {
		"model": model,
		"stream": true,
		"messages": _sanitize_messages(messages)
	}
	if not tools.is_empty():
		payload["tools"] = _sanitize_tools(tools)
		payload["tool_choice"] = "auto"
	return payload

func _build_complete_payload(messages: Array, tools: Array, model: String) -> Dictionary:
	if config.get_api_type(provider_name) == "responses":
		return _build_responses_payload(messages, tools, model, false)
	var payload := {
		"model": model,
		"messages": _sanitize_messages(messages)
	}
	if not tools.is_empty():
		payload["tools"] = _sanitize_tools(tools)
		payload["tool_choice"] = "auto"
	return payload

# --- Payload chat_completions ---

func _sanitize_messages(messages: Array) -> Array:
	var out: Array = []
	for message in messages:
		if not (message is Dictionary):
			continue
		var role := str(message.get("role", "user"))
		var entry: Dictionary = {"role": role}
		var content = message.get("content", "")
		if content is Array:
			entry["content"] = content
		elif content is String:
			if not content.is_empty() or role == "user":
				entry["content"] = content
		if role == "tool":
			entry["tool_call_id"] = str(message.get("tool_call_id", ""))
			if message.has("name"):
				entry["name"] = str(message["name"])
		if role == "assistant" and message.get("tool_calls") is Array and not message["tool_calls"].is_empty():
			entry["tool_calls"] = _normalize_tool_calls(message["tool_calls"])
			if not entry.has("content"):
				entry["content"] = ""
		out.append(entry)
	return out

func _sanitize_tools(tools: Array) -> Array:
	var out: Array = []
	for tool in tools:
		if tool is Dictionary and tool.get("function") is Dictionary:
			out.append(tool)
	return out

func _normalize_tool_calls(calls) -> Array:
	var out: Array = []
	if not (calls is Array):
		return out
	for i in range(calls.size()):
		var call = calls[i]
		if not (call is Dictionary):
			continue
		var function_entry = call.get("function", {})
		if not (function_entry is Dictionary):
			function_entry = {}
		var arguments_value = function_entry.get("arguments", "{}")
		out.append({
			"id": str(call.get("id", "call_" + str(i))),
			"type": "function",
			"function": {
				"name": str(function_entry.get("name", "")),
				"arguments": arguments_value if arguments_value is String else JSON.stringify(arguments_value)
			}
		})
	return out

# --- Payload & parsing Responses API ---

func _build_responses_payload(messages: Array, tools: Array, model: String, streaming: bool) -> Dictionary:
	var converted := _responses_input(messages)
	var payload := {
		"model": model,
		"input": converted["input"]
	}
	var instructions := str(converted["instructions"])
	if not instructions.is_empty():
		payload["instructions"] = instructions
	if streaming:
		payload["stream"] = true
	var response_tools: Array = []
	for tool in _sanitize_tools(tools):
		var function_entry: Dictionary = tool["function"]
		response_tools.append({
			"type": "function",
			"name": str(function_entry.get("name", "")),
			"description": str(function_entry.get("description", "")),
			"parameters": function_entry.get("parameters", {"type": "object", "properties": {}})
		})
	if not response_tools.is_empty():
		payload["tools"] = response_tools
	return payload

func _responses_input(messages: Array) -> Dictionary:
	var instructions_parts: Array[String] = []
	var input: Array = []
	for message in messages:
		if not (message is Dictionary):
			continue
		var role := str(message.get("role", "user"))
		if role == "system":
			var system_text := _content_to_text(message.get("content", ""))
			if not system_text.is_empty():
				instructions_parts.append(system_text)
			continue
		if role == "tool":
			input.append({
				"type": "function_call_output",
				"call_id": str(message.get("tool_call_id", "")),
				"output": _content_to_text(message.get("content", ""))
			})
			continue
		if role == "assistant":
			var assistant_text := _content_to_text(message.get("content", ""))
			if not assistant_text.is_empty():
				input.append({
					"role": "assistant",
					"content": [{"type": "output_text", "text": assistant_text}]
				})
			for call in _normalize_tool_calls(message.get("tool_calls", [])):
				input.append({
					"type": "function_call",
					"call_id": str(call.get("id", "")),
					"name": str(call["function"]["name"]),
					"arguments": str(call["function"]["arguments"])
				})
			continue
		input.append({
			"role": "user",
			"content": _responses_user_content(message.get("content", ""))
		})
	return {
		"instructions": "\n\n".join(PackedStringArray(instructions_parts)),
		"input": input
	}

func _responses_user_content(content) -> Array:
	if content is Array:
		var parts: Array = []
		for part in content:
			if part is Dictionary:
				var part_type := str(part.get("type", ""))
				if part_type in ["text", "input_text"]:
					parts.append({"type": "input_text", "text": str(part.get("text", ""))})
				elif part_type == "image_url":
					var image_value = part.get("image_url", {})
					var url := str(image_value.get("url", "")) if image_value is Dictionary else str(image_value)
					if not url.is_empty():
						parts.append({"type": "input_image", "image_url": url})
		return parts
	return [{"type": "input_text", "text": _content_to_text(content)}]

func _parse_complete_response(json: Dictionary) -> Dictionary:
	if json.has("choices") and json["choices"] is Array and not json["choices"].is_empty():
		var choice: Dictionary = json["choices"][0]
		var message = choice.get("message", {})
		if message is Dictionary:
			return {
				"content": _content_to_text(message.get("content", "")),
				"tool_calls": _normalize_tool_calls(message.get("tool_calls", []))
			}
		return {"content": "", "tool_calls": []}
	if json.has("output") and json["output"] is Array:
		return _parse_responses_output(json["output"])
	if json.has("message") and json["message"] is Dictionary:
		var ollama_message: Dictionary = json["message"]
		return {
			"content": _content_to_text(ollama_message.get("content", "")),
			"tool_calls": _normalize_tool_calls(ollama_message.get("tool_calls", []))
		}
	return {"content": "", "tool_calls": []}

func _parse_responses_output(output: Array) -> Dictionary:
	var content := ""
	var tool_calls: Array = []
	for item in output:
		if not (item is Dictionary):
			continue
		var item_type := str(item.get("type", ""))
		if item_type == "message":
			var parts = item.get("content", [])
			if parts is Array:
				for part in parts:
					if part is Dictionary and str(part.get("type", "")) in ["output_text", "text"]:
						content += str(part.get("text", ""))
		elif item_type == "function_call":
			tool_calls.append({
				"id": str(item.get("call_id", item.get("id", ""))),
				"type": "function",
				"function": {
					"name": str(item.get("name", "")),
					"arguments": str(item.get("arguments", "{}"))
				}
			})
	return {"content": content, "tool_calls": tool_calls}

# --- Parsing stream ---

func _reset_stream_state() -> void:
	_responses_item_index.clear()
	_responses_next_index = 0

func _parse_stream_line(event: Dictionary) -> void:
	if event.has("error") and not event.has("choices") and not event.has("type"):
		_fail(_error_message_from(event["error"]))
		return
	var event_type := str(event.get("type", ""))
	if event_type.begins_with("response."):
		_parse_responses_event(event_type, event)
		return
	if event.has("choices") and event["choices"] is Array and not event["choices"].is_empty():
		_parse_chat_choice(event["choices"][0])
		return
	if event.has("message") and event["message"] is Dictionary:
		_parse_ollama_message(event["message"])
		return
	var legacy_delta = event.get("delta", {})
	if legacy_delta is Dictionary and legacy_delta.get("text", null) != null:
		_emit_delta(str(legacy_delta["text"]))

func _parse_chat_choice(choice) -> void:
	if not (choice is Dictionary):
		return
	var piece = choice.get("delta", {})
	if not (piece is Dictionary):
		piece = choice.get("message", {})
	if not (piece is Dictionary):
		return
	var content = piece.get("content", "")
	if content is String:
		_emit_delta(content)
	elif content is Array:
		for part in content:
			if part is Dictionary and str(part.get("type", "")) in ["text", "output_text"]:
				_emit_delta(str(part.get("text", "")))
	var tool_calls = piece.get("tool_calls", [])
	if tool_calls is Array:
		for call in tool_calls:
			if not (call is Dictionary):
				continue
			var function_entry = call.get("function", {})
			if not (function_entry is Dictionary):
				function_entry = {}
			_append_tool_call_delta(
				int(call.get("index", 0)),
				str(call.get("id", "")),
				str(function_entry.get("name", "")),
				str(function_entry.get("arguments", ""))
			)

func _parse_ollama_message(message: Dictionary) -> void:
	var content = message.get("content", "")
	if content is String:
		_emit_delta(content)
	var tool_calls = message.get("tool_calls", [])
	if tool_calls is Array and not tool_calls.is_empty():
		var index := 0
		for call in _normalize_tool_calls(tool_calls):
			_set_tool_call(index, str(call.get("id", "")), str(call["function"]["name"]), str(call["function"]["arguments"]))
			index += 1

func _parse_responses_event(event_type: String, event: Dictionary) -> void:
	match event_type:
		"response.output_text.delta":
			_emit_delta(str(event.get("delta", "")))
		"response.output_text.done":
			# Proxy without deltas: use the full text only when no content exists yet.
			if _content.is_empty():
				_emit_delta(str(event.get("text", "")))
		"response.function_call_arguments.delta":
			var delta_index := _responses_index_for(str(event.get("item_id", "")), true)
			if delta_index >= 0:
				_append_tool_call_delta(delta_index, "", "", str(event.get("delta", "")))
		"response.output_item.added":
			var added = event.get("item", {})
			if added is Dictionary and str(added.get("type", "")) == "function_call":
				var index := _responses_index_for(str(added.get("id", "")), true)
				if index >= 0:
					_set_tool_call(
						index,
						str(added.get("call_id", added.get("id", ""))),
						str(added.get("name", "")),
						str(added.get("arguments", ""))
					)
		"response.output_item.done":
			var done = event.get("item", {})
			if done is Dictionary and str(done.get("type", "")) == "function_call":
				var index := _responses_index_for(str(done.get("id", "")), true)
				if index >= 0:
					_set_tool_call(
						index,
						str(done.get("call_id", done.get("id", ""))),
						str(done.get("name", "")),
						str(done.get("arguments", "{}"))
					)
		"response.completed", "response.done":
			var response = event.get("response", {})
			if response is Dictionary:
				_absorb_responses_final_output(response.get("output", []))
		"response.failed", "response.incomplete":
			var response = event.get("response", {})
			var message := "Response failed."
			if response is Dictionary:
				var error_value = response.get("error", null)
				if error_value != null:
					message = _error_message_from(error_value)
			_fail(message)
		"error":
			_fail(_error_message_from(event.get("error", event)))
		_:
			pass

func _absorb_responses_final_output(output) -> void:
	if not (output is Array):
		return
	for item in output:
		if not (item is Dictionary):
			continue
		var item_type := str(item.get("type", ""))
		if item_type == "function_call":
			var index := _responses_index_for(str(item.get("id", "")), false)
			if index < 0:
				index = _responses_index_for(str(item.get("id", "")), true)
			if index >= 0:
				_set_tool_call(
					index,
					str(item.get("call_id", item.get("id", ""))),
					str(item.get("name", "")),
					str(item.get("arguments", "{}"))
				)
		elif item_type == "message" and _content.is_empty():
			var parts = item.get("content", [])
			if parts is Array:
				for part in parts:
					if part is Dictionary and str(part.get("type", "")) in ["output_text", "text"]:
						_emit_delta(str(part.get("text", "")))

func _responses_index_for(item_id: String, create: bool) -> int:
	if not item_id.is_empty() and _responses_item_index.has(item_id):
		return int(_responses_item_index[item_id])
	if not create:
		return -1
	var index := _responses_next_index
	_responses_next_index += 1
	if not item_id.is_empty():
		_responses_item_index[item_id] = index
	return index

func _error_message_from(error_value) -> String:
	if error_value is Dictionary:
		var message := str(error_value.get("message", "")).strip_edges()
		var error_type := str(error_value.get("type", "")).strip_edges()
		if message.is_empty():
			message = str(error_value.get("code", ""))
		if message.is_empty():
			message = JSON.stringify(error_value)
		return message if error_type.is_empty() else error_type + ": " + message
	var text := str(error_value).strip_edges()
	return text if not text.is_empty() else "The provider returned an error without a message."

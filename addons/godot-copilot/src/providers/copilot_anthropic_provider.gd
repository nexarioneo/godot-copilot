@tool
class_name CopilotAnthropicProvider
extends CopilotProvider
# Native Anthropic Messages API provider.
# Converts from the internal format (OpenAI chat) to the Anthropic format and back;
# streaming uses Anthropic's own SSE events (content_block_delta / input_json_delta).

const ANTHROPIC_VERSION := "2023-06-01"
const DEFAULT_MAX_TOKENS := 8192

var _tool_json_buffers: Dictionary = {}

func _endpoint_url() -> String:
	var base := config.get_base_url(provider_name).trim_suffix("/")
	if base.is_empty():
		base = "https://api.anthropic.com/v1"
	if base.ends_with("/messages"):
		return base
	return base + "/messages"

func _request_headers(api_key: String, streaming: bool) -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: " + ANTHROPIC_VERSION,
		"User-Agent: GodotCopilot/2.0",
		"Accept: " + ("text/event-stream" if streaming else "application/json")
	])

func _build_stream_payload(messages: Array, tools: Array, model: String) -> Dictionary:
	return _build_request_payload(messages, tools, model, true)

func _build_complete_payload(messages: Array, tools: Array, model: String) -> Dictionary:
	return _build_request_payload(messages, tools, model, false)

func _build_request_payload(messages: Array, tools: Array, model: String, streaming: bool) -> Dictionary:
	var converted := _convert_messages(messages)
	var payload := {
		"model": model,
		"max_tokens": DEFAULT_MAX_TOKENS,
		"messages": converted["messages"]
	}
	var system_prompt := str(converted["system"])
	if not system_prompt.is_empty():
		payload["system"] = system_prompt
	if streaming:
		payload["stream"] = true
	if not tools.is_empty():
		payload["tools"] = _convert_tools(tools)
	return payload

# --- Internal format -> Anthropic conversion ---

func _convert_messages(messages: Array) -> Dictionary:
	var system_parts: Array[String] = []
	var converted: Array = []
	for message in messages:
		if not (message is Dictionary):
			continue
		var role := str(message.get("role", "user"))
		if role == "system":
			var system_text := _content_to_text(message.get("content", ""))
			if not system_text.is_empty():
				system_parts.append(system_text)
			continue

		var blocks: Array = []
		if role == "tool":
			blocks.append({
				"type": "tool_result",
				"tool_use_id": str(message.get("tool_call_id", "")),
				"content": _content_to_text(message.get("content", ""))
			})
			role = "user"
		elif role == "assistant":
			var assistant_text := _content_to_text(message.get("content", ""))
			if not assistant_text.is_empty():
				blocks.append({"type": "text", "text": assistant_text})
			var tool_calls = message.get("tool_calls", [])
			if tool_calls is Array:
				for call in tool_calls:
					if not (call is Dictionary):
						continue
					var function_entry = call.get("function", {})
					if not (function_entry is Dictionary):
						function_entry = {}
					blocks.append({
						"type": "tool_use",
						"id": str(call.get("id", "")),
						"name": str(function_entry.get("name", "")),
						"input": _parse_arguments_string(str(function_entry.get("arguments", "{}")))
					})
		else:
			blocks.append({"type": "text", "text": _content_to_text(message.get("content", ""))})

		if blocks.is_empty():
			continue
		_append_anthropic_message(converted, role, blocks)
	return {
		"system": "\n\n".join(PackedStringArray(system_parts)),
		"messages": converted
	}

func _append_anthropic_message(converted: Array, role: String, blocks: Array) -> void:
	# Anthropic requires alternating roles; consecutive blocks of the same kind are merged.
	if not converted.is_empty() and str(converted[converted.size() - 1].get("role", "")) == role:
		var last: Dictionary = converted[converted.size() - 1]
		var content: Array = last["content"]
		content.append_array(blocks)
		last["content"] = content
		return
	converted.append({"role": role, "content": blocks})

func _convert_tools(tools: Array) -> Array:
	var out: Array = []
	for tool in tools:
		if not (tool is Dictionary):
			continue
		var function_entry = tool.get("function", tool)
		if not (function_entry is Dictionary):
			continue
		var name := str(function_entry.get("name", ""))
		if name.is_empty():
			continue
		out.append({
			"name": name,
			"description": str(function_entry.get("description", "")),
			"input_schema": function_entry.get("parameters", {"type": "object", "properties": {}})
		})
	return out

# --- Parsing non-streaming ---

func _parse_complete_response(json: Dictionary) -> Dictionary:
	var content := ""
	var tool_calls: Array = []
	var blocks = json.get("content", [])
	if blocks is Array:
		for block in blocks:
			if not (block is Dictionary):
				continue
			match str(block.get("type", "")):
				"text":
					content += str(block.get("text", ""))
				"tool_use":
					tool_calls.append({
						"id": str(block.get("id", "")),
						"type": "function",
						"function": {
							"name": str(block.get("name", "")),
							"arguments": JSON.stringify(block.get("input", {}))
						}
					})
	return {"content": content, "tool_calls": tool_calls}

# --- Parsing stream ---

func _reset_stream_state() -> void:
	_tool_json_buffers.clear()

func _parse_stream_line(event: Dictionary) -> void:
	match str(event.get("type", "")):
		"content_block_start":
			var block = event.get("content_block", {})
			if block is Dictionary:
				match str(block.get("type", "")):
					"tool_use":
						var index := int(event.get("index", 0))
						_set_tool_call(index, str(block.get("id", "")), str(block.get("name", "")), "")
						_tool_json_buffers[index] = ""
					"text":
						_emit_delta(str(block.get("text", "")))
		"content_block_delta":
			var delta = event.get("delta", {})
			if delta is Dictionary:
				match str(delta.get("type", "")):
					"text_delta":
						_emit_delta(str(delta.get("text", "")))
					"input_json_delta":
						var index := int(event.get("index", 0))
						_tool_json_buffers[index] = str(_tool_json_buffers.get(index, "")) + str(delta.get("partial_json", ""))
					_:
						if delta.get("text", null) != null:
							_emit_delta(str(delta["text"]))
		"content_block_stop":
			var index := int(event.get("index", 0))
			if _tool_json_buffers.has(index):
				_finalize_tool_arguments(index)
		"error":
			_fail(_error_message_from(event.get("error", event)))
		_:
			pass

func _finalize_tool_arguments(index: int) -> void:
	var arguments := str(_tool_json_buffers.get(index, "")).strip_edges()
	_tool_json_buffers.erase(index)
	if arguments.is_empty():
		arguments = "{}"
	var entry = _accumulated_tool_calls.get(index, null)
	if entry is Dictionary:
		var function_entry: Dictionary = entry["function"]
		function_entry["arguments"] = arguments

func _error_message_from(error_value) -> String:
	if error_value is Dictionary:
		var message := str(error_value.get("message", "")).strip_edges()
		var error_type := str(error_value.get("type", "")).strip_edges()
		if message.is_empty():
			message = JSON.stringify(error_value)
		return message if error_type.is_empty() else error_type + ": " + message
	var text := str(error_value).strip_edges()
	return text if not text.is_empty() else "Anthropic returned an error without a message."

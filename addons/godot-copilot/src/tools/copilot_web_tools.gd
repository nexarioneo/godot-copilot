@tool
class_name CopilotWebTools
extends RefCounted
# Web tools: read_url (GET) and http_request (any method).

const DEFAULT_MAX_CHARS := 10000
const MAX_BODY_CHARS := 200000
const REQUEST_TIMEOUT := 15.0

const METHOD_MAP := {
	"GET": HTTPClient.METHOD_GET,
	"POST": HTTPClient.METHOD_POST,
	"PUT": HTTPClient.METHOD_PUT,
	"PATCH": HTTPClient.METHOD_PATCH,
	"DELETE": HTTPClient.METHOD_DELETE,
	"HEAD": HTTPClient.METHOD_HEAD
}

func read_url(args: Dictionary, host: Node) -> Dictionary:
	var url := str(args.get("url", "")).strip_edges()
	if url.is_empty():
		return {"success": false, "error": "Parameter 'url' is required."}
	var max_chars := clampi(int(args.get("max_chars", DEFAULT_MAX_CHARS)), 200, MAX_BODY_CHARS)
	return await _fetch(url, "GET", {}, "", max_chars, host)

func http_request(args: Dictionary, host: Node) -> Dictionary:
	var url := str(args.get("url", "")).strip_edges()
	if url.is_empty():
		return {"success": false, "error": "Parameter 'url' is required."}
	var method_name := str(args.get("method", "GET")).strip_edges().to_upper()
	if not METHOD_MAP.has(method_name):
		return {"success": false, "error": "Unsupported method: " + method_name + " (use GET/POST/PUT/PATCH/DELETE/HEAD)."}
	var headers: Dictionary = {}
	var headers_value = args.get("headers", {})
	if headers_value is Dictionary:
		headers = headers_value
	var body_value = args.get("body", "")
	var body: String = body_value if body_value is String else JSON.stringify(body_value)
	var max_chars := clampi(int(args.get("max_chars", DEFAULT_MAX_CHARS)), 200, MAX_BODY_CHARS)
	return await _fetch(url, method_name, headers, body, max_chars, host)

func _fetch(url: String, method_name: String, headers: Dictionary, body: String, max_chars: int, host: Node) -> Dictionary:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return {"success": false, "error": "Request host is not available."}
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT
	request.max_redirects = 5
	host.add_child(request)

	var header_array := PackedStringArray()
	var has_content_type := false
	for key in headers.keys():
		var header_line := str(key) + ": " + str(headers[key])
		if str(key).to_lower() == "content-type":
			has_content_type = true
		header_array.append(header_line)
	if not body.is_empty() and not has_content_type:
		var clean_body := body.strip_edges()
		if clean_body.begins_with("{") or clean_body.begins_with("["):
			header_array.append("Content-Type: application/json")

	var err := request.request(url, header_array, METHOD_MAP[method_name], body)
	if err != OK:
		request.queue_free()
		return {"success": false, "error": "Failed to start the request (code " + str(err) + ")."}

	var response: Array = await request.request_completed
	request.queue_free()

	var transport_code := int(response[0])
	var status_code := int(response[1])
	var body_bytes: PackedByteArray = response[3]
	if transport_code != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": "Connection failed (transport code " + str(transport_code) + ")."}

	var text := body_bytes.get_string_from_utf8()
	var truncated := text.length() > max_chars
	if truncated:
		text = text.substr(0, max_chars)
	var success := status_code >= 200 and status_code < 400
	var result := {
		"success": success,
		"url": url,
		"status": status_code,
		"content": text,
		"truncated": truncated
	}
	if not success:
		result["error"] = "HTTP " + str(status_code)
	return result

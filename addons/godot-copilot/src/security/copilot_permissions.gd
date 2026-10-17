@tool
class_name CopilotPermissions
extends RefCounted
# Permission rule engine using the action(target) format.
# Verdicts: ALLOW, ASK, DENY. Evaluation precedence: DENY > ASK > ALLOW.

enum Verdict { ALLOW, ASK, DENY }

const ACTION_READ_FILE := "read_file"
const ACTION_WRITE_FILE := "write_file"
const ACTION_COMMAND := "command"
const ACTION_READ_URL := "read_url"
const ACTION_HTTP_REQUEST := "http_request"
const ACTION_MCP := "mcp"
const ACTION_SUBAGENT := "subagent"

var config: CopilotConfig
var _session_grants: Array[String] = []

func _init(p_config: CopilotConfig = null) -> void:
	config = p_config

# --- Session grants ---

func clear_session_grants() -> void:
	_session_grants.clear()

func add_session_grant(rule: String) -> void:
	var clean := rule.strip_edges()
	if not clean.is_empty() and not _session_grants.has(clean):
		_session_grants.append(clean)

# --- Main evaluation ---

func check(action: String, target: String) -> Dictionary:
	var normalized := normalize_target(action, target)
	var sandboxed := is_sandbox_enabled()

	var deny_rules := get_rules("deny")
	var ask_rules := get_rules("ask")
	var allow_rules := get_rules("allow")
	for rule in _session_grants:
		if not allow_rules.has(rule):
			allow_rules.append(rule)

	# 1. Deny (highest priority)
	var matched_deny := _find_matching_rule(action, normalized, deny_rules, sandboxed)
	if not matched_deny.is_empty():
		return _result(Verdict.DENY, matched_deny, "Action blocked by Deny rule: " + matched_deny)

	# Implicit: denying read_file means denying write_file on the same target.
	if action == ACTION_WRITE_FILE:
		var matched_read_deny := _find_matching_rule(ACTION_READ_FILE, normalized, deny_rules, sandboxed)
		if not matched_read_deny.is_empty():
			return _result(Verdict.DENY, matched_read_deny, "write_file denied because read_file is blocked: " + matched_read_deny)

	# 2. Ask
	var matched_ask := _find_matching_rule(action, normalized, ask_rules, sandboxed)
	if not matched_ask.is_empty():
		return _result(Verdict.ASK, matched_ask, "Permission required by Ask rule: " + matched_ask)

	# 3. Allow
	var matched_allow := _find_matching_rule(action, normalized, allow_rules, sandboxed)
	if not matched_allow.is_empty():
		return _result(Verdict.ALLOW, matched_allow, "Allowed by rule: " + matched_allow)

	# Implicit: allowing write_file means allowing read_file.
	if action == ACTION_READ_FILE:
		var matched_write_allow := _find_matching_rule(ACTION_WRITE_FILE, normalized, allow_rules, sandboxed)
		if not matched_write_allow.is_empty():
			return _result(Verdict.ALLOW, matched_write_allow, "read_file implicitly allowed by rule: " + matched_write_allow)

	# 4. Fallback preset
	return _evaluate_preset_fallback(action, normalized)

func _evaluate_preset_fallback(action: String, target: String) -> Dictionary:
	var preset := get_preset()
	if preset == CopilotConfig.PRESET_TURBO:
		return _result(Verdict.ALLOW, "[preset:turbo]", "Automatically allowed in Turbo mode.")
	if preset == CopilotConfig.PRESET_SANDBOX:
		if is_inside_project(action, target):
			return _result(Verdict.ALLOW, "[sandbox:inside_project]", "Sandbox: operations inside the project are allowed.")
		return _result(Verdict.ASK, "[sandbox:outside_project]", "Sandbox: operations outside the project require permission.")
	return _result(Verdict.ASK, "[review:ask_all]", "Review mode: every action requires permission.")

func _result(verdict: int, rule: String, reason: String) -> Dictionary:
	return {"verdict": verdict, "rule": rule, "reason": reason}

func is_sandbox_enabled() -> bool:
	return get_preset() == CopilotConfig.PRESET_SANDBOX

func get_preset() -> String:
	if config:
		return config.get_permission_preset()
	return CopilotConfig.PRESET_SANDBOX

func get_rules(list_name: String) -> Array:
	if config:
		return config.get_permission_rules(list_name)
	return []

# --- Target position relative to the project ---

func is_inside_project(action: String, target: String) -> bool:
	match action:
		ACTION_READ_FILE, ACTION_WRITE_FILE:
			var normalized := normalize_target(action, target)
			if normalized == "*":
				return true
			if normalized.begins_with("res://"):
				return not (normalized.contains("/../") or normalized.ends_with("/.."))
			if normalized.begins_with("user://"):
				var project_user := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
				var globalized := ProjectSettings.globalize_path(normalized).replace("\\", "/")
				return not project_user.is_empty() and globalized.begins_with(project_user)
			var project_dir := ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
			return not project_dir.is_empty() and normalized.replace("\\", "/").begins_with(project_dir)
		ACTION_COMMAND:
			for marker in ["..", "/storage", "/home", "/etc", "~"]:
				if target.contains(marker):
					return false
			return true
		ACTION_SUBAGENT:
			return true
		_:
			return false

# --- Text for the permission card ---

func describe(action: String, target: String) -> Dictionary:
	var title := ""
	var question := ""
	var outside := not is_inside_project(action, target)
	match action:
		ACTION_READ_FILE:
			title = "Read File Permission"
			question = "May this file/directory be read?"
		ACTION_WRITE_FILE:
			title = "Write File Permission"
			question = "May this file be written or modified?"
		ACTION_COMMAND:
			title = "Run Command Permission"
			question = "May this terminal command be run?"
		ACTION_READ_URL:
			title = "Read URL Permission"
			question = "May this web address be accessed?"
		ACTION_HTTP_REQUEST:
			title = "HTTP Request Permission"
			question = "May this HTTP request be sent to this address?"
		ACTION_MCP:
			title = "MCP Tool Permission"
			question = "May this MCP tool be invoked?"
		ACTION_SUBAGENT:
			title = "Sub-Agent Permission"
			question = "May this sub-agent be spawned?"
		_:
			title = "Permission Request"
			question = "May the action '" + action + "' be performed?"
	return {
		"title": title,
		"question": question,
		"badge": "Outside Project" if outside else "Workspace",
		"outside": outside,
		"action": action,
		"target": target
	}

func scope_options(action: String, target: String) -> Array:
	var options: Array = [{
		"label": "This target only: " + format_rule(action, target),
		"rule": format_rule(action, target),
		"description": "Allow this exact target."
	}]

	if action in [ACTION_READ_FILE, ACTION_WRITE_FILE]:
		var parent_dir := normalize_target(action, target).get_base_dir()
		if not parent_dir.ends_with("/"):
			parent_dir += "/"
		if not parent_dir.is_empty() and parent_dir != target and parent_dir != "res:/":
			options.append({
				"label": "Whole directory: " + format_rule(action, parent_dir),
				"rule": format_rule(action, parent_dir),
				"description": "Allow every file inside " + parent_dir
			})
	elif action == ACTION_COMMAND:
		var tokens := target.strip_edges().split(" ", false)
		if tokens.size() > 1:
			var prefix := str(tokens[0])
			options.append({
				"label": "All commands starting with '" + prefix + "': " + format_rule(action, prefix),
				"rule": format_rule(action, prefix),
				"description": "Allow every sub-command that starts with '" + prefix + "'."
			})
	elif action in [ACTION_READ_URL, ACTION_HTTP_REQUEST]:
		var domain := normalize_target(action, target)
		options.append({
			"label": "Whole domain and subdomains: " + format_rule(action, domain),
			"rule": format_rule(action, domain),
			"description": "Allow the main domain and all of its subdomains."
		})

	options.append({
		"label": "Everything, unlimited: " + format_rule(action, "*"),
		"rule": format_rule(action, "*"),
		"description": "Allow this action at any target without asking again."
	})
	return options

# --- Rule parsing & matching ---

func format_rule(action: String, target: String) -> String:
	return action + "(" + target + ")"

func parse_rule(rule: String) -> Dictionary:
	var trimmed := rule.strip_edges()
	var paren_start := trimmed.find("(")
	var paren_end := trimmed.rfind(")")
	if paren_start < 1 or paren_end <= paren_start:
		return {"action": "", "target": ""}
	return {
		"action": trimmed.substr(0, paren_start).strip_edges().to_lower(),
		"target": trimmed.substr(paren_start + 1, paren_end - paren_start - 1).strip_edges()
	}

func normalize_target(action: String, target: String) -> String:
	var clean := target.strip_edges()
	match action:
		ACTION_READ_FILE, ACTION_WRITE_FILE:
			clean = clean.replace("\\", "/")
			if clean == "*":
				return clean
			if not clean.begins_with("res://") and not clean.begins_with("user://") and not clean.begins_with("/"):
				clean = "res://" + clean
			return clean
		ACTION_READ_URL, ACTION_HTTP_REQUEST:
			if clean == "*":
				return clean
			var url := clean.to_lower()
			if url.begins_with("https://"):
				url = url.substr(8)
			elif url.begins_with("http://"):
				url = url.substr(7)
			var slash := url.find("/")
			if slash != -1:
				url = url.substr(0, slash)
			var colon := url.find(":")
			if colon != -1:
				url = url.substr(0, colon)
			return url
		_:
			return clean

func matches_rule(action: String, target: String, rule: String, sandboxed: bool) -> bool:
	var parsed := parse_rule(rule)
	var rule_action := str(parsed.get("action", ""))
	var rule_target := str(parsed.get("target", ""))
	if rule_action.is_empty():
		return false

	# Legacy rule "unsandboxed(command)": only applies outside the sandbox preset.
	if rule_action == "unsandboxed":
		if action != ACTION_COMMAND or sandboxed:
			return false
	elif rule_action != action:
		return false

	if rule_target == "*":
		return true

	match action:
		ACTION_READ_FILE, ACTION_WRITE_FILE:
			return _matches_path(target, rule_target)
		ACTION_READ_URL, ACTION_HTTP_REQUEST:
			return _matches_domain(target, rule_target)
		ACTION_COMMAND:
			return _matches_command(target, rule_target)
		ACTION_MCP:
			return _matches_mcp(target, rule_target)
		ACTION_SUBAGENT:
			return target == rule_target or target.begins_with(rule_target + ":") or target.ends_with(":" + rule_target)
		_:
			return target == rule_target

func _matches_path(target_path: String, rule_path: String) -> bool:
	var normalized_target := normalize_target(ACTION_READ_FILE, target_path)
	var normalized_rule := normalize_target(ACTION_READ_FILE, rule_path)
	if normalized_target == normalized_rule:
		return true
	if not normalized_rule.ends_with("/"):
		normalized_rule += "/"
	return normalized_target.begins_with(normalized_rule)

func _matches_domain(target_value: String, rule_value: String) -> bool:
	var normalized_target := normalize_target(ACTION_READ_URL, target_value)
	var normalized_rule := normalize_target(ACTION_READ_URL, rule_value)
	if normalized_target == normalized_rule:
		return true
	return normalized_target.ends_with("." + normalized_rule)

func _matches_command(target_command: String, rule_target: String) -> bool:
	var command := target_command.strip_edges()
	if rule_target.begins_with("regex:"):
		var pattern := rule_target.substr(6).strip_edges()
		var regex := RegEx.new()
		if regex.compile(pattern) != OK:
			return false
		return regex.search(command) != null
	if _has_dangerous_constructs(command):
		return command == rule_target
	return command == rule_target or command.begins_with(rule_target + " ") or command.begins_with(rule_target + "\t")

func _matches_mcp(target_tool: String, rule_target: String) -> bool:
	if rule_target == "*":
		return true
	if rule_target.ends_with("/*"):
		return target_tool.begins_with(rule_target.trim_suffix("/*") + "/")
	return target_tool == rule_target

func _has_dangerous_constructs(command: String) -> bool:
	for symbol in ["$(", "`", "<(", "{", "|", ";", "&&", "||", "\n", "\r", ">"]:
		if command.contains(symbol):
			return true
	return false

func _find_matching_rule(action: String, target: String, rules: Array, sandboxed: bool) -> String:
	for rule in rules:
		if rule is String and matches_rule(action, target, rule, sandboxed):
			return rule
	return ""

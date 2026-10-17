@tool
class_name CopilotConfig
extends RefCounted
# settings.json (schema v2) manager for user://godot-copilot/settings.json.
# Every configuration access in the addon must go through this class.

const SCHEMA_VERSION := 2

const PRESET_SANDBOX := "sandbox"
const PRESET_REVIEW := "review"
const PRESET_TURBO := "turbo"

const STRATEGY_ROUND_ROBIN := "round_robin"
const STRATEGY_STICKY_COUNT := "sticky_count"

var data: Dictionary = {}

# Per-provider key rotation counters (in-memory, reset when the editor restarts).
var _rotation_counters: Dictionary = {}

func _init() -> void:
	load_settings()

# --- Load / Save / Migration ---

func load_settings() -> void:
	data = {}
	var text := CopilotPaths.read_text(CopilotPaths.SETTINGS_FILE)
	if text.is_empty():
		text = CopilotPaths.read_text(CopilotPaths.SETTINGS_BACKUP_FILE)

	var migrated := false
	if not text.is_empty():
		var parsed := _parse_json(text)
		if parsed.has("schema") and int(parsed.get("schema", 1)) >= SCHEMA_VERSION:
			data = parsed
		elif not parsed.is_empty():
			data = _convert_v1(parsed)
			migrated = true
	else:
		# No settings at the current location yet: try the older v2 location
		# (used before the addon folder rename), then the v1 location.
		var legacy_v2_text := CopilotPaths.read_text(CopilotPaths.LEGACY_V2_SETTINGS_FILE)
		if legacy_v2_text.is_empty():
			legacy_v2_text = CopilotPaths.read_text(CopilotPaths.LEGACY_V2_SETTINGS_BACKUP_FILE)
		if not legacy_v2_text.is_empty():
			var legacy_v2_parsed := _parse_json(legacy_v2_text)
			if not legacy_v2_parsed.is_empty():
				if legacy_v2_parsed.has("schema") and int(legacy_v2_parsed.get("schema", 1)) >= SCHEMA_VERSION:
					data = legacy_v2_parsed
				else:
					data = _convert_v1(legacy_v2_parsed)
				migrated = true
		if data.is_empty():
			var legacy_v1_text := CopilotPaths.read_text(CopilotPaths.LEGACY_V1_SETTINGS_FILE)
			if not legacy_v1_text.is_empty():
				var legacy_v1_parsed := _parse_json(legacy_v1_text)
				if not legacy_v1_parsed.is_empty():
					data = _convert_v1(legacy_v1_parsed)
					migrated = true

	if data.is_empty():
		data = _default_data()

	_normalize()
	if _migrate_legacy_sessions():
		migrated = true
	if migrated:
		save()

func save() -> void:
	_normalize()
	var ordered := {
		"schema": SCHEMA_VERSION,
		"active_model": str(data.get("active_model", "")),
		"providers": data.get("providers", {}),
		"permissions": data.get("permissions", {}),
		"memory": data.get("memory", {}),
		"agent": data.get("agent", {}),
		"mcp": data.get("mcp", {})
	}
	var json_text := JSON.stringify(ordered, "\t")
	CopilotPaths.write_text(CopilotPaths.SETTINGS_FILE, json_text)
	CopilotPaths.write_text(CopilotPaths.SETTINGS_BACKUP_FILE, json_text)

func _parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

func _default_data() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"active_model": "",
		"providers": {},
		"permissions": {
			"preset": PRESET_SANDBOX,
			"deny": [],
			"ask": [],
			"allow": []
		},
		"memory": _default_memory(),
		"agent": _default_agent(),
		"mcp": {"servers": {}}
	}

func _default_memory() -> Dictionary:
	return {
		"auto": true,
		"prune": true,
		"mode": "text",
		"model": "",
		"max_steps": 12,
		"tail_size": 4
	}

func _default_agent() -> Dictionary:
	return {
		"max_steps": 8,
		"subagents": {}
	}

func _normalize() -> void:
	if not (data.get("providers") is Dictionary):
		data["providers"] = {}
	if not (data.get("permissions") is Dictionary):
		data["permissions"] = {}
	var permissions: Dictionary = data["permissions"]
	var preset := str(permissions.get("preset", PRESET_SANDBOX))
	if not (preset in [PRESET_SANDBOX, PRESET_REVIEW, PRESET_TURBO]):
		preset = PRESET_SANDBOX
	permissions["preset"] = preset
	for list_name in ["deny", "ask", "allow"]:
		if not (permissions.get(list_name) is Array):
			permissions[list_name] = []
	if not (data.get("memory") is Dictionary):
		data["memory"] = _default_memory()
	var memory: Dictionary = data["memory"]
	var defaults := _default_memory()
	for key in defaults.keys():
		if not memory.has(key):
			memory[key] = defaults[key]
	var mode := str(memory.get("mode", "text")).to_lower()
	memory["mode"] = "native" if mode == "native" else "text"
	memory["max_steps"] = maxi(2, int(memory.get("max_steps", 12)))
	memory["tail_size"] = maxi(1, int(memory.get("tail_size", 4)))
	if not (data.get("agent") is Dictionary):
		data["agent"] = _default_agent()
	var agent: Dictionary = data["agent"]
	if not (agent.get("subagents") is Dictionary):
		agent["subagents"] = {}
	agent["max_steps"] = maxi(1, int(agent.get("max_steps", 8)))
	if not (data.get("mcp") is Dictionary):
		data["mcp"] = {"servers": {}}
	var mcp: Dictionary = data["mcp"]
	if not (mcp.get("servers") is Dictionary):
		mcp["servers"] = {}

# --- v1 -> v2 migration ---

func _convert_v1(raw: Dictionary) -> Dictionary:
	var out := _default_data()

	# Providers
	var providers: Dictionary = {}
	var legacy_providers = raw.get("provider", {})
	if legacy_providers is Dictionary:
		for pname_var in legacy_providers.keys():
			var pname := str(pname_var)
			var legacy = legacy_providers[pname_var]
			if not (legacy is Dictionary):
				continue
			providers[pname] = _convert_v1_provider(legacy)
	out["providers"] = providers
	out["active_model"] = str(raw.get("model", ""))

	# Permissions
	var legacy_permissions = raw.get("permissions", {})
	var preset := PRESET_SANDBOX
	var sandbox_on := bool(raw.get("enableTerminalSandbox", false))
	preset = PRESET_SANDBOX if sandbox_on else PRESET_REVIEW
	if legacy_permissions is Dictionary:
		var legacy_preset := str(legacy_permissions.get("preset", "default")).to_lower()
		if legacy_preset == "turbo":
			preset = PRESET_TURBO
		elif legacy_preset in ["request_review", "review"]:
			preset = PRESET_REVIEW
		for list_name in ["deny", "ask", "allow"]:
			var converted: Array = []
			var legacy_rules = legacy_permissions.get(list_name, [])
			if legacy_rules is Array:
				for rule_var in legacy_rules:
					converted.append(_convert_v1_rule(str(rule_var)))
			out["permissions"][list_name] = converted
	out["permissions"]["preset"] = preset

	# Memory (from compaction)
	var legacy_compaction = raw.get("compaction", {})
	if legacy_compaction is Dictionary:
		var memory: Dictionary = out["memory"]
		memory["auto"] = bool(legacy_compaction.get("auto", true))
		memory["prune"] = bool(legacy_compaction.get("prune", true))
		memory["mode"] = str(legacy_compaction.get("mode", "text"))
		memory["model"] = str(legacy_compaction.get("model", ""))
		memory["max_steps"] = int(legacy_compaction.get("max_steps", 12))
		memory["tail_size"] = int(legacy_compaction.get("tail_size", 4))

	# Agent & subagent
	out["agent"]["max_steps"] = int(raw.get("max_react_steps", 8))
	var subagents: Dictionary = {}
	var legacy_agents = raw.get("agent", {})
	if legacy_agents is Dictionary:
		for aname_var in legacy_agents.keys():
			var cfg = legacy_agents[aname_var]
			if cfg is Dictionary and str(cfg.get("mode", "")) == "subagent":
				subagents[str(aname_var)] = {
					"mode": "read_only",
					"model": str(cfg.get("model", ""))
				}
	out["agent"]["subagents"] = subagents

	# MCP
	var servers = raw.get("mcpServers", {})
	out["mcp"]["servers"] = servers if servers is Dictionary else {}

	return out

func _convert_v1_provider(legacy: Dictionary) -> Dictionary:
	var options = legacy.get("options", {})
	if not (options is Dictionary):
		options = {}
	var provider_type := str(legacy.get("provider", "@ai-sdk/openai"))
	var kind := "anthropic" if provider_type == "@ai-sdk/anthropic" else "openai"
	var api_type := "responses" if str(legacy.get("api_type", "")) == "responses" else "chat_completions"

	var keys: Array = []
	var legacy_keys = options.get("apiKeys", [])
	if legacy_keys is Array:
		for item in legacy_keys:
			if item is Dictionary:
				keys.append({
					"label": str(item.get("label", "Key " + str(keys.size() + 1))),
					"value": str(item.get("key", "")).strip_edges(),
					"enabled": bool(item.get("active", true))
				})
	# The old checkApiKey becomes a regular key so it is not lost.
	var check_key := str(options.get("checkApiKey", "")).strip_edges()
	if not check_key.is_empty():
		keys.append({"label": "Legacy Key", "value": check_key, "enabled": true})

	var models = legacy.get("models", {})
	return {
		"kind": kind,
		"base_url": str(options.get("baseURL", "")),
		"api_type": api_type,
		"model_prefix": str(options.get("prefix", "")),
		"key_strategy": STRATEGY_ROUND_ROBIN if bool(options.get("round_robin", false)) else STRATEGY_STICKY_COUNT,
		"sticky_count": maxi(1, int(options.get("sticky_limit", 1))),
		"keys": keys,
		"models": models if models is Dictionary else {}
	}

func _convert_v1_rule(rule: String) -> String:
	# Old execute_url action -> http_request.
	var trimmed := rule.strip_edges()
	if trimmed.begins_with("execute_url("):
		return "http_request" + trimmed.substr("execute_url".length())
	return trimmed

func _migrate_legacy_sessions() -> bool:
	var legacy_dirs := [CopilotPaths.LEGACY_V2_SESSIONS_DIR, CopilotPaths.LEGACY_V1_SESSIONS_DIR]
	var has_legacy := false
	for legacy_dir in legacy_dirs:
		if DirAccess.dir_exists_absolute(legacy_dir):
			has_legacy = true
			break
	if not has_legacy:
		return false
	if not CopilotPaths.ensure_dir(CopilotPaths.SESSIONS_DIR):
		return false
	if CopilotPaths.list_json_files(CopilotPaths.SESSIONS_DIR).size() > 0:
		return false
	var copied := 0
	for legacy_dir in legacy_dirs:
		for legacy_path in CopilotPaths.list_json_files(legacy_dir):
			var target := CopilotPaths.SESSIONS_DIR.path_join(legacy_path.get_file())
			if CopilotPaths.exists(target):
				continue
			if CopilotPaths.copy_file(legacy_path, target):
				copied += 1
	return copied > 0

# --- Provider ---

func get_provider_names() -> Array:
	var names: Array = []
	var providers = data.get("providers", {})
	if providers is Dictionary:
		for pname in providers.keys():
			names.append(str(pname))
	return names

func has_provider(provider_name: String) -> bool:
	var providers = data.get("providers", {})
	return providers is Dictionary and providers.has(provider_name)

func get_provider(provider_name: String) -> Dictionary:
	var providers = data.get("providers", {})
	if providers is Dictionary and providers.has(provider_name) and providers[provider_name] is Dictionary:
		return providers[provider_name]
	return {}

func ensure_provider(provider_name: String) -> Dictionary:
	if provider_name.is_empty():
		return {}
	var providers: Dictionary = data["providers"]
	if not providers.has(provider_name) or not (providers[provider_name] is Dictionary):
		providers[provider_name] = {
			"kind": "openai",
			"base_url": "",
			"api_type": "chat_completions",
			"model_prefix": "",
			"key_strategy": STRATEGY_STICKY_COUNT,
			"sticky_count": 1,
			"keys": [],
			"models": {}
		}
	var provider: Dictionary = providers[provider_name]
	if not (provider.get("keys") is Array):
		provider["keys"] = []
	if not (provider.get("models") is Dictionary):
		provider["models"] = {}
	return provider

func add_provider(provider_name: String, kind: String, base_url: String, api_type := "chat_completions") -> bool:
	var clean := provider_name.strip_edges()
	if clean.is_empty() or has_provider(clean):
		return false
	var provider := ensure_provider(clean)
	provider["kind"] = "anthropic" if kind == "anthropic" else "openai"
	provider["base_url"] = base_url.strip_edges()
	provider["api_type"] = "responses" if api_type == "responses" else "chat_completions"
	save()
	return true

func remove_provider(provider_name: String) -> bool:
	var providers: Dictionary = data["providers"]
	if not providers.has(provider_name):
		return false
	providers.erase(provider_name)
	var active := get_active_model_id()
	if active.begins_with(provider_name + "/"):
		data["active_model"] = ""
	var agent: Dictionary = data["agent"]
	var subagents = agent.get("subagents", {})
	if subagents is Dictionary:
		for subagent_name in subagents.keys():
			var cfg = subagents[subagent_name]
			if cfg is Dictionary and str(cfg.get("model", "")).begins_with(provider_name + "/"):
				cfg["model"] = ""
	save()
	return true

func get_provider_kind(provider_name: String) -> String:
	return "anthropic" if str(get_provider(provider_name).get("kind", "openai")) == "anthropic" else "openai"

func set_provider_kind(provider_name: String, kind: String) -> void:
	var provider := ensure_provider(provider_name)
	provider["kind"] = "anthropic" if kind == "anthropic" else "openai"
	save()

func get_base_url(provider_name: String) -> String:
	return str(get_provider(provider_name).get("base_url", "")).strip_edges()

func set_base_url(provider_name: String, url: String) -> void:
	ensure_provider(provider_name)["base_url"] = url.strip_edges()
	save()

func get_api_type(provider_name: String) -> String:
	return "responses" if str(get_provider(provider_name).get("api_type", "")) == "responses" else "chat_completions"

func set_api_type(provider_name: String, api_type: String) -> void:
	ensure_provider(provider_name)["api_type"] = "responses" if api_type == "responses" else "chat_completions"
	save()

func get_model_prefix(provider_name: String) -> String:
	return str(get_provider(provider_name).get("model_prefix", "")).strip_edges()

func set_model_prefix(provider_name: String, prefix: String) -> void:
	ensure_provider(provider_name)["model_prefix"] = prefix.strip_edges()
	save()

# --- API Keys ---

func get_api_keys(provider_name: String) -> Array:
	var keys = get_provider(provider_name).get("keys", [])
	return keys if keys is Array else []

func set_api_keys(provider_name: String, keys: Array) -> void:
	ensure_provider(provider_name)["keys"] = keys.duplicate(true)
	save()

func add_api_key(provider_name: String, value: String, label := "", enabled := true) -> void:
	var clean := value.strip_edges()
	if clean.is_empty():
		return
	var keys := get_api_keys(provider_name).duplicate(true)
	var final_label := label.strip_edges()
	if final_label.is_empty():
		final_label = "Key " + str(keys.size() + 1)
	keys.append({"label": final_label, "value": clean, "enabled": enabled})
	set_api_keys(provider_name, keys)

func update_api_key(provider_name: String, index: int, value: String, label: String) -> void:
	var keys := get_api_keys(provider_name).duplicate(true)
	if index < 0 or index >= keys.size():
		return
	var item: Dictionary = keys[index]
	item["value"] = value.strip_edges()
	var clean_label := label.strip_edges()
	if not clean_label.is_empty():
		item["label"] = clean_label
	keys[index] = item
	set_api_keys(provider_name, keys)

func remove_api_key(provider_name: String, index: int) -> void:
	var keys := get_api_keys(provider_name).duplicate(true)
	if index < 0 or index >= keys.size():
		return
	keys.remove_at(index)
	set_api_keys(provider_name, keys)

func move_api_key(provider_name: String, from_index: int, to_index: int) -> bool:
	var keys := get_api_keys(provider_name).duplicate(true)
	if from_index < 0 or from_index >= keys.size():
		return false
	if to_index < 0 or to_index >= keys.size():
		return false
	if from_index == to_index:
		return true
	var item = keys[from_index]
	keys.remove_at(from_index)
	keys.insert(to_index, item)
	set_api_keys(provider_name, keys)
	return true

func set_api_key_enabled(provider_name: String, index: int, enabled: bool) -> void:
	var keys := get_api_keys(provider_name).duplicate(true)
	if index < 0 or index >= keys.size():
		return
	var item: Dictionary = keys[index]
	item["enabled"] = enabled
	keys[index] = item
	set_api_keys(provider_name, keys)

func get_enabled_key_count(provider_name: String) -> int:
	var count := 0
	for item in get_api_keys(provider_name):
		if item is Dictionary and bool(item.get("enabled", true)) and not str(item.get("value", "")).strip_edges().is_empty():
			count += 1
	return count

func get_key_strategy(provider_name: String) -> String:
	return STRATEGY_ROUND_ROBIN if str(get_provider(provider_name).get("key_strategy", "")) == STRATEGY_ROUND_ROBIN else STRATEGY_STICKY_COUNT

func set_key_strategy(provider_name: String, strategy: String) -> void:
	ensure_provider(provider_name)["key_strategy"] = STRATEGY_ROUND_ROBIN if strategy == STRATEGY_ROUND_ROBIN else STRATEGY_STICKY_COUNT
	save()

func get_sticky_count(provider_name: String) -> int:
	return maxi(1, int(get_provider(provider_name).get("sticky_count", 1)))

func set_sticky_count(provider_name: String, count: int) -> void:
	ensure_provider(provider_name)["sticky_count"] = maxi(1, count)
	save()

func _enabled_key_entries(provider_name: String) -> Array:
	var entries: Array = []
	var keys := get_api_keys(provider_name)
	for i in range(keys.size()):
		var item = keys[i]
		if not (item is Dictionary):
			continue
		var value := str(item.get("value", "")).strip_edges()
		if value.is_empty() or not bool(item.get("enabled", true)):
			continue
		entries.append({"index": i, "value": value, "label": str(item.get("label", ""))})
	return entries

func next_api_key(provider_name: String) -> Dictionary:
	var entries := _enabled_key_entries(provider_name)
	if entries.is_empty():
		return {}
	var sticky := 1
	if get_key_strategy(provider_name) == STRATEGY_STICKY_COUNT:
		sticky = get_sticky_count(provider_name)
	var counter := int(_rotation_counters.get(provider_name, 0))
	_rotation_counters[provider_name] = counter + 1
	var slot := (counter / sticky) % entries.size()
	return entries[slot]

func peek_api_key(provider_name: String) -> String:
	var entries := _enabled_key_entries(provider_name)
	if entries.is_empty():
		return ""
	return str(entries[0].get("value", ""))

# --- Model ---

func get_model_keys(provider_name: String) -> Array:
	var models = get_provider(provider_name).get("models", {})
	var keys: Array = []
	if models is Dictionary:
		for model_key in models.keys():
			keys.append(str(model_key))
	return keys

func get_model(provider_name: String, model_key: String) -> Dictionary:
	var models = get_provider(provider_name).get("models", {})
	if models is Dictionary and models.has(model_key) and models[model_key] is Dictionary:
		return models[model_key]
	return {}

func get_model_display_name(provider_name: String, model_key: String) -> String:
	var model := get_model(provider_name, model_key)
	var display := str(model.get("name", "")).strip_edges()
	return display if not display.is_empty() else model_key

func add_or_update_model(provider_name: String, model_key: String, display_name := "", flags: Dictionary = {}) -> void:
	var clean_key := model_key.strip_edges()
	if provider_name.is_empty() or clean_key.is_empty():
		return
	var provider := ensure_provider(provider_name)
	var models: Dictionary = provider["models"]
	var existing: Dictionary = models.get(clean_key, {}) if models.get(clean_key, {}) is Dictionary else {}
	var final_name := display_name.strip_edges()
	if final_name.is_empty():
		final_name = str(existing.get("name", clean_key))

	var inputs: Array = ["text", "image"]
	if bool(flags.get("vision", true)) == false:
		inputs = ["text"]
	var entry := {
		"name": final_name,
		"modalities": {"input": inputs, "output": ["text"]}
	}
	if bool(flags.get("reasoning", false)) or bool(existing.get("reasoning", false)):
		entry["reasoning"] = true
	if bool(existing.get("disabled", false)):
		entry["disabled"] = true
	models[clean_key] = entry
	save()

func remove_model(provider_name: String, model_key: String) -> bool:
	var provider := get_provider(provider_name)
	var models = provider.get("models", {})
	if not (models is Dictionary) or not models.has(model_key):
		return false
	models.erase(model_key)
	if get_active_model_id() == provider_name + "/" + model_key:
		data["active_model"] = ""
	save()
	return true

func is_model_disabled(provider_name: String, model_key: String) -> bool:
	return bool(get_model(provider_name, model_key).get("disabled", false))

func set_model_disabled(provider_name: String, model_key: String, disabled: bool) -> void:
	var models = get_provider(provider_name).get("models", {})
	if not (models is Dictionary) or not models.has(model_key):
		return
	var model: Dictionary = models[model_key]
	if disabled:
		model["disabled"] = true
	else:
		model.erase("disabled")
	models[model_key] = model
	save()

func set_all_models_disabled(provider_name: String, disabled: bool) -> void:
	for model_key_var in get_model_keys(provider_name):
		set_model_disabled(provider_name, str(model_key_var), disabled)

func get_model_caps(provider_name: String, model_key: String) -> Dictionary:
	var caps := {"vision": false, "reasoning": false}
	var model := get_model(provider_name, model_key)
	if model.is_empty():
		return caps
	var modalities = model.get("modalities", {})
	if modalities is Dictionary:
		var inputs = modalities.get("input", [])
		if inputs is Array and inputs.has("image"):
			caps["vision"] = true
	caps["reasoning"] = bool(model.get("reasoning", false))
	return caps

func get_available_models() -> Array:
	var results: Array = []
	var providers = data.get("providers", {})
	if not (providers is Dictionary):
		return results
	for provider_name_var in providers.keys():
		var provider_name := str(provider_name_var)
		for model_key_var in get_model_keys(provider_name):
			var model_key := str(model_key_var)
			if is_model_disabled(provider_name, model_key):
				continue
			results.append({
				"id": provider_name + "/" + model_key,
				"provider": provider_name,
				"model_key": model_key,
				"display_name": provider_name + " — " + get_model_display_name(provider_name, model_key)
			})
	return results

# --- Active Model ---

func get_active_model_id() -> String:
	return str(data.get("active_model", "")).strip_edges()

func set_active_model_id(model_id: String) -> void:
	var clean := model_id.strip_edges()
	data["active_model"] = clean
	save()

func get_active_provider_name() -> String:
	var model_id := get_active_model_id()
	if not model_id.is_empty():
		var slash := model_id.find("/")
		if slash > 0:
			return model_id.substr(0, slash)
	var names := get_provider_names()
	return str(names[0]) if not names.is_empty() else ""

func get_active_model_key() -> String:
	var model_id := get_active_model_id()
	var slash := model_id.find("/")
	if slash != -1:
		return model_id.substr(slash + 1)
	return model_id

func split_model_id(model_id: String) -> Dictionary:
	var clean := model_id.strip_edges()
	var slash := clean.find("/")
	if slash <= 0:
		return {"provider": "", "model_key": clean}
	return {"provider": clean.substr(0, slash), "model_key": clean.substr(slash + 1)}

# --- Permission ---

func get_permission_preset() -> String:
	var permissions = data.get("permissions", {})
	if permissions is Dictionary:
		return str(permissions.get("preset", PRESET_SANDBOX))
	return PRESET_SANDBOX

func set_permission_preset(preset: String) -> void:
	var clean := preset.to_lower()
	if not (clean in [PRESET_SANDBOX, PRESET_REVIEW, PRESET_TURBO]):
		clean = PRESET_SANDBOX
	data["permissions"]["preset"] = clean
	save()

func get_permission_rules(list_name: String) -> Array:
	var permissions = data.get("permissions", {})
	if permissions is Dictionary and permissions.get(list_name) is Array:
		return permissions[list_name]
	return []

func set_permission_rules(list_name: String, rules: Array) -> void:
	data["permissions"][list_name] = rules.duplicate()
	save()

func add_permission_rule(list_name: String, rule: String) -> void:
	var clean := rule.strip_edges()
	if clean.is_empty():
		return
	var rules := get_permission_rules(list_name).duplicate()
	if rules.has(clean):
		return
	rules.append(clean)
	set_permission_rules(list_name, rules)

func remove_permission_rule(list_name: String, rule: String) -> void:
	var rules := get_permission_rules(list_name).duplicate()
	if not rules.has(rule):
		return
	rules.erase(rule)
	set_permission_rules(list_name, rules)

# --- Memory ---

func is_memory_auto() -> bool:
	return bool(data["memory"].get("auto", true))

func is_memory_prune() -> bool:
	return bool(data["memory"].get("prune", true))

func get_memory_mode() -> String:
	return str(data["memory"].get("mode", "text"))

func get_memory_model() -> String:
	return str(data["memory"].get("model", "")).strip_edges()

func get_memory_max_steps() -> int:
	return maxi(2, int(data["memory"].get("max_steps", 12)))

func get_memory_tail_size() -> int:
	return maxi(1, int(data["memory"].get("tail_size", 4)))

func set_memory_value(key: String, value: Variant) -> void:
	data["memory"][key] = value
	save()

# --- Agent & Subagent ---

func get_agent_max_steps() -> int:
	return maxi(1, int(data["agent"].get("max_steps", 8)))

func set_agent_max_steps(steps: int) -> void:
	data["agent"]["max_steps"] = maxi(1, steps)
	save()

func get_subagent_names() -> Array:
	var subagents = data["agent"].get("subagents", {})
	var names: Array = []
	if subagents is Dictionary:
		for subagent_name in subagents.keys():
			names.append(str(subagent_name))
	return names

func get_subagent_config(subagent_name: String) -> Dictionary:
	var subagents = data["agent"].get("subagents", {})
	if subagents is Dictionary and subagents.has(subagent_name) and subagents[subagent_name] is Dictionary:
		return subagents[subagent_name]
	return {}

func ensure_subagent(subagent_name: String, mode := "read_only") -> Dictionary:
	var subagents: Dictionary = data["agent"]["subagents"]
	if not subagents.has(subagent_name) or not (subagents[subagent_name] is Dictionary):
		subagents[subagent_name] = {"mode": mode, "model": ""}
	return subagents[subagent_name]

func get_subagent_model(subagent_name: String) -> String:
	var model_id := str(get_subagent_config(subagent_name).get("model", "")).strip_edges()
	if not model_id.is_empty():
		return model_id
	return get_active_model_id()

func set_subagent_model(subagent_name: String, model_id: String) -> void:
	var clean := subagent_name.strip_edges()
	if clean.is_empty():
		return
	ensure_subagent(clean)["model"] = model_id.strip_edges()
	save()

func remove_subagent(subagent_name: String) -> void:
	var subagents: Dictionary = data["agent"]["subagents"]
	if not subagents.has(subagent_name):
		return
	subagents.erase(subagent_name)
	save()

# --- MCP ---

func get_mcp_servers() -> Dictionary:
	var mcp = data.get("mcp", {})
	if mcp is Dictionary and mcp.get("servers") is Dictionary:
		return mcp["servers"]
	return {}

func set_mcp_server(server_name: String, server_config: Dictionary) -> void:
	data["mcp"]["servers"][server_name] = server_config
	save()

func remove_mcp_server(server_name: String) -> void:
	var servers: Dictionary = data["mcp"]["servers"]
	if servers.has(server_name):
		servers.erase(server_name)
		save()

@tool
class_name CopilotProviderPresets
extends RefCounted
# Provider preset catalog (data only). The wizard and Provider Manager read from here.
# To add a new preset: add an entry to PRESETS plus an SVG icon in assets/providers/.

const ICONS_DIR := "res://addons/godot-copilot/assets/providers"

const PRESETS: Array[Dictionary] = [
	{
		"name": "OpenAI",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://api.openai.com/v1",
		"key_url": "https://platform.openai.com/api-keys",
		"icon": "openai"
	},
	{
		"name": "Anthropic",
		"kind": "anthropic",
		"api_type": "",
		"base_url": "https://api.anthropic.com/v1",
		"key_url": "https://console.anthropic.com/settings/keys",
		"icon": "anthropic"
	},
	{
		"name": "Gemini",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://generativelanguage.googleapis.com/v1beta/openai",
		"key_url": "https://aistudio.google.com/apikey",
		"icon": "gemini"
	},
	{
		"name": "Vertex AI",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://aiplatform.googleapis.com/v1",
		"key_url": "https://console.cloud.google.com/apis/credentials",
		"icon": "vertexai"
	},
	{
		"name": "OpenRouter",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://openrouter.ai/api/v1",
		"key_url": "https://openrouter.ai/keys",
		"icon": "openrouter"
	},
	{
		"name": "DeepSeek",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://api.deepseek.com/v1",
		"key_url": "https://platform.deepseek.com/api_keys",
		"icon": "deepseek"
	},
	{
		"name": "Groq",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://api.groq.com/openai/v1",
		"key_url": "https://console.groq.com/keys",
		"icon": "groq"
	},
	{
		"name": "Ollama",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "http://localhost:11434/v1",
		"key_url": "",
		"icon": "ollama"
	},
	{
		"name": "Agnes AI",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://api.agnesai.com/v1",
		"key_url": "https://agnesai.com",
		"icon": "agnesai"
	},
	{
		"name": "Kiro",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://api.kiro.ai/v1",
		"key_url": "https://kiro.ai",
		"icon": "kiro"
	},
	{
		"name": "Blackbox AI",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://api.blackbox.ai/v1",
		"key_url": "https://blackbox.ai",
		"icon": ""
	},
	{
		"name": "OpenCode Zen",
		"kind": "openai",
		"api_type": "chat_completions",
		"base_url": "https://opencode.ai/zen/v1",
		"key_url": "https://opencode.ai",
		"icon": ""
	}
]

# Custom provider logo heuristic: keyword -> file name (without .svg).
const ICON_KEYWORDS := [
	["openrouter", "openrouter"],
	["deepseek", "deepseek"],
	["kiro", "kiro"],
	["gemini", "gemini"],
	["groq", "groq"],
	["vertex", "vertexai"],
	["agnes", "agnesai"],
	["anthropic", "anthropic"],
	["claude", "anthropic"],
	["ollama", "ollama"],
	["openai", "openai"]
]

static func get_presets() -> Array:
	return PRESETS.duplicate(true)

static func get_preset(preset_name: String) -> Dictionary:
	for preset in PRESETS:
		if str(preset.get("name", "")).to_lower() == preset_name.to_lower():
			return preset.duplicate(true)
	return {}

static func has_preset(preset_name: String) -> bool:
	return not get_preset(preset_name).is_empty()

static func icon_path_for(provider_name: String) -> String:
	var lower := provider_name.to_lower()
	for keyword_entry in ICON_KEYWORDS:
		if lower.contains(str(keyword_entry[0])):
			return icon_path_for_slug(str(keyword_entry[1]))
	return ""

static func icon_path_for_slug(slug: String) -> String:
	if slug.is_empty():
		return ""
	var path := ICONS_DIR + "/" + slug + ".svg"
	return path if FileAccess.file_exists(path) else ""

static func icon_path_for_preset(preset: Dictionary) -> String:
	return icon_path_for_slug(str(preset.get("icon", "")))

static func key_url_for(provider_name: String) -> String:
	return str(get_preset(provider_name).get("key_url", ""))

static func kind_for_url(base_url: String) -> String:
	return "anthropic" if base_url.to_lower().contains("anthropic") else "openai"

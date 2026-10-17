@tool
class_name CopilotMd3Icons
extends RefCounted
# Bundled Material Symbols (Rounded, 24px, white) for the Material 3 component
# library. Components use symbol() (returns null when missing) or
# apply_to_button(), which falls back to a Godot editor icon and finally to a
# text label.

static var _cache: Dictionary = {}

static func symbol(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name] as Texture2D
	var texture: Texture2D = null
	var path := CopilotPaths.SYMBOLS_DIR + "/" + name + ".svg"
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_cache[name] = texture
	return texture

static func has_symbol(name: String) -> bool:
	return symbol(name) != null

static func apply_to_button(button: Button, symbol_name: String, editor_fallback: String = "", text_fallback: String = "") -> void:
	var texture := symbol(symbol_name)
	if texture == null and not editor_fallback.is_empty() and button.has_theme_icon(editor_fallback, "EditorIcons"):
		texture = button.get_theme_icon(editor_fallback, "EditorIcons")
	if texture != null:
		button.icon = texture
	elif not text_fallback.is_empty():
		button.text = text_fallback

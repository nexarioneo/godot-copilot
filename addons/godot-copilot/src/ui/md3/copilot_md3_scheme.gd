@tool
class_name CopilotMd3Scheme
extends RefCounted
# Resolves Material 3 color roles to Color values for one theme mode. Create one
# scheme per UI tree (dock plus its dialogs) and inject it into the components.
# Role tables live in CopilotMd3Tokens.

const MODE_LIGHT := "light"
const MODE_DARK := "dark"

var mode: String = MODE_LIGHT
var _roles: Dictionary = {}

static func light() -> CopilotMd3Scheme:
	return _from_table(CopilotMd3Tokens.ROLES_LIGHT, MODE_LIGHT)

static func dark() -> CopilotMd3Scheme:
	return _from_table(CopilotMd3Tokens.ROLES_DARK, MODE_DARK)

static func detect_mode(node: Node) -> String:
	# Reads the editor theme base color when the caller can resolve theme
	# values; defaults to dark, which matches the Godot editor default theme.
	var base := Color("#1d1d1d")
	if node != null and node.has_method("has_theme_color"):
		if node.call("has_theme_color", "base_color", "Editor") == true:
			var theme_color: Variant = node.call("get_theme_color", "base_color", "Editor")
			if theme_color is Color:
				base = theme_color
	if base.get_luminance() > 0.5:
		return MODE_LIGHT
	return MODE_DARK

static func _from_table(table: Dictionary, scheme_mode: String) -> CopilotMd3Scheme:
	var scheme := CopilotMd3Scheme.new()
	scheme.mode = scheme_mode
	scheme._roles = table.duplicate()
	scheme._roles.merge(CopilotMd3Tokens.ROLES_FIXED)
	return scheme

func has_role(role: String) -> bool:
	return _roles.has(role)

func color(role: String) -> Color:
	if _roles.has(role):
		return Color(_roles[role])
	push_warning("CopilotMd3Scheme: unknown color role '%s'" % role)
	return Color(1.0, 0.0, 1.0)

func alpha(role: String, opacity: float) -> Color:
	var result := color(role)
	result.a *= clampf(opacity, 0.0, 1.0)
	return result

func state_overlay(content_role: String, state: String) -> Color:
	var opacity: float = float(CopilotMd3Tokens.STATE_OPACITY.get(state, 0.0))
	return alpha(content_role, opacity)

func disabled_content(content_role: String) -> Color:
	return alpha(content_role, CopilotMd3Tokens.DISABLED_CONTENT_OPACITY)

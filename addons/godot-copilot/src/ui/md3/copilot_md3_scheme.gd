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

static var _light_cache: CopilotMd3Scheme = null
static var _dark_cache: CopilotMd3Scheme = null

static func light() -> CopilotMd3Scheme:
	return _from_table(CopilotMd3Tokens.ROLES_LIGHT, MODE_LIGHT)

static func dark() -> CopilotMd3Scheme:
	return _from_table(CopilotMd3Tokens.ROLES_DARK, MODE_DARK)

static func for_node(node: Node) -> CopilotMd3Scheme:
	# Standalone accessor used by components that are not given an explicit
	# scheme (the dock can still inject one with set_scheme()).
	if detect_mode(node) == MODE_LIGHT:
		if _light_cache == null:
			_light_cache = light()
		return _light_cache
	if _dark_cache == null:
		_dark_cache = dark()
	return _dark_cache

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

func state_fill(base_color: Color, content_color: Color, opacity: float) -> Color:
	# State layer over a container: blends the content color into the base when
	# the base is visible, or returns the overlay color alone when the base is
	# transparent.
	if base_color.a <= 0.0:
		var layer := content_color
		layer.a = opacity
		return layer
	return base_color.lerp(content_color, opacity)

func box(fill_role: String, radius: int, border_role: String = "", border_width: int = 0, shadow_level: int = 0) -> StyleBoxFlat:
	# Shared StyleBoxFlat builder: fill role ("" for none), corner radius,
	# optional outline, optional shadow level.
	var sb := StyleBoxFlat.new()
	if fill_role.is_empty():
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	else:
		sb.bg_color = color(fill_role)
	if border_width > 0 and not border_role.is_empty():
		sb.set_border_width_all(border_width)
		sb.border_color = color(border_role)
	sb.set_corner_radius_all(radius)
	if shadow_level > 0:
		CopilotMd3Tokens.apply_shadow(sb, shadow_level)
	return sb

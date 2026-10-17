@tool
class_name CopilotMd3Card
extends PanelContainer
# Material 3 card: elevated (surface-container-low + elevation 1), filled
# (surface-container-highest) or outlined (surface + 1dp outline-variant).
# Corner 12 by default, 16dp content padding.

const VARIANT_ELEVATED := "elevated"
const VARIANT_FILLED := "filled"
const VARIANT_OUTLINED := "outlined"

const PADDING := 16

var variant: String = VARIANT_FILLED
var radius_shape: String = "medium"
var _scheme: CopilotMd3Scheme = null
# Role overrides for composites (chat surfaces, custom panels): when a fill
# role is set it wins over the variant mapping. -1 keeps the variant/shape
# value. Padding and corners are explicit 4-tuples for reusable layouts.
var _fill_override := ""
var _border_override := ""
var _border_width_override := 0
var _shadow_override := -1
var _padding := Vector4i(PADDING, PADDING, PADDING, PADDING)
var _corner_override := Vector4i(-1, -1, -1, -1)

func configure(scheme: CopilotMd3Scheme, card_variant: String = VARIANT_FILLED, corner_shape: String = "medium") -> void:
	_scheme = scheme
	variant = card_variant
	radius_shape = corner_shape
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_variant(card_variant: String) -> void:
	variant = card_variant
	_apply()

func set_corner_shape(corner_shape: String) -> void:
	radius_shape = corner_shape
	_apply()

func set_roles(fill_role: String, border_role: String = "", border_width: int = 0, shadow_level: int = -1) -> void:
	_fill_override = fill_role
	_border_override = border_role
	_border_width_override = border_width
	_shadow_override = shadow_level
	_apply()

func set_padding(left: int, top: int, right: int, bottom: int) -> void:
	_padding = Vector4i(left, top, right, bottom)
	_apply()

func set_corner_radii(top_left: int, top_right: int, bottom_right: int, bottom_left: int) -> void:
	_corner_override = Vector4i(top_left, top_right, bottom_right, bottom_left)
	_apply()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_apply()

func _apply() -> void:
	if _scheme == null:
		return
	var fill_role := "surface-container-highest"
	var border_role := ""
	var border_width := 0
	var shadow := 0
	match variant:
		VARIANT_ELEVATED:
			fill_role = "surface-container-low"
			shadow = 1
		VARIANT_OUTLINED:
			fill_role = "surface"
			border_role = "outline-variant"
			border_width = 1
	if not _fill_override.is_empty():
		fill_role = _fill_override
		border_role = _border_override
		border_width = _border_width_override
		shadow = maxi(_shadow_override, 0)
	var radius := CopilotMd3Tokens.corner_radius(radius_shape, size)
	var box := _scheme.box(fill_role, radius, border_role, border_width, shadow)
	if _corner_override.x >= 0:
		box.corner_radius_top_left = _corner_override.x
	if _corner_override.y >= 0:
		box.corner_radius_top_right = _corner_override.y
	if _corner_override.z >= 0:
		box.corner_radius_bottom_right = _corner_override.z
	if _corner_override.w >= 0:
		box.corner_radius_bottom_left = _corner_override.w
	box.content_margin_left = _padding.x
	box.content_margin_top = _padding.y
	box.content_margin_right = _padding.z
	box.content_margin_bottom = _padding.w
	add_theme_stylebox_override("panel", box)

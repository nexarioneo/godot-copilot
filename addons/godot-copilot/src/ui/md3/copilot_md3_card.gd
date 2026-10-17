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
	var radius := CopilotMd3Tokens.corner_radius(radius_shape, size)
	var box := _scheme.box(fill_role, radius, border_role, border_width, shadow)
	box.content_margin_left = PADDING
	box.content_margin_right = PADDING
	box.content_margin_top = PADDING
	box.content_margin_bottom = PADDING
	add_theme_stylebox_override("panel", box)

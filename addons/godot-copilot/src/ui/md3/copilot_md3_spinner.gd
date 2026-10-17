@tool
class_name CopilotMd3Spinner
extends Control
# Material 3 circular progress indicator (indeterminate): a rotating
# 270-degree arc. Used for thinking rows and running tool rows.

const SWEEP_DEGREES := 270.0
const REVOLUTION_SECONDS := 1.33
const DEFAULT_DIAMETER := 24

var _scheme: CopilotMd3Scheme = null
var _color_role := "primary"
var _diameter := DEFAULT_DIAMETER
var _stroke := 3
var _angle := 0.0

func configure(scheme: CopilotMd3Scheme, color_role: String = "primary", diameter: int = DEFAULT_DIAMETER, stroke: int = 0) -> void:
	_scheme = scheme
	_color_role = color_role
	_diameter = maxi(8, diameter)
	_stroke = stroke if stroke > 0 else _default_stroke(_diameter)
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	queue_redraw()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_apply()

func _apply() -> void:
	custom_minimum_size = Vector2(_diameter, _diameter)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_angle = fmod(_angle + (TAU / REVOLUTION_SECONDS) * delta, TAU)
	queue_redraw()

func _draw() -> void:
	if _scheme == null:
		return
	var center := size * 0.5
	var radius := maxf(1.0, (float(_diameter) - float(_stroke)) * 0.5)
	var start := -PI * 0.5 + _angle
	draw_arc(center, radius, start, start + deg_to_rad(SWEEP_DEGREES), 48, _scheme.color(_color_role), float(_stroke), true)

static func _default_stroke(diameter: int) -> int:
	if diameter >= 40:
		return 4
	if diameter >= 24:
		return 3
	return 2

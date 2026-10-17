@tool
class_name CopilotMd3Divider
extends Control
# Material 3 divider: 1dp outline-variant line, horizontal or vertical, with
# optional insets (left / right for horizontal, top / bottom for vertical).

const THICKNESS := 1

var vertical := false
var _scheme: CopilotMd3Scheme = null
var _color := Color(0.6, 0.6, 0.6, 1.0)
var _start_inset := 0
var _end_inset := 0

func configure(scheme: CopilotMd3Scheme, start_inset: int = 0, end_inset: int = 0, is_vertical: bool = false) -> void:
	_scheme = scheme
	_color = scheme.color("outline-variant")
	_start_inset = start_inset
	_end_inset = end_inset
	vertical = is_vertical
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(THICKNESS, 0) if vertical else Vector2(0, THICKNESS)
	queue_redraw()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_color = scheme.color("outline-variant")
	queue_redraw()

func _ready() -> void:
	if _scheme == null:
		set_scheme(CopilotMd3Scheme.for_node(self))

func _draw() -> void:
	if vertical:
		var span := maxf(size.y - float(_start_inset) - float(_end_inset), 0.0)
		draw_rect(Rect2(0.0, float(_start_inset), float(THICKNESS), span), _color)
	else:
		var span := maxf(size.x - float(_start_inset) - float(_end_inset), 0.0)
		draw_rect(Rect2(float(_start_inset), 0.0, span, float(THICKNESS)), _color)

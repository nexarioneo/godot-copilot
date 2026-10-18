@tool
class_name CopilotMd3LinearProgress
extends Control
# Material 3 linear progress indicator: 4px track (surface-container-highest)
# with a primary active indicator with round caps. Indeterminate by default
# (start()); set_value() switches to determinate; stop() hides the indicator
# without removing the node.

const TRACK_H := 4
const WAVE_SECONDS := 2.0
const MIN_FRACTION := 0.15
const MAX_FRACTION := 0.55

var _scheme: CopilotMd3Scheme = null
var _active := false
var _indeterminate := true
var _value := 0.0
var _time := 0.0
var _track_box: StyleBoxFlat = null
var _indicator_box: StyleBoxFlat = null

func configure(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func start() -> void:
	_active = true
	_indeterminate = true
	_time = 0.0
	set_process(true)
	queue_redraw()

func set_value(value: float) -> void:
	_active = true
	_indeterminate = false
	_value = clampf(value, 0.0, 1.0)
	set_process(false)
	queue_redraw()

func stop() -> void:
	_active = false
	set_process(false)
	queue_redraw()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_apply()
	set_process(_active and _indeterminate)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _apply() -> void:
	if _scheme == null:
		return
	custom_minimum_size = Vector2(0, TRACK_H)
	_track_box = _scheme.box("surface-container-highest", TRACK_H / 2, "", 0)
	_indicator_box = _scheme.box("primary", TRACK_H / 2, "", 0)
	queue_redraw()

func _draw() -> void:
	if _scheme == null or not _active:
		return
	if _track_box == null:
		_apply()
	var y := (size.y - TRACK_H) * 0.5
	var track_rect := Rect2(Vector2(0.0, y), Vector2(size.x, TRACK_H))
	draw_style_box(_track_box, track_rect)
	if size.x <= 0.0:
		return
	if _indeterminate:
		var phase := fposmod(_time, WAVE_SECONDS) / WAVE_SECONDS
		var grow := sin(phase * PI)
		var width := size.x * lerpf(MIN_FRACTION, MAX_FRACTION, maxf(grow, 0.0))
		var center := size.x * phase
		var x := clampf(center - width * 0.5, 0.0, maxf(size.x - width, 0.0))
		draw_style_box(_indicator_box, Rect2(Vector2(x, y), Vector2(width, TRACK_H)))
	else:
		draw_style_box(_indicator_box, Rect2(Vector2(0.0, y), Vector2(size.x * _value, TRACK_H)))

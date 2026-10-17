@tool
class_name CopilotMd3StateLayer
extends Control
# Shared state overlay for interactive components: draws the hover / focus /
# pressed layer (content color at the opacities from MATERIAL3.md section 8.1)
# on top of its host control. The host keeps handling input; the layer follows
# the host rect.
#
# Usage: add the layer as a child of the host and fill it, then bind() it.
# Hosts that are not BaseButton call set_state() from their own input code.

const STATE_HOVER := "hover"
const STATE_FOCUS := "focus"
const STATE_PRESSED := "pressed"
const STATE_DRAGGED := "dragged"

var _scheme: CopilotMd3Scheme = null
var _content_role := "on-surface"
var _state := ""
var _active := {
	STATE_HOVER: false,
	STATE_FOCUS: false,
	STATE_PRESSED: false,
	STATE_DRAGGED: false,
}
var _tint := Color(0.0, 0.0, 0.0, 0.0)
var _style: StyleBoxFlat = null
var _fade: Tween = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

func bind(host: Control, scheme: CopilotMd3Scheme, radius: int, content_role: String = "on-surface") -> void:
	_scheme = scheme
	_content_role = content_role
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style = scheme.box("", radius)
	host.mouse_entered.connect(_on_host_hover.bind(true))
	host.mouse_exited.connect(_on_host_hover.bind(false))
	host.focus_entered.connect(set_state.bind(STATE_FOCUS, true))
	host.focus_exited.connect(set_state.bind(STATE_FOCUS, false))
	if host is BaseButton:
		var base := host as BaseButton
		base.button_down.connect(set_state.bind(STATE_PRESSED, true))
		base.button_up.connect(set_state.bind(STATE_PRESSED, false))
	queue_redraw()

func set_state(state: String, active: bool) -> void:
	if not _active.has(state):
		return
	if _active[state] == active:
		return
	_active[state] = active
	_refresh()

func set_content_role(role: String) -> void:
	_content_role = role
	if _scheme != null and not _state.is_empty():
		_tint = _scheme.state_overlay(_content_role, _state)
		queue_redraw()

func set_radius(radius: int) -> void:
	if _style != null:
		_style.set_corner_radius_all(radius)
		queue_redraw()

func _on_host_hover(hovered: bool) -> void:
	set_state(STATE_HOVER, hovered)

func _refresh() -> void:
	var next := ""
	if _active[STATE_PRESSED]:
		next = STATE_PRESSED
	elif _active[STATE_DRAGGED]:
		next = STATE_DRAGGED
	elif _active[STATE_FOCUS]:
		next = STATE_FOCUS
	elif _active[STATE_HOVER]:
		next = STATE_HOVER
	if next == _state:
		return
	_state = next
	if _scheme != null and not _state.is_empty():
		_tint = _scheme.state_overlay(_content_role, _state)
	queue_redraw()
	_animate()

func _animate() -> void:
	var target: float = 1.0 if not _state.is_empty() else 0.0
	if not is_inside_tree():
		modulate.a = target
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", target, CopilotMd3Motion.duration_seconds("short2")).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	if _style == null or _state.is_empty() or _tint.a <= 0.0:
		return
	_style.bg_color = _tint
	draw_style_box(_style, Rect2(Vector2.ZERO, size))

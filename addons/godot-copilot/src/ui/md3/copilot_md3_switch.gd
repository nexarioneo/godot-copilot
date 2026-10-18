@tool
class_name CopilotMd3Switch
extends Button
# Material 3 switch: 52x32 track with a 24px thumb that animates with the
# effects easing. Off: surface-container-highest track with a 2dp outline
# border and an outline thumb; on: primary track and on-primary thumb with an
# optional 16px symbol. Toggle state lives in `button_pressed`.

const TRACK_W := 52
const TRACK_H := 32
const THUMB := 24
const THUMB_MARGIN := 4
const ICON_SIZE := 16
const HALO_RADIUS := 20.0
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10

var _scheme: CopilotMd3Scheme = null
var _icon_name := ""
var _progress := 0.0
var _hovered := false
var _held := false
var _touch_device := false
var _track_box: StyleBoxFlat = null
var _track_on_color := Color(0.0, 0.0, 0.0, 0.0)
var _track_off_color := Color(0.0, 0.0, 0.0, 0.0)
var _border_color := Color(0.0, 0.0, 0.0, 0.0)
var _thumb_on_color := Color(0.0, 0.0, 0.0, 0.0)
var _thumb_off_color := Color(0.0, 0.0, 0.0, 0.0)
var _icon_color := Color(0.0, 0.0, 0.0, 0.0)
var _icon_texture: Texture2D = null

func configure(scheme: CopilotMd3Scheme, checked: bool = false, icon_name: String = "") -> void:
	_scheme = scheme
	_icon_name = icon_name
	toggle_mode = true
	set_pressed_no_signal(checked)
	_progress = 1.0 if checked else 0.0
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_checked(checked: bool, emit_signal_wanted: bool = false) -> void:
	if emit_signal_wanted:
		set_pressed(checked)
		return
	set_pressed_no_signal(checked)
	_animate_to(1.0 if checked else 0.0)

func is_checked() -> bool:
	return button_pressed

func _ready() -> void:
	toggle_mode = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	# Touch devices keep the pressed state layer (shown while the finger is
	# down) but never show a hover or focus halo, which would linger after a
	# tap and look like a stray circle.
	_touch_device = DisplayServer.is_touchscreen_available()
	_progress = 1.0 if button_pressed else 0.0
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw()
	)
	button_down.connect(func() -> void:
		_held = true
		queue_redraw()
	)
	button_up.connect(func() -> void:
		_held = false
		queue_redraw()
	)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(_on_toggled)
	_apply()

func _on_toggled(pressed: bool) -> void:
	_animate_to(1.0 if pressed else 0.0)

func _animate_to(target: float) -> void:
	if not is_inside_tree():
		_progress = target
		queue_redraw()
		return
	var tween := create_tween()
	CopilotMd3Motion.animate_eased(tween, _set_progress, _progress, target, CopilotMd3Motion.duration_seconds("short4"), "emphasized")

func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()

func _apply() -> void:
	if _scheme == null:
		return
	custom_minimum_size = Vector2(TRACK_W, TRACK_H)
	_track_off_color = _scheme.color("surface-container-highest")
	_track_on_color = _scheme.color("primary")
	_thumb_off_color = _scheme.color("outline")
	_thumb_on_color = _scheme.color("on-primary")
	_border_color = _scheme.color("outline")
	_icon_color = _scheme.color("on-secondary-container")
	_icon_texture = CopilotMd3Icons.symbol(_icon_name) if not _icon_name.is_empty() else null
	_track_box = _scheme.box("", TRACK_H / 2, "", 0)
	_track_box.set_border_width_all(2)
	_track_box.border_color = _border_color
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)
	queue_redraw()

func _draw() -> void:
	if _scheme == null:
		return
	if _track_box == null:
		_apply()
		if _track_box == null:
			return
	var top := (size.y - TRACK_H) * 0.5
	var left := (size.x - TRACK_W) * 0.5
	var track_rect := Rect2(Vector2(left, top), Vector2(TRACK_W, TRACK_H))
	var track_color := _track_off_color.lerp(_track_on_color, _progress)
	var border_alpha := 1.0 - _progress
	if disabled:
		track_color = _scheme.alpha("on-surface", 0.12)
		border_alpha = 0.0
	_track_box.bg_color = track_color
	_track_box.border_color = Color(_border_color, _border_color.a * border_alpha)
	draw_style_box(_track_box, track_rect)

	var thumb_x := lerpf(float(THUMB_MARGIN), float(TRACK_W - THUMB - THUMB_MARGIN), _progress)
	var center := Vector2(left + thumb_x + THUMB * 0.5, top + TRACK_H * 0.5)
	var thumb_color := _thumb_off_color.lerp(_thumb_on_color, _progress)
	if disabled:
		thumb_color = _scheme.alpha("on-surface", 0.38)
	else:
		var halo_opacity := 0.0
		if _held:
			halo_opacity = PRESSED_OPACITY
		elif not _touch_device and (_hovered or has_focus()):
			halo_opacity = HOVER_OPACITY
		if halo_opacity > 0.0:
			draw_circle(center, HALO_RADIUS, _scheme.alpha("on-surface", halo_opacity))
	draw_circle(center, THUMB * 0.5, thumb_color)
	if _icon_texture != null and not disabled:
		var icon_rect := Rect2(center - Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5), Vector2(ICON_SIZE, ICON_SIZE))
		draw_texture_rect(_icon_texture, icon_rect, false, Color(_icon_color, _icon_color.a * _progress))

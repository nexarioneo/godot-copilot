@tool
class_name CopilotMd3Snackbar
extends Control
# Material 3 snackbar hosted inline by the dock: inverse-surface container,
# body-medium message, optional text-button action, 4s auto-dismiss. The dock
# reserves vertical space and this control animates it (rise/fall reveal).

const MIN_HEIGHT := 48
const CORNER_RADIUS := 4
const PAD_H := 16
const PAD_V := 4
const AUTO_DISMISS_SECONDS := 4.0
const FADE_GAIN := 2.0

signal dismissed()

var _scheme: CopilotMd3Scheme = null

var _panel: PanelContainer = null
var _row: HBoxContainer = null
var _label: Label = null
var _action: CopilotMd3Button = null
var _timer: Timer = null
var _tween: Tween = null
var _panel_height := float(MIN_HEIGHT)
var _action_callback := Callable()

func _init() -> void:
	clip_contents = true
	visible = false

func configure(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func show_message(message: String, action_label: String = "", action: Callable = Callable()) -> void:
	if _panel == null:
		_build()
	_label.text = message
	if action_label.is_empty() or not action.is_valid():
		_action.visible = false
		_action_callback = Callable()
	else:
		_action.text = action_label
		_action.visible = true
		_action_callback = action
	_apply()
	visible = true
	_panel_height = maxf(float(MIN_HEIGHT), _panel.get_combined_minimum_size().y)
	_set_reveal(0.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	CopilotMd3Motion.animate_eased(
		_tween, _set_reveal, 0.0, 1.0,
		CopilotMd3Motion.duration_seconds("medium2"), "standard-decelerate"
	)
	_timer.start(AUTO_DISMISS_SECONDS)

func hide_now() -> void:
	if not visible:
		return
	_timer.stop()
	_dismiss()

func _ready() -> void:
	_build()
	_apply()
	visible = false

func _build() -> void:
	if _panel != null:
		return
	_panel = PanelContainer.new()
	_panel.name = "snackbar_panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("m"))
	_panel.add_child(_row)

	_label = Label.new()
	CopilotMd3Tokens.apply_text(_label, "body-medium")
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_label)

	_action = CopilotMd3Button.new()
	_action.configure(_scheme, CopilotMd3Button.VARIANT_TEXT, "", "", "")
	_action.custom_minimum_size.y = 40
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action.visible = false
	_action.pressed.connect(_on_action_pressed)
	_row.add_child(_action)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_dismiss)
	add_child(_timer)

func _apply() -> void:
	if _scheme == null or _panel == null:
		return
	var panel_box := _scheme.box("inverse-surface", CORNER_RADIUS, "", 0, 3)
	panel_box.content_margin_left = PAD_H
	panel_box.content_margin_right = PAD_H
	panel_box.content_margin_top = PAD_V
	panel_box.content_margin_bottom = PAD_V
	_panel.add_theme_stylebox_override("panel", panel_box)
	_label.add_theme_color_override("font_color", _scheme.color("inverse-on-surface"))
	_action.set_scheme(_scheme)
	var inverse_primary := _scheme.color("inverse-primary")
	_action.add_theme_color_override("font_color", inverse_primary)
	_action.add_theme_color_override("font_hover_color", inverse_primary)
	_action.add_theme_color_override("font_pressed_color", inverse_primary)
	_action.add_theme_color_override("font_focus_color", inverse_primary)

func _dismiss() -> void:
	if not visible:
		return
	_timer.stop()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.finished.connect(func() -> void:
		visible = false
		custom_minimum_size.y = 0.0
		dismissed.emit()
	)
	CopilotMd3Motion.animate_eased(
		_tween, _set_reveal, 1.0, 0.0,
		CopilotMd3Motion.duration_seconds("short4"), "standard-accelerate"
	)

func _set_reveal(value: float) -> void:
	# Clamp guards the layout while the reveal drives the reserved height and fade.
	var reveal := clampf(value, 0.0, 1.0)
	custom_minimum_size.y = _panel_height * reveal
	modulate.a = clampf(reveal * FADE_GAIN, 0.0, 1.0)

func _on_action_pressed() -> void:
	if _action_callback.is_valid():
		_action_callback.call()
	_dismiss()

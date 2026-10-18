@tool
class_name CopilotMd3SpinField
extends HBoxContainer
# Stepped numeric field: compact outlined text input with a stacked chevron
# stepper on the trailing edge (expand_less / expand_more). The value commits
# on stepper press, Enter, or focus loss and clamps to [min, max]; emits
# value_changed only when the committed value differs from the previous one.

signal value_changed(value: int)

const FIELD_HEIGHT := 40
const FIELD_MIN_WIDTH := 96
const STEP_SIZE := 20
const STEP_ICON_SIZE := 16

var _scheme: CopilotMd3Scheme = null
var _input: CopilotMd3TextField = null
var _up_button: Button = null
var _down_button: Button = null
var _value := 0
var _min := 0
var _max := 100
var _step := 1

func configure(scheme: CopilotMd3Scheme, value: int = 0, min_value: int = 0, max_value: int = 100, step: int = 1) -> void:
	_scheme = scheme
	_min = min_value
	_max = maxi(max_value, min_value)
	_step = maxi(step, 1)
	_value = clampi(value, _min, _max)
	_build_ui()
	if _input != null:
		_input.text = str(_value)

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	if _input != null:
		_input.set_scheme(scheme)
	_apply()

func get_value() -> int:
	return _value

func set_value(value: int) -> void:
	_value = clampi(value, _min, _max)
	if _input != null:
		_input.text = str(_value)

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_build_ui()

func _build_ui() -> void:
	if _input != null:
		return
	_input = CopilotMd3TextField.new()
	_input.configure(_scheme, "", CopilotMd3TextField.VARIANT_OUTLINED, FIELD_HEIGHT)
	_input.custom_minimum_size.x = FIELD_MIN_WIDTH
	_input.text_submitted.connect(func(_text: String) -> void: _commit_text())
	_input.focus_exited.connect(_commit_text)
	add_child(_input)
	var stepper := VBoxContainer.new()
	stepper.add_theme_constant_override("separation", 0)
	add_child(stepper)
	_up_button = _make_step_button("expand_less", "ArrowUp", "Increase")
	_up_button.pressed.connect(func() -> void: _bump(1))
	stepper.add_child(_up_button)
	_down_button = _make_step_button("expand_more", "ArrowDown", "Decrease")
	_down_button.pressed.connect(func() -> void: _bump(-1))
	stepper.add_child(_down_button)
	_apply()

func _apply() -> void:
	if _scheme == null or _up_button == null:
		return
	var radius := CopilotMd3Tokens.corner_radius("extra-small", Vector2(24, STEP_SIZE))
	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	for button in [_up_button, _down_button]:
		button.add_theme_stylebox_override("normal", _step_box(transparent, radius))
		button.add_theme_stylebox_override("hover", _step_box(_scheme.alpha("on-surface", 0.08), radius))
		button.add_theme_stylebox_override("pressed", _step_box(_scheme.alpha("on-surface", 0.10), radius))
		button.add_theme_stylebox_override("disabled", _step_box(transparent, radius))
		button.add_theme_color_override("icon_normal_color", _scheme.color("on-surface-variant"))
		button.add_theme_color_override("icon_hover_color", _scheme.color("on-surface"))
		button.add_theme_color_override("icon_pressed_color", _scheme.color("on-surface"))
		button.add_theme_color_override("icon_focus_color", _scheme.color("on-surface"))
		button.add_theme_color_override("icon_disabled_color", _scheme.disabled_content("on-surface"))

func _step_box(fill_color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.set_corner_radius_all(radius)
	return sb

func _make_step_button(icon_name: String, editor_fallback: String, tooltip: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(24, STEP_SIZE)
	CopilotMd3Icons.apply_to_button(button, icon_name, editor_fallback, "")
	button.add_theme_constant_override("icon_max_width", STEP_ICON_SIZE)
	return button

func _commit_text() -> void:
	if _input == null:
		return
	var parsed := _input.text.strip_edges()
	if not parsed.is_valid_int():
		_input.text = str(_value)
		return
	var new_value := clampi(parsed.to_int(), _min, _max)
	_input.text = str(new_value)
	if new_value == _value:
		return
	_value = new_value
	value_changed.emit(_value)

func _bump(delta: int) -> void:
	var new_value := clampi(_value + delta * _step, _min, _max)
	if new_value == _value:
		return
	_value = new_value
	if _input != null:
		_input.text = str(_value)
	value_changed.emit(_value)

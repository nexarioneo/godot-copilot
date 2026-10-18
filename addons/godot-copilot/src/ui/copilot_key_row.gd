@tool
class_name CopilotKeyRow
extends CopilotMd3ListItem
# Single API key row built on the M3 list item: leading switch (enabled),
# title = key label, supporting = masked value (mono, body-small), trailing =
# test status (badge or spinner) plus reveal / test / move / edit / delete
# compact icon buttons.

signal enabled_toggled(index: int, enabled: bool)
signal test_requested(index: int)
signal move_requested(index: int, delta: int)
signal edit_requested(index: int)
signal remove_requested(index: int)

const STATUS_SIZE := 16

var key_index := -1

var _enabled_switch: CopilotMd3Switch = null
var _status_box: HBoxContainer = null
var _reveal_button: CopilotMd3IconButton = null
var _value := ""
var _revealed := false

func _ready() -> void:
	super._ready()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(scheme: CopilotMd3Scheme, index: int, label: String, value: String, enabled: bool, status: String) -> void:
	key_index = index
	_value = value
	_revealed = false
	configure(scheme, label if not label.is_empty() else "Key " + str(index + 1), "")
	set_subtitle_style("body-small")
	set_subtitle_mono(true)
	_enabled_switch = CopilotMd3Switch.new()
	_enabled_switch.configure(scheme, enabled)
	_enabled_switch.tooltip_text = "Enable/disable this key for rotation"
	_enabled_switch.toggled.connect(func(pressed: bool) -> void: enabled_toggled.emit(key_index, pressed))
	set_leading(_enabled_switch)
	_build_trailing(scheme)
	_update_value_text()
	set_status(status)

func set_status(status: String) -> void:
	if _status_box == null:
		return
	for child in _status_box.get_children():
		_status_box.remove_child(child)
		child.queue_free()
	match status:
		"queued":
			_add_badge("queued", "neutral")
		"testing":
			_add_spinner()
		"success":
			_add_badge("Valid", "success")
		"failed":
			_add_badge("Failed", "error")

static func mask_value(value: String) -> String:
	if value.length() <= 8:
		return "••••••"
	return value.substr(0, 3) + "…" + value.substr(value.length() - 4)

func _build_trailing(scheme: CopilotMd3Scheme) -> void:
	_status_box = HBoxContainer.new()
	_status_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_box.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	add_trailing(_status_box)
	_reveal_button = _make_icon_button(scheme, "visibility", "Show/hide the key value")
	_reveal_button.set_toggle(true)
	_reveal_button.toggled.connect(_on_reveal_toggled)
	add_trailing(_reveal_button)
	add_trailing(_make_icon_button(scheme, "refresh", "Test this key", func() -> void: test_requested.emit(key_index)))
	add_trailing(_make_icon_button(scheme, "arrow_upward", "Move this key up", func() -> void: move_requested.emit(key_index, -1)))
	add_trailing(_make_icon_button(scheme, "arrow_downward", "Move this key down", func() -> void: move_requested.emit(key_index, 1)))
	add_trailing(_make_icon_button(scheme, "edit", "Edit key", func() -> void: edit_requested.emit(key_index)))
	add_trailing(_make_icon_button(scheme, "delete", "Delete key", func() -> void: remove_requested.emit(key_index)))

func _make_icon_button(scheme: CopilotMd3Scheme, icon_name: String, tooltip: String, handler: Callable = Callable()) -> CopilotMd3IconButton:
	var button := CopilotMd3IconButton.new()
	button.configure(scheme, CopilotMd3IconButton.VARIANT_STANDARD, "", icon_name)
	button.set_compact(true)
	button.tooltip_text = tooltip
	if handler.is_valid():
		button.pressed.connect(handler)
	return button

func _add_badge(text: String, tone: String) -> void:
	var badge := CopilotMd3Badge.new()
	badge.configure(_scheme, text, tone)
	_status_box.add_child(badge)

func _add_spinner() -> void:
	var spinner := CopilotMd3Spinner.new()
	spinner.configure(_scheme, "primary", STATUS_SIZE, 2)
	spinner.custom_minimum_size = Vector2(STATUS_SIZE, STATUS_SIZE)
	_status_box.add_child(spinner)

func _update_value_text() -> void:
	set_subtitle(_value if _revealed else mask_value(_value))

func _on_reveal_toggled(pressed: bool) -> void:
	_revealed = pressed
	_reveal_button.set_icon("visibility_off" if pressed else "visibility")
	_update_value_text()

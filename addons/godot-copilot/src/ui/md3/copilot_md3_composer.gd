@tool
class_name CopilotMd3Composer
extends VBoxContainer
# Material 3 chat composer: a surface-container-highest pill with a flat
# multiline TextEdit, trailing Send (filled) and Stop (tonal) icon buttons, and
# a supporting hint shown while the input is focused. Grows from 48px to 120px.

const MIN_PILL_HEIGHT := 48
const MAX_PILL_HEIGHT := 120
const PAD_H := 16
const PAD_V := 4
const V_PAD_INPUT := 10
const RADIUS := 24

signal submitted(text: String)
signal stop_requested()

var _scheme: CopilotMd3Scheme = null

var _pill: PanelContainer = null
var _row: HBoxContainer = null
var _input: TextEdit = null
var _send_button: CopilotMd3IconButton = null
var _stop_button: CopilotMd3IconButton = null
var _hint_label: Label = null
var _busy := false

func configure(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_ensure_built()
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_busy(busy: bool) -> void:
	_busy = busy
	_stop_button.visible = busy
	_hint_label.visible = _input.has_focus() and not busy
	_update_send_state()

func text() -> String:
	return _input.text

func clear() -> void:
	_input.clear()
	_update_height()
	_update_send_state()

func focus_input() -> void:
	if _input != null:
		_input.grab_focus()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_ensure_built()
	_apply()

func _ensure_built() -> void:
	if _input != null:
		return
	add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))

	_pill = PanelContainer.new()
	add_child(_pill)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	_pill.add_child(_row)

	_input = TextEdit.new()
	_input.name = "composer_input"
	_input.placeholder_text = "Message Copilot..."
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input.custom_minimum_size.y = MIN_PILL_HEIGHT - PAD_V * 2
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.scroll_fit_content_height = false
	_input.gui_input.connect(_on_input_gui_input)
	_input.text_changed.connect(_on_text_changed)
	_input.focus_entered.connect(_on_focus_changed)
	_input.focus_exited.connect(_on_focus_changed)
	_row.add_child(_input)

	var trailing := HBoxContainer.new()
	trailing.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	trailing.size_flags_vertical = Control.SIZE_SHRINK_END
	_row.add_child(trailing)

	_stop_button = CopilotMd3IconButton.new()
	_stop_button.configure(_scheme, CopilotMd3Button.VARIANT_TONAL, "", "stop", "")
	_stop_button.tooltip_text = "Stop the running request"
	_stop_button.visible = false
	_stop_button.pressed.connect(func() -> void: stop_requested.emit())
	trailing.add_child(_stop_button)

	_send_button = CopilotMd3IconButton.new()
	_send_button.configure(_scheme, CopilotMd3Button.VARIANT_FILLED, "", "send", "")
	_send_button.tooltip_text = "Send the message to Copilot"
	_send_button.disabled = true
	_send_button.pressed.connect(_submit)
	trailing.add_child(_send_button)

	_hint_label = Label.new()
	CopilotMd3Tokens.apply_text(_hint_label, "body-small")
	_hint_label.text = "Enter to send, Shift+Enter for a new line"
	_hint_label.visible = false
	add_child(_hint_label)

	_input.get_v_scroll_bar().visible = false

func _apply() -> void:
	if _scheme == null or _input == null:
		return
	var pill_box := _scheme.box("surface-container-highest", RADIUS, "", 0, 1)
	pill_box.content_margin_left = PAD_H
	pill_box.content_margin_right = PAD_H
	pill_box.content_margin_top = PAD_V
	pill_box.content_margin_bottom = PAD_V
	_pill.add_theme_stylebox_override("panel", pill_box)

	add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	CopilotMd3Tokens.apply_text(_input, "body-medium")

	var empty := StyleBoxEmpty.new()
	empty.content_margin_top = V_PAD_INPUT
	empty.content_margin_bottom = V_PAD_INPUT
	for state in ["normal", "focus", "read_only"]:
		_input.add_theme_stylebox_override(state, empty)
	_input.add_theme_color_override("font_color", _scheme.color("on-surface"))
	_input.add_theme_color_override("font_placeholder_color", _scheme.color("on-surface-variant"))
	_input.add_theme_color_override("caret_color", _scheme.color("primary"))
	_input.add_theme_color_override("selection_color", _scheme.alpha("primary", 0.30))
	_input.add_theme_color_override("current_line_color", Color(0.0, 0.0, 0.0, 0.0))

	_hint_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	_send_button.set_scheme(_scheme)
	_stop_button.set_scheme(_scheme)
	_update_height()
	_update_send_state()

func _on_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not event.shift_pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_input.accept_event()
			_submit()

func _on_text_changed() -> void:
	_update_height()
	_update_send_state()

func _on_focus_changed() -> void:
	_hint_label.visible = _input.has_focus() and not _busy

func _submit() -> void:
	var value := _input.text
	if value.strip_edges().is_empty():
		return
	submitted.emit(value)

func _update_send_state() -> void:
	if _send_button == null:
		return
	_send_button.disabled = _busy or _input.text.strip_edges().is_empty()

func _update_height() -> void:
	if _input == null:
		return
	var font := CopilotMd3Tokens.font_for_weight(CopilotMd3Tokens.type_weight("body-medium"))
	var line_height := 20
	if font != null:
		line_height = ceili(font.get_height(CopilotMd3Tokens.type_size("body-medium")))
	var lines := maxi(_input.get_line_count(), 1)
	var input_height := clampi(lines * line_height + V_PAD_INPUT * 2, MIN_PILL_HEIGHT - PAD_V * 2, MAX_PILL_HEIGHT - PAD_V * 2)
	_input.custom_minimum_size.y = input_height
	_pill.custom_minimum_size.y = input_height + PAD_V * 2

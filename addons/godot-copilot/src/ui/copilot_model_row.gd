@tool
class_name CopilotModelRow
extends CopilotMd3ListItem
# Provider model row built on the M3 list item: leading switch (enabled),
# title = model id (mono), supporting = display name plus capability hints,
# trailing delete. Disabled rows are dimmed.

signal active_toggled(model_key: String, active: bool)
signal remove_requested(model_key: String)

var model_key := ""

var _active_switch: CopilotMd3Switch = null

func _ready() -> void:
	super._ready()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(scheme: CopilotMd3Scheme, p_model_key: String, display_name: String, disabled: bool, vision: bool, reasoning: bool) -> void:
	model_key = p_model_key
	var supporting_parts: Array[String] = []
	if not display_name.is_empty():
		supporting_parts.append(display_name)
	var caps: Array[String] = []
	if vision:
		caps.append("vision")
	if reasoning:
		caps.append("reasoning")
	if not caps.is_empty():
		supporting_parts.append("[" + ", ".join(caps) + "]")
	configure(scheme, p_model_key, " ".join(supporting_parts))
	set_title_mono(true)
	_active_switch = CopilotMd3Switch.new()
	_active_switch.configure(scheme, not disabled)
	_active_switch.tooltip_text = "Enable/disable this model in the model picker"
	_active_switch.toggled.connect(func(pressed: bool) -> void: active_toggled.emit(model_key, pressed))
	set_leading(_active_switch)
	var remove_button := CopilotMd3IconButton.new()
	remove_button.configure(scheme, CopilotMd3IconButton.VARIANT_STANDARD, "", "delete")
	remove_button.set_compact(true)
	remove_button.tooltip_text = "Remove the model from the list"
	remove_button.pressed.connect(func() -> void: remove_requested.emit(model_key))
	add_trailing(remove_button)
	modulate = Color(1, 1, 1, 0.55) if disabled else Color(1, 1, 1, 1)

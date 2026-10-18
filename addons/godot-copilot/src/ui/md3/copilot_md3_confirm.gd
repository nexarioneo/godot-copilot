@tool
class_name CopilotMd3Confirm
extends CopilotMd3Dialog
# Confirmation variant of CopilotMd3Dialog: wrapped message (body-medium,
# on-surface-variant) with Cancel (text) and OK (filled, or danger for
# destructive actions). Connect to the AcceptDialog `confirmed` signal.

var _message_label: Label = null

func configure(scheme: CopilotMd3Scheme, title_text: String, ok_text: String = "Close", cancel_text: String = "") -> void:
	super.configure(scheme, title_text, ok_text, cancel_text)

func set_message(message: String) -> void:
	_build_message(message)

func set_danger(danger: bool) -> void:
	set_ok_variant(CopilotMd3Button.VARIANT_DANGER if danger else CopilotMd3Button.VARIANT_FILLED)

func _build_message(message: String) -> void:
	body().custom_minimum_size.x = 360
	if _message_label != null:
		_message_label.text = message
		return
	_message_label = Label.new()
	_message_label.text = message
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CopilotMd3Tokens.apply_text(_message_label, "body-medium")
	if _scheme != null:
		_message_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	body().add_child(_message_label)

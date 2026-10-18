@tool
class_name CopilotMd3Badge
extends Label
# Material 3 badge: 16dp tall pill with label-small text. Tones map to role
# pairs; default is error / on-error as in the M3 spec.

const TONES := {
	"error": ["error", "on-error"],
	"primary": ["primary", "on-primary"],
	"secondary": ["secondary", "on-secondary"],
	"neutral": ["surface-container-highest", "on-surface-variant"],
	"success": ["status-success", "on-status-success"],
	"warning": ["status-warning", "on-status-warning"],
	"info": ["status-info", "on-status-info"],
}

const HEIGHT := 16
const PAD_H := 6

var tone: String = "error"
var _scheme: CopilotMd3Scheme = null

func configure(scheme: CopilotMd3Scheme, text_value: String = "", badge_tone: String = "error") -> void:
	_scheme = scheme
	text = text_value
	tone = badge_tone
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_tone(badge_tone: String) -> void:
	tone = badge_tone
	_apply()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_apply()

func _apply() -> void:
	if _scheme == null:
		return
	CopilotMd3Tokens.apply_text(self, "label-small")
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size.y = HEIGHT

	var roles: Array = TONES.get(tone, TONES["error"])
	var fill_role := String(roles[0])
	var content_role := String(roles[1])
	var radius := CopilotMd3Tokens.corner_radius("full", Vector2(HEIGHT, HEIGHT))
	var box := _scheme.box(fill_role, radius)
	box.content_margin_left = PAD_H
	box.content_margin_right = PAD_H
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	add_theme_stylebox_override("normal", box)
	add_theme_color_override("font_color", _scheme.color(content_role))

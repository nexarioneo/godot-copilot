@tool
class_name CopilotPermissionCard
extends PanelContainer
# Inline permission card above the composer: scope + "Remember" + Allow/Deny.

signal resolved(request_id: String, allowed: bool, remember: bool, scope_index: int)

var _request: Dictionary = {}

var _title_label: Label
var _badge_label: Label
var _question_label: RichTextLabel
var _scope_option: OptionButton
var _remember_check: CheckBox
var _allow_button: Button
var _deny_button: Button

func _ready() -> void:
	_build_ui()
	visible = false

func show_request(request: Dictionary) -> void:
	_request = request
	if not is_inside_tree():
		return
	_title_label.text = str(request.get("title", "Permission Request"))
	var outside := bool(request.get("outside", false))
	_badge_label.text = "Outside Project" if outside else "Workspace"
	_badge_label.add_theme_color_override(
		"font_color",
		CopilotTheme.error_color(self) if outside else CopilotTheme.success_color(self)
	)
	_question_label.clear()
	_question_label.add_text(str(request.get("question", "")))
	_question_label.add_text("\nTarget: " + str(request.get("target", "")))

	_scope_option.clear()
	var options: Array = request.get("scope_options", [])
	for option in options:
		if option is Dictionary:
			_scope_option.add_item(str(option.get("label", "")))
			_scope_option.set_item_tooltip(_scope_option.item_count - 1, str(option.get("description", "")))
	if _scope_option.item_count == 0:
		_scope_option.add_item("Just this once")
	_scope_option.selected = 0
	_remember_check.button_pressed = false
	visible = true

func hide_card() -> void:
	_request = {}
	visible = false

func _build_ui() -> void:
	add_theme_stylebox_override("panel", CopilotTheme.card_style(self, CopilotTheme.warning_color(self), 1))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)

	var lock_icon := CopilotTheme.icon(self, PackedStringArray(["Lock"]))
	if lock_icon != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = lock_icon
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(icon_rect)
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", CopilotTheme.warning_color(self))
	header.add_child(_title_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_badge_label = Label.new()
	_badge_label.add_theme_font_size_override("font_size", 11)
	header.add_child(_badge_label)

	_question_label = RichTextLabel.new()
	_question_label.bbcode_enabled = true
	_question_label.fit_content = true
	_question_label.scroll_active = false
	_question_label.selection_enabled = true
	_question_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_question_label)

	var scope_row := HBoxContainer.new()
	scope_row.add_theme_constant_override("separation", 6)
	box.add_child(scope_row)
	var scope_label := Label.new()
	scope_label.text = "Scope"
	scope_label.add_theme_font_size_override("font_size", 11)
	scope_label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
	scope_row.add_child(scope_label)
	_scope_option = OptionButton.new()
	_scope_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scope_option.tooltip_text = "How broad the granted permission is"
	scope_row.add_child(_scope_option)

	_remember_check = CheckBox.new()
	_remember_check.text = "Remember for the next session"
	_remember_check.tooltip_text = "Saves this permission rule permanently to settings.json"
	box.add_child(_remember_check)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)
	_allow_button = Button.new()
	_allow_button.text = "Allow"
	_allow_button.tooltip_text = "Run this action"
	_allow_button.pressed.connect(_on_allow_pressed)
	buttons.add_child(_allow_button)
	_deny_button = Button.new()
	_deny_button.text = "Deny"
	_deny_button.tooltip_text = "Deny this action"
	_deny_button.pressed.connect(_on_deny_pressed)
	buttons.add_child(_deny_button)

func _on_allow_pressed() -> void:
	if _request.is_empty():
		return
	resolved.emit(
		str(_request.get("id", "")),
		true,
		_remember_check.button_pressed,
		_scope_option.selected
	)
	hide_card()

func _on_deny_pressed() -> void:
	if _request.is_empty():
		return
	resolved.emit(str(_request.get("id", "")), false, false, 0)
	hide_card()

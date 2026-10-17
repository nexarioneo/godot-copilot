@tool
class_name CopilotMd3EmptyState
extends VBoxContainer
# Material 3 empty state: a centered 48px symbol, headline-small title,
# body-medium hint, and one or more centered action buttons. Used for the empty
# chat view and for empty lists in dialogs.

const ICON_SIZE := 48

var _scheme: CopilotMd3Scheme = null

var _icon_rect: TextureRect = null
var _title_label: Label = null
var _hint_label: Label = null
var _actions_box: VBoxContainer = null
var _buttons: Array[CopilotMd3Button] = []

func configure(scheme: CopilotMd3Scheme, title: String = "", hint: String = "", icon_name: String = "auto_awesome", editor_fallback: String = "") -> void:
	_scheme = scheme
	_ensure_built()
	_title_label.text = title
	_hint_label.text = hint
	_hint_label.visible = not hint.is_empty()
	var texture := CopilotMd3Icons.symbol(icon_name)
	if texture == null and not editor_fallback.is_empty() and has_theme_icon(editor_fallback, "EditorIcons"):
		texture = get_theme_icon(editor_fallback, "EditorIcons")
	_icon_rect.texture = texture
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	for button in _buttons:
		button.set_scheme(scheme)
	_apply()

func add_action(button_variant: String, label: String, callback: Callable, icon_name: String = "", editor_fallback: String = "") -> CopilotMd3Button:
	_ensure_built()
	var button := CopilotMd3Button.new()
	button.configure(_scheme, button_variant, label, icon_name, editor_fallback)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	_actions_box.add_child(button)
	_buttons.append(button)
	return button

func clear_actions() -> void:
	_ensure_built()
	for button in _buttons:
		button.queue_free()
	_buttons.clear()

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_ensure_built()
	_apply()

func _ensure_built() -> void:
	if _icon_rect != null:
		return
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", CopilotMd3Tokens.spacing("m"))

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_icon_rect)

	_title_label = Label.new()
	CopilotMd3Tokens.apply_text(_title_label, "headline-small")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title_label)

	_hint_label = Label.new()
	CopilotMd3Tokens.apply_text(_hint_label, "body-medium")
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint_label)

	_actions_box = VBoxContainer.new()
	_actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions_box.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	add_child(_actions_box)

func _apply() -> void:
	if _scheme == null or _icon_rect == null:
		return
	add_theme_constant_override("separation", CopilotMd3Tokens.spacing("m"))
	_icon_rect.modulate = _scheme.color("primary")
	_title_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	_hint_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	if not is_connected("resized", _on_resized):
		resized.connect(_on_resized)

func _on_resized() -> void:
	# Keep the hint readable in narrow docks: cap the text column width.
	var cap := 320.0
	_title_label.custom_minimum_size.x = 0.0
	_hint_label.custom_minimum_size.x = 0.0
	if size.x > cap:
		_title_label.custom_minimum_size.x = cap
		_hint_label.custom_minimum_size.x = cap
		_title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_hint_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		_title_label.size_flags_horizontal = Control.SIZE_FILL
		_hint_label.size_flags_horizontal = Control.SIZE_FILL

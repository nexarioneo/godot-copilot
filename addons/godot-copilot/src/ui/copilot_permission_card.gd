@tool
class_name CopilotPermissionCard
extends CopilotMd3Card
# Inline permission card above the composer (DESIGN.md section 7): tertiary
# shield badge, action/target lines, location chip, single-select scope chips,
# a remember checkbox and Deny / Always allow / Allow actions. The card appears
# only while the agent waits for a decision.

signal resolved(request_id: String, allowed: bool, remember: bool, scope_index: int)

const BADGE_SIZE := 28
const BADGE_ICON := 16

var _scheme: CopilotMd3Scheme = null

var _badge: PanelContainer = null
var _badge_icon: TextureRect = null
var _title_label: Label = null
var _action_label: Label = null
var _target_label: Label = null
var _location_chip: CopilotMd3Chip = null
var _scope_box: HFlowContainer = null
var _remember: CopilotMd3Checkbox = null
var _deny_button: CopilotMd3Button = null
var _always_button: CopilotMd3Button = null
var _allow_button: CopilotMd3Button = null

var _scope_chips: Array[CopilotMd3Chip] = []
var _request: Dictionary = {}
var _scope_index := 0
var _tween: Tween = null

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	super.set_scheme(scheme)
	_apply()

func show_request(request: Dictionary) -> void:
	_request = request
	_title_label.text = "Permission required"
	_action_label.text = str(request.get("action", ""))
	_target_label.text = str(request.get("target", ""))
	var outside := bool(request.get("outside", false))
	_location_chip.text = "Outside project" if outside else "In project"
	if outside:
		_location_chip.set_tone("error-container", "on-error-container")
	else:
		_location_chip.set_tone("secondary-container", "on-secondary-container")
	_build_scope_chips(request.get("scope_options", []))
	_remember.button_pressed = false
	_scope_index = 0
	visible = true
	call_deferred("_animate_in")

func hide_card() -> void:
	if not visible:
		_request = {}
		return
	_request = {}
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_property(self, "scale", Vector2(0.98, 0.98), 0.12)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		scale = Vector2.ONE
		modulate.a = 1.0
	)

func _ready() -> void:
	visible = false
	_build_ui()
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	super.configure(_scheme, VARIANT_ELEVATED, "medium")
	_apply()
	resized.connect(func() -> void: pivot_offset = size * 0.5)

func _build_ui() -> void:
	if _title_label != null:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	box.add_child(header)

	_badge = PanelContainer.new()
	_badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_badge)
	_badge_icon = TextureRect.new()
	_badge_icon.custom_minimum_size = Vector2(BADGE_ICON, BADGE_ICON)
	_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge_icon.texture = CopilotMd3Icons.symbol("shield")
	_badge.add_child(_badge_icon)

	_title_label = Label.new()
	CopilotMd3Tokens.apply_text(_title_label, "title-medium")
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_location_chip = CopilotMd3Chip.new()
	_location_chip.configure(_scheme, CopilotMd3Chip.VARIANT_ASSIST, "In project")
	_location_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_location_chip)

	_action_label = Label.new()
	CopilotMd3Tokens.apply_text(_action_label, "label-large")
	_action_label.clip_text = true
	box.add_child(_action_label)

	_target_label = Label.new()
	CopilotMd3Tokens.apply_text(_target_label, "body-small")
	_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_label.selection_enabled = true
	box.add_child(_target_label)

	_scope_box = HFlowContainer.new()
	_scope_box.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("xs"))
	_scope_box.add_theme_constant_override("v_separation", CopilotMd3Tokens.spacing("xs"))
	box.add_child(_scope_box)

	_remember = CopilotMd3Checkbox.new()
	_remember.configure(_scheme, "Remember for this session")
	_remember.tooltip_text = "Keep the selected scope allowed for the rest of this session"
	box.add_child(_remember)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	box.add_child(buttons)

	_deny_button = CopilotMd3Button.new()
	_deny_button.configure(_scheme, CopilotMd3Button.VARIANT_TEXT, "Deny")
	_deny_button.tooltip_text = "Deny this action"
	_deny_button.pressed.connect(_on_deny_pressed)
	buttons.add_child(_deny_button)

	_always_button = CopilotMd3Button.new()
	_always_button.configure(_scheme, CopilotMd3Button.VARIANT_TONAL, "Always allow")
	_always_button.tooltip_text = "Allow and save a permanent rule to settings.json"
	_always_button.pressed.connect(_on_always_pressed)
	buttons.add_child(_always_button)

	_allow_button = CopilotMd3Button.new()
	_allow_button.configure(_scheme, CopilotMd3Button.VARIANT_FILLED, "Allow once")
	_allow_button.tooltip_text = "Run this action now"
	_allow_button.pressed.connect(_on_allow_pressed)
	buttons.add_child(_allow_button)

func _apply() -> void:
	if _scheme == null or _title_label == null:
		return
	var badge_box := _scheme.box("tertiary-container", CopilotMd3Tokens.corner_radius("full", Vector2(BADGE_SIZE, BADGE_SIZE)))
	badge_box.content_margin_left = 0
	badge_box.content_margin_right = 0
	badge_box.content_margin_top = 0
	badge_box.content_margin_bottom = 0
	_badge.add_theme_stylebox_override("panel", badge_box)
	_badge_icon.modulate = _scheme.color("on-tertiary-container")

	_title_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	_action_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	_target_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	var mono := CopilotMd3ToolRow.mono_font()
	if mono != null:
		_target_label.add_theme_font_override("font", mono)

	_location_chip.set_scheme(_scheme)
	_remember.set_scheme(_scheme)
	_remember.add_theme_font_override("font", CopilotMd3Tokens.font_for_weight(500))
	_remember.add_theme_font_size_override("font_size", CopilotMd3Tokens.type_size("label-medium"))
	_deny_button.set_scheme(_scheme)
	_always_button.set_scheme(_scheme)
	_allow_button.set_scheme(_scheme)
	for chip in _scope_chips:
		chip.set_scheme(_scheme)

func _build_scope_chips(options: Array) -> void:
	for chip in _scope_chips:
		_scope_box.remove_child(chip)
		chip.queue_free()
	_scope_chips.clear()
	_scope_box.visible = not options.is_empty()
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var full_label := str(option.get("label", "Option " + str(i + 1)))
		var short_label := full_label.split(":")[0]
		var chip := CopilotMd3Chip.new()
		chip.configure(_scheme, CopilotMd3Chip.VARIANT_FILTER, short_label)
		chip.tooltip_text = full_label + "\n" + str(option.get("description", ""))
		chip.set_selected(i == 0)
		chip.pressed.connect(_on_scope_pressed.bind(i))
		_scope_box.add_child(chip)
		_scope_chips.append(chip)

func _on_scope_pressed(index: int) -> void:
	_scope_index = index
	for i in range(_scope_chips.size()):
		_scope_chips[i].set_selected(i == index)

func _on_deny_pressed() -> void:
	if _request.is_empty():
		return
	resolved.emit(str(_request.get("id", "")), false, false, 0)
	hide_card()

func _on_always_pressed() -> void:
	if _request.is_empty():
		return
	resolved.emit(str(_request.get("id", "")), true, true, _scope_index)
	hide_card()

func _on_allow_pressed() -> void:
	if _request.is_empty():
		return
	var scope_index := _scope_index if _remember.button_pressed else -1
	resolved.emit(str(_request.get("id", "")), true, false, scope_index)
	hide_card()

func _animate_in() -> void:
	if not is_inside_tree() or not visible:
		return
	pivot_offset = size * 0.5
	if _tween != null:
		_tween.kill()
	scale = Vector2(0.96, 0.96)
	modulate.a = 0.0
	_tween = create_tween()
	_tween.set_parallel(true)
	CopilotMd3Motion.animate_spring(
		_tween, func(value: float) -> void: scale = Vector2(value, value),
		0.96, 1.0, CopilotMd3Motion.spring_duration_seconds("default-spatial"), "default-spatial"
	)
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)

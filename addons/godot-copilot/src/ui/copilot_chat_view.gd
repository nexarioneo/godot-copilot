@tool
class_name CopilotChatView
extends ScrollContainer
# Material 3 chat list: user bubbles (primary-container), assistant cards
# (surface-container-high), notice cards, tool rows, thinking row and an empty
# state. Dynamic content always goes through add_text() so model/user text is
# never evaluated as BBCode.

const MAX_ARG_DISPLAY := 60
const BUBBLE_MAX_WIDTH_RATIO := 0.85
const BUBBLE_MIN_WIDTH := 96
const PAD_H := 12
const SUBAGENT_SEPARATOR := " → "

signal pinned_changed(pinned: bool)
signal snackbar_requested(message: String)
signal empty_action_requested(provider_available: bool)
signal retry_requested()

var _scheme: CopilotMd3Scheme = null
var _margin: MarginContainer = null
var _content: VBoxContainer = null
var _empty_state: CopilotMd3EmptyState = null
var _thinking_row: HBoxContainer = null
var _thinking_label: Label = null

var _current_assistant: Dictionary = {}
var _running_rows: Dictionary = {}
var _user_bubbles: Array = []
var _pinned_to_bottom := true
var _provider_available := false
var _message_count := 0

func configure(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_ensure_built()
	_apply()
	get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	resized.connect(_reflow_user_bubbles)

# --- Message API ---

func add_user_message(text: String) -> void:
	_make_user_bubble(text)
	_message_count += 1
	_update_empty_state()
	_scroll_to_bottom_if_pinned()

func add_assistant_message(text: String) -> void:
	_make_assistant_card(text)
	_message_count += 1
	_update_empty_state()
	_scroll_to_bottom_if_pinned()

func begin_assistant_message() -> void:
	if _current_assistant.is_empty():
		_current_assistant = _make_assistant_card("")
		_set_streaming(true)
		_message_count += 1
		_update_empty_state()

func append_assistant_delta(delta: String) -> void:
	if _current_assistant.is_empty():
		begin_assistant_message()
	var content: RichTextLabel = _current_assistant["content"]
	content.add_text(delta)
	_scroll_to_bottom_if_pinned()

func complete_assistant_message(text: String) -> void:
	# Rewrite from the final text so missing/extra deltas cannot corrupt the display.
	if _current_assistant.is_empty():
		_make_assistant_card(text)
		_message_count += 1
	else:
		var content: RichTextLabel = _current_assistant["content"]
		content.clear()
		content.add_text(text)
		_set_streaming(false)
		_current_assistant = {}
	_update_empty_state()
	_scroll_to_bottom_if_pinned()

func add_tool_row(tool_name: String, args: Dictionary) -> void:
	var agent_name := ""
	var base_name := tool_name
	var arrow := tool_name.find(SUBAGENT_SEPARATOR)
	if arrow >= 0:
		agent_name = tool_name.substr(0, arrow)
		base_name = tool_name.substr(arrow + SUBAGENT_SEPARATOR.length())
	var row := CopilotMd3ToolRow.new()
	row.configure(_scheme, base_name, summarize_args(args), agent_name)
	_add_indented_tool_row(row)
	if not _running_rows.has(tool_name):
		_running_rows[tool_name] = []
	_running_rows[tool_name].append({"row": row, "started_ms": Time.get_ticks_msec()})
	_message_count += 1
	_update_empty_state()
	_content.move_child(_thinking_row, -1)
	_scroll_to_bottom_if_pinned()

func finish_tool_row(tool_name: String, result: Dictionary) -> void:
	var entries: Array = _running_rows.get(tool_name, [])
	if entries.is_empty():
		return
	var entry: Dictionary = entries.pop_front()
	var row: CopilotMd3ToolRow = entry["row"]
	var success := bool(result.get("success", false))
	var output := str(result.get("output", result.get("content", "")))
	var error_text := str(result.get("error", ""))
	row.set_finished(success, output, error_text)
	row.set_elapsed(int(Time.get_ticks_msec() - int(entry["started_ms"])))
	_scroll_to_bottom_if_pinned()

func add_notice(text: String, severity: String = "info") -> void:
	_make_notice(text, severity)
	_message_count += 1
	_update_empty_state()
	_scroll_to_bottom_if_pinned()

func set_thinking(active: bool, label: String = "Thinking...") -> void:
	_thinking_label.text = label
	_thinking_row.visible = active
	if active:
		_content.move_child(_thinking_row, -1)
		_scroll_to_bottom_if_pinned()

func set_provider_available(available: bool) -> void:
	if _provider_available == available:
		return
	_provider_available = available
	_update_empty_state()

func clear() -> void:
	_stop_caret_tween()
	for child in _content.get_children():
		child.queue_free()
	_current_assistant = {}
	_running_rows.clear()
	_user_bubbles.clear()
	_message_count = 0
	_pinned_to_bottom = true
	_rebuild_control_refs()
	_update_empty_state()

func rebuild_from_trajectory(trajectory: Array) -> void:
	clear()
	for step in trajectory:
		if not (step is Dictionary):
			continue
		match str(step.get("role", "")):
			"user":
				add_user_message(str(step.get("display", step.get("content", ""))))
			"assistant":
				var content := str(step.get("content", ""))
				if not content.strip_edges().is_empty():
					add_assistant_message(content)
			"tool":
				add_tool_row(str(step.get("name", "tool")), {})
				var result = step.get("result_raw", {})
				finish_tool_row(str(step.get("name", "tool")), result if result is Dictionary else {})
	_pinned_to_bottom = true
	_scroll_to_bottom()

func scroll_to_bottom() -> void:
	_pinned_to_bottom = true
	pinned_changed.emit(true)
	call_deferred("_scroll_to_bottom")

func is_pinned() -> bool:
	return _pinned_to_bottom

func summarize_args(args: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in ["path", "command", "url", "pattern", "query", "tool", "server", "node_path", "type", "agent_name"]:
		if not args.has(key):
			continue
		var value := str(args[key]).replace("\n", " ")
		parts.append(value)
		if parts.size() >= 2:
			break
	if parts.is_empty():
		for key in args.keys():
			parts.append(str(key) + "=" + str(args[key]).replace("\n", " "))
			break
	var summary := ", ".join(parts)
	if summary.length() > MAX_ARG_DISPLAY:
		summary = summary.substr(0, MAX_ARG_DISPLAY) + "…"
	return summary

# --- Building ---

func _ensure_built() -> void:
	if _content != null:
		return
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.add_theme_constant_override("margin_left", 12)
	_margin.add_theme_constant_override("margin_right", 12)
	_margin.add_theme_constant_override("margin_top", 8)
	_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(_margin)
	_content = VBoxContainer.new()
	_content.name = "chat_content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_margin.add_child(_content)
	_build_dynamic_controls()

func _build_dynamic_controls() -> void:
	_empty_state = CopilotMd3EmptyState.new()
	_empty_state.name = "empty_state"
	_content.add_child(_empty_state)

	_thinking_row = HBoxContainer.new()
	_thinking_row.name = "thinking_row"
	_thinking_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	_thinking_row.visible = false
	var spinner := CopilotMd3Spinner.new()
	spinner.configure(_scheme, "primary", 24)
	spinner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_thinking_row.add_child(spinner)
	_thinking_label = Label.new()
	CopilotMd3Tokens.apply_text(_thinking_label, "label-large")
	_thinking_label.text = "Thinking..."
	_thinking_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_thinking_row.add_child(_thinking_label)
	_content.add_child(_thinking_row)

func _rebuild_control_refs() -> void:
	# clear() frees every child; rebuild the persistent controls.
	_build_dynamic_controls()
	_apply()

func _apply() -> void:
	if _scheme == null or _content == null:
		return
	_content.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	if _empty_state != null:
		_empty_state.configure(
			_scheme,
			"Start a conversation",
			"Connect a provider and ask Copilot to work on your project.",
			"auto_awesome",
			""
		)
		_update_empty_state()
	if _thinking_label != null:
		_thinking_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))

func _update_empty_state() -> void:
	if _empty_state == null:
		return
	_empty_state.visible = _message_count == 0
	if not _empty_state.visible:
		return
	_empty_state.clear_actions()
	var label := "New session" if _provider_available else "Open provider manager"
	_empty_state.add_action(
		CopilotMd3Button.VARIANT_FILLED,
		label,
		func() -> void: empty_action_requested.emit(_provider_available)
	)

func _make_user_bubble(text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_content.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var bubble := PanelContainer.new()
	var bubble_box := _scheme.box("primary-container", 16)
	bubble_box.corner_radius_bottom_right = 4
	bubble_box.content_margin_left = PAD_H
	bubble_box.content_margin_right = PAD_H
	bubble_box.content_margin_top = CopilotMd3Tokens.spacing("s")
	bubble_box.content_margin_bottom = CopilotMd3Tokens.spacing("s")
	bubble.add_theme_stylebox_override("panel", bubble_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	row.add_child(column)
	column.add_child(bubble)

	var body := RichTextLabel.new()
	_style_body(body, "on-primary-container")
	body.add_text(text)
	bubble.add_child(body)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.visible = false
	column.add_child(actions)
	var copy_button := _make_action_button("content_copy", "Copy the message")
	copy_button.pressed.connect(_on_copy_pressed.bind(body))
	actions.add_child(copy_button)
	bubble.mouse_entered.connect(func() -> void: actions.visible = true)
	bubble.mouse_exited.connect(func() -> void: _schedule_hide_actions(bubble, actions))

	bubble.set_meta("message_text", text)
	_user_bubbles.append(bubble)
	_reflow_user_bubbles()

func _make_assistant_card(text: String) -> Dictionary:
	var card := PanelContainer.new()
	var card_box := _scheme.box("surface-container-high", 16)
	card_box.corner_radius_bottom_left = 4
	card_box.content_margin_left = PAD_H
	card_box.content_margin_right = PAD_H + 8
	card_box.content_margin_top = CopilotMd3Tokens.spacing("s")
	card_box.content_margin_bottom = CopilotMd3Tokens.spacing("s")
	card.add_theme_stylebox_override("panel", card_box)
	_content.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	card.add_child(box)

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	box.add_child(role_row)
	var role_icon := TextureRect.new()
	role_icon.custom_minimum_size = Vector2(16, 16)
	role_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	role_icon.texture = CopilotMd3Icons.symbol("auto_awesome")
	role_icon.modulate = _scheme.color("on-surface-variant")
	role_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	role_row.add_child(role_icon)
	var role_label := Label.new()
	CopilotMd3Tokens.apply_text(role_label, "label-medium")
	role_label.text = "Copilot"
	role_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	role_row.add_child(role_label)

	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	box.add_child(body_row)
	var content := RichTextLabel.new()
	_style_body(content, "on-surface")
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_child(content)
	var caret := ColorRect.new()
	caret.color = _scheme.color("primary")
	caret.custom_minimum_size = Vector2(2, 14)
	caret.size_flags_vertical = Control.SIZE_SHRINK_END
	caret.visible = false
	body_row.add_child(caret)
	if not text.is_empty():
		content.add_text(text)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.visible = false
	box.add_child(actions)
	var copy_button := _make_action_button("content_copy", "Copy the message")
	copy_button.pressed.connect(_on_copy_pressed.bind(content))
	actions.add_child(copy_button)
	var retry_button := _make_action_button("refresh", "Regenerate this reply")
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	actions.add_child(retry_button)

	card.mouse_entered.connect(func() -> void: actions.visible = true)
	card.mouse_exited.connect(func() -> void: _schedule_hide_actions(card, actions))

	_content.move_child(_thinking_row, -1)
	return {"panel": card, "content": content, "caret": caret, "actions": actions}

func _make_notice(text: String, severity: String) -> void:
	var panel := PanelContainer.new()
	var fill := "surface-container-low"
	var content_role := "on-surface-variant"
	var icon_color_role := "status-info"
	var icon_name := "info"
	if severity == "warning":
		icon_color_role = "status-warning"
		content_role = "on-surface"
		icon_name = "warning"
	elif severity == "error":
		fill = "error-container"
		content_role = "on-error-container"
		icon_color_role = "error"
		icon_name = "error"
	var box := _scheme.box(fill, CopilotMd3Tokens.corner_radius("medium", Vector2(0, 32)))
	box.content_margin_left = PAD_H
	box.content_margin_right = PAD_H
	box.content_margin_top = CopilotMd3Tokens.spacing("s")
	box.content_margin_bottom = CopilotMd3Tokens.spacing("s")
	panel.add_theme_stylebox_override("panel", box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	panel.add_child(row)
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = CopilotMd3Icons.symbol(icon_name)
	icon_rect.modulate = _scheme.color(icon_color_role)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_rect)
	var label := RichTextLabel.new()
	label.bbcode_enabled = false
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("normal_font", CopilotMd3Tokens.font_for_weight(CopilotMd3Tokens.type_weight("body-small")))
	label.add_theme_font_size_override("normal_font_size", CopilotMd3Tokens.type_size("body-small"))
	label.add_theme_color_override("default_color", _scheme.color(content_role))
	label.add_text(text)
	row.add_child(label)

	_content.add_child(panel)
	_content.move_child(_thinking_row, -1)

func _make_action_button(symbol_name: String, tooltip: String) -> CopilotMd3IconButton:
	var button := CopilotMd3IconButton.new()
	button.configure(_scheme, CopilotMd3Button.VARIANT_STANDARD, "", symbol_name, "")
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(28, 28)
	button.add_theme_constant_override("icon_max_width", 16)
	return button

func _add_indented_tool_row(row: Control) -> void:
	# Tool rows are left-indented 8px (DESIGN.md section 6.1).
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", CopilotMd3Tokens.spacing("s"))
	_content.add_child(indent)
	indent.add_child(row)

func _on_copy_pressed(content: RichTextLabel) -> void:
	DisplayServer.clipboard_set(content.get_parsed_text())
	snackbar_requested.emit("Copied to clipboard")

func _schedule_hide_actions(card: Control, actions: Control) -> void:
	call_deferred("_hide_actions_if_outside", card, actions)

func _hide_actions_if_outside(card: Control, actions: Control) -> void:
	if not is_instance_valid(card) or not is_instance_valid(actions):
		return
	if not card.get_global_rect().has_point(get_global_mouse_position()):
		actions.visible = false

func _style_body(body: RichTextLabel, color_role: String) -> void:
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.selection_enabled = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("normal_font", CopilotMd3Tokens.font_for_weight(CopilotMd3Tokens.type_weight("body-medium")))
	body.add_theme_font_size_override("normal_font_size", CopilotMd3Tokens.type_size("body-medium"))
	body.add_theme_color_override("default_color", _scheme.color(color_role))
	body.add_theme_color_override("selection_color", _scheme.alpha("primary", 0.30))

func _set_streaming(streaming: bool) -> void:
	if _current_assistant.is_empty():
		return
	var caret: ColorRect = _current_assistant.get("caret")
	if caret == null:
		return
	if not streaming:
		_stop_caret_tween()
		caret.visible = false
		return
	caret.visible = true
	caret.modulate.a = 1.0
	var tween := create_tween().set_loops()
	tween.tween_property(caret, "modulate:a", 0.15, 0.4).from(1.0)
	tween.tween_property(caret, "modulate:a", 1.0, 0.4)
	caret.set_meta("tween", tween)

func _stop_caret_tween() -> void:
	var caret = _current_assistant.get("caret")
	if not is_instance_valid(caret):
		return
	if caret is ColorRect and caret.has_meta("tween"):
		var tween: Tween = caret.get_meta("tween")
		tween.kill()
		caret.remove_meta("tween")

# --- Layout ---

func _reflow_user_bubbles() -> void:
	if _content == null:
		return
	var available := _content.size.x
	if available <= 0.0:
		return
	var cap := maxf(float(BUBBLE_MIN_WIDTH), available * BUBBLE_MAX_WIDTH_RATIO)
	for bubble in _user_bubbles:
		if not is_instance_valid(bubble):
			continue
		var text := str(bubble.get_meta("message_text", ""))
		var measured := _measure_text_width(text) + PAD_H * 2
		bubble.custom_minimum_size.x = minf(measured, cap)

func _measure_text_width(text: String) -> float:
	var font := CopilotMd3Tokens.font_for_weight(CopilotMd3Tokens.type_weight("body-medium"))
	if font == null:
		return 0.0
	var font_size := CopilotMd3Tokens.type_size("body-medium")
	var width := 0.0
	for line in text.split("\n"):
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	return width

# --- Auto-scroll ---

func _on_scroll_changed(_value: float) -> void:
	var bar := get_v_scroll_bar()
	var pinned := bar.value >= bar.max_value - bar.page - 24.0
	if pinned != _pinned_to_bottom:
		_pinned_to_bottom = pinned
		pinned_changed.emit(pinned)

func _scroll_to_bottom_if_pinned() -> void:
	if not _pinned_to_bottom or not is_inside_tree():
		return
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	var bar := get_v_scroll_bar()
	bar.value = bar.max_value

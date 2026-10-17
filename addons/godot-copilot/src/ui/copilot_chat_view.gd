@tool
class_name CopilotChatView
extends ScrollContainer
# List of message cards + tool rows. Dynamic content always goes through add_text()
# so model/user text is never evaluated as BBCode.

const ROLE_USER := "You"
const ROLE_ASSISTANT := "Copilot"
const MAX_ARG_DISPLAY := 60

var _content: VBoxContainer
var _current_assistant_card: Dictionary = {}
var _running_tool_rows: Dictionary = {}
var _pinned_to_bottom := true

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content = VBoxContainer.new()
	_content.name = "chat_content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)
	get_v_scroll_bar().value_changed.connect(_on_scroll_changed)

# --- Message API ---

func add_user_message(text: String) -> void:
	_make_card(ROLE_USER, CopilotTheme.accent_color(self), text)
	_scroll_to_bottom_if_pinned()

func add_assistant_message(text: String) -> void:
	_make_card(ROLE_ASSISTANT, CopilotTheme.font_color(self), text)
	_scroll_to_bottom_if_pinned()

func begin_assistant_message() -> void:
	if _current_assistant_card.is_empty():
		_current_assistant_card = _make_card(ROLE_ASSISTANT, CopilotTheme.font_color(self), "")

func append_assistant_delta(delta: String) -> void:
	if _current_assistant_card.is_empty():
		begin_assistant_message()
	var content: RichTextLabel = _current_assistant_card["content"]
	content.add_text(delta)
	_scroll_to_bottom_if_pinned()

func complete_assistant_message(text: String) -> void:
	# Rewrite from the final text so missing/extra deltas cannot corrupt the display.
	if _current_assistant_card.is_empty():
		_make_card(ROLE_ASSISTANT, CopilotTheme.font_color(self), text)
		_current_assistant_card = {}
	else:
		var content: RichTextLabel = _current_assistant_card["content"]
		content.clear()
		content.add_text(text)
		_current_assistant_card = {}
	_scroll_to_bottom_if_pinned()

func add_tool_row(tool_name: String, args: Dictionary) -> void:
	var row := _make_tool_row(tool_name, args)
	if not _running_tool_rows.has(tool_name):
		_running_tool_rows[tool_name] = []
	_running_tool_rows[tool_name].append(row)
	_scroll_to_bottom_if_pinned()

func finish_tool_row(tool_name: String, result: Dictionary) -> void:
	var rows: Array = _running_tool_rows.get(tool_name, [])
	if rows.is_empty():
		return
	var row: Dictionary = rows.pop_front()
	var status_label: Label = row["status"]
	var success := bool(result.get("success", false))
	status_label.text = "OK" if success else "Failed"
	status_label.add_theme_color_override("font_color", CopilotTheme.success_color(self) if success else CopilotTheme.error_color(self))
	var panel: PanelContainer = row["panel"]
	var tooltip := str(result.get("error", ""))
	if tooltip.is_empty():
		var output := str(result.get("output", result.get("content", "")))
		tooltip = output.substr(0, 400) if not output.is_empty() else "Completed"
	panel.tooltip_text = tooltip
	_scroll_to_bottom_if_pinned()

func add_notice(text: String) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.selection_enabled = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.push_italic()
	label.push_color(CopilotTheme.font_placeholder_color(self))
	label.add_text("• " + text)
	label.pop()
	label.pop()
	_content.add_child(label)
	_scroll_to_bottom_if_pinned()

func clear() -> void:
	for child in _content.get_children():
		child.queue_free()
	_current_assistant_card = {}
	_running_tool_rows.clear()
	_pinned_to_bottom = true

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

# --- Building widgets ---

func _make_card(role_label: String, role_color: Color, text: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CopilotTheme.card_style(self))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var header := Label.new()
	header.text = role_label
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", role_color)
	box.add_child(header)

	var content := RichTextLabel.new()
	content.bbcode_enabled = true
	content.fit_content = true
	content.scroll_active = false
	content.selection_enabled = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(content)
	if not text.is_empty():
		content.add_text(text)

	_content.add_child(panel)
	return {"panel": panel, "content": content}

func _make_tool_row(tool_name: String, args: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CopilotTheme.card_style(self))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var status := Label.new()
	status.text = "…"
	status.add_theme_color_override("font_color", CopilotTheme.accent_color(self))
	row.add_child(status)

	var name_label := Label.new()
	name_label.text = tool_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", CopilotTheme.warning_color(self))
	row.add_child(name_label)

	var detail := Label.new()
	detail.text = _summarize_args(args)
	detail.add_theme_font_size_override("font_size", 11)
	detail.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(detail)

	panel.tooltip_text = _summarize_args(args)
	_content.add_child(panel)
	return {"panel": panel, "status": status}

func _summarize_args(args: Dictionary) -> String:
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

# --- Auto-scroll ---

func _on_scroll_changed(_value: float) -> void:
	var bar := get_v_scroll_bar()
	_pinned_to_bottom = bar.value >= bar.max_value - bar.page - 24.0

func _scroll_to_bottom_if_pinned() -> void:
	if not _pinned_to_bottom or not is_inside_tree():
		return
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	var bar := get_v_scroll_bar()
	bar.value = bar.max_value

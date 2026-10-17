@tool
class_name CopilotDock
extends VBoxContainer
# Chat panel in the right dock: session header, chat view, permission card, composer, status bar.
# Everything is wired to CopilotAgent signals; the dock never touches storage directly.

signal provider_manager_requested()
signal settings_requested()

var agent: CopilotAgent

var _session_option: OptionButton
var _chat_view: CopilotChatView
var _permission_card: CopilotPermissionCard
var _composer: TextEdit
var _send_button: Button
var _stop_button: Button
var _status_label: Label
var _model_label: Label

var _sessions: Array = []
var _updating_sessions := false

func _ready() -> void:
	_build_ui()

# --- Setup ---

func setup(p_agent: CopilotAgent) -> void:
	_build_ui()
	agent = p_agent
	agent.state_changed.connect(_on_state_changed)
	agent.user_message_added.connect(_on_user_message_added)
	agent.assistant_delta.connect(_on_assistant_delta)
	agent.assistant_message_added.connect(_on_assistant_message_added)
	agent.assistant_message_completed.connect(_on_assistant_message_completed)
	agent.tool_started.connect(_on_tool_started)
	agent.tool_finished.connect(_on_tool_finished)
	agent.permission_requested.connect(_on_permission_requested)
	agent.permission_resolved.connect(_on_permission_resolved)
	agent.notice.connect(_on_notice)
	agent.session_changed.connect(_on_session_changed)
	agent.turn_finished.connect(_on_turn_finished)
	agent.memory_compacted.connect(_on_memory_compacted)
	_permission_card.resolved.connect(_on_permission_card_resolved)
	_update_status(agent.state())
	_update_buttons()
	_update_model_label()
	_refresh_sessions()

func focus_composer() -> void:
	if _composer != null:
		_composer.grab_focus()

func refresh() -> void:
	# Called by the plugin after the provider/settings dialog closes or the config changes.
	_update_status(agent.state() if agent != null else "idle")
	_update_buttons()
	_update_model_label()
	_refresh_sessions()

# --- Build UI ---

func _build_ui() -> void:
	if _chat_view != null:
		return
	add_theme_constant_override("separation", 4)
	_build_header()
	_chat_view = CopilotChatView.new()
	_chat_view.name = "chat_view"
	add_child(_chat_view)
	_permission_card = CopilotPermissionCard.new()
	_permission_card.name = "permission_card"
	add_child(_permission_card)
	_build_composer()
	_build_status_bar()

func _build_header() -> void:
	var header := HBoxContainer.new()
	header.name = "header_row"
	header.add_theme_constant_override("separation", 4)
	add_child(header)

	_session_option = OptionButton.new()
	_session_option.name = "session_option"
	_session_option.tooltip_text = "Choose a chat session"
	_session_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_session_option.clip_text = true
	_session_option.item_selected.connect(_on_session_selected)
	header.add_child(_session_option)

	var new_session_button := _icon_button(PackedStringArray(["Add"]), "+", "New session")
	new_session_button.pressed.connect(_on_new_session_pressed)
	header.add_child(new_session_button)

	var delete_session_button := _icon_button(PackedStringArray(["Remove"]), "✕", "Delete active session")
	delete_session_button.pressed.connect(_on_delete_session_pressed)
	header.add_child(delete_session_button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	header.add_child(spacer)

	var provider_button := _icon_button(PackedStringArray(["CryptoKey", "Key"]), "Key", "Provider Manager (manage API providers and models)")
	provider_button.pressed.connect(func() -> void: provider_manager_requested.emit())
	header.add_child(provider_button)

	var settings_button := _icon_button(PackedStringArray(["Tools"]), "Config", "Settings (permissions, memory, agent)")
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	header.add_child(settings_button)

	var clear_button := _icon_button(PackedStringArray(["Clear", "Eraser"]), "⌫", "Clear the chat view")
	clear_button.pressed.connect(func() -> void: _chat_view.clear())
	header.add_child(clear_button)

func _build_composer() -> void:
	var composer_box := VBoxContainer.new()
	composer_box.name = "composer_box"
	composer_box.add_theme_constant_override("separation", 4)
	add_child(composer_box)

	_composer = TextEdit.new()
	_composer.name = "composer"
	_composer.placeholder_text = "Type a message… (Enter to send, Shift+Enter for a new line)"
	_composer.custom_minimum_size = Vector2(0, 64)
	_composer.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_composer.gui_input.connect(_on_composer_gui_input)
	composer_box.add_child(_composer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 6)
	composer_box.add_child(buttons)

	_stop_button = Button.new()
	_stop_button.name = "stop_button"
	_stop_button.text = "Stop"
	_stop_button.tooltip_text = "Stop the running request"
	_stop_button.disabled = true
	_stop_button.pressed.connect(_on_stop_pressed)
	buttons.add_child(_stop_button)

	_send_button = Button.new()
	_send_button.name = "send_button"
	_send_button.text = "Send"
	_send_button.tooltip_text = "Send the message to Copilot"
	_send_button.pressed.connect(_on_send_pressed)
	buttons.add_child(_send_button)

func _build_status_bar() -> void:
	var status_bar := HBoxContainer.new()
	status_bar.name = "status_bar"
	status_bar.add_theme_constant_override("separation", 6)
	add_child(status_bar)

	_status_label = Label.new()
	_status_label.name = "status_label"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	status_bar.add_child(_status_label)

	_model_label = Label.new()
	_model_label.name = "model_label"
	_model_label.add_theme_font_size_override("font_size", 11)
	_model_label.add_theme_color_override("font_color", CopilotTheme.font_placeholder_color(self))
	_model_label.clip_text = true
	status_bar.add_child(_model_label)

func _icon_button(names: PackedStringArray, fallback: String, tooltip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	CopilotTheme.apply_icon(button, names, fallback)
	return button

# --- Sessions ---

func _refresh_sessions() -> void:
	if agent == null or _session_option == null:
		return
	_sessions = agent.list_sessions()
	var current_id := agent.current_session_id()
	_updating_sessions = true
	_session_option.clear()
	var selected_index := -1
	for i in range(_sessions.size()):
		var session: Dictionary = _sessions[i]
		_session_option.add_item(str(session.get("title", "Untitled")) + "  (" + str(session.get("step_count", 0)) + " steps)")
		_session_option.set_item_metadata(i, str(session.get("id", "")))
		if str(session.get("id", "")) == current_id:
			selected_index = i
	if selected_index >= 0:
		_session_option.selected = selected_index
	elif _session_option.item_count > 0:
		_session_option.selected = 0
	_updating_sessions = false

func _on_session_selected(index: int) -> void:
	if _updating_sessions or agent == null:
		return
	var session_id := str(_session_option.get_item_metadata(index))
	if session_id.is_empty() or session_id == agent.current_session_id():
		return
	agent.load_session(session_id)

func _on_new_session_pressed() -> void:
	if agent != null:
		agent.new_session()

func _on_delete_session_pressed() -> void:
	if agent == null or agent.current_session_id().is_empty():
		_chat_view.add_notice("There is no active session to delete.")
		return
	var session_id := agent.current_session_id()
	var session_title := agent.current_session_title()
	var confirm := ConfirmationDialog.new()
	confirm.title = "Delete Session"
	confirm.dialog_text = "Delete session '" + session_title + "' and its entire history?"
	confirm.ok_button_text = "Delete"
	add_child(confirm)
	confirm.confirmed.connect(func() -> void:
		agent.delete_session(session_id)
		_chat_view.rebuild_from_trajectory(agent.trajectory())
		_refresh_sessions()
		confirm.queue_free()
	)
	confirm.canceled.connect(func() -> void: confirm.queue_free())
	confirm.popup_centered()

# --- Composer ---

func _on_composer_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not event.shift_pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_composer.accept_event()
			_on_send_pressed()

func _on_send_pressed() -> void:
	if agent == null:
		return
	var text := _composer.text
	if text.strip_edges().is_empty():
		return
	agent.send_user_message(text)

func _on_stop_pressed() -> void:
	if agent != null:
		agent.cancel_turn()

# --- Agent signals ---

func _on_state_changed(state: String) -> void:
	_update_status(state)
	_update_buttons()

func _on_user_message_added(text: String) -> void:
	_chat_view.add_user_message(text)
	_composer.clear()
	_refresh_sessions()

func _on_assistant_delta(delta: String) -> void:
	_chat_view.append_assistant_delta(delta)

func _on_assistant_message_added(text: String) -> void:
	_chat_view.add_assistant_message(text)

func _on_assistant_message_completed(text: String) -> void:
	_chat_view.complete_assistant_message(text)

func _on_tool_started(tool_name: String, args: Dictionary) -> void:
	_chat_view.add_tool_row(tool_name, args)

func _on_tool_finished(tool_name: String, result: Dictionary) -> void:
	_chat_view.finish_tool_row(tool_name, result)

func _on_permission_requested(request: Dictionary) -> void:
	_permission_card.show_request(request)

func _on_permission_resolved(_resolution: Dictionary) -> void:
	_permission_card.hide_card()

func _on_permission_card_resolved(request_id: String, allowed: bool, remember: bool, scope_index: int) -> void:
	if agent != null:
		agent.resolve_permission(request_id, allowed, remember, scope_index)

func _on_notice(message: String) -> void:
	_chat_view.add_notice(message)

func _on_session_changed(_session_id: String, _title: String) -> void:
	_chat_view.rebuild_from_trajectory(agent.trajectory())
	_refresh_sessions()
	_update_model_label()

func _on_turn_finished() -> void:
	_update_status(agent.state())
	_update_buttons()
	_update_model_label()
	_refresh_sessions()
	if is_inside_tree() and is_visible_in_tree():
		_composer.grab_focus()

func _on_memory_compacted(_summary: String) -> void:
	_chat_view.add_notice("Conversation memory was compacted automatically.")

# --- Status ---

func _update_status(state: String) -> void:
	if _status_label == null:
		return
	_status_label.text = "● " + CopilotTheme.status_text(self, state)
	_status_label.add_theme_color_override("font_color", CopilotTheme.status_color(self, state))

func _update_buttons() -> void:
	if _send_button == null or agent == null:
		return
	var busy := agent.is_busy()
	_send_button.disabled = busy
	_stop_button.disabled = not busy

func _update_model_label() -> void:
	if _model_label != null and agent != null:
		_model_label.text = agent.active_model_label()

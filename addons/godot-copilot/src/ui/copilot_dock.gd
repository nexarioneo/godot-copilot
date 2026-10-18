@tool
class_name CopilotDock
extends VBoxContainer
# Material 3 chat panel in the right dock: header, chat view, permission card,
# composer, snackbar and status strip. Everything is wired to CopilotAgent
# signals; the dock never touches storage directly. See DESIGN.md section 5.

signal provider_manager_requested()
signal settings_requested()

const HEADER_HEIGHT := 48
const STATUS_HEIGHT := 28
const NARROW_WIDTH := 320
const SESSION_ITEM_BASE := 1000
const DELETE_ITEM_ID := 999999

var agent: CopilotAgent

var _scheme: CopilotMd3Scheme = null

var _surface: PanelContainer = null
var _title_label: Label = null
var _sessions_button: CopilotMd3IconButton = null
var _session_menu: CopilotMd3Menu = null
var _chat_view: CopilotChatView = null
var _permission_card: CopilotPermissionCard = null
var _jump_chip: CopilotMd3Chip = null
var _jump_row: HBoxContainer = null
var _snackbar: CopilotMd3Snackbar = null
var _composer: CopilotMd3Composer = null
var _state_dot: PanelContainer = null
var _state_dot_box: StyleBoxFlat = null
var _status_label: Label = null
var _model_label: Label = null

var _sessions: Array = []
var _header_buttons: Array[CopilotMd3IconButton] = []

func _ready() -> void:
	_build_ui()
	_sync_from_agent()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _surface != null:
		_scheme = CopilotMd3Scheme.for_node(self)
		_apply_scheme()

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
	_chat_view.snackbar_requested.connect(_on_snackbar_requested)
	_chat_view.empty_action_requested.connect(_on_empty_action_requested)
	_chat_view.pinned_changed.connect(_on_pinned_changed)
	_chat_view.retry_requested.connect(_on_retry_requested)
	_composer.submitted.connect(_on_composer_submitted)
	_composer.stop_requested.connect(_on_stop_pressed)
	_sync_from_agent()

func _sync_from_agent() -> void:
	if agent == null:
		return
	_update_status(agent.state())
	_update_buttons()
	_update_model_label()
	_update_provider_availability()
	_refresh_sessions()

func focus_composer() -> void:
	if _composer != null:
		_composer.focus_input()

func refresh() -> void:
	# Called by the plugin after a dialog closes or the config changes.
	_update_status(agent.state() if agent != null else "idle")
	_update_buttons()
	_update_model_label()
	_update_provider_availability()
	_refresh_sessions()

# --- Build UI ---

func _build_ui() -> void:
	if _surface != null:
		return
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_surface = PanelContainer.new()
	_surface.name = "dock_surface"
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_surface)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_surface.add_child(column)

	_build_header(column)
	_build_chat_area(column)
	_build_bottom_area(column)
	_build_status_strip(column)
	_apply_scheme()

func _build_header(parent: Control) -> void:
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", CopilotMd3Tokens.spacing("s"))
	header_margin.add_theme_constant_override("margin_right", CopilotMd3Tokens.spacing("s"))
	header_margin.add_theme_constant_override("margin_top", CopilotMd3Tokens.spacing("xs"))
	header_margin.add_theme_constant_override("margin_bottom", CopilotMd3Tokens.spacing("xs"))
	parent.add_child(header_margin)
	var header := HBoxContainer.new()
	header.name = "header_row"
	header.custom_minimum_size.y = HEADER_HEIGHT - CopilotMd3Tokens.spacing("s")
	header.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	header_margin.add_child(header)

	_title_label = Label.new()
	_title_label.name = "header_title"
	CopilotMd3Tokens.apply_text(_title_label, "title-small")
	_title_label.text = "Copilot"
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_sessions_button = _header_button(header, "history", "Show all sessions", _on_sessions_pressed)
	_header_button(header, "add", "New session", _on_new_session_pressed)
	_header_button(header, "settings", "Settings (permissions, memory, agent)", func() -> void: settings_requested.emit())
	_header_button(header, "key", "Provider Manager (manage API providers and models)", func() -> void: provider_manager_requested.emit())
	_header_button(header, "delete_sweep", "Clear the chat view", _on_clear_pressed)

	_session_menu = CopilotMd3Menu.new()
	_session_menu.name = "session_menu"
	_session_menu.configure(_scheme)
	_session_menu.item_selected.connect(_on_session_menu_selected)
	add_child(_session_menu)

	resized.connect(_on_dock_resized)

func _build_chat_area(parent: Control) -> void:
	_chat_view = CopilotChatView.new()
	_chat_view.name = "chat_view"
	parent.add_child(_chat_view)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", CopilotMd3Tokens.spacing("m"))
	card_margin.add_theme_constant_override("margin_right", CopilotMd3Tokens.spacing("m"))
	card_margin.add_theme_constant_override("margin_top", CopilotMd3Tokens.spacing("xs"))
	parent.add_child(card_margin)
	_permission_card = CopilotPermissionCard.new()
	_permission_card.name = "permission_card"
	card_margin.add_child(_permission_card)

func _build_bottom_area(parent: Control) -> void:
	var jump_margin := MarginContainer.new()
	jump_margin.add_theme_constant_override("margin_right", CopilotMd3Tokens.spacing("m"))
	jump_margin.add_theme_constant_override("margin_top", CopilotMd3Tokens.spacing("xs"))
	parent.add_child(jump_margin)
	_jump_row = HBoxContainer.new()
	_jump_row.alignment = BoxContainer.ALIGNMENT_END
	jump_margin.add_child(_jump_row)
	_jump_chip = CopilotMd3Chip.new()
	_jump_chip.name = "jump_to_latest"
	_jump_chip.configure(_scheme, CopilotMd3Chip.VARIANT_ASSIST, "Jump to latest", "arrow_downward")
	_jump_chip.set_tone("secondary-container", "on-secondary-container")
	_jump_chip.tooltip_text = "Scroll back to the newest message"
	_jump_chip.visible = false
	_jump_chip.pressed.connect(_on_jump_pressed)
	_jump_row.add_child(_jump_chip)

	_snackbar = CopilotMd3Snackbar.new()
	_snackbar.name = "snackbar"
	var snackbar_margin := MarginContainer.new()
	snackbar_margin.add_theme_constant_override("margin_left", CopilotMd3Tokens.spacing("m"))
	snackbar_margin.add_theme_constant_override("margin_right", CopilotMd3Tokens.spacing("m"))
	parent.add_child(snackbar_margin)
	snackbar_margin.add_child(_snackbar)

	var composer_margin := MarginContainer.new()
	composer_margin.add_theme_constant_override("margin_left", CopilotMd3Tokens.spacing("m"))
	composer_margin.add_theme_constant_override("margin_right", CopilotMd3Tokens.spacing("m"))
	composer_margin.add_theme_constant_override("margin_bottom", CopilotMd3Tokens.spacing("s"))
	parent.add_child(composer_margin)
	_composer = CopilotMd3Composer.new()
	_composer.name = "composer"
	composer_margin.add_child(_composer)

func _build_status_strip(parent: Control) -> void:
	var divider := CopilotMd3Divider.new()
	divider.name = "status_divider"
	divider.configure(_scheme)
	parent.add_child(divider)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", CopilotMd3Tokens.spacing("m"))
	status_margin.add_theme_constant_override("margin_right", CopilotMd3Tokens.spacing("m"))
	parent.add_child(status_margin)
	var strip := HBoxContainer.new()
	strip.name = "status_strip"
	strip.custom_minimum_size.y = STATUS_HEIGHT
	strip.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	status_margin.add_child(strip)

	_state_dot = PanelContainer.new()
	_state_dot.custom_minimum_size = Vector2(6, 6)
	_state_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_state_dot_box = StyleBoxFlat.new()
	_state_dot_box.set_corner_radius_all(3)
	_state_dot_box.bg_color = Color(0.5, 0.5, 0.5)
	_state_dot.add_theme_stylebox_override("panel", _state_dot_box)
	strip.add_child(_state_dot)

	_status_label = Label.new()
	_status_label.name = "status_label"
	CopilotMd3Tokens.apply_text(_status_label, "label-small")
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip.add_child(_status_label)

	_model_label = Label.new()
	_model_label.name = "model_label"
	CopilotMd3Tokens.apply_text(_model_label, "label-small")
	_model_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The model label expands into the leftover space and ellipsizes first when
	# the dock is narrow; the state label keeps its full text.
	_model_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_model_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_model_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(_model_label)

func _header_button(parent: Control, symbol_name: String, tooltip: String, action: Callable) -> CopilotMd3IconButton:
	var button := CopilotMd3IconButton.new()
	button.configure(_scheme, CopilotMd3IconButton.VARIANT_STANDARD, "", symbol_name, "")
	button.tooltip_text = tooltip
	button.pressed.connect(action)
	parent.add_child(button)
	_header_buttons.append(button)
	return button

# --- Scheme ---

func _apply_scheme() -> void:
	if _scheme == null or _surface == null:
		return
	var surface_box := _scheme.box("surface", 0)
	_surface.add_theme_stylebox_override("panel", surface_box)
	_title_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	_chat_view.set_scheme(_scheme)
	_permission_card.set_scheme(_scheme)
	_composer.set_scheme(_scheme)
	_snackbar.set_scheme(_scheme)
	_jump_chip.set_scheme(_scheme)
	_jump_chip.set_tone("secondary-container", "on-secondary-container")
	_status_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	_model_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	for button in _header_buttons:
		button.set_scheme(_scheme)
	if _session_menu != null:
		_session_menu.set_scheme(_scheme)
	_update_status(agent.state() if agent != null else "idle")

# --- Sessions ---

func _on_dock_resized() -> void:
	if _title_label != null:
		_title_label.visible = size.x >= NARROW_WIDTH

func _on_sessions_pressed() -> void:
	_refresh_sessions()
	_session_menu.popup_on(_sessions_button)

func _refresh_sessions() -> void:
	if agent == null or _session_menu == null:
		return
	_sessions = agent.list_sessions()
	var current_id := agent.current_session_id()
	_session_menu.clear_items()
	var checked_id := -1
	for i in range(_sessions.size()):
		var session: Dictionary = _sessions[i]
		var title := str(session.get("title", "Untitled"))
		var steps := int(session.get("step_count", 0))
		var item_id := _session_menu.add_item(title + "  (" + str(steps) + " steps)", SESSION_ITEM_BASE + i)
		if str(session.get("id", "")) == current_id:
			checked_id = item_id
	if _sessions.is_empty():
		_session_menu.add_item("No sessions yet", SESSION_ITEM_BASE)
	if not current_id.is_empty():
		_session_menu.add_separator()
		_session_menu.add_item("Delete current session", DELETE_ITEM_ID, "", "", true)
	if checked_id >= 0:
		_session_menu.set_checked_id(checked_id)

func _on_session_menu_selected(id: int) -> void:
	if agent == null:
		return
	if id == DELETE_ITEM_ID:
		_on_delete_session_pressed()
		return
	if id < SESSION_ITEM_BASE:
		return
	var index := id - SESSION_ITEM_BASE
	if index < 0 or index >= _sessions.size():
		return
	var session_id := str(_sessions[index].get("id", ""))
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
	var confirm := CopilotMd3Confirm.new()
	add_child(confirm)
	confirm.configure(_scheme, "Delete Session", "Delete", "Cancel")
	confirm.set_message("Delete session '" + session_title + "' and its entire history?")
	confirm.set_danger(true)
	confirm.confirmed.connect(func() -> void:
		agent.delete_session(session_id)
		_chat_view.rebuild_from_trajectory(agent.trajectory())
		_refresh_sessions()
		_snackbar.show_message("Session deleted")
		confirm.queue_free()
	)
	confirm.canceled.connect(func() -> void: confirm.queue_free())
	confirm.popup_centered()

# --- Composer ---

func _on_composer_submitted(text: String) -> void:
	if agent == null:
		return
	agent.send_user_message(text)

func _on_stop_pressed() -> void:
	if agent != null:
		agent.cancel_turn()

func _on_clear_pressed() -> void:
	_chat_view.clear()
	_snackbar.show_message("Chat view cleared")

func _on_jump_pressed() -> void:
	_chat_view.scroll_to_bottom()

func _on_pinned_changed(pinned: bool) -> void:
	_update_jump_chip(pinned)

func _update_jump_chip(pinned: bool) -> void:
	var busy := agent != null and agent.is_busy()
	_jump_chip.visible = (not pinned) and busy

func _on_retry_requested() -> void:
	if agent == null:
		return
	if agent.is_busy():
		_snackbar.show_message("Wait for the current turn to finish")
		return
	if agent.retry_last_turn():
		_chat_view.rebuild_from_trajectory(agent.trajectory())
		_refresh_sessions()

# --- Agent signals ---

func _on_state_changed(state: String) -> void:
	_update_status(state)
	_update_buttons()
	_chat_view.set_thinking(
		state == CopilotAgent.STATE_THINKING or state == CopilotAgent.STATE_COMPACTING,
		"Compacting memory..." if state == CopilotAgent.STATE_COMPACTING else "Thinking..."
	)
	_update_jump_chip(_chat_view.is_pinned())

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
	_update_provider_availability()

func _on_turn_finished() -> void:
	_update_status(agent.state())
	_update_buttons()
	_update_model_label()
	_update_provider_availability()
	_refresh_sessions()
	if is_inside_tree() and is_visible_in_tree():
		_composer.focus_input()

func _on_memory_compacted(_summary: String) -> void:
	_chat_view.add_notice("Conversation memory was compacted automatically.")

func _on_snackbar_requested(message: String, action_label: String = "", action: Callable = Callable()) -> void:
	_snackbar.show_message(message, action_label, action)

func _on_empty_action_requested(provider_available: bool) -> void:
	if provider_available:
		if agent != null:
			agent.new_session()
	else:
		provider_manager_requested.emit()

# --- Status ---

func _update_status(state: String) -> void:
	if _status_label == null:
		return
	_status_label.text = state_text(state)
	if _state_dot_box != null and _scheme != null:
		_state_dot_box.bg_color = _scheme.color(state_role(state))

func _update_buttons() -> void:
	if _composer == null or agent == null:
		return
	_composer.set_busy(agent.is_busy())

func _update_model_label() -> void:
	if _model_label != null and agent != null:
		_model_label.text = agent.active_model_label()
		_model_label.tooltip_text = _model_label.text

func _update_provider_availability() -> void:
	if _chat_view != null and agent != null:
		_chat_view.set_provider_available(not agent.active_model_label().is_empty())

static func state_text(state: String) -> String:
	match state:
		CopilotAgent.STATE_IDLE:
			return "Ready"
		CopilotAgent.STATE_THINKING:
			return "Thinking..."
		CopilotAgent.STATE_STREAMING:
			return "Replying..."
		CopilotAgent.STATE_RUNNING_TOOLS:
			return "Running tools..."
		CopilotAgent.STATE_WAITING_PERMISSION:
			return "Waiting for permission..."
		CopilotAgent.STATE_COMPACTING:
			return "Compacting memory..."
		"error":
			return "Error"
		"canceled":
			return "Canceled"
	return state

static func state_role(state: String) -> String:
	match state:
		CopilotAgent.STATE_IDLE:
			return "status-success"
		CopilotAgent.STATE_STREAMING:
			return "primary"
		CopilotAgent.STATE_THINKING, CopilotAgent.STATE_RUNNING_TOOLS, CopilotAgent.STATE_WAITING_PERMISSION, CopilotAgent.STATE_COMPACTING:
			return "status-warning"
		"error":
			return "error"
	return "on-surface-variant"


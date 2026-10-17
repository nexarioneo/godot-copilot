@tool
class_name CopilotMd3ToolRow
extends PanelContainer
# Collapsible tool call row: surface-container-low, 1px outline-variant,
# corner 12, 36px collapsed height. The header shows a chevron, the tool icon,
# the (optionally agent-prefixed) tool name, truncated args and the status
# glyph plus elapsed time. Expanding reveals the output block in code style.

const MAX_OUTPUT_CHARS := 600
const COLLAPSED_HEIGHT := 36
const ICON_SIZE := 18
const GLYPH_SIZE := 16

var _scheme: CopilotMd3Scheme = null
var _tool_name := ""
var _agent_name := ""
var _output_text := ""
var _success := true
var _done := false
var _expanded := false
var _output_fully_shown := false

var _root: VBoxContainer = null
var _header: HBoxContainer = null
var _chevron: CopilotMd3IconButton = null
var _icon_rect: TextureRect = null
var _agent_label: Label = null
var _name_label: Label = null
var _args_label: Label = null
var _spinner: CopilotMd3Spinner = null
var _status_icon: TextureRect = null
var _elapsed_label: Label = null
var _output_panel: PanelContainer = null
var _output_label: RichTextLabel = null
var _output_button: CopilotMd3Button = null

func configure(scheme: CopilotMd3Scheme, tool_name: String, args_summary: String = "", agent_name: String = "") -> void:
	_scheme = scheme
	_tool_name = tool_name
	_agent_name = agent_name
	_ensure_built()
	_agent_label.text = agent_name
	_agent_label.visible = not agent_name.is_empty()
	_name_label.text = tool_name
	_args_label.text = args_summary
	_args_label.visible = not args_summary.is_empty()
	var texture := CopilotMd3Icons.symbol(icon_for_tool(tool_name))
	_icon_rect.texture = texture
	_icon_rect.visible = texture != null
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func set_running() -> void:
	_done = false
	_success = true
	_spinner.visible = true
	_status_icon.visible = false
	_elapsed_label.visible = false

func set_finished(success: bool, output: String, error_text: String) -> void:
	_done = true
	_success = success
	_output_text = error_text if not success and not error_text.is_empty() else output
	_has_output_changed()
	_apply_state_visibility()
	_status_icon.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_status_icon, "modulate:a", 1.0, CopilotMd3Motion.duration_seconds("short2"))

func set_elapsed(milliseconds: int) -> void:
	if milliseconds <= 0:
		_elapsed_label.visible = false
		return
	_elapsed_label.text = format_elapsed(milliseconds)
	_elapsed_label.visible = _done

static func format_elapsed(milliseconds: int) -> String:
	if milliseconds < 1000:
		return str(milliseconds) + " ms"
	var seconds := float(milliseconds) / 1000.0
	if seconds < 60.0:
		return "%.1f s" % seconds
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]

static func icon_for_tool(tool_name: String) -> String:
	match tool_name:
		"read_file", "list_files", "glob_files":
			return "description"
		"write_file", "edit_file_lines", "patch_file", "delete_file":
			return "edit_note"
		"grep_search", "search_available_tools":
			return "search"
		"execute_command":
			return "terminal"
		"read_url", "web_search", "web_fetch":
			return "language"
		"mcp_call_tool":
			return "hub"
		"run_subagent":
			return "smart_toy"
	if tool_name.begins_with("mcp") or tool_name.begins_with("editor"):
		return "hub"
	if tool_name.begins_with("scene"):
		return "widgets"
	return "widgets"

func _ready() -> void:
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_ensure_built()
	_apply()

func _ensure_built() -> void:
	if _header != null:
		return
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	add_child(_root)

	_header = HBoxContainer.new()
	_header.custom_minimum_size.y = COLLAPSED_HEIGHT - CopilotMd3Tokens.spacing("s")
	_header.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("s"))
	_root.add_child(_header)

	_chevron = CopilotMd3IconButton.new()
	_chevron.configure(_scheme, CopilotMd3IconButton.VARIANT_STANDARD, "", "expand_more", "")
	_chevron.disabled = true
	_chevron.pressed.connect(_toggle_output)
	_header.add_child(_chevron)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_icon_rect)

	_agent_label = Label.new()
	CopilotMd3Tokens.apply_text(_agent_label, "label-large")
	_agent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_agent_label)

	_name_label = Label.new()
	CopilotMd3Tokens.apply_text(_name_label, "label-large")
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_name_label)

	_args_label = Label.new()
	CopilotMd3Tokens.apply_text(_args_label, "body-small")
	_args_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_args_label.clip_text = true
	_args_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_args_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_args_label)

	_spinner = CopilotMd3Spinner.new()
	_spinner.configure(_scheme, "primary", GLYPH_SIZE)
	_spinner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.add_child(_spinner)

	_status_icon = TextureRect.new()
	_status_icon.custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
	_status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_icon.visible = false
	_header.add_child(_status_icon)

	_elapsed_label = Label.new()
	CopilotMd3Tokens.apply_text(_elapsed_label, "label-small")
	_elapsed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_elapsed_label.visible = false
	_header.add_child(_elapsed_label)

	_output_panel = PanelContainer.new()
	_output_panel.visible = false
	_root.add_child(_output_panel)

	var output_box := VBoxContainer.new()
	output_box.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("xs"))
	_output_panel.add_child(output_box)

	_output_label = RichTextLabel.new()
	_output_label.bbcode_enabled = false
	_output_label.fit_content = true
	_output_label.scroll_active = false
	_output_label.selection_enabled = true
	_output_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_box.add_child(_output_label)

	_output_button = CopilotMd3Button.new()
	_output_button.configure(_scheme, CopilotMd3Button.VARIANT_TEXT, "Show more", "", "")
	_output_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_output_button.pressed.connect(_toggle_full_output)
	output_box.add_child(_output_button)

func _apply() -> void:
	if _scheme == null or _header == null:
		return
	var panel_box := _scheme.box("surface-container-low", CopilotMd3Tokens.corner_radius("medium", Vector2(0, COLLAPSED_HEIGHT)), "outline-variant", 1)
	panel_box.content_margin_left = CopilotMd3Tokens.spacing("s")
	panel_box.content_margin_right = CopilotMd3Tokens.spacing("s")
	panel_box.content_margin_top = CopilotMd3Tokens.spacing("xs")
	panel_box.content_margin_bottom = CopilotMd3Tokens.spacing("xs")
	add_theme_stylebox_override("panel", panel_box)

	_chevron.custom_minimum_size = Vector2(24, 24)
	_chevron.add_theme_constant_override("icon_max_width", ICON_SIZE)
	_chevron.disabled = _output_text.strip_edges().is_empty()
	_icon_rect.modulate = _scheme.color("on-surface-variant")
	_agent_label.add_theme_color_override("font_color", _scheme.color("status-info"))
	_name_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
	_args_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	_elapsed_label.add_theme_color_override("font_color", _scheme.color("on-surface-variant"))
	_apply_state_visibility()

	var output_box := _scheme.box("surface-container-lowest", CopilotMd3Tokens.corner_radius("small", Vector2(0, 40)))
	output_box.content_margin_left = CopilotMd3Tokens.spacing("m")
	output_box.content_margin_right = CopilotMd3Tokens.spacing("m")
	output_box.content_margin_top = CopilotMd3Tokens.spacing("s")
	output_box.content_margin_bottom = CopilotMd3Tokens.spacing("s")
	_output_panel.add_theme_stylebox_override("panel", output_box)
	_output_label.add_theme_color_override("default_color", _scheme.color("on-surface-variant"))
	_output_label.add_theme_color_override("selection_color", _scheme.alpha("primary", 0.30))
	var mono := mono_font()
	if mono != null:
		_output_label.add_theme_font_override("normal_font", mono)
	_output_label.add_theme_font_size_override("normal_font_size", CopilotMd3Tokens.type_size("body-small"))
	_output_button.add_theme_color_override("font_color", _scheme.color("primary"))
	_output_button.add_theme_color_override("font_hover_color", _scheme.color("primary"))
	_output_button.add_theme_color_override("font_pressed_color", _scheme.color("primary"))
	_output_button.add_theme_color_override("font_focus_color", _scheme.color("primary"))

func _apply_state_visibility() -> void:
	_spinner.visible = not _done
	_status_icon.visible = _done
	_elapsed_label.visible = _done and not _elapsed_label.text.is_empty()
	if _done:
		_status_icon.texture = CopilotMd3Icons.symbol("check_circle" if _success else "error")
		_status_icon.modulate = _scheme.color("status-success") if _success else _scheme.color("error")

func _has_output_changed() -> void:
	var has_output := not _output_text.strip_edges().is_empty()
	_output_panel.visible = has_output and _expanded
	if _chevron != null:
		_chevron.disabled = not has_output
		_output_fully_shown = false
		_refresh_output_text()

func _toggle_output() -> void:
	if _output_text.strip_edges().is_empty():
		return
	_expanded = not _expanded
	_output_panel.visible = _expanded
	_chevron.set_icon("expand_less" if _expanded else "expand_more")
	if _expanded:
		_refresh_output_text()

func _toggle_full_output() -> void:
	_output_fully_shown = not _output_fully_shown
	_refresh_output_text()

func _refresh_output_text() -> void:
	if _output_text.strip_edges().is_empty():
		_output_button.visible = false
		return
	var truncated := _output_text.length() > MAX_OUTPUT_CHARS
	var shown := _output_text if _output_fully_shown or not truncated else _output_text.substr(0, MAX_OUTPUT_CHARS) + "…"
	_output_label.clear()
	_output_label.add_text(shown)
	_output_button.visible = truncated
	_output_button.text = "Show less" if _output_fully_shown else "Show more"

static func mono_font() -> Font:
	var settings := EditorInterface.get_editor_settings()
	if settings != null:
		var configured: Variant = settings.get_setting("interface/editor/code_font")
		if configured is Font:
			return configured as Font
		if configured is String and not (configured as String).is_empty() and ResourceLoader.exists(configured as String):
			return load(configured as String) as Font
	var theme := EditorInterface.get_editor_theme()
	if theme != null:
		for font_name in ["mono_font", "source", "mono"]:
			if theme.has_font(font_name, "EditorFonts"):
				var theme_font := theme.get_font(font_name, "EditorFonts")
				if theme_font != null:
					return theme_font
	return null

@tool
class_name CopilotMd3Dialog
extends AcceptDialog
# Material 3 dialog base: a borderless embedded window with a single
# surface-container-high panel (extra-large 28 corner, elevation 3), an in-panel
# headline-small title, 24px body padding, Roboto type and restyled actions:
# the OK button becomes an M3 filled (or danger) button, an optional cancel
# button becomes a text button. Callers add content through body().

const RADIUS := 28
const PAD := 24
const ACTION_HEIGHT := 40
const ACTION_MIN_WIDTH := 72
const HOVER_OPACITY := 0.08
const PRESSED_OPACITY := 0.10
const EDGE_MARGIN := 8

var _scheme: CopilotMd3Scheme = null
var _body: VBoxContainer = null
var _title_label: Label = null
var _cancel_button: Button = null
var _ok_variant := CopilotMd3Button.VARIANT_FILLED
var _ok_label := "Close"

func configure(scheme: CopilotMd3Scheme, title_text: String, ok_text: String = "Close", cancel_text: String = "") -> void:
	_scheme = scheme
	_ok_label = ok_text
	title = title_text
	ok_button_text = ok_text
	borderless = true
	# AcceptDialog windows are opaque by default, which leaves a square of the
	# viewport clear color behind our rounded panel; PopupPanel sets the same
	# flag so embedded corners composite cleanly.
	transparent = true
	_build_body()
	if not cancel_text.is_empty() and _cancel_button == null:
		_cancel_button = add_cancel_button(cancel_text)
	_apply()

func set_scheme(scheme: CopilotMd3Scheme) -> void:
	_scheme = scheme
	_apply()

func body() -> VBoxContainer:
	_build_body()
	return _body

func set_ok_variant(button_variant: String) -> void:
	_ok_variant = button_variant
	_apply()

func sync_scheme() -> bool:
	# Re-resolves the editor theme mode (light/dark can change while a dialog
	# instance stays alive) and rebuilds the dialog when it changed.
	# Returns true when the mode changed.
	if not is_inside_tree() or _scheme == null:
		return false
	var detected := CopilotMd3Scheme.for_node(self)
	if detected == _scheme:
		return false
	_scheme = detected
	if _body != null:
		_apply()
		_on_scheme_changed()
	return true

func _on_scheme_changed() -> void:
	# Overridable hook: subclasses re-inject the new scheme into their widgets.
	pass

func _ready() -> void:
	# Own title inside the panel: the embedded window frame draws the default
	# editor decoration (square border + title bar) on top of our rounded
	# panel, so the dialog is borderless and titles itself. Transparency keeps
	# the area outside the rounded panel corners see-through.
	borderless = true
	transparent = true
	if _scheme == null:
		_scheme = CopilotMd3Scheme.for_node(self)
	_build_body()
	_apply()
	_clamp_to_editor()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		sync_scheme()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		# The editor area can change between popups (rotation, resized docks);
		# re-measure before every show so the clamp stays correct.
		_clamp_to_editor()

func _build_body() -> void:
	if _body != null:
		return
	_body = VBoxContainer.new()
	_body.name = "md3_body"
	_body.custom_minimum_size.x = 400
	_body.add_theme_constant_override("separation", CopilotMd3Tokens.spacing("l"))
	add_child(_body)
	_title_label = Label.new()
	_title_label.name = "md3_title"
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_title_label)

func _apply() -> void:
	if _scheme == null:
		return
	var panel := _scheme.box("surface-container-high", RADIUS, "", 0, 3)
	panel.content_margin_left = PAD
	panel.content_margin_right = PAD
	panel.content_margin_bottom = PAD
	panel.content_margin_top = PAD
	add_theme_stylebox_override("panel", panel)
	if _title_label != null:
		_title_label.text = title
		_title_label.visible = not title.is_empty()
		_title_label.add_theme_color_override("font_color", _scheme.color("on-surface"))
		CopilotMd3Tokens.apply_text(_title_label, "headline-small")
	ok_button_text = _ok_label
	_style_action(get_ok_button(), _ok_variant)
	_style_action(_cancel_button, CopilotMd3Button.VARIANT_TEXT)

func _clamp_to_editor() -> void:
	# The editor area can be smaller than the dialog's own content minimum (a
	# phone in landscape, for example). Without a maximum the embedded window
	# grows past the visible editor, the engine places the action buttons below
	# the clipped bottom edge and the dialog cannot be closed. Window applies
	# the maximum after the content minimum, so the buttons stay reachable and
	# tall pages scroll instead of pushing the window off screen.
	if not Engine.is_editor_hint():
		return
	# Window.max_size exists from Godot 4.7; older engines keep the content
	# minimum as the only limit.
	if not ClassDB.class_has_property("Window", "max_size"):
		return
	var base := EditorInterface.get_base_control()
	if base == null:
		return
	var limit := Vector2i(base.get_global_rect().size) - Vector2i(EDGE_MARGIN * 2, EDGE_MARGIN * 2)
	if limit.x <= 0 or limit.y <= 0:
		return
	# A minimum larger than the maximum disables the clamp entirely, so the
	# minimum is pulled down first when the screen cannot fit it.
	min_size = Vector2i(mini(min_size.x, limit.x), mini(min_size.y, limit.y))
	max_size = limit

func _style_action(button: Button, variant: String) -> void:
	if button == null:
		return
	var fill_role := ""
	var content_role := "primary"
	match variant:
		CopilotMd3Button.VARIANT_DANGER:
			fill_role = "error"
			content_role = "on-error"
		CopilotMd3Button.VARIANT_TEXT:
			fill_role = ""
			content_role = "primary"
		_:
			fill_role = "primary"
			content_role = "on-primary"
	var radius := CopilotMd3Tokens.corner_radius("full", Vector2(ACTION_HEIGHT, ACTION_HEIGHT))
	var fill_color := Color(0.0, 0.0, 0.0, 0.0)
	if not fill_role.is_empty():
		fill_color = _scheme.color(fill_role)
	var content_color := _scheme.color(content_role)
	var disabled_fill := Color(0.0, 0.0, 0.0, 0.0)
	if not fill_role.is_empty():
		disabled_fill = _scheme.alpha("on-surface", CopilotMd3Tokens.DISABLED_CONTAINER_OPACITY)
	button.custom_minimum_size = Vector2(ACTION_MIN_WIDTH, ACTION_HEIGHT)
	button.add_theme_constant_override("icon_max_width", 18)
	button.add_theme_constant_override("h_separation", CopilotMd3Tokens.spacing("s"))
	CopilotMd3Tokens.apply_text(button, "label-large")
	button.add_theme_stylebox_override("normal", _action_box(fill_color, radius))
	button.add_theme_stylebox_override("hover", _action_box(_scheme.state_fill(fill_color, content_color, HOVER_OPACITY), radius))
	button.add_theme_stylebox_override("pressed", _action_box(_scheme.state_fill(fill_color, content_color, PRESSED_OPACITY), radius))
	button.add_theme_stylebox_override("focus", _action_focus_box(radius))
	button.add_theme_stylebox_override("disabled", _action_box(disabled_fill, radius))
	button.add_theme_color_override("font_color", content_color)
	button.add_theme_color_override("font_hover_color", content_color)
	button.add_theme_color_override("font_pressed_color", content_color)
	button.add_theme_color_override("font_focus_color", content_color)
	button.add_theme_color_override("font_disabled_color", _scheme.disabled_content("on-surface"))

func _action_box(fill_color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = CopilotMd3Tokens.spacing("l")
	sb.content_margin_right = CopilotMd3Tokens.spacing("l")
	sb.content_margin_top = CopilotMd3Tokens.spacing("xs")
	sb.content_margin_bottom = CopilotMd3Tokens.spacing("xs")
	return sb

func _action_focus_box(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	if not CopilotMd3Tokens.focus_ring_visible():
		return sb
	sb.set_border_width_all(CopilotMd3Tokens.FOCUS_RING_WIDTH)
	sb.border_color = _scheme.color("primary")
	sb.set_corner_radius_all(radius)
	return sb

@tool
class_name CopilotProviderRow
extends CopilotMd3ListItem
# Provider list row: leading logo/initials badge (28px on a rounded surface),
# name + key status, selected state, and a trailing check_circle on the active
# provider. The manager binds the provider name to the inherited `pressed`
# signal.

const BADGE_SIZE := 28
const BADGE_ICON_SIZE := 20
const CHECK_SIZE := 18

var provider_name := ""

var _badge_icon: TextureRect = null
var _badge_label: Label = null
var _check: TextureRect = null

func _ready() -> void:
	super._ready()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func setup(scheme: CopilotMd3Scheme, p_provider_name: String, status_text: String, icon_path: String, selected: bool, active: bool) -> void:
	provider_name = p_provider_name
	configure(scheme, p_provider_name, status_text)
	set_selected(selected)
	set_subtitle_style("body-small")
	set_leading(_build_badge(scheme, icon_path))
	tooltip_text = p_provider_name
	if active:
		if _check == null:
			_check = TextureRect.new()
			_check.texture = CopilotMd3Icons.symbol("check_circle")
			_check.custom_minimum_size = Vector2(CHECK_SIZE, CHECK_SIZE)
			_check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_trailing(_check)
		_check.modulate = scheme.color("primary")
	elif _check != null:
		_check.queue_free()
		_check = null

func _build_badge(scheme: CopilotMd3Scheme, icon_path: String) -> Control:
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := scheme.box("surface-container-lowest", CopilotMd3Tokens.corner_radius("extra-small", Vector2(BADGE_SIZE, BADGE_SIZE)))
	box.content_margin_left = CopilotMd3Tokens.spacing("xs")
	box.content_margin_right = CopilotMd3Tokens.spacing("xs")
	box.content_margin_top = CopilotMd3Tokens.spacing("xs")
	box.content_margin_bottom = CopilotMd3Tokens.spacing("xs")
	badge.add_theme_stylebox_override("panel", box)
	var texture: Texture2D = null
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var loaded := ResourceLoader.load(icon_path)
		if loaded is Texture2D:
			texture = loaded
	if texture != null:
		_badge_icon = TextureRect.new()
		_badge_icon.texture = texture
		_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_badge_icon.custom_minimum_size = Vector2(BADGE_ICON_SIZE, BADGE_ICON_SIZE)
		_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(_badge_icon)
	else:
		_badge_label = Label.new()
		_badge_label.text = _initials(provider_name)
		_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		CopilotMd3Tokens.apply_text(_badge_label, "label-small")
		_badge_label.add_theme_color_override("font_color", scheme.color("on-surface"))
		badge.add_child(_badge_label)
	return badge

func _initials(text: String) -> String:
	var clean := text.strip_edges()
	if clean.is_empty():
		return "?"
	var pieces := clean.split(" ", false)
	if pieces.is_empty():
		return clean.substr(0, 1).to_upper()
	if pieces.size() == 1:
		return pieces[0].substr(0, mini(2, pieces[0].length())).to_upper()
	return (pieces[0].substr(0, 1) + pieces[1].substr(0, 1)).to_upper()

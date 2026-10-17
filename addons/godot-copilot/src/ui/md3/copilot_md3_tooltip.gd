@tool
class_name CopilotMd3Tooltip
extends PanelContainer
# Plain Material 3 tooltip: inverse-surface container, inverse-on-surface
# label-medium, shown 0.5s after hover. Implemented as an overlay in the host
# viewport so it is never clipped by dock or dialog layout.
#
# attach() requires the host to be inside the tree; it returns the tooltip.

const DELAY_SECONDS := 0.5
const CURSOR_OFFSET := Vector2(14.0, 18.0)
const EDGE_MARGIN := 4.0

var _host: Control = null
var _scheme: CopilotMd3Scheme = null
var _label: Label = null
var _hovered := false
var _pending := false

static func attach(host: Control, text: String) -> CopilotMd3Tooltip:
	if not host.is_inside_tree():
		push_warning("CopilotMd3Tooltip.attach: host must be inside the tree")
		return null
	var tip := CopilotMd3Tooltip.new()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	tip._host = host
	tip._scheme = CopilotMd3Scheme.for_node(host)
	tip._build(text)
	host.get_viewport().add_child(tip)
	host.mouse_entered.connect(tip._on_host_entered)
	host.mouse_exited.connect(tip._on_host_exited)
	host.tree_exiting.connect(tip._on_host_exiting)
	return tip

func set_text(text: String) -> void:
	if _label != null:
		_label.text = text

func _build(text: String) -> void:
	_label = Label.new()
	_label.text = text
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	var box := _scheme.box("inverse-surface", CopilotMd3Tokens.corner_radius("extra-small", Vector2.ZERO))
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	add_theme_stylebox_override("panel", box)
	CopilotMd3Tokens.apply_text(_label, "label-medium")
	_label.add_theme_color_override("font_color", _scheme.color("inverse-on-surface"))

func _on_host_entered() -> void:
	_hovered = true
	_pending = true
	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(DELAY_SECONDS)
	timer.timeout.connect(_maybe_show)

func _on_host_exited() -> void:
	_hovered = false
	_pending = false
	visible = false

func _on_host_exiting() -> void:
	queue_free()

func _maybe_show() -> void:
	if not _pending or not _hovered or not is_instance_valid(_host):
		return
	_pending = false
	_place_and_show()

func _place_and_show() -> void:
	if not is_inside_tree() or not is_instance_valid(_host):
		return
	visible = true
	size = get_combined_minimum_size()
	var viewport := _host.get_viewport()
	if viewport == null:
		return
	var view_rect := viewport.get_visible_rect()
	var pos := viewport.get_mouse_position() + CURSOR_OFFSET
	pos.x = minf(pos.x, view_rect.size.x - size.x - EDGE_MARGIN)
	pos.y = minf(pos.y, view_rect.size.y - size.y - EDGE_MARGIN)
	pos.x = maxf(pos.x, view_rect.position.x + EDGE_MARGIN)
	pos.y = maxf(pos.y, view_rect.position.y + EDGE_MARGIN)
	position = pos

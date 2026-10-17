@tool
class_name CopilotSceneTools
extends RefCounted
# Scene manipulation tools via EditorInterface + EditorUndoRedoManager.
# All node changes go through undo/redo so the user can undo them.

var editor_plugin: EditorPlugin

func setup(p_editor_plugin: EditorPlugin) -> void:
	editor_plugin = p_editor_plugin

# --- Read scene ---

func inspect_scene_tree(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open in the editor.")
	var start_node := root
	var root_path := str(args.get("root_path", "")).strip_edges()
	if not root_path.is_empty():
		start_node = _resolve_node(root_path)
		if start_node == null:
			return _error("Node not found: " + root_path)
	var max_depth := clampi(int(args.get("max_depth", 4)), 1, 10)
	var lines := PackedStringArray()
	_append_tree(lines, start_node, 0, max_depth)
	return {
		"success": true,
		"scene": root.scene_file_path,
		"tree": "\n".join(lines),
		"node_count": lines.size()
	}

func get_selected_nodes(_args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	var nodes: Array = []
	for node in EditorInterface.get_selection().get_selected_nodes():
		if not (node is Node):
			continue
		nodes.append({
			"name": str(node.name),
			"type": node.get_class(),
			"path": _node_path(root, node)
		})
	return {"success": true, "nodes": nodes, "count": nodes.size()}

# --- Write scene ---

func add_node(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open in the editor.")
	var parent := _resolve_node(str(args.get("parent_path", ".")))
	if parent == null:
		return _error("Parent node not found: " + str(args.get("parent_path", "")))
	var type_name := str(args.get("type", "")).strip_edges()
	if not ClassDB.class_exists(type_name):
		return _error("Unknown node type: " + type_name)
	if not ClassDB.can_instantiate(type_name):
		return _error("Node type cannot be instantiated: " + type_name)
	var node := ClassDB.instantiate(type_name) as Node
	if node == null:
		return _error("Failed to create node of type " + type_name + ".")
	var node_name := str(args.get("name", "")).strip_edges()
	if not node_name.is_empty():
		node.name = node_name

	var undo_redo := _undo_redo()
	if undo_redo == null:
		node.free()
		return _error("Editor undo/redo manager is not available.")
	undo_redo.create_action("Copilot: Add " + type_name)
	undo_redo.add_do_method(parent, "add_child", node, true)
	undo_redo.add_do_property(node, "owner", root)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(parent, "remove_child", node)
	undo_redo.commit_action()
	return {"success": true, "node_path": _node_path(root, node), "type": type_name}

func delete_node(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	var node := _resolve_node(str(args.get("node_path", "")))
	if node == null:
		return _error("Node not found: " + str(args.get("node_path", "")))
	if node == root or node.get_parent() == null:
		return _error("The scene root cannot be deleted.")
	var undo_redo := _undo_redo()
	if undo_redo == null:
		return _error("Editor undo/redo manager is not available.")
	var parent := node.get_parent()
	var original_owner := node.owner
	undo_redo.create_action("Copilot: Delete " + str(node.name))
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node, true)
	if original_owner != null:
		undo_redo.add_undo_property(node, "owner", original_owner)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()
	return {"success": true, "deleted": str(node.name)}

func instantiate_scene(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error("No scene is currently open in the editor.")
	var scene_path := str(args.get("scene_path", "")).strip_edges()
	if not ResourceLoader.exists(scene_path):
		return _error("Scene not found: " + scene_path)
	var packed := ResourceLoader.load(scene_path)
	if not (packed is PackedScene):
		return _error("File is not a PackedScene: " + scene_path)
	var parent := _resolve_node(str(args.get("parent_path", ".")))
	if parent == null:
		return _error("Parent node not found: " + str(args.get("parent_path", "")))
	var instance := packed.instantiate()
	var instance_name := str(args.get("name", "")).strip_edges()
	if not instance_name.is_empty():
		instance.name = instance_name

	var undo_redo := _undo_redo()
	if undo_redo == null:
		instance.free()
		return _error("Editor undo/redo manager is not available.")
	undo_redo.create_action("Copilot: Instantiate " + scene_path.get_file())
	undo_redo.add_do_method(parent, "add_child", instance, true)
	undo_redo.add_do_property(instance, "owner", root)
	undo_redo.add_do_reference(instance)
	undo_redo.add_undo_method(parent, "remove_child", instance)
	undo_redo.commit_action()
	return {"success": true, "node_path": _node_path(root, instance), "scene": scene_path}

func set_node_property(args: Dictionary) -> Dictionary:
	var node := _resolve_node(str(args.get("node_path", "")))
	if node == null:
		return _error("Node not found: " + str(args.get("node_path", "")))
	var property := str(args.get("property", "")).strip_edges()
	if property.is_empty():
		return _error("Parameter 'property' is required.")
	if not _has_property(node, property):
		return _error("Property '" + property + "' does not exist on " + node.get_class() + ".")
	var converted = _convert_value(node.get(property), args.get("value"))
	var undo_redo := _undo_redo()
	if undo_redo == null:
		return _error("Editor undo/redo manager is not available.")
	undo_redo.create_action("Copilot: Set " + property)
	undo_redo.add_do_property(node, property, converted)
	undo_redo.add_undo_property(node, property, node.get(property))
	undo_redo.commit_action()
	return {"success": true, "node_path": _node_path(EditorInterface.get_edited_scene_root(), node), "property": property, "value": str(converted)}

func attach_script(args: Dictionary) -> Dictionary:
	var node := _resolve_node(str(args.get("node_path", "")))
	if node == null:
		return _error("Node not found: " + str(args.get("node_path", "")))
	var script_path := str(args.get("script_path", "")).strip_edges()
	if not ResourceLoader.exists(script_path):
		return _error("Script not found: " + script_path)
	var script := ResourceLoader.load(script_path)
	if not (script is Script):
		return _error("File is not a Script: " + script_path)
	var undo_redo := _undo_redo()
	if undo_redo == null:
		return _error("Editor undo/redo manager is not available.")
	undo_redo.create_action("Copilot: Attach script " + script_path.get_file())
	undo_redo.add_do_property(node, "script", script)
	undo_redo.add_undo_property(node, "script", node.get_script())
	undo_redo.commit_action()
	return {"success": true, "node_path": _node_path(EditorInterface.get_edited_scene_root(), node), "script": script_path}

# --- Helper ---

func _undo_redo() -> EditorUndoRedoManager:
	if editor_plugin == null or not is_instance_valid(editor_plugin):
		return null
	return editor_plugin.get_undo_redo()

func _resolve_node(path: String) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return null
	var clean := path.strip_edges().replace("\\", "/")
	if clean.begins_with("/root/"):
		clean = clean.substr(6)
	if clean.begins_with(str(root.name)):
		clean = clean.trim_prefix(str(root.name))
	clean = clean.trim_prefix("/").trim_prefix("./")
	if clean.is_empty() or clean == ".":
		return root
	return root.get_node_or_null(clean)

func _node_path(root: Node, node: Node) -> String:
	if root == null or node == root:
		return "."
	return str(root.get_path_to(node))

func _append_tree(lines: PackedStringArray, node: Node, depth: int, max_depth: int) -> void:
	var indent := ""
	if depth > 0:
		indent = "  ".repeat(depth - 1) + "├─ "
	lines.append(indent + str(node.name) + " (" + node.get_class() + ")")
	if depth >= max_depth:
		return
	for child in node.get_children():
		_append_tree(lines, child, depth + 1, max_depth)

func _has_property(node: Node, property: String) -> bool:
	for entry in node.get_property_list():
		if str(entry.get("name", "")) == property:
			return true
	return false

func _convert_value(current, raw_value):
	if raw_value is String and not (current is String):
		var parsed = str_to_var(raw_value)
		if parsed != null:
			return parsed
	if current is float and (raw_value is int or raw_value is float):
		return float(raw_value)
	if current is int and (raw_value is int or raw_value is float):
		return int(raw_value)
	if current is bool and raw_value is String:
		return raw_value.strip_edges().to_lower() in ["true", "1", "yes", "on"]
	return raw_value

func _error(message: String) -> Dictionary:
	return {"success": false, "error": message}

@tool
class_name CopilotEditorContext
extends RefCounted
# Builds a summary of the editor context (active scene, selected nodes, open scripts)
# that is appended to the user message before it is sent to the model.

const MAX_OPEN_SCRIPTS := 6

static func build() -> String:
	var lines := PackedStringArray()
	lines.append("[Editor Context]")
	lines.append("Project: " + str(ProjectSettings.get_setting("application/config/name", "Untitled")))

	var edited_scene := EditorInterface.get_edited_scene_root()
	if edited_scene != null:
		lines.append("Active scene: " + str(edited_scene.scene_file_path) + " (root: " + str(edited_scene.name) + ", " + edited_scene.get_class() + ")")
		var selected := EditorInterface.get_selection().get_selected_nodes()
		if not selected.is_empty():
			var selected_names := PackedStringArray()
			for node in selected:
				if node is Node:
					selected_names.append(str(edited_scene.get_path_to(node)) + " (" + node.get_class() + ")")
			if not selected_names.is_empty():
				lines.append("Selected nodes: " + ", ".join(selected_names))
	else:
		lines.append("Active scene: (none)")

	var script_editor := EditorInterface.get_script_editor()
	if script_editor != null:
		var open_paths := PackedStringArray()
		for script in script_editor.get_open_scripts():
			if script is Script and not str(script.resource_path).is_empty():
				open_paths.append(script.resource_path)
				if open_paths.size() >= MAX_OPEN_SCRIPTS:
					break
		if not open_paths.is_empty():
			lines.append("Open scripts: " + ", ".join(open_paths))

	return "\n".join(lines)

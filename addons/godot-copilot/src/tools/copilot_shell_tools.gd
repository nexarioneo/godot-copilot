@tool
class_name CopilotShellTools
extends RefCounted
# Non-blocking shell executor: OS.create_process + per-frame polling.
# Output is redirected to a temp file (CopilotPaths.temp_dir), then the exit code
# is read from the marker echoed after the command finishes.

const DEFAULT_TIMEOUT := 60.0
const MAX_TIMEOUT := 600.0
const MAX_OUTPUT_CHARS := 20000
const EXIT_MARKER := "__EXIT_CODE__:"

func execute(args: Dictionary, host: Node) -> Dictionary:
	var command := str(args.get("command", "")).strip_edges()
	if command.is_empty():
		return {"success": false, "error": "Parameter 'command' is required."}
	var workdir := str(args.get("workdir", "")).strip_edges()
	var timeout_seconds := clampf(float(args.get("timeout", DEFAULT_TIMEOUT)), 1.0, MAX_TIMEOUT)

	var script := command
	if not workdir.is_empty():
		script = "cd " + quote_shell_arg(_globalize_dir(workdir)) + " && " + script
	var result := await run_script(script, timeout_seconds, host)
	result["command"] = command
	result["workdir"] = workdir if not workdir.is_empty() else ProjectSettings.globalize_path("res://")
	return result

func run_script(script: String, timeout_seconds: float, host: Node) -> Dictionary:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return {"success": false, "error": "Process host is not available."}

	var output_file := CopilotPaths.temp_dir().path_join("process_" + str(Time.get_ticks_usec()) + ".log")
	CopilotPaths.write_text(output_file, "")
	var output_quote := quote_shell_arg(ProjectSettings.globalize_path(output_file))

	var is_windows := OS.get_name() == "Windows"
	var shell_path := "/bin/sh"
	var shell_args := PackedStringArray()
	if is_windows:
		shell_path = "cmd.exe"
		shell_args = PackedStringArray([
			"/v:on",
			"/c",
			script + " > " + output_quote + " 2>&1 & echo " + EXIT_MARKER + "!errorlevel! >> " + output_quote
		])
	else:
		if not FileAccess.file_exists("/bin/sh"):
			shell_path = "sh"
		shell_args = PackedStringArray([
			"-c",
			"( " + script + " ) > " + output_quote + " 2>&1\n__CP_STATUS__=$?\necho " + EXIT_MARKER + "$__CP_STATUS__ >> " + output_quote
		])

	var pid := OS.create_process(shell_path, shell_args)
	if pid <= 0:
		CopilotPaths.remove_file(output_file)
		return {"success": false, "error": "Failed to run the shell process."}

	var tree := host.get_tree()
	var start_ticks := Time.get_ticks_msec()
	var timeout_ms := int(timeout_seconds * 1000.0)
	var timed_out := false
	while OS.is_process_running(pid):
		if not is_instance_valid(host) or not host.is_inside_tree():
			OS.kill(pid)
			break
		if Time.get_ticks_msec() - start_ticks > timeout_ms:
			OS.kill(pid)
			timed_out = true
			break
		await tree.process_frame
	# Give the shell one frame to finish writing the marker before the file is read.
	await tree.process_frame

	var raw := CopilotPaths.read_text(output_file)
	CopilotPaths.remove_file(output_file)
	var exit_code := -1
	var marker_index := raw.rfind(EXIT_MARKER)
	if marker_index != -1:
		exit_code = int(raw.substr(marker_index + EXIT_MARKER.length()).strip_edges())
		raw = raw.substr(0, marker_index)

	var result := {
		"success": not timed_out and exit_code == 0,
		"exit_code": exit_code,
		"output": _truncate_output(raw.strip_edges(false, true)),
		"timed_out": timed_out
	}
	if timed_out:
		result["error"] = "Command exceeded the timeout of " + str(int(timeout_seconds)) + " seconds and was stopped."
	elif exit_code != 0:
		result["error"] = "Command exited with code " + str(exit_code) + "."
	return result

static func quote_shell_arg(value: String) -> String:
	if OS.get_name() == "Windows":
		return "\"" + value.replace("\"", "\\\"") + "\""
	return "'" + value.replace("'", "'\\''") + "'"

func _globalize_dir(path: String) -> String:
	var clean := path.strip_edges()
	if clean.begins_with("res://") or clean.begins_with("user://"):
		return ProjectSettings.globalize_path(clean)
	return clean

func _truncate_output(text: String) -> String:
	if text.length() <= MAX_OUTPUT_CHARS:
		return text
	var omitted := text.length() - MAX_OUTPUT_CHARS
	var head := text.substr(0, 4000)
	var tail := text.substr(text.length() - 15500)
	return head + "\n... [output truncated " + str(omitted) + " characters] ...\n" + tail

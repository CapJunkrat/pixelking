class_name AllTestsRunner
extends SceneTree

const NODE_RUNNER = "res://scripts/tests/runner/run_node_methods.gd"

var layer_filter: String = ""
var domain_filter: String = ""
var failures: int = 0
var passed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_filters()
	var tests: Array[Dictionary] = TestManifest.select(layer_filter, domain_filter)
	if tests.is_empty():
		push_error("No tests match layer='%s' domain='%s'" % [layer_filter, domain_filter])
		quit(2)
		return
	print("===== PixelKing automated tests: %d files =====" % tests.size())
	for entry: Dictionary in tests:
		_run_test(entry)
	print("===== Test files: %d passed / %d failed =====" % [passed, failures])
	quit(1 if failures > 0 else 0)

func _run_test(entry: Dictionary) -> void:
	var test_path: String = str(entry.get("path", ""))
	var arguments: PackedStringArray = PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--script",
	])
	if str(entry.get("kind", "scene_tree")) == "node_methods":
		arguments.append(NODE_RUNNER)
		arguments.append("--")
		arguments.append("--test-file=%s" % test_path)
	else:
		arguments.append(test_path)
	var output: Array = []
	print("\n[RUN] [%s/%s] %s" % [entry.get("layer", ""), entry.get("domain", ""), test_path])
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true, false)
	var text: String = "\n".join(PackedStringArray(output))
	if exit_code == 0 and not _contains_script_failure(text):
		passed += 1
		print("[PASS] %s" % test_path)
		return
	failures += 1
	print(text)
	push_error("[FAIL] %s (exit %d)" % [test_path, exit_code])

func _contains_script_failure(output: String) -> bool:
	return (
		"SCRIPT ERROR:" in output
		or "Parse Error:" in output
		or "Compile Error:" in output
		or "Assertion failed" in output
		or "[FAIL]" in output
	)

func _parse_filters() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--layer="):
			layer_filter = argument.trim_prefix("--layer=")
		elif argument.begins_with("--domain="):
			domain_filter = argument.trim_prefix("--domain=")

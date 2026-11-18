class_name AllTestsRunner
extends SceneTree

## Runs the manifest's test files, each in its own headless Godot process.
##
##   Godot --headless --path . --script res://scripts/tests/runner/run_all_tests.gd -- [options]
##
## Options:
##   --layer=<layer> / --domain=<domain>  only matching tests
##   --quick           skip tests marked "slow" (the full strike animation sweep)
##   --jobs=<n>        processes at once (default: up to 6, by CPU count; 1 = one by one)
##   --timeout=<sec>   a test still running after this long is killed and fails (default 120)
##
## Tests marked "serial" in the manifest share state such as user://settings.cfg; they
## run one at a time after the parallel batch.

const NODE_RUNNER = "res://scripts/tests/runner/run_node_methods.gd"
const DEFAULT_TIMEOUT_SECONDS := 120.0
const MAX_DEFAULT_JOBS := 6
const POLL_SECONDS := 0.05

var layer_filter: String = ""
var domain_filter: String = ""
var quick: bool = false
var jobs: int = 0
var timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS
var failures: int = 0
var passed: int = 0
var _log_dir: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_options()
	var tests: Array[Dictionary] = TestManifest.select(layer_filter, domain_filter, quick)
	if tests.is_empty():
		push_error("No tests match layer='%s' domain='%s'" % [layer_filter, domain_filter])
		quit(2)
		return
	if jobs <= 0:
		jobs = clampi(OS.get_processor_count() / 2, 1, MAX_DEFAULT_JOBS)
	_log_dir = OS.get_cache_dir().path_join("pixelking_tests_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(_log_dir)
	var started_msec: int = Time.get_ticks_msec()
	print("===== PixelKing automated tests: %d files, %d at a time%s =====" % [tests.size(), jobs, " (quick)" if quick else ""])
	var parallel: Array[Dictionary] = []
	var serial: Array[Dictionary] = []
	for entry: Dictionary in tests:
		if bool(entry.get("serial", false)):
			serial.append(entry)
		else:
			parallel.append(entry)
	await _run_batch(parallel, jobs)
	await _run_batch(serial, 1)
	DirAccess.remove_absolute(_log_dir)
	print("===== Test files: %d passed / %d failed in %.1fs =====" % [passed, failures, (Time.get_ticks_msec() - started_msec) / 1000.0])
	quit(1 if failures > 0 else 0)

## Keeps up to `width` test processes running until the queue is empty.
func _run_batch(queue: Array[Dictionary], width: int) -> void:
	var pending: Array[Dictionary] = queue.duplicate()
	var running: Array[Dictionary] = []
	while not pending.is_empty() or not running.is_empty():
		while running.size() < width and not pending.is_empty():
			var job: Dictionary = _start(pending.pop_front())
			if not job.is_empty():
				running.append(job)
		await create_timer(POLL_SECONDS).timeout
		for job: Dictionary in running.duplicate():
			var pid: int = int(job["pid"])
			var elapsed: float = (Time.get_ticks_msec() - int(job["started"])) / 1000.0
			if OS.is_process_running(pid):
				if elapsed > timeout_seconds:
					OS.kill(pid)
					_report(job, -1, elapsed, "timed out after %ds" % int(timeout_seconds))
					running.erase(job)
				continue
			_report(job, OS.get_process_exit_code(pid), elapsed, "")
			running.erase(job)

func _start(entry: Dictionary) -> Dictionary:
	var test_path: String = str(entry.get("path", ""))
	var log_path: String = _log_dir.path_join("%s.log" % test_path.get_file().get_basename())
	var arguments: PackedStringArray = PackedStringArray([
		"--headless",
		"--log-file", log_path,
		"--path", ProjectSettings.globalize_path("res://"),
		"--script",
	])
	if str(entry.get("kind", "scene_tree")) == "node_methods":
		arguments.append(NODE_RUNNER)
		arguments.append("--")
		arguments.append("--test-file=%s" % test_path)
	else:
		arguments.append(test_path)
	var pid: int = OS.create_process(OS.get_executable_path(), arguments)
	if pid <= 0:
		failures += 1
		push_error("[FAIL] %s (could not start)" % test_path)
		return {}
	return {"entry": entry, "pid": pid, "log": log_path, "started": Time.get_ticks_msec()}

func _report(job: Dictionary, exit_code: int, elapsed: float, problem: String) -> void:
	var entry: Dictionary = job["entry"]
	var test_path: String = str(entry.get("path", ""))
	var text: String = FileAccess.get_file_as_string(str(job["log"]))
	DirAccess.remove_absolute(str(job["log"]))
	var label: String = "[%s/%s] %s (%.1fs)" % [entry.get("layer", ""), entry.get("domain", ""), test_path, elapsed]
	if problem.is_empty() and exit_code == 0 and not _contains_script_failure(text):
		passed += 1
		print("[PASS] %s" % label)
		return
	failures += 1
	print(text)
	push_error("[FAIL] %s %s" % [label, problem if not problem.is_empty() else "(exit %d)" % exit_code])

func _contains_script_failure(output: String) -> bool:
	return (
		"SCRIPT ERROR:" in output
		or "Parse Error:" in output
		or "Compile Error:" in output
		or "Assertion failed" in output
		or "[FAIL]" in output
	)

func _parse_options() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--layer="):
			layer_filter = argument.trim_prefix("--layer=")
		elif argument.begins_with("--domain="):
			domain_filter = argument.trim_prefix("--domain=")
		elif argument == "--quick":
			quick = true
		elif argument.begins_with("--jobs="):
			jobs = maxi(1, int(argument.trim_prefix("--jobs=")))
		elif argument.begins_with("--timeout="):
			timeout_seconds = maxf(1.0, float(argument.trim_prefix("--timeout=")))

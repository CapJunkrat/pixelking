extends SceneTree

const TEST_PATH := "user://pixelking_active_run_test.save"

var failed: bool = false

func _init() -> void:
	_cleanup()
	var state_script: Script = load("res://scripts/run/RunState.gd") as Script
	var save_script: Script = load("res://scripts/run/ActiveRunSaveService.gd") as Script
	var state: RefCounted = state_script.new() as RefCounted
	state.call("initialize_new", 700000000000000001, "standard")
	state.call("allocate_piece", "king", true)
	state.set("gold", 88)
	var service: RefCounted = save_script.new(TEST_PATH) as RefCounted

	_expect(not bool(service.call("exists")), "test begins without an active Run save")
	_expect(int(service.call("save", state)) == OK, "active Run saves atomically")
	_expect(bool(service.call("exists")), "saved active Run exists")
	var loaded: RefCounted = service.call("load_run") as RefCounted
	_expect(loaded != null, "active Run loads")
	_expect(loaded != null and int(loaded.get("run_seed")) == 700000000000000001, "save preserves 64-bit seed")
	_expect(loaded != null and int(loaded.get("gold")) == 88, "save preserves Run data")

	var broken_file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	broken_file.store_buffer(PackedByteArray([1, 2, 3, 4]))
	broken_file.close()
	_expect(service.call("load_run") == null, "corrupt active Run fails safely")

	_expect(int(service.call("save", state)) == OK, "valid save can replace corrupt data")
	_expect(int(service.call("delete")) == OK, "active Run can be deleted")
	_expect(not bool(service.call("exists")), "deleted active Run no longer exists")
	_cleanup()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	print("[PASS] Active Run save test" if not failed else "[FAIL] Active Run save test")
	quit(1 if failed else 0)

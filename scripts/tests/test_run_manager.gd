extends SceneTree

const TEST_PATH := "user://pixelking_run_manager_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager_script: Script = load("res://scripts/autoload/RunManager.gd") as Script
	var manager: Node = manager_script.new() as Node
	manager.call("configure_save_path", TEST_PATH)
	root.add_child(manager)
	await process_frame
	_expect(manager.get("current_run") == null, "RunManager does not create a Run on startup")
	_expect(not bool(manager.call("can_continue")), "Continue is unavailable without a save")
	_expect(manager.call("create_run", 24680, "standard", false), "RunManager creates a new Run")
	var current: RefCounted = manager.get("current_run") as RefCounted
	_expect(current != null and (current.get("player_roster") as Array).size() == 1, "new Run starts with one persistent king")
	var first_candidates: Array = ((current.get("pending_choice") as Dictionary).get("candidate_piece_def_ids", []) as Array).duplicate()
	_expect(first_candidates.size() == 3, "new Run persists its first opening offer")
	_expect(not bool(manager.call("create_run", 13579, "standard", false)), "RunManager refuses accidental overwrite")
	current.set("gold", 44)
	_expect(int(manager.call("save_active_run")) == OK, "RunManager saves current Run")
	manager.queue_free()
	await process_frame

	var loader: Node = manager_script.new() as Node
	loader.call("configure_save_path", TEST_PATH)
	root.add_child(loader)
	await process_frame
	_expect(loader.call("load_active_run"), "RunManager loads active Run")
	var loaded: RefCounted = loader.get("current_run") as RefCounted
	_expect(loaded != null and int(loaded.get("gold")) == 44, "RunManager restores saved state")
	var loaded_candidates: Array = (loaded.get("pending_choice") as Dictionary).get("candidate_piece_def_ids", []) as Array
	_expect(loaded_candidates == first_candidates, "RunManager reloads the exact persisted opening offer")
	_expect(loader.call("create_run", 13579, "standard", true), "RunManager replaces a Run only with explicit permission")
	var replacement: RefCounted = loader.get("current_run") as RefCounted
	_expect(replacement != null and int(replacement.get("run_seed")) == 13579, "approved overwrite commits the new Run")
	_expect(loader.call("abandon_run") == OK, "RunManager abandons active Run")
	_expect(not bool(loader.call("can_continue")), "Continue becomes unavailable after abandon")
	loader.queue_free()
	await process_frame

	var corrupt_file: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	corrupt_file.store_buffer(PackedByteArray([9, 8, 7]))
	corrupt_file.close()
	var invalid_loader: Node = manager_script.new() as Node
	invalid_loader.call("configure_save_path", TEST_PATH)
	root.add_child(invalid_loader)
	await process_frame
	_expect(not bool(invalid_loader.call("can_continue")), "corrupt Run is never exposed through Continue")
	_expect(not FileAccess.file_exists(TEST_PATH), "corrupt active Run is safely invalidated")
	invalid_loader.queue_free()
	_cleanup()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	print("[PASS] RunManager test" if not failed else "[FAIL] RunManager test")
	quit(1 if failed else 0)

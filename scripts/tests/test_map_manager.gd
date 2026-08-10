extends SceneTree

const TEST_PATH := "user://pixelking_map_manager_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager_script: Script = load("res://scripts/autoload/RunManager.gd") as Script
	var manager: AppRunManager = manager_script.new() as AppRunManager
	manager.configure_save_path(TEST_PATH)
	root.add_child(manager)
	await process_frame
	_expect(manager.create_run(7654321, RunState.MODE_STANDARD, true), "map manager test creates a Run")
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		_expect(manager.submit_opening_draft_choice(str(candidates[0])) == OK, "manager commits draft selection")
	_expect(manager.resume_scene_path().ends_with("PathMapScene.tscn"), "completed draft resumes at route map")
	_expect(manager.ensure_run_map() == OK, "RunManager generates and saves route map transactionally")
	var map_snapshot: Dictionary = manager.current_run.map_state.to_dictionary()
	var rng_snapshot: Dictionary = manager.rng_service.snapshot_states()
	_expect(manager.ensure_run_map() == OK, "RunManager reuses persisted route map")
	_expect(manager.current_run.map_state.to_dictionary() == map_snapshot and manager.rng_service.snapshot_states() == rng_snapshot, "reopening map never rerolls it")
	var available: Array[StringName] = manager.available_map_node_ids()
	var selected_id: StringName = available[0]
	_expect(manager.select_map_node(selected_id) == OK, "RunManager selects an available node")
	var selected_snapshot: Dictionary = manager.current_run.to_dictionary()
	_expect(manager.select_map_node(&"not.a.real.node") != OK, "RunManager rejects unavailable node")
	_expect(manager.current_run.to_dictionary() == selected_snapshot, "failed manager selection preserves active Run")
	manager.queue_free()
	await process_frame

	var loader: AppRunManager = manager_script.new() as AppRunManager
	loader.configure_save_path(TEST_PATH)
	root.add_child(loader)
	await process_frame
	_expect(loader.load_active_run(), "RunManager reloads map progress")
	_expect(loader.current_run.map_state.to_dictionary() == map_snapshot, "reload preserves exact route topology")
	_expect(loader.current_run.current_node_id == selected_id, "reload preserves selected current node")
	_expect(loader.available_map_node_ids() == [selected_id], "unresolved node remains locked after reload")
	_expect(loader.resolve_current_map_node({"outcome": "prototype_success"}) == OK, "RunManager resolves current node transactionally")
	var current: MapNodeState = loader.current_run.map_state.get_node(selected_id)
	_expect(loader.available_map_node_ids() == current.outgoing_node_ids, "resolution unlocks only connected choices")
	loader.abandon_run()
	loader.queue_free()
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
	print("[PASS] Map manager test" if not failed else "[FAIL] Map manager test")
	quit(1 if failed else 0)

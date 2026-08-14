extends SceneTree

var failures: int = 0
var save_path: String = "user://test_complete_run.save"
var meta_path: String = "user://test_complete_run_meta.save"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = AppRunManager.new()
	root.add_child(manager)
	manager.configure_save_path(save_path)
	manager.meta_progress_service.save_path = meta_path
	_expect(manager.create_run(246813579, RunState.MODE_STANDARD, true), "complete flow creates a run")
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		_expect(manager.submit_opening_draft_choice(str(candidates[0])) == OK, "draft choice commits")
	_expect(manager.ensure_run_map() == OK, "route map is generated")
	var guard: int = 0
	while str(manager.current_run.pending_choice.get("type", "")) != "run_summary" and guard < 20:
		guard += 1
		var available: Array[StringName] = manager.available_map_node_ids()
		_expect(not available.is_empty(), "route exposes a next node")
		if available.is_empty():
			break
		_expect(manager.select_map_node(available[0]) == OK, "next route node is selected")
		var current: MapNodeState = manager.current_map_node()
		var definition: MapNodeDef = MapNodeDefDatabase.get_def(current.node_type_id)
		if definition.is_battle:
			_expect(manager.begin_deployment() == OK, "battle deployment begins")
			_expect(manager.apply_battle_outcome(true) == OK, "battle victory commits")
		else:
			_expect(manager.begin_current_run_interaction() == OK, "non-battle interaction is staged")
		_resolve_pending(manager)
	_expect(str(manager.current_run.pending_choice.get("type", "")) == "run_summary", "boss victory reaches run summary")
	_expect(bool(manager.current_run.run_statistics.get("run_won", false)), "summary records a won run")
	_expect(manager.resume_scene_path() == RunContentService.INTERACTION_SCENE, "summary is resumable")
	_expect(manager.finish_run_summary() == OK, "summary finalization commits meta progression")
	_expect(manager.current_run == null, "finished run clears active save")
	_expect(manager.endless_unlocked(), "standard victory unlocks endless mode")
	manager.queue_free()
	_cleanup()
	_finish()

func _resolve_pending(manager: AppRunManager) -> void:
	var pending: Dictionary = manager.current_run.pending_choice
	if pending.is_empty() or str(pending.get("type", "")) == "run_summary":
		return
	var options: Array = pending.get("options", []) as Array
	for value: Variant in options:
		if value is Dictionary and bool((value as Dictionary).get("enabled", true)):
			var id: String = str((value as Dictionary).get("id", ""))
			if manager.submit_run_interaction(id) == OK:
				return
	if bool(pending.get("allow_leave", false)):
		manager.leave_run_interaction()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)

func _cleanup() -> void:
	if FileAccess.file_exists(meta_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(meta_path))
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	if failures == 0:
		print("[PASS] Complete Run flow test")
		quit(0)
	else:
		print("[FAIL] Complete Run flow test")
		quit(1)

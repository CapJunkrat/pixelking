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
	var unlocked: Array[String] = []
	manager.achievements_unlocked.connect(func(ids: Array[String]) -> void: unlocked.append_array(ids))
	_expect(manager.create_run(246813579, RunState.MODE_STANDARD, true), "complete flow creates a run")
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		_expect(manager.submit_opening_draft_choice(str(candidates[0])) == OK, "draft choice commits")
	_expect(manager.ensure_run_map() == OK, "route map is generated")
	var guard: int = 0
	var acts_seen: Array[int] = []
	var act_three_seen: bool = false
	while manager.current_run.act_index < RunState.ACT_COUNT and guard < 80:
		guard += 1
		# The map screen does this on every visit; after a Boss it starts the next act.
		if manager.current_run.phase == RunPhase.MAP:
			_expect(manager.ensure_run_map() == OK, "the map is ready")
		if manager.current_run.act_index not in acts_seen:
			acts_seen.append(manager.current_run.act_index)
		var available: Array[StringName] = manager.available_map_node_ids()
		_expect(not available.is_empty(), "route exposes a next node")
		if available.is_empty():
			break
		_expect(manager.select_map_node(available[0]) == OK, "next route node is selected")
		var current: MapNodeState = manager.current_map_node()
		var definition: MapNodeDef = Content.map_node(current.node_type_id)
		if definition.is_battle:
			_expect(manager.begin_deployment() == OK, "battle deployment begins")
			_expect(manager.confirm_deployment() == OK, "battle deployment is confirmed")
			_expect(manager.start_current_battle() == OK, "confirmed battle starts")
			_expect(manager.apply_battle_outcome(true) == OK, "battle victory commits")
			if str(manager.current_run.pending_choice.get("description_key", "")) == "ACT_3_CLEARED_DESC":
				act_three_seen = true
				_expect(manager.current_run.pending_choice.get("title_key", "") == "ACT_CLEARED_TITLE", "the third Boss is an ordinary act-cleared reward")
				_expect("act_3" in unlocked, "beating the third Boss unlocks its achievement at once")
		else:
			_expect(manager.begin_current_run_interaction() == OK, "non-battle interaction is staged")
		_resolve_pending(manager)
	_expect(acts_seen.slice(0, 3) == ([0, 1, 2] as Array[int]), "the run goes through three acts, each on its own map")
	_expect(int(manager.current_run.run_statistics.get("acts_cleared", 0)) == 3, "all three acts are cleared")
	_expect(act_three_seen, "the third Boss's reward says the journey goes on")
	_expect(manager.current_run.act_index == RunState.ACT_COUNT and manager.current_run.map_state != null, "Act 4 begins on a new map with the same army")
	var stats: Dictionary = manager.lifetime_stats()
	_expect(int(stats.get("best_acts", 0)) == 3 and int(stats.get("total_runs", 0)) == 1, "lifetime records follow the journey (%s)" % [stats])
	_expect(int(stats.get("bosses", 0)) == 3, "three different Bosses are on record")
	_expect("first_steps" in unlocked and "act_3" in unlocked, "journey achievements unlock along the way")
	manager.abandon_run()
	manager.queue_free()
	_cleanup()
	_finish()

## Answers whatever the run asks until nothing is pending (a reward can lead to a
## fusion confirmation or a full-reserve choice).
func _resolve_pending(manager: AppRunManager) -> void:
	for _step: int in range(5):
		var pending: Dictionary = manager.current_run.pending_choice
		if pending.is_empty() or str(pending.get("type", "")) == "run_summary":
			return
		_answer(manager, pending)

func _answer(manager: AppRunManager, pending: Dictionary) -> void:
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

extends SceneTree

const TEST_PATH := "user://pixelking_roster_manager_test.save"

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
	_expect(RunTestFixture.create_drafted_run(manager) == OK, "roster manager fixture creates drafted Run and route")
	for instance_id: int in manager.current_run.reserve_piece_ids.duplicate():
		_expect(manager.move_roster_piece(instance_id, true) == OK, "RunManager transaction moves reserve piece active")
	var battle_node_id: StringName = &""
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		if MapNodeDefDatabase.get_def(node.node_type_id).is_battle:
			battle_node_id = node_id
			break
	_expect(not battle_node_id.is_empty(), "test seed offers an initial battle")
	manager.select_map_node(battle_node_id)
	_expect(manager.begin_deployment() == OK, "RunManager creates and saves pre-battle deployment")
	_expect(manager.resume_scene_path().ends_with("PreBattleScene.tscn"), "Continue resumes the pre-battle deployment stage")
	var king_id: int = manager.current_run.active_piece_ids[0]
	var original_king_position: Vector2i = manager.current_run.deployment_state.player_position(king_id)
	var target: Vector2i = Vector2i(0, 1)
	_expect(manager.move_deployed_piece(king_id, target) == OK, "RunManager transaction moves deployed King")
	_expect(manager.current_run.deployment_state.player_position(king_id) == target, "deployed King move commits")
	var non_king_id: int = manager.current_run.active_piece_ids[1]
	_expect(manager.move_roster_piece(non_king_id, false) == OK, "roster remains editable during deployment")
	_expect(not manager.current_run.deployment_state.player_positions.has(str(non_king_id)), "deployment synchronizes after moving piece to reserve")
	_expect(manager.move_roster_piece(non_king_id, true) == OK, "reserve piece can rejoin deployment")
	_expect(manager.current_run.deployment_state.player_positions.has(str(non_king_id)), "returning active piece receives a legal deployment square")
	var before_king_reserve: Dictionary = manager.current_run.to_dictionary()
	_expect(manager.move_roster_piece(king_id, false) == ERR_UNAUTHORIZED, "RunManager rejects moving King to reserve")
	_expect(manager.current_run.to_dictionary() == before_king_reserve, "failed King roster transaction has no side effects")
	_expect(manager.confirm_deployment() == OK and manager.current_run.deployment_state.confirmed, "RunManager confirms and saves deployment")
	var saved_deployment: Dictionary = manager.current_run.deployment_state.to_dictionary()
	manager.queue_free()
	await process_frame

	var loader: AppRunManager = manager_script.new() as AppRunManager
	loader.configure_save_path(TEST_PATH)
	root.add_child(loader)
	await process_frame
	_expect(loader.load_active_run(), "RunManager reloads deployment Run")
	_expect(loader.current_run.deployment_state.to_dictionary() == saved_deployment, "Continue restores exact pre-battle positions")
	_expect(loader.start_current_battle() == OK, "reloaded confirmed deployment starts its battle")
	_expect(loader.resolve_current_battle_node({"outcome": "test_victory"}) == OK, "battle resolution commits through dedicated transaction")
	_expect(loader.current_run.deployment_state == null, "resolved battle clears deployment snapshot")
	_expect(loader.current_run.resolved_node_payloads.has(String(battle_node_id)), "resolved battle unlocks map progress")
	_expect(loader.resume_scene_path().ends_with("PathMapScene.tscn"), "resolved battle resumes at route map")
	_expect(original_king_position != Vector2i(-1, -1), "initial King deployment was legal")
	loader.abandon_run()
	loader.queue_free()
	_cleanup()
	await _test_full_swap(manager_script)
	_cleanup()
	_finish()

## Both the line and the reserve full: a line piece and a reserve piece still trade places,
## on the roster screen and during deployment.
func _test_full_swap(manager_script: Script) -> void:
	var manager: AppRunManager = manager_script.new() as AppRunManager
	manager.configure_save_path(TEST_PATH)
	root.add_child(manager)
	await process_frame
	_expect(RunTestFixture.create_drafted_run(manager) == OK, "swap fixture creates a drafted Run")
	while manager.current_run.allocate_piece("pawn") != null:
		pass
	_expect(manager.current_run.reserve_piece_ids.size() == RunState.MAX_RESERVE_PIECES, "the reserve is full for the swap test")
	var line_id: int = manager.current_run.active_piece_ids[1]
	var bench_id: int = manager.current_run.reserve_piece_ids[2]
	_expect(manager.move_roster_piece(bench_id, true) != OK, "a full line refuses a plain move in")
	_expect(manager.swap_roster_pieces(line_id, bench_id) == OK, "a line piece and a reserve piece swap while both sides are full")
	_expect(bench_id in manager.current_run.active_piece_ids and manager.current_run.reserve_piece_ids[2] == line_id, "the swap trades list places")
	var king_id: int = manager.current_run.active_piece_ids[0]
	_expect(manager.swap_roster_pieces(king_id, line_id) == ERR_UNAUTHORIZED, "the King never swaps into the reserve")
	_expect(manager.swap_roster_pieces(line_id, bench_id) == ERR_UNAVAILABLE, "a swap needs one piece from each side")
	_expect(RunTestFixture.select_first_battle(manager) == OK and manager.begin_deployment() == OK, "a full roster deploys")
	var square: Vector2i = manager.current_run.deployment_state.player_position(bench_id)
	_expect(manager.swap_roster_pieces(bench_id, line_id) == OK, "pieces swap during deployment while both sides are full")
	_expect(manager.current_run.deployment_state.player_position(line_id) == square, "the reserve piece takes the square the line piece left")
	manager.abandon_run()
	manager.queue_free()
	await process_frame

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
	print("[PASS] Roster manager test" if not failed else "[FAIL] Roster manager test")
	quit(1 if failed else 0)

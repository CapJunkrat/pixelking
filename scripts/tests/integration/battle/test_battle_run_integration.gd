extends SceneTree

const TEST_PATH := "user://pixelking_battle_run_integration_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_expect(RunTestFixture.create_drafted_run(manager) == OK, "battle integration creates a drafted Run")
	var battle_node_id: StringName = RunTestFixture.first_battle_node_id(manager)
	_expect(not battle_node_id.is_empty(), "test seed exposes a first-layer battle")
	if battle_node_id.is_empty():
		manager.abandon_run()
		_cleanup()
		_finish()
		return
	manager.select_map_node(battle_node_id)
	manager.begin_deployment()
	manager.confirm_deployment()
	var game_state: Node = root.get_node("GameState")
	_expect(manager.start_current_battle() == OK, "confirmed Run deployment initializes prototype battle")
	var battle_scene: PackedScene = load("res://scenes/battle/BattleScene.tscn") as PackedScene
	var node_before: MapNodeState = manager.current_map_node()
	var army_before: Array = EncounterDefDatabase.for_node(manager.current_run, node_before).enemy_placements.duplicate(true)

	# A draw: fought again for free, the retry kept.
	var draw_battle: Control = await _finish_battle(battle_scene, game_state, -1, true)
	var draw_flow: Node = draw_battle.get_node("BattleFlow")
	_expect(manager.current_run.failed_battles == 0, "a draw is not counted as a failure")
	_expect(manager.current_run.retries_left == 1, "a draw keeps the run's retry")
	_expect(int(manager.current_run.run_statistics.get("battles_drawn", 0)) == 1, "a draw is counted as a draw")
	_expect(manager.current_run.pending_choice.is_empty() and manager.current_run.phase == RunPhase.DEPLOYMENT, "a draw goes straight back to deployment")
	_expect((draw_flow.get("exit_button") as Button).text == "Redeploy and Retry", "draw result offers to redeploy")
	_expect("retry is kept" in (draw_flow.get("result_detail") as Label).text, "draw result says the retry is kept")
	_expect(manager.current_map_node().node_id == node_before.node_id, "a draw keeps the same battle node")
	_expect(EncounterDefDatabase.for_node(manager.current_run, manager.current_map_node()).enemy_placements == army_before, "a draw is fought again against the same army")
	draw_battle.queue_free()
	await process_frame
	manager.confirm_deployment()
	_expect(manager.start_current_battle() == OK, "the drawn battle starts again")

	var battle: Control = await _finish_battle(battle_scene, game_state, GameRules.PieceColor.BLACK, false)
	var flow: Node = battle.get_node("BattleFlow")
	var defeat_exit: Button = flow.get("exit_button") as Button
	_expect(manager.current_run.failed_battles == 1, "defeat increments the Run failure counter")
	_expect(manager.current_run.retries_left == 0, "defeat spends the run's single retry")
	_expect(manager.current_run.pending_choice.is_empty() and manager.current_run.phase == RunPhase.DEPLOYMENT, "retryable defeat goes straight back to deployment")
	_expect(manager.resume_scene_path() == AppSceneRoutes.DEPLOYMENT, "defeated Run resumes at deployment")
	_expect(defeat_exit.text == "Redeploy and Retry", "defeat result offers to redeploy")
	manager.confirm_deployment()
	_expect(manager.start_current_battle() == OK, "retry starts from the confirmed deployment")
	_expect(manager.apply_battle_outcome(true) == OK, "subsequent victory resolves the encounter")
	_expect(manager.map_progress_service.is_current_node_resolved(manager.current_run), "victory resolves the selected Run node")
	_expect(str(manager.current_run.pending_choice.get("type", "")) == "battle_reward", "victory stages a persisted reward")
	battle.queue_free()
	manager.abandon_run()
	_cleanup()
	_finish()

## Mounts a battle scene, forces the result and waits for the result screen.
func _finish_battle(battle_scene: PackedScene, game_state: Node, winner: int, draw: bool) -> Control:
	var battle: Control = battle_scene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame
	var flow: Node = battle.get_node("BattleFlow")
	var processor: BattleCommandProcessor = game_state.get("command_processor") as BattleCommandProcessor
	var forced: BattleCommandResult = processor.force_finish(winner, draw, &"test_draw" if draw else &"test_defeat")
	game_state.call("_publish_command_result", forced)
	# The result banner plays out before the result screen.
	var guard: int = 0
	while not bool(flow.get("_result_presented")) and guard < 900:
		guard += 1
		await process_frame
	return battle

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
	print("[PASS] Battle Run integration test" if not failed else "[FAIL] Battle Run integration test")
	quit(1 if failed else 0)

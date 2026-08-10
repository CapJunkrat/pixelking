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
	_expect(manager.create_run(42424242, RunState.MODE_STANDARD, true), "battle integration creates a Run")
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		manager.submit_opening_draft_choice(str(candidates[0]))
	manager.ensure_run_map()
	var battle_node_id: StringName = &""
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		var definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
		if definition.is_battle:
			battle_node_id = node_id
			break
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
	_expect(bool(game_state.call("start_run_battle", manager.current_run)), "confirmed Run deployment initializes prototype battle")
	var battle_scene: PackedScene = load("res://scenes/battle/BattleScene.tscn") as PackedScene
	var battle: Control = battle_scene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame
	var flow: Node = battle.get_node("BattleFlow")
	flow.call("_show_result", true, false)
	await process_frame
	_expect(manager.map_progress_service.is_current_node_resolved(manager.current_run), "prototype victory resolves the selected Run node")
	var retry: Button = flow.get("retry_button") as Button
	var exit: Button = flow.get("exit_button") as Button
	_expect(not retry.visible, "victory prevents replaying an already resolved Run node")
	var localization: Node = root.get_node("Localization")
	_expect(exit.text == str(localization.call("text", "BATTLE_RESULT_MAP")), "Run battle result returns to the route map")
	battle.queue_free()
	manager.abandon_run()
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
	print("[PASS] Battle Run integration test" if not failed else "[FAIL] Battle Run integration test")
	quit(1 if failed else 0)

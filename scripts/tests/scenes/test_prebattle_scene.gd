extends SceneTree

## The pre-battle preview replaces the deployment step: it shows both sides on the
## board with the automatic formation, explains enemy pieces, swaps pieces between the
## battle line and the reserve, and starts the battle in one tap.

const TEST_PATH := "user://pixelking_prebattle_scene_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_prepare_battle_run(manager)
	_expect(manager.current_run.active_piece_ids.size() == 4, "the three drafted pieces join the battle line on their own")
	var scene: PackedScene = load(AppSceneRoutes.DEPLOYMENT) as PackedScene
	_expect(scene != null, "the pre-battle scene loads")
	var preview: PreBattleScene = scene.instantiate() as PreBattleScene
	root.add_child(preview)
	await process_frame
	await process_frame
	_expect(manager.current_run.phase == RunPhase.DEPLOYMENT, "opening the preview prepares the battle")
	var board: DeploymentBoardView = preview.get_node("SafeArea/Layout/BoardFrame") as DeploymentBoardView
	var deployment: DeploymentState = manager.current_run.deployment_state
	_expect(board.board_size == 8 and board.piece_count(true) == manager.current_run.active_piece_ids.size(), "the board shows every active piece")
	_expect(board.piece_count(false) == deployment.enemy_placements.size(), "the board shows the whole enemy formation")
	var king_id: int = manager.current_run.active_piece_ids[0]
	_expect(deployment.player_position(king_id) == Vector2i(4, 0), "the King stands in the middle of the back rank")

	var chips: HFlowContainer = preview.get_node("SafeArea/Layout/Details").get_child(0).get_node("EnemyPieces") as HFlowContainer
	_expect(chips != null and chips.get_child_count() > 0, "enemy pieces are listed")
	var pattern: PanelContainer = preview.get_node("SafeArea/Layout/Details").get_child(0).get_node("PiecePattern") as PanelContainer
	_expect(not pattern.visible, "no piece is explained until one is chosen")
	(chips.get_child(0) as Button).pressed.emit()
	await process_frame
	_expect(pattern.visible, "tapping an enemy piece shows how it moves")

	# Send one piece to the reserve and back: the formation follows the line-up.
	var moved_id: int = manager.current_run.active_piece_ids[1]
	var reserve_row: HBoxContainer = preview.get_node("SafeArea/Layout/Details").get_child(0).get_node("ReserveRow") as HBoxContainer
	var active_row: HBoxContainer = preview.get_node("SafeArea/Layout/Details").get_child(0).get_node("ActiveRow") as HBoxContainer
	(active_row.get_node("Piece_%d" % moved_id) as Button).pressed.emit()
	await process_frame
	_expect(moved_id in manager.current_run.reserve_piece_ids and board.piece_count(true) == 3, "tapping a battle-line piece sends it to the reserve")
	(reserve_row.get_node("Piece_%d" % moved_id) as Button).pressed.emit()
	await process_frame
	_expect(moved_id in manager.current_run.active_piece_ids and manager.current_run.deployment_state.player_position(moved_id).y <= 1, "tapping a reserve piece sends it back in and places it")

	(preview.get_node("SafeArea/Layout/Actions/FightButton") as Button).pressed.emit()
	await process_frame
	_expect(manager.current_run.phase == RunPhase.BATTLE_ACTIVE, "Fight starts the battle in one tap")
	manager.abandon_run()
	_cleanup()
	_finish()

func _prepare_battle_run(manager: AppRunManager) -> void:
	manager.create_run(42424242, RunState.MODE_STANDARD, true)
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		manager.submit_opening_draft_choice(str(candidates[0]))
	manager.ensure_run_map()
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		if MapNodeDefDatabase.get_def(node.node_type_id).is_battle:
			manager.select_map_node(node_id)
			break

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
	print("[PASS] Pre-battle scene test" if not failed else "[FAIL] Pre-battle scene test")
	quit(1 if failed else 0)

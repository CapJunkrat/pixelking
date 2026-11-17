extends SceneTree

const TEST_PATH := "user://pixelking_deployment_scene_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_prepare_battle_run(manager)
	var scene: PackedScene = load("res://scenes/run/DeploymentScene.tscn") as PackedScene
	_expect(scene != null, "deployment scene loads")
	var deployment_scene: DeploymentScene = scene.instantiate() as DeploymentScene
	root.add_child(deployment_scene)
	await process_frame
	var board: DeploymentBoardView = deployment_scene.get_node("SafeArea/Layout/BoardFrame") as DeploymentBoardView
	_expect(board != null and board.board_size == 8 and board.square_count() == 64, "deployment scene renders the complete standard 8 x 8 board")
	var round_trip: bool = true
	for y_position: int in range(8):
		for x_position: int in range(8):
			if board.projection.screen_to_square(board.square_center(Vector2i(x_position, y_position))) != Vector2i(x_position, y_position):
				round_trip = false
	_expect(round_trip, "every deployment square maps back to itself on the tilted board")
	_expect(board.square_center(Vector2i(0, 0)).y > board.square_center(Vector2i(0, 7)).y, "the player's deployment rows are nearest the viewer")
	_expect(board.piece_count(true) == manager.current_run.active_piece_ids.size(), "deployment shows every active player piece")
	_expect(board.piece_count(false) == manager.current_run.deployment_state.enemy_placements.size(), "deployment reveals complete enemy setup")
	_expect(board.get_node("PieceLayer").get_child_count() == board.piece_count(true) + board.piece_count(false), "every shown piece stands on the board as a sprite")
	var king_id: int = manager.current_run.active_piece_ids[0]
	var source: Vector2i = manager.current_run.deployment_state.player_position(king_id)
	var target: Vector2i = _empty_player_square(manager.current_run.deployment_state)
	var king_sprite: Sprite2D = board.get_node("PieceLayer/Piece_%d_%d" % [source.x, source.y]) as Sprite2D
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = king_sprite.position + Vector2(0, -10)
	board._gui_input(tap)
	await process_frame
	_expect(deployment_scene.selected_instance_id == king_id and board.selected_square == source, "tapping a standing piece picks it up")
	_expect(board.square_at(board.square_center(target)) == target, "an empty deployment square wins the tap while a piece is in hand")
	board.press_square(target)
	await process_frame
	_expect(manager.current_run.deployment_state.player_position(king_id) == target, "board interaction freely repositions the King")
	var swap_a: int = manager.current_run.active_piece_ids[0]
	var swap_b: int = manager.current_run.active_piece_ids[1]
	var swap_a_before: Vector2i = manager.current_run.deployment_state.player_position(swap_a)
	var swap_b_before: Vector2i = manager.current_run.deployment_state.player_position(swap_b)
	board.press_square(swap_a_before)
	await process_frame
	board.press_square(swap_b_before)
	await process_frame
	_expect(manager.current_run.deployment_state.player_position(swap_a) == swap_b_before, "clicking a second deployed piece moves the selected piece to its square")
	_expect(manager.current_run.deployment_state.player_position(swap_b) == swap_a_before, "clicking a second deployed piece swaps both positions")
	_expect(deployment_scene.selected_instance_id == 0, "successful swap clears the selected piece")
	_expect(board.selected_square == Vector2i(-1, -1), "successful swap clears the board highlight")
	board.press_square(Vector2i(3, 4))
	await process_frame
	_expect(manager.current_run.deployment_state.player_position(swap_a) == swap_b_before, "tapping outside the deployment rows moves nothing")
	_expect(deployment_scene.get_node("SafeArea/Layout/Actions/RosterButton") != null, "deployment provides roster management access")
	_expect(not (deployment_scene.get_node("SafeArea/Layout/Actions/ConfirmButton") as Button).disabled, "valid deployment enables battle confirmation")
	deployment_scene.queue_free()
	manager.abandon_run()
	_cleanup()
	_finish()

func _prepare_battle_run(manager: AppRunManager) -> void:
	manager.create_run(42424242, RunState.MODE_STANDARD, true)
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		manager.submit_opening_draft_choice(str(candidates[0]))
	for instance_id: int in manager.current_run.reserve_piece_ids.duplicate():
		manager.move_roster_piece(instance_id, true)
	manager.ensure_run_map()
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		if MapNodeDefDatabase.get_def(node.node_type_id).is_battle:
			manager.select_map_node(node_id)
			break
	manager.begin_deployment()

func _empty_player_square(deployment: DeploymentState) -> Vector2i:
	for y_position: int in range(2):
		for x_position: int in range(deployment.board_size):
			var position: Vector2i = Vector2i(x_position, y_position)
			if deployment.player_at(position) == 0:
				return position
	return Vector2i(-1, -1)

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
	print("[PASS] Deployment scene test" if not failed else "[FAIL] Deployment scene test")
	quit(1 if failed else 0)

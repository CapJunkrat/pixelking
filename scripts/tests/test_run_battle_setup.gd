extends SceneTree

const TEST_PATH := "user://pixelking_run_battle_setup_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_prepare_battle_run(manager)
	var deployment_snapshot: Dictionary = manager.current_run.deployment_state.to_dictionary()
	var game_state: Node = root.get_node("GameState")
	_expect(bool(game_state.call("start_run_battle", manager.current_run)), "confirmed deployment builds Run battle board")
	var board: BoardState = game_state.get("board") as BoardState
	_expect(board != null and board.board_size == 5, "Run battle uses deployment board size")
	var white_count: int = 0
	var black_count: int = 0
	var persistent_positions_match: bool = true
	for x_position: int in range(board.board_size):
		for y_position: int in range(board.board_size):
			var runtime_piece: ChessPiece = board.get_piece(Vector2i(x_position, y_position))
			if runtime_piece == null:
				continue
			if runtime_piece.color == GameRules.PieceColor.WHITE:
				white_count += 1
				var expected: Vector2i = manager.current_run.deployment_state.player_position(runtime_piece.instance_id)
				persistent_positions_match = persistent_positions_match and expected == Vector2i(x_position, y_position)
			else:
				black_count += 1
	_expect(white_count == manager.current_run.active_piece_ids.size(), "battle contains every active Run piece")
	_expect(black_count == manager.current_run.deployment_state.enemy_placements.size(), "battle contains complete previewed enemy setup")
	_expect(persistent_positions_match, "battle preserves persistent piece IDs and chosen positions")
	_expect(board.king_pos.has(GameRules.PieceColor.WHITE) and board.king_pos.has(GameRules.PieceColor.BLACK), "both Kings are registered for legal move checks")
	var moved: bool = _make_first_legal_move(game_state, board)
	_expect(moved, "Run battle accepts a legal move from deployed position")
	_expect(manager.current_run.deployment_state.to_dictionary() == deployment_snapshot, "mid-battle moves never overwrite pre-deployment snapshot")
	game_state.call("start_new_game")
	_expect(manager.current_run.deployment_state.to_dictionary() == deployment_snapshot, "leaving battle restores saved pre-deployment state")
	_expect(manager.resume_scene_path().ends_with("DeploymentScene.tscn"), "Continue returns an unresolved battle to deployment")
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
	manager.confirm_deployment()

func _make_first_legal_move(game_state: Node, board: BoardState) -> bool:
	for x_position: int in range(board.board_size):
		for y_position: int in range(board.board_size):
			var from: Vector2i = Vector2i(x_position, y_position)
			var piece: ChessPiece = board.get_piece(from)
			if piece == null or piece.color != GameRules.PieceColor.WHITE:
				continue
			var legal_moves: Array[Vector2i] = board.get_legal_moves(from)
			if not legal_moves.is_empty():
				return bool(game_state.call("try_move", from, legal_moves[0]))
	return false

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
	print("[PASS] Run battle setup test" if not failed else "[FAIL] Run battle setup test")
	quit(1 if failed else 0)

extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var board: BoardState = BoardState.new()
	board.remove_all_pawns()
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var move: MoveAction = MoveAction.new(Vector2i(1, 0), Vector2i(0, 2), GameRules.PieceColor.WHITE)
	var result: BattleCommandResult = processor.execute(move)
	_expect(result.success, "command processor executes a legal MoveAction")
	_expect(board.get_piece(Vector2i(0, 2)) != null, "MoveAction mutates the authoritative board")
	_expect(board.turn == GameRules.PieceColor.BLACK, "MoveAction advances the authoritative turn")

	var wrong_actor: MoveAction = MoveAction.new(Vector2i(1, 4), Vector2i(0, 2), GameRules.PieceColor.WHITE)
	var rejected: BattleCommandResult = processor.execute(wrong_actor)
	_expect(not rejected.success and rejected.error == &"wrong_turn", "command processor rejects an action from the wrong actor")
	_expect(board.turn == GameRules.PieceColor.BLACK, "rejected command leaves turn unchanged")

	var game_state: Node = root.get_node("GameState")
	game_state.call("start_new_game")
	var facade_success: bool = bool(game_state.call("try_move", Vector2i(1, 0), Vector2i(0, 2)))
	var facade_result: BattleCommandResult = game_state.get("last_command_result") as BattleCommandResult
	_expect(facade_success and facade_result != null and facade_result.success, "legacy try_move delegates to the command processor")
	print("[PASS] Battle command processor test" if not failed else "[FAIL] Battle command processor test")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

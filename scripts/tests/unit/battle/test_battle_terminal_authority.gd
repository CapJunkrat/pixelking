extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_king_capture_finishes_once()
	_test_initial_draw_is_evaluated_by_processor()
	_test_turn_limit_uses_same_authority()
	_finish()

func _test_king_capture_finishes_once() -> void:
	var board: BoardState = BoardState.new(5, false)
	board.clear_for_setup()
	board.place_piece_for_setup(Vector2i(0, 0), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(4, 4), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.BLACK))
	board.place_piece_for_setup(Vector2i(4, 0), ChessPiece.new(PieceDefDatabase.get_def("rook"), GameRules.PieceColor.WHITE))
	board.finalize_setup(GameRules.PieceColor.WHITE)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(4, 0), Vector2i(4, 4), GameRules.PieceColor.WHITE))
	_expect(result.success and processor.status.is_finished(), "king capture finishes authoritative BattleStatus")
	_expect(processor.status.winner == GameRules.PieceColor.WHITE and processor.status.reason == &"king_captured", "BattleStatus stores winner and reason")
	_expect(_event_count(result.events, BattleCommandProcessor.EVENT_BATTLE_ENDED) == 1, "terminal command emits exactly one battle-ended event")
	var board_after_finish: String = board.to_ascii()
	var rejected: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(0, 0), Vector2i(1, 0), GameRules.PieceColor.BLACK))
	_expect(not rejected.success and rejected.error == &"battle_already_finished", "processor rejects commands after terminal state")
	_expect(board.to_ascii() == board_after_finish, "post-terminal command leaves board unchanged")
	_expect(_event_count(rejected.events, BattleCommandProcessor.EVENT_BATTLE_ENDED) == 0, "post-terminal rejection emits no duplicate battle-ended event")

func _test_initial_draw_is_evaluated_by_processor() -> void:
	var board: BoardState = BoardState.new(5, false)
	board.clear_for_setup()
	board.place_piece_for_setup(Vector2i(0, 0), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(4, 4), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.BLACK))
	board.finalize_setup(GameRules.PieceColor.WHITE)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var result: BattleCommandResult = processor.evaluate_terminal_state()
	_expect(result != null and result.success, "processor evaluates terminal initial board without UI rules")
	_expect(processor.status.draw and processor.status.reason == &"two_lone_kings", "initial terminal evaluation records draw reason")
	_expect(processor.evaluate_terminal_state() == null, "terminal initial board cannot finish twice")

func _test_turn_limit_uses_same_authority() -> void:
	var board: BoardState = BoardState.new()
	board.remove_all_pawns()
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board, [], GameRules.PieceColor.WHITE, 1)
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(1, 0), Vector2i(0, 2), GameRules.PieceColor.WHITE))
	_expect(result.success and processor.status.is_finished(), "turn-limit objective finishes through BattleStatus")
	_expect(processor.status.reason == &"objective_turn_limit" and processor.status.winner == GameRules.PieceColor.BLACK, "turn-limit outcome is authoritative")

func _event_count(events: Array[BattleEvent], event_type: StringName) -> int:
	var count: int = 0
	for event: BattleEvent in events:
		if event.event_type == event_type:
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _finish() -> void:
	print("[PASS] Battle terminal authority test" if not failed else "[FAIL] Battle terminal authority test")
	quit(1 if failed else 0)

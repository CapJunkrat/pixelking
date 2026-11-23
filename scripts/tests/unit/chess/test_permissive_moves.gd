extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var board: BoardState = BoardState.new(8, false)
	_place_kings(board, Vector2i(4, 0), Vector2i(0, 7))
	board.set_piece(Vector2i(4, 3), _piece("knight", GameRules.PieceColor.WHITE))
	board.set_piece(Vector2i(4, 7), _piece("rook", GameRules.PieceColor.BLACK))
	var pinned_target: Vector2i = Vector2i(5, 5)
	_expect(pinned_target not in board.get_legal_moves(Vector2i(4, 3)), "strict chess analysis still identifies the pinned move")
	_expect(pinned_target in board.get_executable_moves(Vector2i(4, 3)), "PixelKing permits a move that exposes its king")
	_expect(board.is_move_dangerous(Vector2i(4, 3), pinned_target), "exposing the king marks the destination dangerous")
	var result: MoveOutcome = BattleTestFixture.play(board, Vector2i(4, 3), pinned_target)
	_expect(result.success, "authoritative move execution accepts the dangerous move")

	var danger_board: BoardState = BoardState.new(8, false)
	_place_kings(danger_board, Vector2i(0, 0), Vector2i(7, 7))
	danger_board.set_piece(Vector2i(1, 0), _piece("rook", GameRules.PieceColor.WHITE))
	danger_board.set_piece(Vector2i(2, 7), _piece("rook", GameRules.PieceColor.BLACK))
	_expect(danger_board.is_move_dangerous(Vector2i(1, 0), Vector2i(2, 0)), "an en-prise non-king destination is marked dangerous")
	_expect(Vector2i(2, 0) in danger_board.get_executable_moves(Vector2i(1, 0)), "an en-prise non-king move remains executable")

	var capture_board: BoardState = BoardState.new(5, false)
	_place_kings(capture_board, Vector2i(0, 0), Vector2i(1, 1))
	var capture_result: MoveOutcome = BattleTestFixture.play(capture_board, Vector2i(0, 0), Vector2i(1, 1))
	_expect(capture_result.king_captured, "capturing an exposed king is reported explicitly")
	_expect(not capture_board.has_king(GameRules.PieceColor.BLACK), "captured king is removed from authoritative tracking")
	_finish()

func _place_kings(board: BoardState, white_pos: Vector2i, black_pos: Vector2i) -> void:
	board.set_piece(white_pos, _piece("king", GameRules.PieceColor.WHITE))
	board.set_piece(black_pos, _piece("king", GameRules.PieceColor.BLACK))
	board.king_pos[GameRules.PieceColor.WHITE] = white_pos
	board.king_pos[GameRules.PieceColor.BLACK] = black_pos
	board.turn = GameRules.PieceColor.WHITE

func _piece(id: String, color: int) -> ChessPiece:
	return ChessPiece.new(PieceDefDatabase.get_def(id), color)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("[PASS] Permissive move test" if failures == 0 else "[FAIL] Permissive move test")
	quit(0 if failures == 0 else 1)

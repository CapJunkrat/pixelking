class_name BattleTestFixture
extends RefCounted

static func standard_board(turn: int = GameRules.PieceColor.WHITE, remove_pawns: bool = false) -> BoardState:
	var board: BoardState = BoardState.new()
	if remove_pawns:
		board.remove_all_pawns()
	board.turn = turn
	return board

static func minimal_kings_board(turn: int = GameRules.PieceColor.WHITE) -> BoardState:
	var board: BoardState = BoardState.new(5, false)
	board.clear_for_setup()
	board.place_piece_for_setup(Vector2i(0, 0), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(4, 4), ChessPiece.new(PieceDefDatabase.get_def("king"), GameRules.PieceColor.BLACK))
	board.finalize_setup(turn)
	return board

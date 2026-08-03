class_name PawnMovementRule
extends MovementRule

func rule_id() -> StringName:
	return &"pawn"

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var forward := 1 if piece.color == GameRules.PieceColor.WHITE else -1
	var start_rank := 1 if piece.color == GameRules.PieceColor.WHITE else board.board_size - 2

	var one_step := pos + Vector2i(0, forward)
	if board.in_bounds(one_step) and board.get_piece(one_step) == null:
		moves.append(one_step)
		var two_step := pos + Vector2i(0, forward * 2)
		if pos.y == start_rank and board.in_bounds(two_step) and board.get_piece(two_step) == null:
			moves.append(two_step)

	for dx in [-1, 1]:
		var capture_pos := pos + Vector2i(dx, forward)
		if not board.in_bounds(capture_pos):
			continue
		var occupant := board.get_piece(capture_pos)
		if occupant != null and occupant.color != piece.color:
			moves.append(capture_pos)
		elif capture_pos == board.en_passant_target:
			moves.append(capture_pos)
	return moves

func get_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var forward := 1 if piece.color == GameRules.PieceColor.WHITE else -1
	var squares: Array[Vector2i] = []
	for dx in [-1, 1]:
		var target := pos + Vector2i(dx, forward)
		if board.in_bounds(target):
			squares.append(target)
	return squares

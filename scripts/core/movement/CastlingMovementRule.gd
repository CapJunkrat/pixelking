class_name CastlingMovementRule
extends MovementRule

@export var partner_piece_ids: Array[StringName] = [&"rook"]

func rule_id() -> StringName:
	return &"castling"

## PixelKing castling is intentionally a king-rook position swap, not standard chess castling.
func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	if piece.has_moved:
		return moves
	var enemy := GameRules.opposite(piece.color)
	if board.is_square_attacked(pos, enemy):
		return moves

	for direction: int in [-1, 1]:
		var x := pos.x + direction
		var path_is_safe := true
		while x >= 0 and x < board.board_size:
			var target := Vector2i(x, pos.y)
			var occupant := board.get_piece(target)
			if occupant == null:
				if board.is_square_attacked(target, enemy):
					path_is_safe = false
				x += direction
				continue
			if (
				path_is_safe
				and not board.is_square_attacked(target, enemy)
				and is_valid_partner(piece, occupant)
			):
				moves.append(target)
			break
	return moves

func get_attack_squares(_board: BoardState, _pos: Vector2i, _piece: ChessPiece) -> Array[Vector2i]:
	return []

func is_valid_partner(piece: ChessPiece, candidate: ChessPiece) -> bool:
	return (
		candidate.color == piece.color
		and StringName(candidate.def.id) in partner_piece_ids
		and not candidate.has_moved
	)

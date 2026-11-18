class_name SwapWithKingMovementRule
extends MovementRule

## Once per battle: trade places with the own King, at any distance.
const ABILITY: StringName = &"swap_king"

func rule_id() -> StringName:
	return &"swap_king"

func get_moves(board: BoardState, _pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	if piece.has_used(ABILITY) or not board.has_king(piece.color):
		return []
	return [board.king_pos[piece.color]]

func get_attack_squares(_board: BoardState, _pos: Vector2i, _piece: ChessPiece) -> Array[Vector2i]:
	return []

func action_kind(board: BoardState, from: Vector2i, to: Vector2i, piece: ChessPiece) -> StringName:
	return ABILITY if to in get_moves(board, from, piece) else &""

func borrowable() -> bool:
	return false

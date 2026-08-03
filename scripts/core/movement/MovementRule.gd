class_name MovementRule
extends Resource

func rule_id() -> StringName:
	return &""

func get_moves(_board: BoardState, _pos: Vector2i, _piece: ChessPiece) -> Array[Vector2i]:
	return []

func get_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	return get_moves(board, pos, piece)

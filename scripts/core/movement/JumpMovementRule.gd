class_name JumpMovementRule
extends MovementRule

@export var offsets: Array[Vector2i] = []

func rule_id() -> StringName:
	return &"jump"

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for offset in offsets:
		var target := pos + offset
		if not board.in_bounds(target):
			continue
		var occupant := board.get_piece(target)
		if occupant == null or occupant.color != piece.color:
			moves.append(target)
	return moves

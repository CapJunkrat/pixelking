class_name SlideMovementRule
extends MovementRule

@export var directions: Array[Vector2i] = []
@export var max_distance: int = 8

func rule_id() -> StringName:
	return &"slide"

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for direction in directions:
		var distance := 1
		while distance <= max_distance:
			var target := pos + direction * distance
			if not board.in_bounds(target):
				break
			var occupant := board.get_piece(target)
			if occupant == null:
				moves.append(target)
			else:
				if occupant.color != piece.color:
					moves.append(target)
				break
			distance += 1
	return moves

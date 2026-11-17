class_name SlideMovementRule
extends MovementRule

@export var directions: Array[Vector2i] = []
@export var min_distance: int = 1
@export var max_distance: int = 8
@export var allow_empty_destinations: bool = true
@export var allow_captures: bool = true
@export var jump_over_occupied: bool = false

func rule_id() -> StringName:
	return &"slide"

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	return _collect(board, pos, piece, false)

func get_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	if not allow_captures:
		return []
	return _collect(board, pos, piece, true)

func _collect(board: BoardState, pos: Vector2i, piece: ChessPiece, attacks_only: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var minimum: int = maxi(1, min_distance)
	for direction: Vector2i in directions:
		for distance: int in range(1, max_distance + 1):
			var target: Vector2i = pos + direction * distance
			if not board.in_bounds(target):
				break
			var occupant: ChessPiece = board.get_piece(target)
			if occupant == null:
				if distance >= minimum and (attacks_only or allow_empty_destinations):
					result.append(target)
				continue
			if distance >= minimum and (attacks_only or (allow_captures and occupant.color != piece.color)):
				result.append(target)
			if not jump_over_occupied:
				break
	return result

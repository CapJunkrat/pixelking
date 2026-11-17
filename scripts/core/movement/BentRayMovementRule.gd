class_name BentRayMovementRule
extends MovementRule

@export var initial_directions: Array[Vector2i] = []
@export var ray_directions: Array[Vector2i] = []
@export var max_distance: int = 8

func rule_id() -> StringName:
	return &"bent_ray"

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	return _collect(board, pos, piece, false)

func get_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	return _collect(board, pos, piece, true)

func _collect(board: BoardState, pos: Vector2i, piece: ChessPiece, attacks_only: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for initial_direction: Vector2i in initial_directions:
		var corner: Vector2i = pos + initial_direction
		if not board.in_bounds(corner) or board.get_piece(corner) != null:
			continue
		for ray_direction: Vector2i in ray_directions:
			for distance: int in range(1, max_distance + 1):
				var target: Vector2i = corner + ray_direction * distance
				if not board.in_bounds(target):
					break
				var occupant: ChessPiece = board.get_piece(target)
				if occupant == null:
					if target not in result:
						result.append(target)
					continue
				if (attacks_only or occupant.color != piece.color) and target not in result:
					result.append(target)
				break
	return result

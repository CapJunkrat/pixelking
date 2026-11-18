class_name SlideMovementRule
extends MovementRule

@export var directions: Array[Vector2i] = []
@export var min_distance: int = 1
@export var max_distance: int = 8
@export var allow_empty_destinations: bool = true
@export var allow_captures: bool = true
@export var jump_over_occupied: bool = false
## Directions are written for White; Black mirrors them vertically (forward-only pieces).
@export var relative_to_color: bool = false
## Captures from this rule hit from a distance: the piece stays on its square.
@export var ranged: bool = false

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
	for raw_direction: Vector2i in directions:
		var direction: Vector2i = raw_direction
		if relative_to_color and piece.color == GameRules.PieceColor.BLACK:
			direction.y = -direction.y
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

func action_kind(board: BoardState, from: Vector2i, to: Vector2i, piece: ChessPiece) -> StringName:
	if not ranged:
		return &""
	var target: ChessPiece = board.get_piece(to)
	if target != null and target.color != piece.color and to in get_moves(board, from, piece):
		return &"ranged"
	return &""

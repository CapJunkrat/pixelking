class_name RangeTeleportMovementRule
extends MovementRule

## Teleports to an empty square within `radius` (king-step distance).
@export var radius: int = 3
## Only squares of the same board colour as the start square.
@export var same_color_square: bool = false
## Only squares the enemy does not attack.
@export var avoid_attacked: bool = false
## Non-empty: a once-per-battle ability with this id.
@export var once_ability: StringName = &""

func rule_id() -> StringName:
	return &"range_teleport"

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not once_ability.is_empty() and piece.has_used(once_ability):
		return result
	var enemy: int = GameRules.opposite(piece.color)
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			var target: Vector2i = pos + Vector2i(dx, dy)
			if target == pos or not board.in_bounds(target) or board.get_piece(target) != null:
				continue
			if same_color_square and (target.x + target.y) % 2 != (pos.x + pos.y) % 2:
				continue
			if avoid_attacked and board.is_square_attacked(target, enemy):
				continue
			result.append(target)
	return result

func get_attack_squares(_board: BoardState, _pos: Vector2i, _piece: ChessPiece) -> Array[Vector2i]:
	return []

func action_kind(board: BoardState, from: Vector2i, to: Vector2i, piece: ChessPiece) -> StringName:
	if once_ability.is_empty() or to not in get_moves(board, from, piece):
		return &""
	return once_ability

func borrowable() -> bool:
	return once_ability.is_empty()

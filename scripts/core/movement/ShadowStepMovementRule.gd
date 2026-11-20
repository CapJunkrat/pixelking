class_name ShadowStepMovementRule
extends MovementRule

const STEP: StringName = &"shadow_step"
const STRIKE: StringName = &"shadow_strike"

func rule_id() -> StringName:
	return STEP

## Geometry only: unlike radius teleport, these are exactly eight rays.
func candidates(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in BoardState.NEIGHBORS:
		for distance: int in range(1, 4):
			var target := pos + direction * distance
			if not board.in_bounds(target):
				continue
			var occupant := board.get_piece(target)
			if occupant == null or (occupant.color != piece.color and not occupant.is_shielded(board.turn_serial)):
				result.append(target)
	return result

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for target: Vector2i in candidates(board, pos, piece):
		if board.is_shadow_action_safe(pos, target):
			result.append(target)
	return result

## Attack maps describe geometry, never safety-filtered executable moves.
func get_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	return candidates(board, pos, piece)

func action_kind(board: BoardState, _from: Vector2i, to: Vector2i, _piece: ChessPiece) -> StringName:
	return STEP if board.get_piece(to) == null else STRIKE

func borrowable() -> bool:
	return false

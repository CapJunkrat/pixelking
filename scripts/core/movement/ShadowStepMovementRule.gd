class_name ShadowStepMovementRule
extends MovementRule

const STEP: StringName = &"shadow_step"
const STRIKE: StringName = &"shadow_strike"

func rule_id() -> StringName:
	return STEP

## How far the Shadow King reaches: every square of the 7x7 area around it.
const REACH := 3

## Geometry only: every square up to REACH away in any direction (a 7x7 area), over
## pieces and rocks; empty squares and enemies that are not shielded.
func candidates(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy: int in range(-REACH, REACH + 1):
		for dx: int in range(-REACH, REACH + 1):
			if dx == 0 and dy == 0:
				continue
			var target := pos + Vector2i(dx, dy)
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

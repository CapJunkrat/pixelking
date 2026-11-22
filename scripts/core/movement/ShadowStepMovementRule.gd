class_name ShadowStepMovementRule
extends MovementRule

const STEP: StringName = &"shadow_step"
const STRIKE: StringName = &"shadow_strike"

func rule_id() -> StringName:
	return STEP

## How far the Shadow King reaches along each of its eight lines.
const REACH := 3
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

## Geometry only: every square 1 to REACH away along a rank, file or diagonal (never a
## knight-like offset), over pieces and rocks; empty squares and enemies that are not
## shielded.
func candidates(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		for distance: int in range(1, REACH + 1):
			var target := pos + direction * distance
			# in_bounds() is false on rocks too: blink over them, never onto them.
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

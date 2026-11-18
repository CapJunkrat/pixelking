class_name MovementRule
extends Resource

func rule_id() -> StringName:
	return &""

func get_moves(_board: BoardState, _pos: Vector2i, _piece: ChessPiece) -> Array[Vector2i]:
	return []

func get_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	return get_moves(board, pos, piece)

## What executing this move means beyond an ordinary move or capture, e.g. &"ranged"
## (capture without moving) or a once-per-battle ability id. Empty for ordinary moves.
func action_kind(_board: BoardState, _from: Vector2i, _to: Vector2i, _piece: ChessPiece) -> StringName:
	return &""

## Whether pieces that copy other pieces' movement (echo, chameleon) may borrow this rule.
func borrowable() -> bool:
	return true

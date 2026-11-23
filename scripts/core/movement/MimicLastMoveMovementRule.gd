class_name MimicLastMoveMovementRule
extends BorrowedMovementRule

## Moves like the own side's most recently moved piece (never copies the opponent).
## Before anyone on its side has moved it steps one square like a King.
const FALLBACK_ID := "king"

func rule_id() -> StringName:
	return &"mimic_last_move"

func borrowed_defs(board: BoardState, piece: ChessPiece) -> Array[PieceDef]:
	var last_id: String = str(board.last_moved_def_id.get(piece.color, ""))
	var definition: PieceDef = Content.piece(last_id if not last_id.is_empty() else FALLBACK_ID)
	return [definition] if definition != null else []

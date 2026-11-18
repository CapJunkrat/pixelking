class_name LearnedMovesMovementRule
extends BorrowedMovementRule

## Moves like every piece this one has learned by capturing (ChessPiece.learned_def_ids).

func rule_id() -> StringName:
	return &"learned_moves"

func borrowed_defs(_board: BoardState, piece: ChessPiece) -> Array[PieceDef]:
	var result: Array[PieceDef] = []
	for id: String in piece.learned_def_ids:
		var definition: PieceDef = PieceDefDatabase.get_def(id)
		if definition != null:
			result.append(definition)
	return result

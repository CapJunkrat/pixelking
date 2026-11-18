class_name BorrowedMovementRule
extends MovementRule

## Base for rules that move like other pieces. Only borrowable rules are copied, so
## copies never chain into each other and never copy once-per-battle abilities.

func borrowed_defs(_board: BoardState, _piece: ChessPiece) -> Array[PieceDef]:
	return []

func borrowed_rules(board: BoardState, piece: ChessPiece) -> Array[MovementRule]:
	var result: Array[MovementRule] = []
	for definition: PieceDef in borrowed_defs(board, piece):
		if definition == null:
			continue
		for rule: MovementRule in definition.resolved_movement_rules():
			if rule != null and rule.borrowable() and rule not in result:
				result.append(rule)
	return result

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for rule: MovementRule in borrowed_rules(board, piece):
		for square: Vector2i in rule.get_moves(board, pos, piece):
			if square not in result:
				result.append(square)
	return result

func get_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for rule: MovementRule in borrowed_rules(board, piece):
		for square: Vector2i in rule.get_attack_squares(board, pos, piece):
			if square not in result:
				result.append(square)
	return result

func action_kind(board: BoardState, from: Vector2i, to: Vector2i, piece: ChessPiece) -> StringName:
	var kind: StringName = &"none"
	for rule: MovementRule in borrowed_rules(board, piece):
		if to not in rule.get_moves(board, from, piece):
			continue
		var rule_kind: StringName = rule.action_kind(board, from, to, piece)
		if rule_kind.is_empty():
			return &""
		kind = rule_kind
	return &"" if kind == &"none" else kind

func borrowable() -> bool:
	return false

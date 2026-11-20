class_name MoveGenerator
extends RefCounted

## Combines the movement strategies declared by PieceDef. New pieces can reuse
## existing rules in any combination without adding piece IDs to this class.
static func generate_pseudo_legal(board: BoardState, pos: Vector2i, geometry_only: bool = false) -> Array[Vector2i]:
	var piece := board.get_piece(pos)
	if piece == null or board.is_piece_immobilized(pos):
		return []

	var moves: Array[Vector2i] = []
	for rule in piece.def.resolved_movement_rules():
		if rule == null:
			continue
		var shadow: ShadowStepMovementRule = rule as ShadowStepMovementRule
		_append_unique(moves, shadow.candidates(board, pos, piece) if geometry_only and shadow != null else rule.get_moves(board, pos, piece))
	return _without_shielded(board, piece, moves)

static func get_attack_squares(board: BoardState, pos: Vector2i) -> Array[Vector2i]:
	var piece := board.get_piece(pos)
	if piece == null or board.is_piece_immobilized(pos):
		return []

	var squares: Array[Vector2i] = []
	for rule in piece.def.resolved_movement_rules():
		if rule == null:
			continue
		_append_unique(squares, rule.get_attack_squares(board, pos, piece))
	return _without_shielded(board, piece, squares)

## What executing from -> to means for this piece: &"" for an ordinary move or capture,
## &"ranged" for a capture from a distance, or a once-per-battle ability id. A move
## that any rule allows as an ordinary move is ordinary.
static func action_kind(board: BoardState, from: Vector2i, to: Vector2i) -> StringName:
	var piece: ChessPiece = board.get_piece(from)
	if piece == null:
		return &""
	var kind: StringName = &"none"
	for rule: MovementRule in piece.def.resolved_movement_rules():
		if rule == null:
			continue
		# Resolution must not re-enter executable safety during its own simulation.
		var shadow: ShadowStepMovementRule = rule as ShadowStepMovementRule
		var candidates: Array[Vector2i] = shadow.candidates(board, from, piece) if shadow != null else rule.get_moves(board, from, piece)
		if to not in candidates:
			continue
		var rule_kind: StringName = rule.action_kind(board, from, to, piece)
		if rule_kind.is_empty():
			return &""
		kind = rule_kind
	return &"" if kind == &"none" else kind

## The rule that makes from -> to a shot from a distance, or null.
static func ranged_rule(board: BoardState, from: Vector2i, to: Vector2i) -> MovementRule:
	var piece: ChessPiece = board.get_piece(from)
	if piece == null:
		return null
	for rule: MovementRule in piece.def.resolved_movement_rules():
		if rule == null or rule.action_kind(board, from, to, piece) != &"ranged":
			continue
		var borrowed: BorrowedMovementRule = rule as BorrowedMovementRule
		if borrowed != null:
			for inner: MovementRule in borrowed.borrowed_rules(board, piece):
				if inner.action_kind(board, from, to, piece) == &"ranged":
					return inner
		return rule
	return null

## Shielded enemies (martyr) can be neither captured nor attacked.
static func _without_shielded(board: BoardState, piece: ChessPiece, squares: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for square: Vector2i in squares:
		var occupant: ChessPiece = board.get_piece(square)
		if occupant != null and occupant.color != piece.color and occupant.is_shielded(board.turn_serial):
			continue
		result.append(square)
	return result

static func _append_unique(target: Array[Vector2i], additions: Array[Vector2i]) -> void:
	for square in additions:
		if square not in target:
			target.append(square)

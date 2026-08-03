class_name MoveGenerator
extends RefCounted

## Combines the movement strategies declared by PieceDef. New pieces can reuse
## existing rules in any combination without adding piece IDs to this class.
static func generate_pseudo_legal(board: BoardState, pos: Vector2i) -> Array[Vector2i]:
	var piece := board.get_piece(pos)
	if piece == null:
		return []

	var moves: Array[Vector2i] = []
	for rule in piece.def.resolved_movement_rules():
		if rule == null:
			continue
		_append_unique(moves, rule.get_moves(board, pos, piece))
	return moves

static func get_attack_squares(board: BoardState, pos: Vector2i) -> Array[Vector2i]:
	var piece := board.get_piece(pos)
	if piece == null:
		return []

	var squares: Array[Vector2i] = []
	for rule in piece.def.resolved_movement_rules():
		if rule == null:
			continue
		_append_unique(squares, rule.get_attack_squares(board, pos, piece))
	return squares

static func _append_unique(target: Array[Vector2i], additions: Array[Vector2i]) -> void:
	for square in additions:
		if square not in target:
			target.append(square)

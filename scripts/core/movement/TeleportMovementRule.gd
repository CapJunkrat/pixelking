class_name TeleportMovementRule
extends MovementRule

@export var capture_offsets: Array[Vector2i] = []

func rule_id() -> StringName:
	return &"teleport"

func get_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for x: int in range(board.board_size):
		for y: int in range(board.board_size):
			var target: Vector2i = Vector2i(x, y)
			if target != pos and board.in_bounds(target) and board.get_piece(target) == null:
				moves.append(target)
	for offset: Vector2i in capture_offsets:
		var target: Vector2i = pos + offset
		var occupant: ChessPiece = board.get_piece(target)
		if board.in_bounds(target) and occupant != null and occupant.color != piece.color:
			moves.append(target)
	return moves

func get_attack_squares(board: BoardState, pos: Vector2i, _piece: ChessPiece) -> Array[Vector2i]:
	var attacks: Array[Vector2i] = []
	for offset: Vector2i in capture_offsets:
		var target: Vector2i = pos + offset
		if board.in_bounds(target):
			attacks.append(target)
	return attacks

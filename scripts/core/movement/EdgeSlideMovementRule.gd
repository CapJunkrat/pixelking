class_name EdgeSlideMovementRule
extends MovementRule

## From a square on the outer ring, slides along the ring in either direction (turning
## corners) until blocked. Moves to empty squares only.

func rule_id() -> StringName:
	return &"edge_slide"

func get_moves(board: BoardState, pos: Vector2i, _piece: ChessPiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var ring: Array[Vector2i] = _ring(board.board_size)
	var start: int = ring.find(pos)
	if start < 0:
		return result
	for step: int in [1, -1]:
		var index: int = start
		for _i: int in range(ring.size() - 1):
			index = posmod(index + step, ring.size())
			var square: Vector2i = ring[index]
			if square == pos or board.get_piece(square) != null:
				break
			if square not in result:
				result.append(square)
	return result

func get_attack_squares(_board: BoardState, _pos: Vector2i, _piece: ChessPiece) -> Array[Vector2i]:
	return []

static func _ring(size: int) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	for x: int in range(size):
		ring.append(Vector2i(x, 0))
	for y: int in range(1, size):
		ring.append(Vector2i(size - 1, y))
	for x: int in range(size - 2, -1, -1):
		ring.append(Vector2i(x, size - 1))
	for y: int in range(size - 2, 0, -1):
		ring.append(Vector2i(0, y))
	return ring

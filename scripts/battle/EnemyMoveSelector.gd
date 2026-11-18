extends RefCounted
class_name EnemyMoveSelector

## Intentionally uses a shallow greedy policy so the opponent stays approachable.
## Chooses a legal action intent without owning UI, timing, or execution state.
func choose_action(board: BoardState, color: int) -> MoveAction:
	var move: Dictionary = choose_move(board, color)
	if move.is_empty():
		return null
	return MoveAction.new(move["from"], move["to"], color)

## Compatibility dictionary used by existing tests and score inspection.
func choose_move(board: BoardState, color: int) -> Dictionary:
	if board == null or board.turn != color:
		return {}
	var best_move: Dictionary = {}
	var best_score := -1000000000
	for x in range(board.board_size):
		for y in range(board.board_size):
			var from := Vector2i(x, y)
			var piece := board.get_piece(from)
			if piece == null or piece.color != color:
				continue
			for to in board.get_executable_moves_for_color(from, color):
				var score := _score_move(board, from, to, color)
				if score > best_score:
					best_score = score
					best_move = {"from": from, "to": to, "score": score}
	return best_move

func _score_move(board: BoardState, from: Vector2i, to: Vector2i, color: int) -> int:
	var score := 0
	var captured := board.get_piece(to)
	if captured != null:
		score += _piece_value(captured) * 10
	var simulation := board.clone()
	var result := simulation.make_move(from, to)
	if not result.get("success", false):
		return -1000000000
	if result.get("checkmate", false):
		return 100000000
	if result.get("check", false):
		score += 700
	var center := Vector2((board.board_size - 1) / 2.0, (board.board_size - 1) / 2.0)
	score += int(20.0 - Vector2(to).distance_squared_to(center))
	# Never hand the opponent a free King: a move that leaves our King capturable is
	# only worth it when nothing else is.
	if simulation.has_king(color) and simulation.is_square_attacked(simulation.king_pos[color], GameRules.opposite(color)):
		score -= 6000
	if simulation.is_square_attacked(to, GameRules.opposite(color)):
		var moved_piece := simulation.get_piece(to)
		if moved_piece != null:
			score -= _piece_value(moved_piece) * 2
	var source_piece: ChessPiece = board.get_piece(from)
	if captured != null and source_piece != null and source_piece.def.extra_move_on_capture:
		score += 250
	return score

func _piece_value(piece: ChessPiece) -> int:
	if piece == null or piece.def == null:
		return 0
	return 20000 if piece.def.is_king else maxi(1, piece.def.base_value) * 100


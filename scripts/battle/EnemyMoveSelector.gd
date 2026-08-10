extends RefCounted
class_name EnemyMoveSelector

const PIECE_VALUES := {
	"pawn": 100, "knight": 320, "bishop": 330,
	"rook": 500, "queen": 900, "king": 20000,
}

## Intentionally uses a shallow greedy policy so the opponent stays approachable.
## Chooses a legal move without owning UI or timing state.
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
			for to in board.get_legal_moves_for_color(from, color):
				var score := _score_move(board, from, to, color)
				if score > best_score:
					best_score = score
					best_move = {"from": from, "to": to, "score": score}
	return best_move

func _score_move(board: BoardState, from: Vector2i, to: Vector2i, color: int) -> int:
	var score := 0
	var captured := board.get_piece(to)
	if captured != null:
		score += int(PIECE_VALUES.get(captured.def.id, 0)) * 10
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
	if simulation.is_square_attacked(to, GameRules.opposite(color)):
		var moved_piece := simulation.get_piece(to)
		if moved_piece != null:
			score -= int(PIECE_VALUES.get(moved_piece.def.id, 0)) * 2
	return score

extends RefCounted
class_name EnemyMoveSelector

## How hard the enemy plays.
## EASY: a shallow greedy policy so the opponent stays approachable (the original AI).
## MEDIUM: the same scoring, then the most promising moves are checked against every
## capturing reply the player could make next, so the enemy stops leaving its King in
## check and stops handing out free pieces (a Shadow King's strike included: it returns
## home, so what it takes is never won back).
## HARD: looks several moves ahead within a time budget (EnemySearch).
const DIFFICULTY_EASY := "easy"
const DIFFICULTY_MEDIUM := "medium"
const DIFFICULTY_HARD := "hard"
const DIFFICULTIES: Array[String] = [DIFFICULTY_EASY, DIFFICULTY_MEDIUM, DIFFICULTY_HARD]

## Medium looks one reply deep at this many of its best-scoring moves (plus every
## capture), which keeps a turn fast on phones.
const MEDIUM_CANDIDATES := 12
## What losing the King costs in the reply check: more than any material.
const KING_LOSS := 10000000

var difficulty: String = DIFFICULTY_EASY
## Hard's time budget per move, in milliseconds.
var hard_budget_ms: int = EnemySearch.default_budget_ms()

static func is_valid_difficulty(value: String) -> bool:
	return value in DIFFICULTIES

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
	if difficulty == DIFFICULTY_MEDIUM:
		return _choose_medium(board, color)
	if difficulty == DIFFICULTY_HARD:
		var search: EnemySearch = EnemySearch.new()
		search.time_budget_ms = hard_budget_ms
		return search.search(board, color, EnemySearch.root_moves(board, color))
	var best_move: Dictionary = {}
	var best_score := -1000000000
	for move: Array in _all_moves(board, color):
		var score: int = int(_score_move(board, move[0], move[1], color, true)["score"])
		if score > best_score:
			best_score = score
			best_move = {"from": move[0], "to": move[1], "score": score}
	return best_move

func _all_moves(board: BoardState, color: int) -> Array:
	var moves: Array = []
	for x in range(board.board_size):
		for y in range(board.board_size):
			var from := Vector2i(x, y)
			var piece := board.get_piece(from)
			if piece == null or piece.color != color:
				continue
			for to in board.get_executable_moves_for_color(from, color):
				moves.append([from, to])
	return moves

## Scores every move as Easy does (without its rough "is the moved piece attacked"
## guesses), keeps the best few plus all captures, and takes off what the player's best
## capturing reply would win.
func _choose_medium(board: BoardState, color: int) -> Dictionary:
	var scored: Array = []
	for move: Array in _all_moves(board, color):
		var scoring: Dictionary = _score_move(board, move[0], move[1], color, false)
		if bool(scoring.get("valid", false)):
			scored.append({"from": move[0], "to": move[1], "score": int(scoring["score"]), "board": scoring["board"], "capture": bool(scoring.get("capture", false)), "wins": bool(scoring.get("wins", false))})
	if scored.is_empty():
		return {}
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left["score"]) > int(right["score"]))
	var best_move: Dictionary = {}
	var best_score := -1000000000
	for index: int in range(scored.size()):
		var entry: Dictionary = scored[index]
		if index >= MEDIUM_CANDIDATES and not bool(entry["capture"]):
			continue
		var score: int = int(entry["score"])
		if not bool(entry["wins"]):
			score -= worst_reply_loss(entry["board"] as BoardState, color)
		if score > best_score:
			best_score = score
			best_move = {"from": entry["from"], "to": entry["to"], "score": score}
	return best_move

## On `after` (the board right after `color` moved), the most the opponent can win with
## one capturing reply: the value of what it removes from `color`, minus what it loses
## itself (a blast can catch its own pieces), minus the attacker when `color` can then
## take it back where it ends up (a shooter or a Shadow King stays home). Taking the
## King costs KING_LOSS. Never below zero: the opponent can always just not capture.
func worst_reply_loss(after: BoardState, color: int) -> int:
	var enemy: int = GameRules.opposite(color)
	var board: BoardState = after.clone()
	board._hand_turn_to(enemy)
	board.process_revivals(enemy)
	var worst: int = 0
	for reply: Array in board._capture_replies(enemy):
		var attacker: ChessPiece = board.get_piece(reply[0])
		if attacker == null:
			continue
		var replied: BoardState = board.clone()
		var outcome: Dictionary = replied._apply_move(reply[0], reply[1], "queen", true)
		if not bool(outcome.get("success", false)):
			continue
		if bool(outcome.get("king_captured", false)) and int(outcome.get("captured_color", -1)) == color:
			return KING_LOSS
		var gain: int = 0
		var attacker_lost: bool = false
		for entry: Dictionary in outcome.get("removed", []):
			var value: int = _value_of(str(entry.get("piece_def_id", "")))
			if int(entry.get("color", enemy)) == color:
				gain += value * 10
			else:
				gain -= value * 10
				attacker_lost = attacker_lost or int(entry.get("instance_id", 0)) == attacker.instance_id
		if gain <= worst:
			continue
		var attacker_square: Vector2i = outcome.get("landing", reply[1])
		var survivor: ChessPiece = replied.get_piece(attacker_square)
		if not attacker_lost and survivor != null and survivor.instance_id == attacker.instance_id and replied.is_square_attacked(attacker_square, color):
			gain -= _piece_value(survivor) * 10
		worst = maxi(worst, gain)
	return worst

## {"valid", "score", "board" (after the move), "capture", "wins"}. `rough_safety` adds
## Easy's guesses about leaving the King or the moved piece attacked.
func _score_move(board: BoardState, from: Vector2i, to: Vector2i, color: int, rough_safety: bool) -> Dictionary:
	var score := 0
	var captured := board.get_piece(to)
	# A plain simulated step: the full checkmate search behind make_move() made every
	# enemy turn cost seconds, and a capture of the King already scores highest here.
	var simulation := board.clone()
	var result := simulation._apply_move(from, to, "queen", true)
	if not result.get("success", false):
		return {"valid": false, "score": -1000000000}
	if result.get("king_captured", false) and int(result.get("captured_color", -1)) != color:
		return {"valid": true, "score": 100000000, "board": simulation, "capture": true, "wins": true}
	# Everything the action removed: a boomerang or a blast can take several pieces,
	# and a blast can also catch our own.
	var removed: Array = result.get("removed", [])
	for entry: Dictionary in removed:
		var value: int = _value_of(str(entry.get("piece_def_id", "")))
		score += value * 10 if int(entry.get("color", color)) != color else -value * 10
	# Ranged shots leave the shooter where it stood.
	var landing: Vector2i = result.get("landing", to)
	var enemy: int = GameRules.opposite(color)
	if simulation.has_king(enemy) and simulation.is_square_attacked(simulation.king_pos[enemy], color):
		score += 700
	var center := Vector2((board.board_size - 1) / 2.0, (board.board_size - 1) / 2.0)
	score += int(20.0 - Vector2(landing).distance_squared_to(center))
	if rough_safety:
		# Never hand the opponent a free King: a move that leaves our King capturable is
		# only worth it when nothing else is.
		if simulation.has_king(color) and simulation.is_square_attacked(simulation.king_pos[color], enemy):
			score -= 6000
		if simulation.is_square_attacked(landing, enemy):
			var moved_piece := simulation.get_piece(landing)
			if moved_piece != null:
				score -= _piece_value(moved_piece) * 2
	var source_piece: ChessPiece = board.get_piece(from)
	if captured != null and source_piece != null and source_piece.def.extra_move_on_capture:
		score += 250
	return {"valid": true, "score": score, "board": simulation, "capture": captured != null or not removed.is_empty(), "wins": false}

func _value_of(def_id: String) -> int:
	var definition: PieceDef = PieceDefDatabase.get_def(def_id)
	if definition == null:
		return 0
	return 20000 if definition.is_king else maxi(1, definition.base_value) * 100

func _piece_value(piece: ChessPiece) -> int:
	if piece == null or piece.def == null:
		return 0
	return 20000 if piece.def.is_king else maxi(1, piece.def.base_value) * 100

extends RefCounted
class_name EnemySearch

## The Hard enemy: looks several moves ahead with the real rules.
##
## Iterative deepening alpha-beta (negamax): it searches 1 move ahead, then 2, then 3...
## until MAX_DEPTH or the time budget runs out, and plays the best move of the deepest
## search it finished. Each line ends with a capture-only search (every capture and
## recapture is played out), so it never stops looking in the middle of an exchange.
## A faster phone simply finishes deeper searches.
##
## Thread safety: `root_moves()` asks the rules for executable moves (the Shadow King's
## safety check uses a shared cache), so it must run on the main thread. `search()` only
## works on its own copy of the board and generates geometry-only moves, so it may run
## on a worker thread.

## Moves ahead the search stops at even with time left.
const MAX_DEPTH := 4
## Captures followed past the last move of a line.
const QUIESCENCE_DEPTH := 4
## How long a search may take: phones get at most 2 s. Web builds have no threads, so
## the search freezes the screen while it runs; it gets less time there.
const TIME_BUDGET_MS := 2000
const WEB_TIME_BUDGET_MS := 700
const MATE := 100000000
const INFINITY := 1000000000

var time_budget_ms: int = TIME_BUDGET_MS
## Set from another thread to stop a search early (the battle ended, the scene left).
var cancelled: bool = false

## What the last search did, for tests and tuning.
var last_depth: int = 0
var last_nodes: int = 0
var last_elapsed_ms: int = 0

var _deadline: int = 0
var _out_of_time: bool = false
var _nodes: int = 0
var _color: int = 0

static func default_budget_ms() -> int:
	return WEB_TIME_BUDGET_MS if OS.has_feature("web") else TIME_BUDGET_MS

## Every move `color` may really make now, as [from, to] pairs. Main thread only.
static func root_moves(board: BoardState, color: int) -> Array:
	var moves: Array = []
	for x: int in range(board.board_size):
		for y: int in range(board.board_size):
			var from: Vector2i = Vector2i(x, y)
			var piece: ChessPiece = board.get_piece(from)
			if piece == null or piece.color != color:
				continue
			for to: Vector2i in board.get_executable_moves_for_color(from, color):
				moves.append([from, to])
	return moves

## The best of `moves` for `color` on `board`: {"from", "to", "score", "depth"}, or {}
## when there is no move. `board` is not changed.
func search(board: BoardState, color: int, moves: Array) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	_deadline = started + time_budget_ms
	_out_of_time = false
	_nodes = 0
	_color = color
	last_depth = 0
	if moves.is_empty():
		return {}
	var root: BoardState = board.clone()
	var ordered: Array = _ordered(root, moves)
	var best: Dictionary = {"from": ordered[0][0], "to": ordered[0][1], "score": -INFINITY, "depth": 0}
	for depth: int in range(1, MAX_DEPTH + 1):
		var result: Dictionary = _search_root(root, color, ordered, depth)
		if _out_of_time and depth > 1:
			break
		if not result.is_empty():
			best = result
			best["depth"] = depth
			last_depth = depth
			# Search the best move first next time: it prunes the most.
			var first: Array = [result["from"], result["to"]]
			ordered.erase(first)
			ordered.push_front(first)
			if int(result["score"]) >= MATE / 2:
				break
		if _out_of_time:
			break
	last_nodes = _nodes
	last_elapsed_ms = Time.get_ticks_msec() - started
	return best

func _search_root(board: BoardState, color: int, moves: Array, depth: int) -> Dictionary:
	var alpha: int = -INFINITY
	var best: Dictionary = {}
	for move: Array in moves:
		var child: Array = _play(board, move, color)
		var score: int
		if int(child[1]) >= 0:
			score = MATE if int(child[1]) != color else -MATE
		else:
			score = -_negamax(child[0], GameRules.opposite(color), depth - 1, -INFINITY, -alpha, 1)
		if _out_of_time and depth > 1:
			return {}
		if best.is_empty() or score > alpha:
			alpha = score
			best = {"from": move[0], "to": move[1], "score": score}
	return best

func _negamax(board: BoardState, color: int, depth: int, alpha: int, beta: int, ply: int) -> int:
	if _check_time():
		return 0
	if depth <= 0:
		return _quiesce(board, color, alpha, beta, QUIESCENCE_DEPTH, ply)
	var moves: Array = _ordered(board, _moves(board, color))
	if moves.is_empty():
		return _evaluate(board, color)
	for move: Array in moves:
		var child: Array = _play(board, move, color)
		var score: int
		if int(child[1]) >= 0:
			# A King was taken: sooner is better for the winner.
			score = (MATE - ply) if int(child[1]) != color else -(MATE - ply)
		else:
			score = -_negamax(child[0], GameRules.opposite(color), depth - 1, -beta, -alpha, ply + 1)
		if _out_of_time:
			return 0
		if score >= beta:
			return beta
		alpha = maxi(alpha, score)
	return alpha

## Captures only, so a line never ends halfway through an exchange. Standing pat (not
## capturing) is always allowed.
func _quiesce(board: BoardState, color: int, alpha: int, beta: int, left: int, ply: int) -> int:
	if _check_time():
		return 0
	var stand: int = _evaluate(board, color)
	if stand >= beta:
		return beta
	alpha = maxi(alpha, stand)
	if left <= 0:
		return alpha
	for move: Array in _ordered(board, board._capture_replies(color, true)):
		var child: Array = _play(board, move, color)
		var score: int
		if int(child[1]) >= 0:
			score = (MATE - ply) if int(child[1]) != color else -(MATE - ply)
		else:
			score = -_quiesce(child[0], GameRules.opposite(color), -beta, -alpha, left - 1, ply + 1)
		if _out_of_time:
			return 0
		if score >= beta:
			return beta
		alpha = maxi(alpha, score)
	return alpha

## [the board after `move`, the color of a King it took or -1]. The turn passes to the
## other side (eggs due then hatch). Bonus actions are not followed inside the search.
func _play(board: BoardState, move: Array, color: int) -> Array:
	_nodes += 1
	var after: BoardState = board.clone()
	var result: Dictionary = after._apply_move(move[0], move[1], "queen", true)
	if not bool(result.get("success", false)):
		return [after, -1]
	if bool(result.get("king_captured", false)):
		return [after, int(result.get("captured_color", -1))]
	var enemy: int = GameRules.opposite(color)
	after._hand_turn_to(enemy)
	after.process_revivals(enemy)
	return [after, -1]

## Geometry-only moves: a Shadow King's unsafe blink is generated too, and the search
## refutes it by taking the King.
func _moves(board: BoardState, color: int) -> Array:
	var moves: Array = []
	for x: int in range(board.board_size):
		for y: int in range(board.board_size):
			var piece: ChessPiece = board.grid[x][y]
			if piece == null or piece.color != color:
				continue
			var from: Vector2i = Vector2i(x, y)
			for to: Vector2i in MoveGenerator.generate_pseudo_legal(board, from, true):
				moves.append([from, to])
	return moves

## Captures first, the most valuable victim first and the cheapest attacker first.
func _ordered(board: BoardState, moves: Array) -> Array:
	var keyed: Array = []
	for move: Array in moves:
		var victim: ChessPiece = board.get_piece(move[1])
		var key: int = 0
		if victim != null:
			var attacker: ChessPiece = board.get_piece(move[0])
			key = _value(victim) * 16 - (_value(attacker) / 100 if attacker != null else 0)
		keyed.append([key, move])
	keyed.sort_custom(func(left: Array, right: Array) -> bool: return int(left[0]) > int(right[0]))
	var result: Array = []
	for entry: Array in keyed:
		result.append(entry[1])
	return result

## The position from `color`'s side: material, with something extra for shells still
## to break and eggs still to hatch, and a little for central squares.
func _evaluate(board: BoardState, color: int) -> int:
	var score: int = 0
	var center: float = (board.board_size - 1) / 2.0
	for x: int in range(board.board_size):
		for y: int in range(board.board_size):
			var piece: ChessPiece = board.grid[x][y]
			if piece == null or piece.def.is_king:
				continue
			var worth: int = _value(piece)
			if piece.def.is_egg and piece.hatch_piece != null:
				worth = _value(piece.hatch_piece) / 2
			worth += piece.shell_left * worth / 3
			if piece.revives_left != 0:
				worth += worth / 4
			worth += 8 - int(absf(x - center) + absf(y - center)) * 2
			score += worth if piece.color == color else -worth
	return score

func _value(piece: ChessPiece) -> int:
	if piece == null or piece.def == null:
		return 0
	return 1000000 if piece.def.is_king else maxi(1, piece.def.base_value) * 100

## Checked at every node: once the time is up (or the search is cancelled) the search
## unwinds and the last finished depth is used.
func _check_time() -> bool:
	if not _out_of_time and (cancelled or Time.get_ticks_msec() >= _deadline):
		_out_of_time = true
	return _out_of_time

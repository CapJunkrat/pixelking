extends RefCounted
class_name BoardState

## Rule-engine implementation note.
const DEFAULT_SIZE := 8
const MIN_SIZE := 5
const VALID_PROMOTIONS := ["queen", "rook", "bishop", "knight"]
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var board_size: int = DEFAULT_SIZE
var grid: Array = []  # grid[x][y]rule ChessPiece ? null
var turn: int = GameRules.PieceColor.WHITE
var en_passant_target: Vector2i = Vector2i(-1, -1)
var move_history: Array = []
var king_pos: Dictionary = {}
var last_move_was_capture: bool = false
var halfmove_clock: int = 0
## Increments only when control passes to the opposing side. Bonus actions keep it stable.
var turn_serial: int = 0
## Definition id of each side's most recently moved piece (echo copies it).
var last_moved_def_id: Dictionary = {}
## Captured pieces waiting to come back: {"piece": ChessPiece, "ready_serial": int}.
var pending_revivals: Array = []
## Each blow on a hard egg delays its hatching by two of its owner's turns.
const EGG_DELAY_SERIALS := 4
## During a bonus action only this piece may act (0 = any piece).
var bonus_instance_id: int = 0
## Actions already taken by the side to move in this turn.
var actions_this_turn: int = 0
## Run-wide growth produced this battle, by instance id (string key):
## {"def_id": String, "capture_count": int, "learned": Array[String]}.
var growth: Dictionary = {}
## Rock squares (Vector2i -> true): not part of the playable board. Nothing stands on,
## moves to or targets a rock, sliding pieces stop in front of it, leapers hop over it.
var rocks: Dictionary = {}

func _init(p_board_size: int = DEFAULT_SIZE, setup_default: bool = true) -> void:
	board_size = maxi(p_board_size, MIN_SIZE)
	_create_empty_grid()
	if setup_default:
		setup_standard()

func _create_empty_grid() -> void:
	grid.clear()
	grid.resize(board_size)
	for x in range(board_size):
		grid[x] = []
		grid[x].resize(board_size)
		for y in range(board_size):
			grid[x][y] = null

## Rule-engine implementation note.
func setup_standard() -> void:
	_create_empty_grid()
	var back_rank := _default_back_rank()
	for x in range(board_size):
		_place(Vector2i(x, 0), back_rank[x], GameRules.PieceColor.WHITE)
		_place(Vector2i(x, 1), "pawn", GameRules.PieceColor.WHITE)
		_place(Vector2i(x, board_size - 2), "pawn", GameRules.PieceColor.BLACK)
		_place(Vector2i(x, board_size - 1), back_rank[x], GameRules.PieceColor.BLACK)

	var king_file := back_rank.find("king")
	king_pos[GameRules.PieceColor.WHITE] = Vector2i(king_file, 0)
	king_pos[GameRules.PieceColor.BLACK] = Vector2i(king_file, board_size - 1)
	turn = GameRules.PieceColor.WHITE
	en_passant_target = Vector2i(-1, -1)
	move_history.clear()
	last_move_was_capture = false
	halfmove_clock = 0
	turn_serial = 0
	_reset_turn_state()

func _default_back_rank() -> Array:
	match board_size:
		5:
			return ["rook", "knight", "king", "bishop", "rook"]
		6:
			return ["rook", "knight", "bishop", "king", "knight", "rook"]
		7:
			return ["rook", "knight", "bishop", "king", "queen", "knight", "rook"]
		_:
			var rank: Array = []
			var standard := ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"]
			for x in range(board_size):
				rank.append(standard[x] if x < standard.size() else "rook")
			return rank

func _reset_turn_state() -> void:
	last_moved_def_id = {}
	pending_revivals = []
	bonus_instance_id = 0
	actions_this_turn = 0
	growth = {}

func _place(pos: Vector2i, def_id: String, color: int) -> void:
	grid[pos.x][pos.y] = ChessPiece.new(PieceDefDatabase.get_def(def_id), color)

func clear_for_setup() -> void:
	_create_empty_grid()
	rocks = {}
	king_pos.clear()
	turn = GameRules.PieceColor.WHITE
	en_passant_target = Vector2i(-1, -1)
	move_history.clear()
	last_move_was_capture = false
	halfmove_clock = 0
	turn_serial = 0
	_reset_turn_state()

func place_piece_for_setup(pos: Vector2i, piece: ChessPiece) -> bool:
	if piece == null or piece.def == null or not in_bounds(pos) or get_piece(pos) != null:
		return false
	if piece.def.is_king and king_pos.has(piece.color):
		return false
	set_piece(pos, piece)
	piece.origin = pos
	if piece.def.is_king:
		king_pos[piece.color] = pos
	return true

func finalize_setup(starting_color: int = GameRules.PieceColor.WHITE) -> bool:
	if not king_pos.has(GameRules.PieceColor.WHITE) or not king_pos.has(GameRules.PieceColor.BLACK):
		return false
	turn = starting_color
	en_passant_target = Vector2i(-1, -1)
	move_history.clear()
	last_move_was_capture = false
	halfmove_clock = 0
	turn_serial = 0
	_reset_turn_state()
	return true

func remove_all_pawns() -> void:
	for x in range(board_size):
		for y in range(board_size):
			var piece := get_piece(Vector2i(x, y))
			if piece != null and piece.def.is_pawn:
				grid[x][y] = null

func has_non_king_piece(color: int) -> bool:
	for x in range(board_size):
		for y in range(board_size):
			var piece := get_piece(Vector2i(x, y))
			if piece != null and piece.color == color and not piece.def.is_king and not piece.def.is_egg:
				return true
	return false

func has_only_king(color: int) -> bool:
	var found_king: bool = false
	for x in range(board_size):
		for y in range(board_size):
			var piece := get_piece(Vector2i(x, y))
			if piece == null or piece.color != color or piece.def.is_egg:
				continue
			if not piece.def.is_king:
				return false
			found_king = true
	return found_king

## Returns the losing color when the side waiting for its turn has only its
## king while the active side still owns a non-king piece.
## Returning -1 means that the lone-king loss condition is not active.
func get_lone_king_loser() -> int:
	var active_color := turn
	var waiting_color := GameRules.opposite(active_color)
	if has_non_king_piece(active_color) and has_only_king(waiting_color):
		return waiting_color
	return -1

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board_size and pos.y >= 0 and pos.y < board_size and not rocks.has(pos)

func is_rock(pos: Vector2i) -> bool:
	return rocks.has(pos)

## Inside the board edges, rocks included.
func on_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board_size and pos.y >= 0 and pos.y < board_size

## Breaks a rock. Clones share the rock table, so it is replaced, never edited.
func break_rock(pos: Vector2i) -> bool:
	if not rocks.has(pos):
		return false
	var remaining: Dictionary = rocks.duplicate()
	remaining.erase(pos)
	rocks = remaining
	return true

## Bodyguard: a King with one of its own pieces next to it cannot be shot at.
func is_king_guarded(pos: Vector2i) -> bool:
	var king: ChessPiece = get_piece(pos)
	if king == null:
		return false
	for offset: Vector2i in NEIGHBORS:
		var ally: ChessPiece = get_piece(pos + offset)
		if ally != null and ally.color == king.color:
			return true
	return false

## Places rocks on empty squares (pieces are never buried).
func set_rocks(squares: Array) -> void:
	rocks = {}
	for value: Variant in squares:
		var square: Vector2i = value as Vector2i
		if square.x >= 0 and square.x < board_size and square.y >= 0 and square.y < board_size and grid[square.x][square.y] == null:
			rocks[square] = true

func get_piece(pos: Vector2i) -> ChessPiece:
	if not in_bounds(pos):
		return null
	return grid[pos.x][pos.y]
func is_piece_immobilized(pos: Vector2i) -> bool:
	var piece: ChessPiece = get_piece(pos)
	if piece == null or piece.def.immune_to_immobilization:
		return false
	if turn_serial < piece.frozen_until_serial:
		return true
	for offset: Vector2i in NEIGHBORS:
		var ally: ChessPiece = get_piece(pos + offset)
		if ally != null and ally.color == piece.color and ally.def.protects_adjacent_from_immobilization:
			return false
	for offset: Vector2i in [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
	]:
		var neighbor: ChessPiece = get_piece(pos + offset)
		if neighbor != null and neighbor.def.immobilizes_adjacent:
			return true
	return false

func set_piece(pos: Vector2i, piece: ChessPiece) -> void:

	if in_bounds(pos):
		grid[pos.x][pos.y] = piece

func is_square_attacked(pos: Vector2i, by_color: int) -> bool:
	for x: int in range(board_size):
		for y: int in range(board_size):
			var piece: ChessPiece = grid[x][y]
			if piece != null and piece.color == by_color:
				if pos in MoveGenerator.get_attack_squares(self, Vector2i(x, y)):
					return true
	return false

func has_king(color: int) -> bool:
	if not king_pos.has(color):
		return false
	var king: ChessPiece = get_piece(king_pos[color])
	return king != null and king.def.is_king and king.color == color

func is_in_check(color: int) -> bool:
	if not has_king(color):
		return false
	return is_square_attacked(king_pos[color], GameRules.opposite(color))

## PixelKing executable moves preserve movement geometry and occupancy rules but
## deliberately allow risky moves that leave the king or moved piece attacked.
func get_executable_moves(pos: Vector2i) -> Array[Vector2i]:
	return get_executable_moves_for_color(pos, turn)

func get_executable_moves_for_color(pos: Vector2i, color: int) -> Array[Vector2i]:
	var piece: ChessPiece = get_piece(pos)
	if piece == null or piece.color != color:
		return []
	if bonus_instance_id != 0 and piece.instance_id != bonus_instance_id:
		return []
	return MoveGenerator.generate_pseudo_legal(self, pos)

func is_move_dangerous(from: Vector2i, to: Vector2i) -> bool:
	var piece: ChessPiece = get_piece(from)
	if piece == null or to not in get_executable_moves_for_color(from, piece.color):
		return false
	var simulation: BoardState = clone()
	var result: Dictionary = simulation._apply_move(from, to, "queen", true)
	if not bool(result.get("success", false)):
		return false
	var landing: Vector2i = result.get("landing", to)
	return simulation.is_in_check(piece.color) or simulation.is_square_attacked(landing, GameRules.opposite(piece.color))

## Strict chess-legal moves remain available for check/checkmate analysis.
func get_legal_moves(pos: Vector2i) -> Array[Vector2i]:
	return get_legal_moves_for_color(pos, turn)

func get_legal_moves_for_color(pos: Vector2i, color: int) -> Array[Vector2i]:
	var piece: ChessPiece = get_piece(pos)
	if piece == null or piece.color != color:
		return []
	var legal: Array[Vector2i] = []
	for target: Vector2i in MoveGenerator.generate_pseudo_legal(self, pos):
		var simulation: BoardState = clone()
		simulation._apply_move(pos, target, "queen", true)
		if not simulation.is_in_check(piece.color):
			legal.append(target)
	return legal

func has_any_legal_move(color: int) -> bool:
	for x: int in range(board_size):
		for y: int in range(board_size):
			var piece: ChessPiece = grid[x][y]
			if piece != null and piece.color == color:
				if not get_legal_moves_for_color(Vector2i(x, y), color).is_empty():
					return true
	return false

func is_checkmate(color: int) -> bool:
	return has_king(color) and is_in_check(color) and not has_any_legal_move(color)

func is_stalemate(color: int) -> bool:
	return has_king(color) and not is_in_check(color) and not has_any_legal_move(color)

func make_move(from: Vector2i, to: Vector2i, promotion_id: String = "queen") -> Dictionary:
	var result: Dictionary = _empty_move_result()
	var piece: ChessPiece = get_piece(from)
	if piece == null:
		result["error"] = "no_piece"
		return result
	if piece.color != turn:
		result["error"] = "wrong_turn"
		return result
	if to not in get_executable_moves(from):
		result["error"] = "illegal_move"
		return result
	if piece.def.is_pawn and to.y == _promotion_rank(piece.color):
		if promotion_id not in VALID_PROMOTIONS:
			result["error"] = "invalid_promotion"
			return result
	return _apply_move(from, to, promotion_id, false)

func _empty_move_result() -> Dictionary:
	return {
		"success": false,
		"error": "",
		"captured": false,
		"king_captured": false,
		"captured_color": -1,
		"en_passant_capture": false,
		"castled": false,
		"promoted": false,
		"check": false,
		"checkmate": false,
		"stalemate": false,
	}

func _empty_capture_fields(result: Dictionary) -> void:
	result["action_kind"] = ""
	result["landing"] = Vector2i(-1, -1)
	result["ranged"] = false
	result["removed"] = []
	result["shells"] = []
	result["shielded"] = []
	result["swapped_with_king"] = false
	result["evolved_into"] = ""
	result["learned"] = ""
	result["form_changed"] = ""
	result["eggs_laid"] = []

func _apply_move(from: Vector2i, to: Vector2i, promotion_id: String, simulate: bool) -> Dictionary:
	var piece: ChessPiece = get_piece(from)
	var result: Dictionary = _empty_move_result()
	_empty_capture_fields(result)
	if piece == null:
		result["error"] = "no_piece"
		return result
	var moving_color: int = piece.color
	var moving_def: PieceDef = piece.def
	var is_pawn_move: bool = piece.def.is_pawn
	var target_piece: ChessPiece = get_piece(to)
	var castling: bool = _is_castling_move(from, to, piece)
	var kind: StringName = &"" if castling else MoveGenerator.action_kind(self, from, to)
	var serial: int = turn_serial
	var landing: Vector2i = to
	result["action_kind"] = String(kind)
	result["moved_def_id"] = moving_def.id
	if castling:
		set_piece(from, target_piece)
		set_piece(to, piece)
		piece.has_moved = true
		target_piece.has_moved = true
		king_pos[moving_color] = to
		result["castled"] = true
	elif kind == SwapWithKingMovementRule.ABILITY and target_piece != null and target_piece.def.is_king:
		set_piece(from, target_piece)
		set_piece(to, piece)
		king_pos[moving_color] = from
		piece.used_abilities[kind] = true
		piece.has_moved = true
		target_piece.has_moved = true
		result["swapped_with_king"] = true
	else:
		if not kind.is_empty() and kind != &"ranged" and kind != SlideMovementRule.SMASH:
			piece.used_abilities[kind] = true
		var victim_died: bool = false
		if kind == SlideMovementRule.SMASH:
			# The rock shatters and the piece steps onto its square.
			break_rock(to)
			result["rock_broken"] = to
		if kind == RangedAttackRule.ACTION:
			landing = from
			result["ranged"] = true
			victim_died = _resolve_shot(piece, from, to, result, serial)
		elif is_pawn_move and target_piece == null and to == en_passant_target and to != Vector2i(-1, -1):
			result["en_passant_capture"] = true
			result["captured"] = true
			_kill(Vector2i(to.x, from.y), &"capture", result, serial)
			victim_died = true
		elif target_piece != null and target_piece.color != moving_color:
			if _absorbs_blow(target_piece, to, result):
				# The shell (or a hard egg) takes the blow; the attacker bounces back.
				landing = from
			else:
				result["captured"] = true
				victim_died = true
		if landing != from:
			if victim_died and not bool(result["en_passant_capture"]):
				# Lift the victim first so the attacker can stand there during its death effects.
				var victim: ChessPiece = get_piece(to)
				set_piece(to, null)
				set_piece(from, null)
				set_piece(landing, piece)
				_resolve_death(victim, to, &"capture", result, serial)
			else:
				set_piece(from, null)
				set_piece(landing, piece)
		piece.has_moved = true
		if victim_died:
			_record_capture(piece, result)
		var alive: bool = get_piece(landing) == piece
		if alive and is_pawn_move and landing.y == _promotion_rank(moving_color):
			var promoted: ChessPiece = ChessPiece.new(PieceDefDatabase.get_def(promotion_id), moving_color)
			promoted.has_moved = true
			promoted.origin = piece.origin
			set_piece(landing, promoted)
			result["promoted"] = true
		elif alive and not piece.def.promotes_to.is_empty() and landing.y == _promotion_rank(moving_color):
			var promoted_def: PieceDef = PieceDefDatabase.get_def(piece.def.promotes_to)
			if promoted_def != null:
				piece.def = promoted_def
				result["promoted"] = true
		elif alive and not piece.def.alternate_form_id.is_empty():
			var form: PieceDef = PieceDefDatabase.get_def(piece.def.alternate_form_id)
			if form != null:
				piece.def = form
				result["form_changed"] = form.id
		if alive and piece.def.is_king:
			king_pos[moving_color] = landing
	if not moving_def.has_movement_rule(&"mimic_last_move"):
		last_moved_def_id[moving_color] = moving_def.id
	result["landing"] = landing if not bool(result["swapped_with_king"]) else to
	if is_pawn_move and abs(to.y - from.y) == 2 and landing == to:
		en_passant_target = Vector2i(from.x, floori((from.y + to.y) / 2.0))
	else:
		en_passant_target = Vector2i(-1, -1)
	result["success"] = true
	if not simulate:
		last_move_was_capture = bool(result["captured"])
		move_history.append({"from": from, "to": to, "piece_id": moving_def.id, "color": moving_color})
		turn = GameRules.opposite(turn)
		turn_serial += 1
		bonus_instance_id = 0
		actions_this_turn = 0
		if has_king(turn):
			result["check"] = is_in_check(turn)
			if bool(result["check"]):
				result["checkmate"] = is_checkmate(turn)
			else:
				result["stalemate"] = is_stalemate(turn)
	return result

## A shot from `from` at `to`; the shooter stays put. Breaks a rock, or hits the
## target (every enemy on the line for a boomerang), with splash around each kill.
## Returns whether anything died.
func _resolve_shot(shooter: ChessPiece, from: Vector2i, to: Vector2i, result: Dictionary, serial: int) -> bool:
	if break_rock(to):
		result["rock_broken"] = to
		return false
	var squares: Array[Vector2i] = [to]
	var rule: RangedAttackRule = MoveGenerator.ranged_rule(self, from, to) as RangedAttackRule
	if rule != null:
		squares = rule.victims(self, from, to, shooter)
	var any_died: bool = false
	for square: Vector2i in squares:
		var victim: ChessPiece = get_piece(square)
		if victim == null or victim.color == shooter.color:
			continue
		if _absorbs_blow(victim, square, result):
			continue
		any_died = true
		if square == to:
			result["captured"] = true
		_kill(square, &"capture" if square == to else &"pierce", result, serial)
		if shooter.def.splash_on_ranged_capture:
			for offset: Vector2i in NEIGHBORS:
				var splashed: ChessPiece = get_piece(square + offset)
				if splashed != null and splashed.color != shooter.color and not splashed.def.immune_to_ranged:
					_hit(square + offset, &"splash", result, serial)
	return any_died

## A blow that a shell can absorb (explosions, splash).
func _hit(pos: Vector2i, cause: StringName, result: Dictionary, serial: int) -> void:
	var occupant: ChessPiece = get_piece(pos)
	if occupant == null or occupant.def.is_king:
		return
	if _absorbs_blow(occupant, pos, result):
		return
	_kill(pos, cause, result, serial)

## A shell layer takes the blow, or a hard egg shrugs it off and hatches 2 turns later.
func _absorbs_blow(victim: ChessPiece, pos: Vector2i, result: Dictionary) -> bool:
	if victim.shell_left > 0:
		victim.shell_left -= 1
		result["shells"].append({"position": pos, "instance_id": victim.instance_id, "left": victim.shell_left})
		return true
	if victim.def.egg_hardened:
		victim.hatch_serial += EGG_DELAY_SERIALS
		result["shells"].append({"position": pos, "instance_id": victim.instance_id, "left": 0, "egg_delayed": true, "turns_left": egg_turns_left(victim)})
		return true
	return false

func _kill(pos: Vector2i, cause: StringName, result: Dictionary, serial: int) -> void:
	var victim: ChessPiece = get_piece(pos)
	if victim == null:
		return
	set_piece(pos, null)
	_resolve_death(victim, pos, cause, result, serial)

## Bookkeeping and on-death abilities of a piece already lifted off the board.
func _resolve_death(victim: ChessPiece, pos: Vector2i, cause: StringName, result: Dictionary, serial: int) -> void:
	if victim == null:
		return
	if victim.def.is_king:
		result["king_captured"] = true
		result["captured_color"] = victim.color
		king_pos.erase(victim.color)
	result["removed"].append({
		"position": pos,
		"piece_def_id": victim.def.id,
		"instance_id": victim.instance_id,
		"color": victim.color,
		"cause": String(cause),
		"was_king": victim.def.is_king,
	})
	if victim.revives_left > 0 and not victim.def.is_king:
		victim.revives_left -= 1
		_lay_egg(victim, serial, result)
	if victim.def.shields_allies_when_captured:
		for offset: Vector2i in NEIGHBORS:
			var ally: ChessPiece = get_piece(pos + offset)
			if ally != null and ally.color == victim.color:
				ally.shield_until_serial = maxi(ally.shield_until_serial, serial + 3)
				result["shielded"].append(pos + offset)
	if victim.def.explodes_when_captured:
		for offset: Vector2i in [Vector2i.ZERO] + NEIGHBORS:
			_hit(pos + offset, &"explosion", result, serial)

## Growth of the piece that made a capture: run-wide count, learning and evolution.
func _record_capture(piece: ChessPiece, result: Dictionary) -> void:
	piece.capture_count += 1
	var victim_id: String = ""
	for entry: Dictionary in result["removed"]:
		if str(entry.get("cause", "")) == "capture":
			victim_id = str(entry.get("piece_def_id", ""))
			break
	var victim_def: PieceDef = PieceDefDatabase.get_def(victim_id)
	if piece.def.learn_capacity > 0 and victim_def != null and not victim_def.is_king:
		var learned_id: String = victim_def.run_form_id()
		if learned_id != piece.def.id and learned_id not in piece.learned_def_ids:
			piece.learned_def_ids.append(learned_id)
			while piece.learned_def_ids.size() > piece.def.learn_capacity:
				piece.learned_def_ids.remove_at(0)
			result["learned"] = learned_id
	while piece.def.evolve_at_captures > 0 and piece.capture_count >= piece.def.evolve_at_captures:
		var next: PieceDef = PieceDefDatabase.get_def(piece.def.evolves_into)
		if next == null or next == piece.def:
			break
		piece.def = next
		result["evolved_into"] = next.id
	growth[str(piece.instance_id)] = {
		"def_id": piece.def.run_form_id(),
		"capture_count": piece.capture_count,
		"learned": piece.learned_def_ids.duplicate(),
	}

## A fallen reviving piece leaves an egg on its side's free square nearest the
## owner's bottom-left corner. With no free square left it is gone for good.
func _lay_egg(victim: ChessPiece, serial: int, result: Dictionary) -> void:
	var egg_def: PieceDef = PieceDefDatabase.get_def(victim.def.egg_def_id)
	var square: Vector2i = egg_square(victim.color)
	if egg_def == null or square.x < 0:
		return
	var egg: ChessPiece = ChessPiece.new(egg_def, victim.color)
	egg.hatch_piece = victim
	egg.hatch_serial = serial + 2 * victim.def.revive_after_turns + 1
	egg.has_moved = true
	set_piece(square, egg)
	result["eggs_laid"].append({"position": square, "piece_def_id": egg_def.id, "instance_id": egg.instance_id, "color": victim.color, "turns_left": egg_turns_left(egg, serial + 1)})

## The free square closest to `color`'s own bottom-left corner (White: a1, Black: h8).
func egg_square(color: int) -> Vector2i:
	var corner: Vector2i = Vector2i(0, 0) if color == GameRules.PieceColor.WHITE else Vector2i(board_size - 1, board_size - 1)
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 1 << 30
	for row: int in range(board_size):
		for column: int in range(board_size):
			var square: Vector2i = corner + Vector2i(column, row) * (1 if color == GameRules.PieceColor.WHITE else -1)
			if not in_bounds(square) or get_piece(square) != null:
				continue
			var offset: Vector2i = square - corner
			var distance: int = offset.x * offset.x + offset.y * offset.y
			if distance < best_distance:
				best = square
				best_distance = distance
	return best

## Owner turns until an egg hatches (counted from `serial`, now by default).
func egg_turns_left(egg: ChessPiece, serial: int = -1) -> int:
	var now: int = turn_serial if serial < 0 else serial
	return maxi(1, ceili((egg.hatch_serial - now) / 2.0))

## Brings back pieces whose wait is over, at the start of `color`'s turn: eggs hatch
## where they lie. Returns [{"position", "piece_def_id", "instance_id", "color"}].
func process_revivals(color: int) -> Array[Dictionary]:
	var revived: Array[Dictionary] = []
	for x: int in range(board_size):
		for y: int in range(board_size):
			var egg: ChessPiece = grid[x][y]
			if egg == null or not egg.def.is_egg or egg.color != color or egg.hatch_piece == null or turn_serial < egg.hatch_serial:
				continue
			var piece: ChessPiece = egg.hatch_piece
			set_piece(Vector2i(x, y), piece)
			piece.has_moved = true
			revived.append({"position": Vector2i(x, y), "piece_def_id": piece.def.id, "instance_id": piece.instance_id, "color": color, "hatched": true})
	var waiting: Array = []
	for entry: Dictionary in pending_revivals:
		var piece: ChessPiece = entry.get("piece") as ChessPiece
		if piece == null or piece.color != color or turn_serial < int(entry.get("ready_serial", 0)):
			waiting.append(entry)
			continue
		var square: Vector2i = _revival_square(piece)
		if square.x < 0:
			waiting.append(entry)
			continue
		set_piece(square, piece)
		piece.has_moved = true
		revived.append({"position": square, "piece_def_id": piece.def.id, "instance_id": piece.instance_id, "color": color})
	pending_revivals = waiting
	return revived

## The starting square, or else the first empty square scanning from the owner's
## back-rank corner row by row.
func _revival_square(piece: ChessPiece) -> Vector2i:
	if in_bounds(piece.origin) and get_piece(piece.origin) == null:
		return piece.origin
	var white: bool = piece.color == GameRules.PieceColor.WHITE
	for row: int in range(board_size):
		var y: int = row if white else board_size - 1 - row
		for column: int in range(board_size):
			var x: int = column if white else board_size - 1 - column
			if get_piece(Vector2i(x, y)) == null:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _promotion_rank(color: int) -> int:
	return board_size - 1 if color == GameRules.PieceColor.WHITE else 00

## Rule-engine implementation note.
func _is_castling_move(from: Vector2i, to: Vector2i, piece: ChessPiece = null) -> bool:
	var moving_piece := piece if piece != null else get_piece(from)
	var partner := get_piece(to)
	if moving_piece == null or partner == null or from.y != to.y:
		return false
	var castling_rule := moving_piece.def.movement_rule(&"castling") as CastlingMovementRule
	return castling_rule != null and castling_rule.is_valid_partner(moving_piece, partner)
func clone() -> BoardState:
	return _clone_with_history(false)

func clone_runtime() -> BoardState:
	return _clone_with_history(true)

func _clone_with_history(preserve_history: bool) -> BoardState:
	var copy: BoardState = BoardState.new(board_size, false)
	for x: int in range(board_size):
		for y: int in range(board_size):
			var piece: ChessPiece = grid[x][y]
			copy.grid[x][y] = piece.clone_for_simulation() if piece != null else null
	copy.turn = turn
	copy.en_passant_target = en_passant_target
	copy.king_pos = king_pos.duplicate()
	copy.move_history = move_history.duplicate(true) if preserve_history else []
	copy.last_move_was_capture = last_move_was_capture
	copy.halfmove_clock = halfmove_clock
	copy.turn_serial = turn_serial
	copy.last_moved_def_id = last_moved_def_id.duplicate()
	copy.bonus_instance_id = bonus_instance_id
	copy.actions_this_turn = actions_this_turn
	copy.growth = growth.duplicate(true)
	copy.rocks = rocks
	copy.pending_revivals = []
	for entry: Dictionary in pending_revivals:
		var waiting: ChessPiece = entry.get("piece") as ChessPiece
		if waiting != null:
			copy.pending_revivals.append({"piece": waiting.clone_for_simulation(), "ready_serial": int(entry.get("ready_serial", 0))})
	return copy



func to_ascii() -> String:
	var symbols := {
		"pawn": "P", "knight": "N", "bishop": "B",
		"rook": "R", "queen": "Q", "king": "K"
	}
	var text := ""
	for y in range(board_size - 1, -1, -1):
		text += str(y + 1) + " "
		for x in range(board_size):
			var piece: ChessPiece = grid[x][y]
			if piece == null:
				text += ". "
			else:
				var symbol: String = symbols.get(piece.def.id, "?")
				text += (symbol if piece.color == GameRules.PieceColor.WHITE else symbol.to_lower()) + " "
		text += "\n"
	text += "  "
	for x in range(board_size):
		text += String.chr(97 + x) + " "
	text += "\n"
	return text

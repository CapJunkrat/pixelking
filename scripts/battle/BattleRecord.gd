class_name BattleRecord
extends RefCounted

## One battle written down so it can be played again move for move: the starting
## line-up (both sides, rocks, items, rules) and every action in order. The battle rules
## have no randomness, so the same start and the same actions always give the same board.
##
## A record travels as a "battle code": the readable text below, deflated and put in
## Base64 behind "PK1:". The player copies it from the battle menu and pastes it anywhere;
## scripts/tools/decode_battle.gd turns it back into the line-up, the moves and the boards.
##
##   PK1
##   v=0.2.0 seed=123 act=3 node=boss enc=boss_stone_fortress
##   board=8 color=W turns=0
##   rocks=c4 f5
##   items=royal_bomb war_banner
##   W king@e1:i12 stone_giant@d1:i13 squire@c2:i14:c3
##   B king@e8:i40 gorgon@d8:i41
##   moves
##   W d1-d5 #3fa9
##   B d8xd5 #11c0       (x = the target square held a piece)
##   W i0>c7 #08be       (item slot 0 aimed at c7; "W i1" has no target)
##   W end #..           (gave up a bonus action)
##   = #..               (the game checked for a last stand / the end of the battle)
##   mark=24 hash=3fa9   (when the code was copied)
##   view!=d5:hidden ... (squares the screen showed differently from the rules)
##   snap
##   W stone_giant@d5:s1 ...  (the board when the code was copied)

const PREFIX := "PK1:"
const HEADER := "PK1"

## Starting pieces in placement order: {def, color, pos: Vector2i, id, caps, learned: Array}.
var pieces: Array[Dictionary] = []
var board_size: int = 8
var player_color: int = GameRules.PieceColor.WHITE
var turn_limit: int = 0
var rocks: Array[Vector2i] = []
var item_ids: Array[String] = []
## Where the battle happened: seed, act, node, encounter, version.
var context: Dictionary = {}
## One line per action, "W d1-d5", "B i0>c7", "W end", "=" or "win", each with " #hash".
var actions: Array[String] = []

# --- recording ----------------------------------------------------------------

## Writes down the line-up of a board that was just set up (before relics or shields).
static func from_setup(board: BoardState, items: Array[ChallengerItemDef], p_player_color: int, p_turn_limit: int, p_context: Dictionary = {}) -> BattleRecord:
	var record: BattleRecord = BattleRecord.new()
	record.board_size = board.board_size
	record.player_color = p_player_color
	record.turn_limit = p_turn_limit
	record.context = p_context.duplicate()
	if not record.context.has("v"):
		record.context["v"] = str(ProjectSettings.get_setting("application/config/version", "?"))
	for square_value: Variant in board.rocks:
		record.rocks.append(square_value as Vector2i)
	record.rocks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for item: ChallengerItemDef in items:
		record.item_ids.append(String(item.id) if item != null else "?")
	# Player pieces first, then the enemy, in square order (the order they were placed in
	# does not matter to the rules).
	for color: int in [p_player_color, 1 - p_player_color]:
		for y: int in range(board.board_size):
			for x: int in range(board.board_size):
				var piece: ChessPiece = board.get_piece(Vector2i(x, y))
				if piece == null or piece.color != color:
					continue
				record.pieces.append({
					"def": piece.get_id(), "color": color, "pos": Vector2i(x, y), "id": piece.instance_id,
					"caps": piece.capture_count, "learned": piece.learned_def_ids.duplicate(),
				})
	return record

func add_action(action: BattleAction, board: BoardState, target_was_occupied: bool = false) -> void:
	var side: String = _side(action.actor_color)
	var line: String = ""
	match action.action_type:
		BattleAction.ActionType.MOVE:
			var move: MoveAction = action as MoveAction
			line = "%s %s%s%s" % [side, square_name(move.from), "x" if target_was_occupied else "-", square_name(move.to)]
			if move.promotion_id != "queen":
				line += "=" + move.promotion_id
		BattleAction.ActionType.USE_ITEM:
			var use: UseItemAction = action as UseItemAction
			line = "%s i%d" % [side, use.slot_index]
			if use.target_position.x >= 0:
				line += ">" + square_name(use.target_position)
		BattleAction.ActionType.END_TURN:
			line = "%s end" % side
	add_line(line, board)

## A step that is not a player or enemy action: "=" (end-of-battle check), "win" (debug).
func add_line(line: String, board: BoardState) -> void:
	actions.append("%s #%s" % [line, board_hash(board)])

# --- building and replaying ---------------------------------------------------

## A fresh board and processor at the start of this battle, set up exactly as the game
## does it: pieces, rocks, items, opening King shields and battle-start relics.
func build() -> Dictionary:
	var board: BoardState = BoardState.new(board_size, false)
	board.clear_for_setup()
	for entry: Dictionary in pieces:
		var definition: PieceDef = Content.piece(str(entry["def"]))
		if definition == null:
			return {"error": "unknown piece %s" % entry["def"]}
		var piece: ChessPiece = ChessPiece.create_with_instance_id(definition, int(entry["color"]), int(entry["id"]))
		piece.capture_count = int(entry.get("caps", 0))
		piece.learned_def_ids.assign(entry.get("learned", []))
		if not board.place_piece_for_setup(entry["pos"], piece):
			return {"error": "cannot place %s on %s" % [entry["def"], square_name(entry["pos"])]}
	if not board.finalize_setup(player_color):
		return {"error": "a side has no King"}
	board.set_rocks(rocks)
	var items: Array[ChallengerItemDef] = []
	for item_id: String in item_ids:
		var item: ChallengerItemDef = Content.challenger_item(StringName(item_id))
		if item == null:
			return {"error": "unknown item %s" % item_id}
		items.append(item)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board, items, player_color, turn_limit)
	processor.shield_kings_for_opening()
	processor.apply_battle_start_relics()
	return {"board": board, "processor": processor}

## Plays the record back. Returns {steps: [{line, ok, hash, expected, board}], error,
## first_mismatch (step index or -1), processor}. Stops early at `upto` steps if >= 0.
func replay(upto: int = -1) -> Dictionary:
	var built: Dictionary = build()
	var report: Dictionary = {"steps": [], "error": str(built.get("error", "")), "first_mismatch": -1}
	if built.has("error"):
		return report
	var processor: BattleCommandProcessor = built["processor"]
	report["processor"] = processor
	for index: int in range(actions.size()):
		if upto >= 0 and index >= upto:
			break
		var parts: PackedStringArray = actions[index].split(" #")
		var line: String = parts[0]
		var expected: String = parts[1] if parts.size() > 1 else ""
		var ok: bool = _apply(line, processor)
		var hash_now: String = board_hash(processor.board)
		report["steps"].append({"line": line, "ok": ok, "hash": hash_now, "expected": expected, "board": processor.board})
		if (not ok or (not expected.is_empty() and expected != hash_now)) and int(report["first_mismatch"]) < 0:
			report["first_mismatch"] = index
	return report

func _apply(line: String, processor: BattleCommandProcessor) -> bool:
	if line == "=":
		processor.evaluate_terminal_state()
		return true
	if line == "win":
		return processor.force_finish(player_color, false, &"debug_victory").success
	var parts: PackedStringArray = line.split(" ")
	if parts.size() < 2:
		return false
	var color: int = GameRules.PieceColor.WHITE if parts[0] == "W" else GameRules.PieceColor.BLACK
	var body: String = parts[1]
	if body == "end":
		return processor.execute(EndTurnAction.new(color)).success
	if body.begins_with("i"):
		var target: Vector2i = Vector2i(-1, -1)
		var slot_text: String = body.substr(1)
		if ">" in body:
			slot_text = body.substr(1, body.find(">") - 1)
			target = parse_square(body.substr(body.find(">") + 1))
		return processor.execute(UseItemAction.new(int(slot_text), color, target)).success
	var promotion: String = "queen"
	if "=" in body:
		promotion = body.substr(body.find("=") + 1)
		body = body.substr(0, body.find("="))
	var split_at: int = maxi(body.find("-"), body.find("x"))
	if split_at < 0:
		return false
	var from: Vector2i = parse_square(body.substr(0, split_at))
	var to: Vector2i = parse_square(body.substr(split_at + 1))
	return processor.execute(MoveAction.new(from, to, color, promotion)).success

# --- the code -----------------------------------------------------------------

## The readable record, with an optional snapshot of the moment it was copied.
## `view_issues` lists squares the screen showed differently from the rules.
func to_text(current: BoardState = null, view_issues: Array[String] = []) -> String:
	var lines: Array[String] = [HEADER]
	var context_parts: Array[String] = []
	for key: String in ["v", "seed", "act", "node", "enc"]:
		if context.has(key):
			context_parts.append("%s=%s" % [key, str(context[key])])
	lines.append(" ".join(context_parts))
	lines.append("board=%d color=%s turns=%d" % [board_size, _side(player_color), turn_limit])
	var rock_names: Array[String] = []
	for square: Vector2i in rocks:
		rock_names.append(square_name(square))
	lines.append("rocks=" + " ".join(rock_names))
	lines.append("items=" + " ".join(item_ids))
	for color: int in [GameRules.PieceColor.WHITE, GameRules.PieceColor.BLACK]:
		var tokens: Array[String] = [_side(color)]
		for entry: Dictionary in pieces:
			if int(entry["color"]) == color:
				tokens.append(_piece_token(entry))
		lines.append(" ".join(tokens))
	lines.append("moves")
	lines.append_array(actions)
	if current != null:
		lines.append("mark=%d hash=%s" % [actions.size(), board_hash(current)])
		if not view_issues.is_empty():
			lines.append("view!=" + " ".join(view_issues))
		lines.append("snap")
		lines.append_array(snapshot_lines(current))
	return "\n".join(lines)

func encode(current: BoardState = null, view_issues: Array[String] = []) -> String:
	var raw: PackedByteArray = to_text(current, view_issues).to_utf8_buffer()
	return PREFIX + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))

## The readable text inside a battle code (or the text itself if it is not encoded).
static func decode_text(code: String) -> String:
	var trimmed: String = code.strip_edges().replace("\n", "").replace(" ", "")
	if not trimmed.begins_with(PREFIX):
		return code
	var packed: PackedByteArray = Marshalls.base64_to_raw(trimmed.substr(PREFIX.length()))
	return packed.decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE).get_string_from_utf8()

## Reads a battle code (or its readable text) back into a record. Returns null if broken.
## The snapshot, mark and view lines go into `context` ("mark", "view", "snap").
static func decode(code: String) -> BattleRecord:
	var text: String = decode_text(code)
	var lines: PackedStringArray = text.split("\n")
	if lines.is_empty() or lines[0].strip_edges() != HEADER:
		return null
	var record: BattleRecord = BattleRecord.new()
	var section: String = "head"
	var snap: Array[String] = []
	for raw_line: String in lines.slice(1):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		if line == "moves":
			section = "moves"
			continue
		if line == "snap":
			section = "snap"
			continue
		match section:
			"moves":
				if line.begins_with("mark="):
					for part: String in line.split(" "):
						var pair: PackedStringArray = part.split("=")
						record.context[pair[0]] = pair[1] if pair.size() > 1 else ""
				elif line.begins_with("view!="):
					record.context["view"] = line.substr(6)
				else:
					record.actions.append(line)
			"snap":
				snap.append(line)
			_:
				record._read_head_line(line)
	record.context["snap"] = snap
	return record

func _read_head_line(line: String) -> void:
	if line.begins_with("W ") or line.begins_with("B ") or line == "W" or line == "B":
		var color: int = GameRules.PieceColor.WHITE if line.begins_with("W") else GameRules.PieceColor.BLACK
		for token: String in line.split(" ").slice(1):
			var entry: Dictionary = _parse_piece_token(token)
			if not entry.is_empty():
				entry["color"] = color
				pieces.append(entry)
		return
	if line.begins_with("rocks="):
		for name: String in line.substr(6).split(" ", false):
			rocks.append(parse_square(name))
		return
	if line.begins_with("items="):
		for item_id: String in line.substr(6).split(" ", false):
			item_ids.append(item_id)
		return
	for part: String in line.split(" ", false):
		var pair: PackedStringArray = part.split("=")
		var value: String = pair[1] if pair.size() > 1 else ""
		match pair[0]:
			"board":
				board_size = int(value)
			"color":
				player_color = GameRules.PieceColor.WHITE if value == "W" else GameRules.PieceColor.BLACK
			"turns":
				turn_limit = int(value)
			_:
				context[pair[0]] = value

func _piece_token(entry: Dictionary) -> String:
	var token: String = "%s@%s:i%d" % [entry["def"], square_name(entry["pos"]), int(entry["id"])]
	if int(entry.get("caps", 0)) > 0:
		token += ":c%d" % int(entry["caps"])
	var learned: Array = entry.get("learned", [])
	if not learned.is_empty():
		token += ":l" + "+".join(PackedStringArray(learned))
	return token

static func _parse_piece_token(token: String) -> Dictionary:
	var at: int = token.find("@")
	if at <= 0:
		return {}
	var fields: PackedStringArray = token.substr(at + 1).split(":")
	var entry: Dictionary = {"def": token.substr(0, at), "pos": parse_square(fields[0]), "id": 0, "caps": 0, "learned": []}
	for field: String in fields.slice(1):
		match field.left(1):
			"i":
				entry["id"] = int(field.substr(1))
			"c":
				entry["caps"] = int(field.substr(1))
			"l":
				entry["learned"] = Array(field.substr(1).split("+", false))
	return entry

# --- boards -------------------------------------------------------------------

## Every piece on the board with what matters to the rules, one side per line:
## "W stone_giant@d5:s1:f6" (s = shell left, f = frozen until serial, h = shielded until,
## m = moved, e = egg hatching on serial).
static func snapshot_lines(board: BoardState) -> Array[String]:
	var lines: Array[String] = ["turn=%s serial=%d actions=%d" % [_side(board.turn), board.turn_serial, board.actions_this_turn]]
	for color: int in [GameRules.PieceColor.WHITE, GameRules.PieceColor.BLACK]:
		var tokens: Array[String] = [_side(color)]
		for y: int in range(board.board_size):
			for x: int in range(board.board_size):
				var piece: ChessPiece = board.get_piece(Vector2i(x, y))
				if piece != null and piece.color == color:
					tokens.append(_state_token(piece, Vector2i(x, y)))
		lines.append(" ".join(tokens))
	var rock_names: Array[String] = []
	for square_value: Variant in board.rocks:
		rock_names.append(square_name(square_value as Vector2i))
	rock_names.sort()
	lines.append("rocks=" + " ".join(rock_names))
	if not board.pending_revivals.is_empty():
		var waiting: Array[String] = []
		for entry: Dictionary in board.pending_revivals:
			var piece: ChessPiece = entry.get("piece") as ChessPiece
			if piece != null:
				waiting.append("%s%s@%d" % [_side(piece.color), piece.get_id(), int(entry.get("ready_serial", 0))])
		lines.append("reviving=" + " ".join(waiting))
	return lines

static func _state_token(piece: ChessPiece, square: Vector2i) -> String:
	var token: String = "%s@%s:i%d" % [piece.get_id(), square_name(square), piece.instance_id]
	if piece.def != null and piece.def.shell_hits > 0:
		token += ":s%d" % piece.shell_left
	if piece.frozen_until_serial > 0:
		token += ":f%d" % piece.frozen_until_serial
	if piece.shield_until_serial > 0:
		token += ":h%d" % piece.shield_until_serial
	if piece.capture_count > 0:
		token += ":c%d" % piece.capture_count
	if piece.hatch_piece != null:
		token += ":e%d" % piece.hatch_serial
	return token

## A short fingerprint of everything the rules care about on this board. Instance ids
## are left out: pieces born in battle (eggs, promotions) draw theirs from a counter
## that differs between the phone and a replay, while the board itself is the same.
static func board_hash(board: BoardState) -> String:
	if board == null:
		return "0000"
	var text: String = "\n".join(snapshot_lines(board))
	return "%04x" % (hash(_INSTANCE_ID.sub(text, "", true)) & 0xffff)

static var _INSTANCE_ID: RegEx = RegEx.create_from_string(":i-?\\d+")

## The board as text: ranks from the top, two letters per piece (upper case = White),
## "##" for rocks, "." for empty squares, then a legend of the letters used.
static func board_ascii(board: BoardState) -> String:
	var codes: Dictionary = {}
	var used: Dictionary = {}
	var rows: Array[String] = []
	for y: int in range(board.board_size - 1, -1, -1):
		var cells: Array[String] = ["%2d" % (y + 1)]
		for x: int in range(board.board_size):
			var square: Vector2i = Vector2i(x, y)
			var piece: ChessPiece = board.get_piece(square)
			if piece != null:
				var code: String = _code_for(piece.get_id(), codes, used)
				cells.append(code.to_upper() if piece.color == GameRules.PieceColor.WHITE else code.to_lower())
			elif board.is_rock(square):
				cells.append("##")
			else:
				cells.append(" .")
		rows.append(" ".join(cells))
	var files: Array[String] = ["  "]
	for x: int in range(board.board_size):
		files.append(" " + char(97 + x))
	rows.append(" ".join(files))
	var legend: Array[String] = []
	for def_id: String in codes:
		legend.append("%s=%s" % [str(codes[def_id]).to_upper(), def_id])
	rows.append("   " + "  ".join(legend))
	return "\n".join(rows)

static func _code_for(def_id: String, codes: Dictionary, used: Dictionary) -> String:
	if codes.has(def_id):
		return codes[def_id]
	var words: PackedStringArray = def_id.split("_")
	var candidates: Array[String] = []
	if words.size() > 1:
		candidates.append(words[0].left(1) + words[1].left(1))
	for index: int in range(1, def_id.length()):
		if def_id[index] != "_":
			candidates.append(def_id.left(1) + def_id[index])
	for index: int in range(26):
		candidates.append(def_id.left(1) + char(97 + index))
	for candidate: String in candidates:
		if not used.has(candidate.to_lower()):
			used[candidate.to_lower()] = true
			codes[def_id] = candidate.to_lower()
			return codes[def_id]
	codes[def_id] = "??"
	return "??"

# --- squares ------------------------------------------------------------------

## "a1" is the bottom-left square on the player's side (x = 0, y = 0).
static func square_name(square: Vector2i) -> String:
	if square.x < 0 or square.y < 0:
		return "-"
	return "%s%d" % [char(97 + square.x), square.y + 1]

static func parse_square(name: String) -> Vector2i:
	if name.length() < 2:
		return Vector2i(-1, -1)
	return Vector2i(name.unicode_at(0) - 97, int(name.substr(1)) - 1)

static func _side(color: int) -> String:
	return "W" if color == GameRules.PieceColor.WHITE else "B"

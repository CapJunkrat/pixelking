extends RefCounted
class_name BoardState

## Rule-engine implementation note.
## Rule-engine implementation note.
const DEFAULT_SIZE := 5
const MIN_SIZE := 5
const VALID_PROMOTIONS := ["queen", "rook", "bishop", "knight"]

var board_size: int = DEFAULT_SIZE
var grid: Array = []  # grid[x][y]rule ChessPiece ? null
var turn: int = GameRules.PieceColor.WHITE
var en_passant_target: Vector2i = Vector2i(-1, -1)
var move_history: Array = []
var king_pos: Dictionary = {}
var last_move_was_capture: bool = false
var halfmove_clock: int = 0

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

func _place(pos: Vector2i, def_id: String, color: int) -> void:
	grid[pos.x][pos.y] = ChessPiece.new(PieceDefDatabase.get_def(def_id), color)

func remove_all_pawns() -> void:
	for x in range(board_size):
		for y in range(board_size):
			var piece := get_piece(Vector2i(x, y))
			if piece != null and piece.def.is_pawn:
				grid[x][y] = null

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board_size and pos.y >= 0 and pos.y < board_size

func get_piece(pos: Vector2i) -> ChessPiece:
	if not in_bounds(pos):
		return null
	return grid[pos.x][pos.y]

func set_piece(pos: Vector2i, piece: ChessPiece) -> void:
	if in_bounds(pos):
		grid[pos.x][pos.y] = piece

func is_square_attacked(pos: Vector2i, by_color: int) -> bool:
	for x in range(board_size):
		for y in range(board_size):
			var piece: ChessPiece = grid[x][y]
			if piece != null and piece.color == by_color:
				if pos in MoveGenerator.get_attack_squares(self, Vector2i(x, y)):
					return true
	return false

func is_in_check(color: int) -> bool:
	if not king_pos.has(color):
		return false
	return is_square_attacked(king_pos[color], GameRules.opposite(color))

func get_legal_moves(pos: Vector2i) -> Array[Vector2i]:
	return get_legal_moves_for_color(pos, turn)

## Rule-engine implementation note.
func get_legal_moves_for_color(pos: Vector2i, color: int) -> Array[Vector2i]:
	var piece := get_piece(pos)
	if piece == null or piece.color != color:
		return []

	var legal: Array[Vector2i] = []
	for target in MoveGenerator.generate_pseudo_legal(self, pos):
		var sim := clone()
		sim._apply_move(pos, target, "queen", true)
		if not sim.is_in_check(piece.color):
			legal.append(target)
	return legal

func has_any_legal_move(color: int) -> bool:
	for x in range(board_size):
		for y in range(board_size):
			var piece: ChessPiece = grid[x][y]
			if piece != null and piece.color == color:
				if not get_legal_moves_for_color(Vector2i(x, y), color).is_empty():
					return true
	return false

func is_checkmate(color: int) -> bool:
	return is_in_check(color) and not has_any_legal_move(color)

func is_stalemate(color: int) -> bool:
	return not is_in_check(color) and not has_any_legal_move(color)

## Rule-engine implementation note.
## Rule-engine implementation note.
func make_move(from: Vector2i, to: Vector2i, promotion_id: String = "queen") -> Dictionary:
	var result := _empty_move_result()
	var piece := get_piece(from)
	if piece == null:
		result["error"] = "no_piece"
		return result
	if piece.color != turn:
		result["error"] = "wrong_turn"
		return result
	if to not in get_legal_moves(from):
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
		"en_passant_capture": false,
		"castled": false,
		"promoted": false,
		"check": false,
		"checkmate": false,
		"stalemate": false,
	}

## Rule-engine implementation note.
func _apply_move(from: Vector2i, to: Vector2i, promotion_id: String, simulate: bool) -> Dictionary:
	var piece := get_piece(from)
	var result := _empty_move_result()
	if piece == null:
		result["error"] = "no_piece"
		return result

	var moving_color := piece.color
	var is_pawn_move := piece.def.is_pawn
	var target_piece := get_piece(to)
	var castling := _is_castling_move(from, to, piece)

	if castling:
		var rook := target_piece
		set_piece(from, rook)
		set_piece(to, piece)
		piece.has_moved = true
		rook.has_moved = true
		king_pos[moving_color] = to
		result["castled"] = true
	else:
		if is_pawn_move and target_piece == null and to == en_passant_target and to != Vector2i(-1, -1):
			set_piece(Vector2i(to.x, from.y), null)
			result["en_passant_capture"] = true
			result["captured"] = true
		elif target_piece != null:
			result["captured"] = true

		set_piece(from, null)
		piece.has_moved = true
		set_piece(to, piece)

		if is_pawn_move and to.y == _promotion_rank(moving_color):
			var promoted := ChessPiece.new(PieceDefDatabase.get_def(promotion_id), moving_color)
			promoted.has_moved = true
			set_piece(to, promoted)
			result["promoted"] = true

		if piece.def.is_king:
			king_pos[moving_color] = to

	if is_pawn_move and abs(to.y - from.y) == 2:
		en_passant_target = Vector2i(from.x, floori((from.y + to.y) / 2.0))
	else:
		en_passant_target = Vector2i(-1, -1)

	result["success"] = true
	if not simulate:
		last_move_was_capture = result["captured"]
		move_history.append({"from": from, "to": to, "piece_id": piece.get_id(), "color": moving_color})
		turn = GameRules.opposite(turn)
		result["check"] = is_in_check(turn)
		if result["check"]:
			result["checkmate"] = is_checkmate(turn)
		else:
			result["stalemate"] = is_stalemate(turn)
	return result

func _promotion_rank(color: int) -> int:
	return board_size - 1 if color == GameRules.PieceColor.WHITE else 0

## Rule-engine implementation note.
func _is_castling_move(from: Vector2i, to: Vector2i, piece: ChessPiece = null) -> bool:
	var moving_piece := piece if piece != null else get_piece(from)
	var partner := get_piece(to)
	if moving_piece == null or partner == null or from.y != to.y:
		return false
	var castling_rule := moving_piece.def.movement_rule(&"castling") as CastlingMovementRule
	return castling_rule != null and castling_rule.is_valid_partner(moving_piece, partner)

func clone() -> BoardState:
	var copy := BoardState.new(board_size, false)
	for x in range(board_size):
		for y in range(board_size):
			var piece: ChessPiece = grid[x][y]
			copy.grid[x][y] = piece.clone_for_simulation() if piece != null else null
	copy.turn = turn
	copy.en_passant_target = en_passant_target
	copy.king_pos = king_pos.duplicate()
	copy.move_history = []
	copy.last_move_was_capture = last_move_was_capture
	copy.halfmove_clock = halfmove_clock
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

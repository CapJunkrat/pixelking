extends RefCounted
class_name MoveGenerator

## 生成某个位置上棋子的"伪合法走法"(pseudo-legal moves):
## 满足棋子自身移动规则、不吃自己棋子、王车易位的通路/权限条件,
## 但**不**检查这步棋走完之后自己的王是否被将军——那一层过滤在 BoardState.get_legal_moves 里做。
##
## 之所以按 PieceDef 的 slide_directions / jump_offsets 通用生成,
## 是为了让以后新增的特殊棋子只要能用"滑动方向+跳跃偏移"描述,就不用碰这份代码。
## 兵和王(易位)有独立的专属规则,所以单独处理。

static func generate_pseudo_legal(board: BoardState, pos: Vector2i) -> Array[Vector2i]:
	var piece := board.get_piece(pos)
	if piece == null:
		return []

	if piece.def.is_pawn:
		return _pawn_moves(board, pos, piece)

	var moves: Array[Vector2i] = []
	_add_slide_moves(board, pos, piece, moves)
	_add_jump_moves(board, pos, piece, moves)

	if piece.def.is_king:
		_add_castling_moves(board, pos, piece, moves)

	return moves

static func _add_slide_moves(board: BoardState, pos: Vector2i, piece: ChessPiece, moves: Array[Vector2i]) -> void:
	for dir in piece.def.slide_directions:
		var dist := 1
		while dist <= piece.def.max_slide_distance:
			var target := pos + dir * dist
			if not board.in_bounds(target):
				break
			var occupant := board.get_piece(target)
			if occupant == null:
				moves.append(target)
			else:
				if occupant.color != piece.color:
					moves.append(target)
				break  # 无论敌我,挡住了就不能再往后滑
			dist += 1

static func _add_jump_moves(board: BoardState, pos: Vector2i, piece: ChessPiece, moves: Array[Vector2i]) -> void:
	for offset in piece.def.jump_offsets:
		var target := pos + offset
		if not board.in_bounds(target):
			continue
		var occupant := board.get_piece(target)
		if occupant == null or occupant.color != piece.color:
			moves.append(target)

static func _pawn_moves(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var forward := 1 if piece.color == GameRules.PieceColor.WHITE else -1
	var start_rank := 1 if piece.color == GameRules.PieceColor.WHITE else 6

	# 直走一格
	var one_step := pos + Vector2i(0, forward)
	if board.in_bounds(one_step) and board.get_piece(one_step) == null:
		moves.append(one_step)
		# 起始位置可直走两格
		var two_step := pos + Vector2i(0, forward * 2)
		if pos.y == start_rank and board.get_piece(two_step) == null:
			moves.append(two_step)

	# 斜吃两侧
	for dx in [-1, 1]:
		var capture_pos := pos + Vector2i(dx, forward)
		if not board.in_bounds(capture_pos):
			continue
		var occupant := board.get_piece(capture_pos)
		if occupant != null and occupant.color != piece.color:
			moves.append(capture_pos)
		elif capture_pos == board.en_passant_target:
			# 吃过路兵:目标格是空的,但符合上一步双步的记录
			moves.append(capture_pos)

	return moves

## 专门给"这一格是否被攻击"用的攻击覆盖范围。
## 和 generate_pseudo_legal 的区别:
##   - 兵:只算斜前方两格(不管是否有子/是否能吃过路兵),因为哪怕那格是空的,
##     敌方兵依然"控制"着它,己方王不能走过去。
##   - 王:不包含易位(易位本身还需要判断"过程中是否被攻击",不能自我依赖)。
## 这样可以避免 is_square_attacked -> 王的易位生成 -> is_square_attacked 的死循环。
static func get_attack_squares(board: BoardState, pos: Vector2i) -> Array[Vector2i]:
	var piece := board.get_piece(pos)
	if piece == null:
		return []

	if piece.def.is_pawn:
		return _pawn_attack_squares(board, pos, piece)

	var squares: Array[Vector2i] = []
	_add_slide_moves(board, pos, piece, squares)
	_add_jump_moves(board, pos, piece, squares)
	return squares

static func _pawn_attack_squares(board: BoardState, pos: Vector2i, piece: ChessPiece) -> Array[Vector2i]:
	var forward := 1 if piece.color == GameRules.PieceColor.WHITE else -1
	var squares: Array[Vector2i] = []
	for dx in [-1, 1]:
		var t := pos + Vector2i(dx, forward)
		if board.in_bounds(t):
			squares.append(t)
	return squares

static func _add_castling_moves(board: BoardState, pos: Vector2i, king: ChessPiece, moves: Array[Vector2i]) -> void:
	if king.has_moved:
		return
	var enemy := GameRules.opposite(king.color)
	if board.is_square_attacked(pos, enemy):
		return  # rule

	# Rule-engine implementation note.
	# Rule-engine implementation note.
	for direction: int in [-1, 1]:
		var x: int = pos.x + direction
		var path_is_safe := true
		while x >= 0 and x < board.board_size:
			var target := Vector2i(x, pos.y)
			var occupant := board.get_piece(target)
			if occupant == null:
				if board.is_square_attacked(target, enemy):
					path_is_safe = false
				x += direction
				continue
			if (
				path_is_safe
				and not board.is_square_attacked(target, enemy)
				and occupant.color == king.color
				and occupant.def.id == "rook"
				and not occupant.has_moved
			):
				moves.append(target)
			break

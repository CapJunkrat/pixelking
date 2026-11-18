class_name DeploymentFormation
extends RefCounted

## Places the player's active pieces automatically, so a battle starts without a
## deployment step. The rule is fixed and easy to predict:
## - the King stands in the middle of the back rank;
## - pieces that only move forward (pawns, Vanguard, level-1 Squire) take the front rank,
##   from the middle outwards;
## - heavy pieces guard the corners of the back rank;
## - everything else fills the back rank from the middle outwards, most valuable first.
## Whatever does not fit spills onto the other player rank.

const PLAYER_RANKS := 2

## Returns {instance_id (int): Vector2i} for every active piece.
static func arrange(run_state: RunState, board_size: int) -> Dictionary:
	var result: Dictionary = {}
	var occupied: Dictionary = {}
	var centre: int = floori(float(board_size) / 2.0)
	var middle_out: Array[int] = _middle_out(board_size, centre)
	var corners: Array[int] = _corners_in(board_size)
	var forward: Array[PieceInstanceState] = []
	var heavy: Array[PieceInstanceState] = []
	var others: Array[PieceInstanceState] = []
	for instance_id: int in run_state.active_piece_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		if piece == null:
			continue
		var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id))
		if piece.is_king:
			result[instance_id] = Vector2i(centre, 0)
			occupied[Vector2i(centre, 0)] = true
		elif definition != null and moves_forward_only(definition):
			forward.append(piece)
		elif definition != null and definition.weight_class == PieceDef.WeightClass.HEAVY:
			heavy.append(piece)
		else:
			others.append(piece)
	others.sort_custom(func(a: PieceInstanceState, b: PieceInstanceState) -> bool:
		var value_a: int = PieceDefDatabase.get_def(String(a.piece_def_id)).base_value
		var value_b: int = PieceDefDatabase.get_def(String(b.piece_def_id)).base_value
		return value_a > value_b if value_a != value_b else a.instance_id < b.instance_id)
	for piece: PieceInstanceState in forward:
		result[piece.instance_id] = _take(occupied, [[middle_out, 1], [middle_out, 0]], board_size)
	for piece: PieceInstanceState in heavy:
		result[piece.instance_id] = _take(occupied, [[corners, 0], [corners, 1], [middle_out, 1]], board_size)
	for piece: PieceInstanceState in others:
		result[piece.instance_id] = _take(occupied, [[middle_out, 0], [middle_out, 1]], board_size)
	return result

## Pawn-like pieces: every move they have goes forward.
static func moves_forward_only(definition: PieceDef) -> bool:
	var rules: Array[MovementRule] = definition.resolved_movement_rules()
	if rules.is_empty():
		return false
	for rule: MovementRule in rules:
		if rule is PawnMovementRule:
			continue
		var slide: SlideMovementRule = rule as SlideMovementRule
		if slide == null or not slide.relative_to_color:
			if slide != null and _sideways_only(slide):
				continue
			return false
	return true

static func _sideways_only(slide: SlideMovementRule) -> bool:
	for direction: Vector2i in slide.directions:
		if direction.y != 0:
			return false
	return true

static func _take(occupied: Dictionary, plans: Array, board_size: int) -> Vector2i:
	for plan: Array in plans:
		var columns: Array[int] = plan[0]
		var rank: int = plan[1]
		for x: int in columns:
			var square: Vector2i = Vector2i(x, rank)
			if not occupied.has(square):
				occupied[square] = true
				return square
	for rank: int in range(PLAYER_RANKS):
		for x: int in range(board_size):
			var square: Vector2i = Vector2i(x, rank)
			if not occupied.has(square):
				occupied[square] = true
				return square
	return Vector2i(-1, -1)

static func _middle_out(board_size: int, centre: int) -> Array[int]:
	var order: Array[int] = [centre]
	for step: int in range(1, board_size):
		for x: int in [centre - step, centre + step]:
			if x >= 0 and x < board_size and x not in order:
				order.append(x)
	return order

static func _corners_in(board_size: int) -> Array[int]:
	var order: Array[int] = []
	for step: int in range(board_size):
		for x: int in [step, board_size - 1 - step]:
			if x not in order:
				order.append(x)
	return order

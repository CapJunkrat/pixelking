class_name PieceRulePreview
extends RefCounted

const DEFAULT_GRID_SIZE := 5

static func pattern(piece_def_id: String, grid_size: int = DEFAULT_GRID_SIZE) -> Dictionary:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_def_id)
	if definition == null:
		return {}
	var board: BoardState = BoardState.new(grid_size, false)
	var center_value: int = floori(float(grid_size) * 0.5)
	var center: Vector2i = Vector2i(center_value, center_value)
	var preview_piece: ChessPiece = ChessPiece.new(definition, GameRules.PieceColor.WHITE, false)
	if not board.place_piece_for_setup(center, preview_piece):
		return {}
	var moves: Array[Vector2i] = MoveGenerator.generate_pseudo_legal(board, center)
	var attacks: Array[Vector2i] = MoveGenerator.get_attack_squares(board, center)
	var result: Dictionary = {}
	for y_position: int in range(grid_size):
		for x_position: int in range(grid_size):
			var square: Vector2i = Vector2i(x_position, y_position)
			if square == center:
				continue
			var can_move: bool = square in moves
			var can_attack: bool = square in attacks
			if can_move and can_attack:
				result[square - center] = "both"
			elif can_move:
				result[square - center] = "move"
			elif can_attack:
				result[square - center] = "attack"
	return result

static func move_key(definition: PieceDef) -> String:
	return "DRAFT_MOVE_%s" % definition.id.to_upper()

static func attack_key(definition: PieceDef) -> String:
	return "DRAFT_ATTACK_%s" % definition.id.to_upper()

static func ability_keys(definition: PieceDef) -> Array[String]:
	var abilities: Array[String] = []
	if definition.extra_move_on_capture:
		abilities.append("CODEX_TRAIT_EXTRA_ACTION")
	if definition.immobilizes_adjacent:
		abilities.append("CODEX_TRAIT_IMMOBILIZE")
	if definition.immune_to_immobilization:
		abilities.append("CODEX_TRAIT_IMMUNE")
	if abilities.is_empty():
		abilities.append("CODEX_TRAIT_NONE")
	return abilities

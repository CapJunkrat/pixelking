class_name PieceDefDatabase
extends RefCounted

static var _cache: Dictionary = {}

static func get_def(id: String) -> PieceDef:
	if _cache.is_empty():
		_build_all()
	return _cache.get(id, null)

static func has_def(id: String) -> bool:
	if _cache.is_empty():
		_build_all()
	return _cache.has(id)

static func all_ids() -> Array[String]:
	if _cache.is_empty():
		_build_all()
	var ids: Array[String] = []
	for id: String in _cache.keys():
		ids.append(id)
	ids.sort()
	return ids

static func opening_draft_defs() -> Array[PieceDef]:
	var result: Array[PieceDef] = []
	for id: String in all_ids():
		var definition: PieceDef = get_def(id)
		if definition != null and definition.is_valid_opening_draft_piece():
			result.append(definition)
	return result

static func _build_all() -> void:
	_cache["pawn"] = _pawn()
	_cache["knight"] = _knight()
	_cache["bishop"] = _bishop()
	_cache["rook"] = _rook()
	_cache["queen"] = _queen()
	_cache["king"] = _king()

static func _pawn() -> PieceDef:
	var definition := _base_def("pawn", &"PIECE_PAWN", 1, PieceDef.Rarity.COMMON, 4)
	definition.is_pawn = true
	definition.movement_profile = _profile([PawnMovementRule.new()])
	return definition

static func _knight() -> PieceDef:
	var definition := _base_def("knight", &"PIECE_KNIGHT", 3, PieceDef.Rarity.COMMON, 3)
	definition.movement_profile = _profile([_jump([
		Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
		Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2),
	])])
	return definition

static func _bishop() -> PieceDef:
	var definition := _base_def("bishop", &"PIECE_BISHOP", 3, PieceDef.Rarity.COMMON, 3)
	definition.movement_profile = _profile([_slide([
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	], 8)])
	return definition

static func _rook() -> PieceDef:
	var definition := _base_def("rook", &"PIECE_ROOK", 5, PieceDef.Rarity.RARE, 2)
	definition.movement_profile = _profile([_slide([
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	], 8)])
	return definition

static func _queen() -> PieceDef:
	var definition := _base_def("queen", &"PIECE_QUEEN", 9, PieceDef.Rarity.RARE, 1)
	definition.movement_profile = _profile([_slide([
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	], 8)])
	return definition

static func _king() -> PieceDef:
	var definition := _base_def("king", &"PIECE_KING", 1000)
	definition.is_royal = true
	definition.is_king = true
	definition.movement_profile = _profile([_slide([
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	], 1)])
	definition.special_move_rules.append(CastlingMovementRule.new())
	return definition

static func _base_def(
	id: String,
	display_name_key: StringName,
	base_value: int,
	rarity: PieceDef.Rarity = PieceDef.Rarity.COMMON,
	opening_draft_weight: int = 0
) -> PieceDef:
	var definition: PieceDef = PieceDef.new()
	definition.id = id
	definition.display_name_key = display_name_key
	definition.base_value = base_value
	definition.rarity = rarity
	definition.available_in_opening_draft = opening_draft_weight > 0
	definition.opening_draft_weight = opening_draft_weight
	return definition

static func _profile(rules: Array[MovementRule], parent: MovementProfile = null) -> MovementProfile:
	var profile := MovementProfile.new()
	profile.parent = parent
	for rule in rules:
		profile.rules.append(rule)
	return profile

static func _slide(directions: Array[Vector2i], max_distance: int) -> SlideMovementRule:
	var rule := SlideMovementRule.new()
	rule.directions = directions
	rule.max_distance = max_distance
	return rule

static func _jump(offsets: Array[Vector2i]) -> JumpMovementRule:
	var rule := JumpMovementRule.new()
	rule.offsets = offsets
	return rule

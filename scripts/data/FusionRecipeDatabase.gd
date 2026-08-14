class_name FusionRecipeDatabase
extends RefCounted

static var _cache: Dictionary = {}

static func get_def(id: StringName) -> FusionRecipeDef:
	if _cache.is_empty():
		_build()
	return _cache.get(id, null) as FusionRecipeDef

static func all_defs() -> Array[FusionRecipeDef]:
	if _cache.is_empty():
		_build()
	var result: Array[FusionRecipeDef] = []
	for value: Variant in _cache.values():
		result.append(value as FusionRecipeDef)
	return result

static func eligible_defs(run_state: RunState) -> Array[FusionRecipeDef]:
	var result: Array[FusionRecipeDef] = []
	for recipe: FusionRecipeDef in all_defs():
		if has_ingredients(run_state, recipe):
			result.append(recipe)
	return result

static func has_ingredients(run_state: RunState, recipe: FusionRecipeDef) -> bool:
	if run_state == null or recipe == null:
		return false
	var required: Dictionary = {}
	for id: StringName in recipe.ingredient_piece_def_ids:
		required[id] = int(required.get(id, 0)) + 1
	var actual: Dictionary = {}
	for piece: PieceInstanceState in run_state.player_roster:
		actual[piece.piece_def_id] = int(actual.get(piece.piece_def_id, 0)) + 1
	for id: StringName in required:
		if int(actual.get(id, 0)) < int(required[id]):
			return false
	return true

static func _build() -> void:
	_add(&"pawn_knight_lancer", [&"pawn", &"knight"], &"lancer", "Lancer Blueprint")
	_add(&"bishop_rook_archmage", [&"bishop", &"rook"], &"archmage", "Archmage Blueprint")

static func _add(id: StringName, ingredients: Array[StringName], result: StringName, label: String) -> void:
	var recipe: FusionRecipeDef = FusionRecipeDef.new()
	recipe.id = id
	recipe.ingredient_piece_def_ids = ingredients
	recipe.result_piece_def_id = result
	recipe.display_name = label
	_cache[id] = recipe

class_name FusionRecipeDef
extends Resource

@export var id: StringName = &""
@export var ingredient_piece_def_ids: Array[StringName] = []
@export var result_piece_def_id: StringName = &""
@export var display_name_key: StringName = &""
@export var description_key: StringName = &""
## Compatibility fallback for saved offers created before localization keys existed.
@export var display_name: String = ""

func is_valid() -> bool:
	if id.is_empty() or ingredient_piece_def_ids.size() < 2 or result_piece_def_id.is_empty():
		return false
	if display_name_key.is_empty() or description_key.is_empty():
		return false
	var result_definition: PieceDef = PieceDefDatabase.get_def(String(result_piece_def_id))
	if result_definition == null:
		return false
	var king_ingredient_count: int = 0
	for ingredient_id: StringName in ingredient_piece_def_ids:
		var ingredient_definition: PieceDef = PieceDefDatabase.get_def(String(ingredient_id))
		if ingredient_definition == null:
			return false
		king_ingredient_count += 1 if ingredient_definition.is_king else 0
	return king_ingredient_count == 1 if result_definition.is_king else king_ingredient_count == 0

class_name FusionRecipeDef
extends Resource

@export var id: StringName = &""
@export var ingredient_piece_def_ids: Array[StringName] = []
@export var result_piece_def_id: StringName = &""
@export var display_name: String = ""

func is_valid() -> bool:
	if id.is_empty() or ingredient_piece_def_ids.size() < 2 or result_piece_def_id.is_empty():
		return false
	if PieceDefDatabase.get_def(String(result_piece_def_id)) == null:
		return false
	for ingredient_id: StringName in ingredient_piece_def_ids:
		if PieceDefDatabase.get_def(String(ingredient_id)) == null:
			return false
	return true

class_name FusionPlan
extends RefCounted

const CURRENT_VERSION := 1

var plan_version: int = CURRENT_VERSION
var recipe_id: StringName = &""
var ingredient_instance_ids: Array[int] = []
var result_piece_def_id: StringName = &""
var result_is_king: bool = false
var preserved_king_instance_id: int = 0
var destination: StringName = &"reserve"
var source_type: StringName = &""
var source_choice_id: String = ""
var price: int = 0
var original_pending_choice: Dictionary = {}

func is_structurally_valid() -> bool:
	if plan_version != CURRENT_VERSION or recipe_id.is_empty() or result_piece_def_id.is_empty():
		return false
	if ingredient_instance_ids.size() < 2 or price < 0:
		return false
	var seen: Dictionary = {}
	for instance_id: int in ingredient_instance_ids:
		if instance_id <= 0 or seen.has(instance_id):
			return false
		seen[instance_id] = true
	if result_is_king:
		if preserved_king_instance_id <= 0 or preserved_king_instance_id not in ingredient_instance_ids or destination != &"active":
			return false
	elif preserved_king_instance_id != 0 or destination != &"reserve":
		return false
	if not source_type.is_empty():
		if source_type not in [&"battle_reward", &"shop"] or source_choice_id.is_empty() or original_pending_choice.is_empty():
			return false
	return true

func to_dictionary() -> Dictionary:
	return {
		"plan_version": plan_version,
		"recipe_id": String(recipe_id),
		"ingredient_instance_ids": ingredient_instance_ids.duplicate(),
		"result_piece_def_id": String(result_piece_def_id),
		"result_is_king": result_is_king,
		"preserved_king_instance_id": preserved_king_instance_id,
		"destination": String(destination),
		"source_type": String(source_type),
		"source_choice_id": source_choice_id,
		"price": price,
		"original_pending_choice": original_pending_choice.duplicate(true),
	}

func load_from_dictionary(data: Dictionary) -> bool:
	plan_version = int(data.get("plan_version", -1))
	recipe_id = StringName(str(data.get("recipe_id", "")))
	ingredient_instance_ids.clear()
	var ingredient_values: Variant = data.get("ingredient_instance_ids", [])
	if not ingredient_values is Array:
		return false
	for value: Variant in ingredient_values as Array:
		ingredient_instance_ids.append(int(value))
	result_piece_def_id = StringName(str(data.get("result_piece_def_id", "")))
	result_is_king = bool(data.get("result_is_king", false))
	preserved_king_instance_id = int(data.get("preserved_king_instance_id", 0))
	destination = StringName(str(data.get("destination", "")))
	source_type = StringName(str(data.get("source_type", "")))
	source_choice_id = str(data.get("source_choice_id", ""))
	price = int(data.get("price", 0))
	var original_value: Variant = data.get("original_pending_choice", {})
	if not original_value is Dictionary:
		return false
	original_pending_choice = (original_value as Dictionary).duplicate(true)
	return is_structurally_valid()

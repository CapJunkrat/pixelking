class_name EncounterDef
extends Resource

@export var id: StringName = &""
@export var board_size: int = BoardState.DEFAULT_SIZE
@export var enemy_placements: Array[Dictionary] = []
@export var turn_limit: int = 0
@export var reward_tier: StringName = &"normal"
@export var is_boss: bool = false

func is_valid() -> bool:
	if id.is_empty() or board_size != BoardState.DEFAULT_SIZE or enemy_placements.is_empty() or turn_limit < 0 or reward_tier not in [&"normal", &"elite", &"boss"]:
		return false
	var placement_ids: Dictionary = {}
	var occupied: Dictionary = {}
	var king_count: int = 0
	for placement: Dictionary in enemy_placements:
		var placement_id: String = str(placement.get("placement_id", ""))
		var piece_def_id: StringName = StringName(str(placement.get("piece_def_id", "")))
		var position: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
		if placement_id.is_empty() or placement_ids.has(placement_id) or piece_def_id.is_empty():
			return false
		if position.x < 0 or position.x >= board_size or position.y < board_size - 2 or position.y >= board_size:
			return false
		if occupied.has(position):
			return false
		placement_ids[placement_id] = true
		occupied[position] = true
		king_count += 1 if piece_def_id == &"king" else 0
	return king_count == 1

func placement_copies() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for placement: Dictionary in enemy_placements:
		result.append(placement.duplicate(true))
	return result

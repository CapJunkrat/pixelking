class_name DeploymentState
extends RefCounted

const CURRENT_VERSION := 1

var deployment_version: int = CURRENT_VERSION
var encounter_id: StringName = &""
var board_size: int = BoardState.DEFAULT_SIZE
var player_positions: Dictionary = {}
var enemy_placements: Array[Dictionary] = []
var confirmed: bool = false

func player_position(instance_id: int) -> Vector2i:
	var value: Variant = player_positions.get(str(instance_id), {})
	return _position_from_value(value)

func player_at(position: Vector2i) -> int:
	for id_value: Variant in player_positions.keys():
		if _position_from_value(player_positions[id_value]) == position:
			return int(str(id_value))
	return 0

func is_valid(run_state: RunState) -> bool:
	if deployment_version != CURRENT_VERSION or encounter_id.is_empty() or board_size != BoardState.DEFAULT_SIZE:
		return false
	if run_state == null or encounter_id != run_state.current_encounter_id:
		return false
	var expected_ids: Dictionary = {}
	for instance_id: int in run_state.active_piece_ids:
		expected_ids[str(instance_id)] = true
	if expected_ids.size() != player_positions.size():
		return false
	var occupied: Dictionary = {}
	var king_placed: bool = false
	for id_value: Variant in player_positions.keys():
		var id_key: String = str(id_value)
		if not expected_ids.has(id_key):
			return false
		var piece: PieceInstanceState = run_state.get_piece_state(int(id_key))
		var position: Vector2i = _position_from_value(player_positions[id_value])
		if piece == null or position == Vector2i(-1, -1) or not _is_player_square(position) or occupied.has(position):
			return false
		occupied[position] = true
		king_placed = king_placed or piece.is_king
	if not king_placed or enemy_placements.is_empty():
		return false
	var enemy_occupied: Dictionary = {}
	var enemy_king_count: int = 0
	for placement: Dictionary in enemy_placements:
		var piece_def_id: String = str(placement.get("piece_def_id", ""))
		var definition: PieceDef = PieceDefDatabase.get_def(piece_def_id)
		var position: Vector2i = _position_from_value(placement.get("position", {}))
		if definition == null or position == Vector2i(-1, -1) or not _is_enemy_square(position) or enemy_occupied.has(position):
			return false
		enemy_occupied[position] = true
		if definition.is_king:
			enemy_king_count += 1
	return enemy_king_count == 1

func to_dictionary() -> Dictionary:
	var enemy_data: Array[Dictionary] = []
	for placement: Dictionary in enemy_placements:
		enemy_data.append(placement.duplicate(true))
	return {
		"deployment_version": deployment_version,
		"encounter_id": String(encounter_id),
		"board_size": board_size,
		"player_positions": player_positions.duplicate(true),
		"enemy_placements": enemy_data,
		"confirmed": confirmed,
	}

func load_from_dictionary(data: Dictionary, run_state: RunState) -> bool:
	if int(data.get("deployment_version", -1)) != CURRENT_VERSION:
		return false
	deployment_version = CURRENT_VERSION
	encounter_id = StringName(str(data.get("encounter_id", "")))
	board_size = int(data.get("board_size", BoardState.DEFAULT_SIZE))
	var positions_value: Variant = data.get("player_positions", {})
	var enemies_value: Variant = data.get("enemy_placements", [])
	if not positions_value is Dictionary or not enemies_value is Array:
		return false
	player_positions = (positions_value as Dictionary).duplicate(true)
	enemy_placements.clear()
	for placement_value: Variant in enemies_value as Array:
		if not placement_value is Dictionary:
			return false
		enemy_placements.append((placement_value as Dictionary).duplicate(true))
	confirmed = bool(data.get("confirmed", false))
	return is_valid(run_state)

func set_player_position(instance_id: int, position: Vector2i) -> void:
	player_positions[str(instance_id)] = _position_value(position)

func _is_player_square(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < board_size and position.y >= 0 and position.y <= 1

func _is_enemy_square(position: Vector2i) -> bool:
	return (
		position.x >= 0
		and position.x < board_size
		and position.y >= board_size - 2
		and position.y < board_size
	)

static func position_value(position: Vector2i) -> Dictionary:
	return {"x": position.x, "y": position.y}

static func position_from_value(value: Variant) -> Vector2i:
	if not value is Dictionary:
		return Vector2i(-1, -1)
	var data: Dictionary = value as Dictionary
	if not data.has("x") or not data.has("y"):
		return Vector2i(-1, -1)
	return Vector2i(int(data["x"]), int(data["y"]))

func _position_value(position: Vector2i) -> Dictionary:
	return position_value(position)

func _position_from_value(value: Variant) -> Vector2i:
	return position_from_value(value)

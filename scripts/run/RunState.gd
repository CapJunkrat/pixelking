class_name RunState
extends RefCounted

const CURRENT_RUN_VERSION := 3
const MODE_STANDARD := "standard"
const MODE_ENDLESS := "endless"
const MAX_ACTIVE_NON_KING_PIECES := 5
const MAX_RESERVE_PIECES := 5
const MAX_FAILURES := 3

var run_version: int = CURRENT_RUN_VERSION
var mode: String = MODE_STANDARD
var run_seed: int = 0
var rng_stream_states: Dictionary = {}
var current_map_id: StringName = &""
var map_state: MapState = null
var current_node_id: StringName = &""
var visited_node_ids: Array[StringName] = []
var resolved_node_payloads: Dictionary = {}
var failed_battles: int = 0
var remaining_failure_allowance: int = MAX_FAILURES
var player_roster: Array[PieceInstanceState] = []
var active_piece_ids: Array[int] = []
var reserve_piece_ids: Array[int] = []
var challenger_slots: Array[StringName] = []
var owned_recipe_history: Array[StringName] = []
var gold: int = 0
var protected_piece_ids: Array[int] = []
var current_encounter_id: StringName = &""
var current_encounter_seed: int = 0
var deployment_state: DeploymentState = null
var pending_choice: Dictionary = {}
var run_statistics: Dictionary = {}
var next_piece_instance_id: int = 1

func initialize_new(seed_value: int, mode_value: String = MODE_STANDARD) -> void:
	run_version = CURRENT_RUN_VERSION
	mode = mode_value
	run_seed = seed_value
	rng_stream_states.clear()
	current_map_id = &""
	map_state = null
	current_node_id = &""
	visited_node_ids.clear()
	resolved_node_payloads.clear()
	failed_battles = 0
	remaining_failure_allowance = MAX_FAILURES
	player_roster.clear()
	active_piece_ids.clear()
	reserve_piece_ids.clear()
	challenger_slots.clear()
	owned_recipe_history.clear()
	gold = 0
	protected_piece_ids.clear()
	current_encounter_id = &""
	current_encounter_seed = 0
	deployment_state = null
	pending_choice.clear()
	run_statistics.clear()
	next_piece_instance_id = 1

func allocate_piece(piece_def_id: String, make_king: bool = false) -> PieceInstanceState:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_def_id)
	if definition == null or definition.is_king != make_king:
		return null
	if make_king and _king_count() > 0:
		return null
	if not make_king and reserve_piece_ids.size() >= MAX_RESERVE_PIECES:
		return null
	var piece: PieceInstanceState = PieceInstanceState.new(next_piece_instance_id, StringName(piece_def_id), make_king)
	next_piece_instance_id += 1
	player_roster.append(piece)
	if make_king:
		active_piece_ids.append(piece.instance_id)
	else:
		reserve_piece_ids.append(piece.instance_id)
	return piece

func get_piece_state(instance_id: int) -> PieceInstanceState:
	for piece: PieceInstanceState in player_roster:
		if piece.instance_id == instance_id:
			return piece
	return null

func move_piece_to_active(instance_id: int) -> bool:
	var piece: PieceInstanceState = get_piece_state(instance_id)
	if piece == null or piece.is_king or instance_id in active_piece_ids:
		return false
	if _active_non_king_count() >= MAX_ACTIVE_NON_KING_PIECES:
		return false
	reserve_piece_ids.erase(instance_id)
	active_piece_ids.append(instance_id)
	return true

func move_piece_to_reserve(instance_id: int) -> bool:
	var piece: PieceInstanceState = get_piece_state(instance_id)
	if piece == null or piece.is_king or instance_id in reserve_piece_ids:
		return false
	if reserve_piece_ids.size() >= MAX_RESERVE_PIECES:
		return false
	active_piece_ids.erase(instance_id)
	reserve_piece_ids.append(instance_id)
	return true

func is_valid() -> bool:
	if run_version != CURRENT_RUN_VERSION or mode not in [MODE_STANDARD, MODE_ENDLESS]:
		return false
	if failed_battles < 0 or failed_battles > MAX_FAILURES:
		return false
	if remaining_failure_allowance != maxi(0, MAX_FAILURES - failed_battles):
		return false
	if gold < 0 or challenger_slots.size() > 6:
		return false
	if not _pending_choice_is_valid() or not _map_progress_is_valid():
		return false
	if _king_count() != 1 or _active_non_king_count() > MAX_ACTIVE_NON_KING_PIECES or reserve_piece_ids.size() > MAX_RESERVE_PIECES:
		return false
	var roster_ids: Dictionary = {}
	var max_id: int = 0
	for piece: PieceInstanceState in player_roster:
		if piece == null or not piece.is_valid() or roster_ids.has(piece.instance_id):
			return false
		roster_ids[piece.instance_id] = true
		max_id = maxi(max_id, piece.instance_id)
	if next_piece_instance_id <= max_id:
		return false
	var membership: Dictionary = {}
	for instance_id: int in active_piece_ids + reserve_piece_ids:
		if not roster_ids.has(instance_id) or membership.has(instance_id):
			return false
		membership[instance_id] = true
	if membership.size() != player_roster.size():
		return false
	for instance_id: int in protected_piece_ids:
		if not roster_ids.has(instance_id):
			return false
	var king: PieceInstanceState = _king_piece()
	if king == null or king.instance_id not in active_piece_ids:
		return false
	if deployment_state != null:
		if not deployment_state.is_valid(self):
			return false
		if resolved_node_payloads.has(String(current_node_id)):
			return false
	return true

func to_dictionary() -> Dictionary:
	var roster_data: Array[Dictionary] = []
	for piece: PieceInstanceState in player_roster:
		roster_data.append(piece.to_dictionary())
	return {
		"run_version": run_version,
		"mode": mode,
		"seed": run_seed,
		"rng_stream_states": rng_stream_states.duplicate(true),
		"current_map_id": String(current_map_id),
		"map_state": map_state.to_dictionary() if map_state != null else {},
		"current_node_id": String(current_node_id),
		"visited_node_ids": _string_name_array_to_strings(visited_node_ids),
		"resolved_node_payloads": resolved_node_payloads.duplicate(true),
		"failed_battles": failed_battles,
		"remaining_failure_allowance": remaining_failure_allowance,
		"player_roster": roster_data,
		"active_piece_ids": active_piece_ids.duplicate(),
		"reserve_piece_ids": reserve_piece_ids.duplicate(),
		"challenger_slots": _string_name_array_to_strings(challenger_slots),
		"owned_recipe_history": _string_name_array_to_strings(owned_recipe_history),
		"gold": gold,
		"protected_piece_ids": protected_piece_ids.duplicate(),
		"current_encounter_id": String(current_encounter_id),
		"current_encounter_seed": current_encounter_seed,
		"deployment_state": deployment_state.to_dictionary() if deployment_state != null else {},
		"pending_choice": pending_choice.duplicate(true),
		"run_statistics": run_statistics.duplicate(true),
		"next_piece_instance_id": next_piece_instance_id,
	}

func load_from_dictionary(data: Dictionary) -> bool:
	if int(data.get("run_version", -1)) != CURRENT_RUN_VERSION:
		return false
	var loaded_mode: String = str(data.get("mode", ""))
	if loaded_mode not in [MODE_STANDARD, MODE_ENDLESS]:
		return false
	run_version = CURRENT_RUN_VERSION
	mode = loaded_mode
	run_seed = int(data.get("seed", 0))
	rng_stream_states = _dictionary_value(data, "rng_stream_states")
	current_map_id = StringName(str(data.get("current_map_id", "")))
	map_state = null
	var map_value: Variant = data.get("map_state", {})
	if map_value is Dictionary and not (map_value as Dictionary).is_empty():
		map_state = MapState.new()
		if not map_state.load_from_dictionary(map_value as Dictionary):
			return false
	elif not map_value is Dictionary:
		return false
	current_node_id = StringName(str(data.get("current_node_id", "")))
	visited_node_ids = _to_string_name_array(data.get("visited_node_ids", []))
	resolved_node_payloads = _dictionary_value(data, "resolved_node_payloads")
	failed_battles = int(data.get("failed_battles", 0))
	remaining_failure_allowance = int(data.get("remaining_failure_allowance", MAX_FAILURES))
	player_roster.clear()
	var roster_values: Array = data.get("player_roster", []) as Array
	for value: Variant in roster_values:
		if not value is Dictionary:
			return false
		var piece: PieceInstanceState = PieceInstanceState.new()
		if not piece.load_from_dictionary(value as Dictionary):
			return false
		player_roster.append(piece)
	active_piece_ids = _to_int_array(data.get("active_piece_ids", []))
	reserve_piece_ids = _to_int_array(data.get("reserve_piece_ids", []))
	challenger_slots = _to_string_name_array(data.get("challenger_slots", []))
	owned_recipe_history = _to_string_name_array(data.get("owned_recipe_history", []))
	gold = int(data.get("gold", 0))
	protected_piece_ids = _to_int_array(data.get("protected_piece_ids", []))
	current_encounter_id = StringName(str(data.get("current_encounter_id", "")))
	current_encounter_seed = int(data.get("current_encounter_seed", 0))
	deployment_state = null
	var deployment_value: Variant = data.get("deployment_state", {})
	if deployment_value is Dictionary and not (deployment_value as Dictionary).is_empty():
		deployment_state = DeploymentState.new()
		if not deployment_state.load_from_dictionary(deployment_value as Dictionary, self):
			return false
	elif not deployment_value is Dictionary:
		return false
	pending_choice = _dictionary_value(data, "pending_choice")
	run_statistics = _dictionary_value(data, "run_statistics")
	next_piece_instance_id = int(data.get("next_piece_instance_id", 1))
	return is_valid()

func _pending_choice_is_valid() -> bool:
	if pending_choice.is_empty():
		return true
	if int(pending_choice.get("choice_version", -1)) != 1:
		return false
	var type: String = str(pending_choice.get("type", ""))
	if type == "opening_draft":
		return _opening_choice_is_valid()
	if type not in ["battle_reward", "roster_overflow", "shop", "event", "rest", "sacrifice", "run_summary"]:
		return false
	var options_value: Variant = pending_choice.get("options", [])
	if not options_value is Array:
		return false
	var seen: Dictionary = {}
	for value: Variant in options_value as Array:
		if not value is Dictionary:
			return false
		var option: Dictionary = value as Dictionary
		var option_id: String = str(option.get("id", ""))
		if option_id.is_empty() or seen.has(option_id) or not option.get("payload", {}) is Dictionary:
			return false
		seen[option_id] = true
	if type == "run_summary":
		return (options_value as Array).is_empty()
	return not (options_value as Array).is_empty()

func _opening_choice_is_valid() -> bool:
	var round_index: int = int(pending_choice.get("round_index", -1))
	var candidates: Array[String] = _to_string_array(pending_choice.get("candidate_piece_def_ids", []))
	var selected_ids: Array[String] = _to_string_array(pending_choice.get("selected_piece_def_ids", []))
	if round_index < 0 or round_index >= 3 or selected_ids.size() != round_index or candidates.size() != 3:
		return false
	var unique_candidates: Dictionary = {}
	var has_rare: bool = false
	for candidate_id: String in candidates:
		if unique_candidates.has(candidate_id):
			return false
		unique_candidates[candidate_id] = true
		var definition: PieceDef = PieceDefDatabase.get_def(candidate_id)
		if definition == null or not definition.is_valid_opening_draft_piece():
			return false
		has_rare = has_rare or definition.is_rare_or_higher()
	if not has_rare:
		return false
	var required: Dictionary = {}
	for selected_id: String in selected_ids:
		required[selected_id] = int(required.get(selected_id, 0)) + 1
	var actual: Dictionary = {}
	for piece: PieceInstanceState in player_roster:
		if not piece.is_king:
			var id: String = String(piece.piece_def_id)
			actual[id] = int(actual.get(id, 0)) + 1
	for selected_id: String in required:
		if int(actual.get(selected_id, 0)) < int(required[selected_id]):
			return false
	return true

func _map_progress_is_valid() -> bool:
	if map_state == null:
		return (
			current_map_id.is_empty()
			and current_node_id.is_empty()
			and visited_node_ids.is_empty()
			and resolved_node_payloads.is_empty()
		)
	if not bool(run_statistics.get("opening_draft_complete", false)):
		return false
	if not map_state.is_valid() or current_map_id != map_state.map_id:
		return false
	var visited: Dictionary = {}
	var previous: MapNodeState = null
	for index: int in range(visited_node_ids.size()):
		var node_id: StringName = visited_node_ids[index]
		if visited.has(node_id):
			return false
		var node: MapNodeState = map_state.get_node(node_id)
		if node == null:
			return false
		if index == 0 and node.layer_index != 0:
			return false
		if previous != null and node_id not in previous.outgoing_node_ids:
			return false
		if index < visited_node_ids.size() - 1 and not resolved_node_payloads.has(String(node_id)):
			return false
		visited[node_id] = true
		previous = node
	if visited_node_ids.is_empty():
		if not current_node_id.is_empty() or not resolved_node_payloads.is_empty():
			return false
	elif current_node_id != visited_node_ids[-1]:
		return false
	for resolved_id: Variant in resolved_node_payloads.keys():
		if not visited.has(StringName(str(resolved_id))) or not resolved_node_payloads[resolved_id] is Dictionary:
			return false
	return true

func _active_non_king_count() -> int:
	var count: int = 0
	for instance_id: int in active_piece_ids:
		var piece: PieceInstanceState = get_piece_state(instance_id)
		if piece != null and not piece.is_king:
			count += 1
	return count

func _king_count() -> int:
	var count: int = 0
	for piece: PieceInstanceState in player_roster:
		if piece.is_king:
			count += 1
	return count

func _king_piece() -> PieceInstanceState:
	for piece: PieceInstanceState in player_roster:
		if piece.is_king:
			return piece
	return null

func _string_name_array_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			result.append(str(entry))
	return result

func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry: Variant in value as Array:
			result.append(StringName(str(entry)))
	return result

func _to_int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for entry: Variant in value as Array:
			result.append(int(entry))
	return result

func _dictionary_value(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}

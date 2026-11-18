class_name OpeningDraftService
extends RefCounted

const CHOICE_TYPE := "opening_draft"
const CHOICE_VERSION := 1
const ROUND_COUNT := 3
const CANDIDATE_COUNT := 3
const RNG_STREAM: StringName = &"reward_rng"

func ensure_pending_choice(run_state: RunState, rng: RunRngService) -> Error:
	if run_state == null or rng == null or not run_state.is_valid():
		return ERR_INVALID_DATA
	if is_complete(run_state):
		return OK
	if not run_state.pending_choice.is_empty():
		return OK if validate_pending_choice(run_state) else ERR_INVALID_DATA
	var selected_ids: Array[String] = _stored_picks(run_state)
	if selected_ids.size() >= ROUND_COUNT:
		_mark_complete(run_state, selected_ids)
		return OK
	var candidates: Array[String] = _generate_candidates(rng)
	if candidates.size() != CANDIDATE_COUNT:
		return ERR_CANT_CREATE
	run_state.pending_choice = _choice_dictionary(selected_ids.size(), candidates, selected_ids)
	return OK

func apply_choice(run_state: RunState, rng: RunRngService, piece_def_id: String) -> Error:
	if not validate_pending_choice(run_state):
		return ERR_INVALID_DATA
	var candidates: Array = run_state.pending_choice.get("candidate_piece_def_ids", []) as Array
	if piece_def_id not in candidates:
		return ERR_INVALID_PARAMETER
	var definition: PieceDef = PieceDefDatabase.get_def(piece_def_id)
	if definition == null or not definition.is_valid_opening_draft_piece():
		return ERR_INVALID_DATA
	var selected_ids: Array[String] = _to_string_array(run_state.pending_choice.get("selected_piece_def_ids", []))
	var piece: PieceInstanceState = run_state.allocate_piece(piece_def_id, false)
	if piece == null:
		return ERR_OUT_OF_MEMORY
	selected_ids.append(piece_def_id)
	if selected_ids.size() >= ROUND_COUNT:
		_mark_complete(run_state, selected_ids)
		return OK
	var next_candidates: Array[String] = _generate_candidates(rng)
	if next_candidates.size() != CANDIDATE_COUNT:
		return ERR_CANT_CREATE
	run_state.pending_choice = _choice_dictionary(selected_ids.size(), next_candidates, selected_ids)
	return OK

func validate_pending_choice(run_state: RunState) -> bool:
	if run_state == null or run_state.pending_choice.is_empty():
		return false
	var choice: Dictionary = run_state.pending_choice
	if str(choice.get("type", "")) != CHOICE_TYPE or int(choice.get("choice_version", -1)) != CHOICE_VERSION:
		return false
	var round_index: int = int(choice.get("round_index", -1))
	var candidates: Array[String] = _to_string_array(choice.get("candidate_piece_def_ids", []))
	var selected_ids: Array[String] = _to_string_array(choice.get("selected_piece_def_ids", []))
	if round_index < 0 or round_index >= ROUND_COUNT or selected_ids.size() != round_index:
		return false
	if candidates.size() != CANDIDATE_COUNT or _unique_count(candidates) != CANDIDATE_COUNT:
		return false
	var has_rare: bool = false
	for candidate_id: String in candidates:
		var definition: PieceDef = PieceDefDatabase.get_def(candidate_id)
		if definition == null or not definition.is_valid_opening_draft_piece():
			return false
		has_rare = has_rare or definition.is_rare_or_higher()
	if not has_rare:
		return false
	return _roster_contains_picks(run_state, selected_ids)

func is_complete(run_state: RunState) -> bool:
	return run_state != null and bool(run_state.run_statistics.get("opening_draft_complete", false))

func selected_piece_ids(run_state: RunState) -> Array[String]:
	if is_complete(run_state):
		return _to_string_array(run_state.run_statistics.get("opening_draft_picks", []))
	if validate_pending_choice(run_state):
		return _to_string_array(run_state.pending_choice.get("selected_piece_def_ids", []))
	return []

func _generate_candidates(rng: RunRngService) -> Array[String]:
	var pool: Array[PieceDef] = PieceDefDatabase.opening_draft_defs()
	var rare_pool: Array[PieceDef] = []
	for definition: PieceDef in pool:
		if definition.is_rare_or_higher():
			rare_pool.append(definition)
	if pool.size() < CANDIDATE_COUNT or rare_pool.is_empty():
		return []
	var chosen: Array[PieceDef] = []
	var guaranteed: PieceDef = _weighted_pick(rare_pool, rng)
	if guaranteed == null:
		return []
	chosen.append(guaranteed)
	pool.erase(guaranteed)
	while chosen.size() < CANDIDATE_COUNT:
		var candidate: PieceDef = _weighted_pick(pool, rng)
		if candidate == null:
			return []
		chosen.append(candidate)
		pool.erase(candidate)
	_shuffle(chosen, rng)
	var ids: Array[String] = []
	for definition: PieceDef in chosen:
		ids.append(definition.id)
	return ids

func _weighted_pick(pool: Array[PieceDef], rng: RunRngService) -> PieceDef:
	var total_weight: int = 0
	for definition: PieceDef in pool:
		total_weight += _draft_weight(definition)
	if total_weight <= 0:
		return null
	var roll: int = rng.randi_range(RNG_STREAM, 1, total_weight)
	var cursor: int = 0
	for definition: PieceDef in pool:
		cursor += _draft_weight(definition)
		if roll <= cursor:
			return definition
	return pool[-1] if not pool.is_empty() else null

## Rare and rarer pieces are drafted far more often than their base weight says.
const RARE_DRAFT_MULTIPLIER := 3

func _draft_weight(definition: PieceDef) -> int:
	return definition.opening_draft_weight * (RARE_DRAFT_MULTIPLIER if definition.is_rare_or_higher() else 1)

func _shuffle(values: Array[PieceDef], rng: RunRngService) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(RNG_STREAM, 0, index)
		var temporary: PieceDef = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary

func _choice_dictionary(round_index: int, candidates: Array[String], selected_ids: Array[String]) -> Dictionary:
	return {
		"type": CHOICE_TYPE,
		"choice_version": CHOICE_VERSION,
		"round_index": round_index,
		"candidate_piece_def_ids": candidates.duplicate(),
		"selected_piece_def_ids": selected_ids.duplicate(),
	}

func _mark_complete(run_state: RunState, selected_ids: Array[String]) -> void:
	run_state.pending_choice.clear()
	run_state.run_statistics["opening_draft_complete"] = true
	run_state.run_statistics["opening_draft_picks"] = selected_ids.duplicate()

func _stored_picks(run_state: RunState) -> Array[String]:
	return _to_string_array(run_state.run_statistics.get("opening_draft_picks", []))

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			result.append(str(entry))
	return result

func _unique_count(values: Array[String]) -> int:
	var unique: Dictionary = {}
	for value: String in values:
		unique[value] = true
	return unique.size()

func _roster_contains_picks(run_state: RunState, selected_ids: Array[String]) -> bool:
	var required: Dictionary = {}
	for selected_id: String in selected_ids:
		required[selected_id] = int(required.get(selected_id, 0)) + 1
	var actual: Dictionary = {}
	for piece: PieceInstanceState in run_state.player_roster:
		if not piece.is_king:
			var id: String = String(piece.piece_def_id)
			actual[id] = int(actual.get(id, 0)) + 1
	for id: String in required:
		if int(actual.get(id, 0)) < int(required[id]):
			return false
	return true

class_name RunRewardService
extends RefCounted

func apply(run_state: RunState, payload: Dictionary) -> Error:
	var kind: String = str(payload.get("kind", ""))
	match kind:
		"gold":
			run_state.gold += int(payload.get("amount", 0))
		"piece":
			var piece_id: String = str(payload.get("piece_def_id", ""))
			return OK if run_state.allocate_piece(piece_id, false) != null else ERR_UNAVAILABLE
		"relic":
			var relic_id: StringName = StringName(str(payload.get("relic_id", "")))
			if not RunContentDatabase.is_relic(relic_id) or relic_id in run_state.challenger_slots or run_state.challenger_slots.size() >= 6:
				return ERR_UNAVAILABLE
			run_state.challenger_slots.append(relic_id)
		"item":
			var item_id: StringName = StringName(str(payload.get("item_id", "")))
			var item_definition: ChallengerItemDef = ChallengerItemDatabase.get_def(item_id)
			if item_definition == null or not item_definition.is_consumable() or run_state.challenger_slots.size() >= 6:
				return ERR_UNAVAILABLE
			run_state.challenger_slots.append(item_id)
		"restore_retry":
			# Capped at one retry: restoring while already full changes nothing.
			if run_state.has_full_retries():
				return ERR_UNAVAILABLE
			run_state.restore_retries()
		"fusion":
			return ERR_INVALID_PARAMETER
		_:
			return ERR_INVALID_PARAMETER
	return OK

func remove_piece(run_state: RunState, instance_id: int) -> Error:
	var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
	if piece == null:
		return ERR_DOES_NOT_EXIST
	if piece.is_king:
		return ERR_UNAUTHORIZED
	run_state.active_piece_ids.erase(instance_id)
	run_state.reserve_piece_ids.erase(instance_id)
	run_state.player_roster.erase(piece)
	return OK

func unowned_relic(run_state: RunState, rng: RunRngService, stream: StringName) -> StringName:
	var candidates: Array[StringName] = []
	for relic: StringName in RunContentDatabase.relic_ids():
		if relic not in run_state.challenger_slots:
			candidates.append(relic)
	return candidates[rng.pick_index(stream, candidates.size())] if not candidates.is_empty() else &""

static func retry_label(run_state: RunState) -> String:
	return "Restore your retry (already full)" if run_state.has_full_retries() else "Restore your retry"

func piece_label(piece: PieceInstanceState) -> String:
	return "%s #%d" % [definition_label(String(piece.piece_def_id)), piece.instance_id]

func definition_label(definition_id: String) -> String:
	return definition_id.replace("_", " ").capitalize()

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
		"nothing":
			pass
		"lose_gold":
			run_state.gold = maxi(0, run_state.gold - int(payload.get("amount", 0)))
		"train":
			var trainee: PieceInstanceState = run_state.get_piece_state(int(payload.get("instance_id", 0)))
			if trainee == null:
				return ERR_UNAVAILABLE
			for _drill: int in range(maxi(1, int(payload.get("times", 1)))):
				train(trainee)
		"transform":
			# One of your pieces becomes another (an armed Pawn, a traded recruit).
			var changed: PieceInstanceState = run_state.get_piece_state(int(payload.get("instance_id", 0)))
			var into: PieceDef = PieceDefDatabase.get_def(str(payload.get("piece_def_id", "")))
			if changed == null or changed.is_king or into == null or into.is_king:
				return ERR_UNAVAILABLE
			changed.piece_def_id = StringName(into.id)
			changed.capture_count = 0
			changed.learned_def_ids.clear()
		"lose_item":
			var lost: StringName = StringName(str(payload.get("item_id", "")))
			if lost not in run_state.challenger_slots:
				return ERR_UNAVAILABLE
			run_state.challenger_slots.erase(lost)
		"lose_retry":
			if run_state.retries_left <= 0:
				return ERR_UNAVAILABLE
			run_state.retries_left = 0
		"fusion":
			return ERR_INVALID_PARAMETER
		_:
			return ERR_INVALID_PARAMETER
	return OK

## One capture's worth of experience, applying any growth it unlocks.
func train(piece: PieceInstanceState) -> void:
	piece.capture_count += 1
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id))
	while definition != null and definition.evolve_at_captures > 0 and piece.capture_count >= definition.evolve_at_captures:
		var next: PieceDef = PieceDefDatabase.get_def(definition.evolves_into)
		if next == null or next.is_king != piece.is_king:
			break
		piece.piece_def_id = StringName(next.id)
		definition = next

## Recruitable pieces of a rarity band: "common" or "rare" (rare and epic).
func piece_pool(band: String) -> Array[String]:
	var ids: Array[StringName] = []
	var table: BattleRewardTableDef = RunContentDatabase.battle_reward_table()
	if table != null:
		ids.append_array(table.recruit_piece_ids)
	var result: Array[String] = []
	for id: StringName in ids:
		var definition: PieceDef = PieceDefDatabase.get_def(String(id))
		if definition == null or definition.is_king or String(id) in result:
			continue
		var common: bool = definition.rarity == PieceDef.Rarity.COMMON
		if (band == "common") == common:
			result.append(String(id))
	return result

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
	var definition: PieceDef = PieceDefDatabase.get_def(definition_id)
	var localization: Node = Engine.get_main_loop().root.get_node_or_null("Localization") if Engine.get_main_loop() is SceneTree else null
	if definition != null and localization != null:
		return str(localization.call("text", String(definition.display_name_key)))
	return definition_id.replace("_", " ").capitalize()

class_name RunContentService
extends RefCounted

const INTERACTION_SCENE := "res://scenes/run/RunInteractionScene.tscn"
const BATTLE_TYPES: Array[StringName] = [&"normal_battle", &"elite_battle", &"boss"]

func begin_current_node(run_state: RunState, rng: RunRngService) -> Error:
	if run_state == null or rng == null or run_state.map_state == null or not run_state.pending_choice.is_empty():
		return ERR_INVALID_DATA
	var node: MapNodeState = run_state.map_state.get_node(run_state.current_node_id)
	if node == null or run_state.resolved_node_payloads.has(String(node.node_id)):
		return ERR_UNAVAILABLE
	match node.node_type_id:
		&"shop":
			_stage_shop(run_state, rng)
		&"event":
			_stage_event(run_state, rng)
		&"rest":
			_stage_rest(run_state)
		_:
			return ERR_INVALID_PARAMETER
	return OK

func apply_battle_victory(run_state: RunState, rng: RunRngService, progress: MapProgressService, deployment: DeploymentService) -> Error:
	if run_state == null or rng == null or progress == null or deployment == null:
		return ERR_INVALID_PARAMETER
	var node: MapNodeState = run_state.map_state.get_node(run_state.current_node_id) if run_state.map_state != null else null
	if node == null or node.node_type_id not in BATTLE_TYPES:
		return ERR_INVALID_DATA
	var payload: Dictionary = {"outcome": "victory", "gold_before_reward": run_state.gold}
	var error: Error = progress.resolve_current_node(run_state, payload)
	if error != OK:
		return error
	deployment.clear(run_state)
	run_state.run_statistics["battles_won"] = int(run_state.run_statistics.get("battles_won", 0)) + 1
	if node.node_type_id == &"boss":
		_stage_summary(run_state, true)
	else:
		_stage_reward(run_state, rng, node.node_type_id == &"elite_battle")
	return OK

func apply_battle_defeat(run_state: RunState, rng: RunRngService, deployment: DeploymentService) -> Error:
	if run_state == null or rng == null or deployment == null:
		return ERR_INVALID_PARAMETER
	run_state.failed_battles += 1
	run_state.remaining_failure_allowance = maxi(0, RunState.MAX_FAILURES - run_state.failed_battles)
	run_state.run_statistics["battles_lost"] = int(run_state.run_statistics.get("battles_lost", 0)) + 1
	deployment.clear(run_state)
	if run_state.failed_battles >= RunState.MAX_FAILURES:
		_stage_summary(run_state, false)
		return OK
	var eligible: Array[int] = []
	var non_king_count: int = 0
	for piece: PieceInstanceState in run_state.player_roster:
		if piece.is_king:
			continue
		non_king_count += 1
		if piece.instance_id not in run_state.protected_piece_ids:
			eligible.append(piece.instance_id)
	for protected_id: int in run_state.protected_piece_ids:
		var protected_piece: PieceInstanceState = run_state.get_piece_state(protected_id)
		if protected_piece != null:
			protected_piece.is_protected = false
	run_state.protected_piece_ids.clear()
	if non_king_count == 0:
		_stage_summary(run_state, false)
		return OK
	if eligible.is_empty():
		return deployment.ensure_deployment(run_state)
	var candidates: Array[int] = []
	while not eligible.is_empty() and candidates.size() < 3:
		var index: int = rng.pick_index(&"sacrifice_rng", eligible.size())
		candidates.append(eligible.pop_at(index))
	var options: Array[Dictionary] = []
	for instance_id: int in candidates:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		options.append(_option("piece_%d" % instance_id, _piece_label(piece), "sacrifice", {"instance_id": instance_id}))
	run_state.pending_choice = _pending("sacrifice", "Choose a Sacrifice", "Lose one challenger, then redeploy against the same encounter.", options, false)
	return OK

func submit(run_state: RunState, _rng: RunRngService, progress: MapProgressService, deployment: DeploymentService, choice_id: String) -> Error:
	if run_state == null or run_state.pending_choice.is_empty():
		return ERR_DOES_NOT_EXIST
	var pending: Dictionary = run_state.pending_choice
	var option: Dictionary = _find_option(pending, choice_id)
	if option.is_empty() or not bool(option.get("enabled", true)):
		return ERR_INVALID_PARAMETER
	var type: String = str(pending.get("type", ""))
	var payload: Dictionary = option.get("payload", {}) as Dictionary
	match type:
		"battle_reward":
			if str(payload.get("kind", "")) == "piece" and run_state.reserve_piece_ids.size() >= RunState.MAX_RESERVE_PIECES:
				_stage_roster_overflow(run_state, str(payload.get("piece_def_id", "")))
				return OK
			var reward_error: Error = _apply_reward(run_state, payload)
			if reward_error != OK:
				return reward_error
			run_state.pending_choice.clear()
		"roster_overflow":
			var overflow_kind: String = str(payload.get("kind", ""))
			if overflow_kind == "discard_new":
				run_state.pending_choice.clear()
				return OK
			if overflow_kind != "replace_piece":
				return ERR_INVALID_PARAMETER
			var replaced_id: int = int(payload.get("instance_id", 0))
			var replacement_id: String = str(payload.get("piece_def_id", ""))
			var remove_error: Error = _remove_piece(run_state, replaced_id)
			if remove_error != OK or run_state.allocate_piece(replacement_id, false) == null:
				return ERR_UNAVAILABLE
			run_state.pending_choice.clear()
		"shop":
			var price: int = int(payload.get("price", 0))
			if run_state.gold < price:
				return ERR_UNAVAILABLE
			var shop_error: Error = _apply_reward(run_state, payload)
			if shop_error != OK:
				return shop_error
			run_state.gold -= price
			return _resolve_interaction_node(run_state, progress, {"outcome": "purchase", "choice": choice_id})
		"event", "rest":
			var effect_error: Error = _apply_reward(run_state, payload)
			if effect_error != OK:
				return effect_error
			return _resolve_interaction_node(run_state, progress, {"outcome": type, "choice": choice_id})
		"sacrifice":
			var instance_id: int = int(payload.get("instance_id", 0))
			var remove_error: Error = _remove_piece(run_state, instance_id)
			if remove_error != OK:
				return remove_error
			run_state.pending_choice.clear()
			return deployment.ensure_deployment(run_state)
		_:
			return ERR_INVALID_PARAMETER
	return OK

func leave(run_state: RunState, progress: MapProgressService) -> Error:
	if run_state == null or run_state.pending_choice.is_empty():
		return ERR_DOES_NOT_EXIST
	if not bool(run_state.pending_choice.get("allow_leave", false)):
		return ERR_UNAUTHORIZED
	if str(run_state.pending_choice.get("type", "")) != "shop":
		return ERR_UNAUTHORIZED
	return _resolve_interaction_node(run_state, progress, {"outcome": "left_shop"})

func _stage_reward(run_state: RunState, rng: RunRngService, elite: bool) -> void:
	var gold_amount: int = rng.randi_range(&"reward_rng", 18 if elite else 10, 30 if elite else 20)
	var options: Array[Dictionary] = [_option("gold", "%d Gold" % gold_amount, "gold", {"amount": gold_amount})]
	var eligible_recipes: Array[FusionRecipeDef] = FusionRecipeDatabase.eligible_defs(run_state)
	if not eligible_recipes.is_empty():
		var recipe: FusionRecipeDef = eligible_recipes[rng.pick_index(&"reward_rng", eligible_recipes.size())]
		options.append(_option("recipe_%s" % recipe.id, recipe.display_name, "fusion", {"recipe_id": String(recipe.id)}))
	var reward_ids: Array[String] = ["pawn", "knight", "bishop", "rook", "queen"]
	var piece_id: String = reward_ids[rng.pick_index(&"reward_rng", reward_ids.size())]
	if run_state.challenger_slots.size() < 6 and rng.randi_range(&"reward_rng", 0, 2) == 0:
		options.append(_option("item_royal_bomb", "Royal Bomb", "item", {"item_id": "royal_bomb"}))
	else:
		options.append(_option("piece_%s" % piece_id, "Recruit %s" % _definition_label(piece_id), "piece", {"piece_def_id": piece_id}))
	while options.size() < 3:
		var relic: StringName = _unowned_relic(run_state, rng, &"reward_rng")
		if relic.is_empty():
			options.append(_option("small_gold_%d" % options.size(), "8 Gold", "gold", {"amount": 8}))
		else:
			options.append(_option("relic_%s" % relic, RunContentDatabase.relic_label(relic), "relic", {"relic_id": String(relic)}))
	run_state.pending_choice = _pending("battle_reward", "Victory Reward", "Choose one reward. Offers are saved and cannot be rerolled.", options, false)

func _stage_roster_overflow(run_state: RunState, new_piece_def_id: String) -> void:
	var options: Array[Dictionary] = []
	for instance_id: int in run_state.reserve_piece_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		options.append(_option("replace_%d" % instance_id, "Replace %s" % _piece_label(piece), "replace_piece", {"instance_id": instance_id, "piece_def_id": new_piece_def_id}))
	options.append(_option("discard_new", "Decline %s" % _definition_label(new_piece_def_id), "discard_new", {}))
	run_state.pending_choice = _pending("roster_overflow", "Reserve Full", "Replace one reserve piece or decline the new recruit.", options, false)

func _stage_shop(run_state: RunState, rng: RunRngService) -> void:
	var options: Array[Dictionary] = []
	var relic: StringName = _unowned_relic(run_state, rng, &"shop_rng")
	if not relic.is_empty():
		options.append(_option("buy_relic", "%s — 35 Gold" % RunContentDatabase.relic_label(relic), "relic", {"relic_id": String(relic), "price": 35}, run_state.gold >= 35 and run_state.challenger_slots.size() < 6))
	var ids: Array[String] = ["pawn", "knight", "bishop", "rook"]
	var piece_id: String = ids[rng.pick_index(&"shop_rng", ids.size())]
	options.append(_option("buy_piece", "%s — 25 Gold" % _definition_label(piece_id), "piece", {"piece_def_id": piece_id, "price": 25}, run_state.gold >= 25 and run_state.reserve_piece_ids.size() < RunState.MAX_RESERVE_PIECES))
	if run_state.challenger_slots.size() < 6:
		options.append(_option("buy_bomb", "Royal Bomb — 20 Gold", "item", {"item_id": "royal_bomb", "price": 20}, run_state.gold >= 20))
	else:
		options.append(_option("buy_protection", "Protect a Challenger — 15 Gold", "protect", {"price": 15}, run_state.gold >= 15 and _first_unprotected_non_king(run_state) > 0))
	run_state.pending_choice = _pending("shop", "Royal Market", "Purchase one offer or leave. Inventory is fixed for this visit.", options, true)

func _stage_event(run_state: RunState, rng: RunRngService) -> void:
	var event_id: StringName = RunContentDatabase.EVENTS[rng.pick_index(&"event_rng", RunContentDatabase.EVENTS.size())]
	var options: Array[Dictionary] = [
		_option("safe_gold", "Take 12 Gold", "gold", {"amount": 12}),
		_option("risky_gold", "Risk it: gain 25 Gold", "gold", {"amount": 25}),
	]
	var relic: StringName = _unowned_relic(run_state, rng, &"event_rng")
	if not relic.is_empty():
		options.append(_option("event_relic", "Claim %s" % RunContentDatabase.relic_label(relic), "relic", {"relic_id": String(relic)}, run_state.challenger_slots.size() < 6))
	run_state.pending_choice = _pending("event", String(event_id).replace("_", " ").capitalize(), "A short risk-and-reward encounter.", options, false)

func _stage_rest(run_state: RunState) -> void:
	var options: Array[Dictionary] = [
		_option("rest_gold", "Prepare supplies: 10 Gold", "gold", {"amount": 10}),
		_option("rest_protect", "Protect one challenger", "protect", {}, _first_unprotected_non_king(run_state) > 0),
	]
	run_state.pending_choice = _pending("rest", "Camp", "Choose one preparation before continuing.", options, false)

func _stage_summary(run_state: RunState, won: bool) -> void:
	var battles_won: int = int(run_state.run_statistics.get("battles_won", 0))
	var description: String = "Boss defeated. Endless mode is now unlocked." if won else "The journey ends after %d defeats." % run_state.failed_battles
	run_state.run_statistics["run_won"] = won
	run_state.pending_choice = _pending("run_summary", "Journey Complete" if won else "Journey Lost", "%s\nBattles won: %d\nGold: %d" % [description, battles_won, run_state.gold], [], true)

func _apply_reward(run_state: RunState, payload: Dictionary) -> Error:
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
		"fusion":
			return _apply_fusion(run_state, StringName(str(payload.get("recipe_id", ""))))
		"protect":
			var target_id: int = _first_unprotected_non_king(run_state)
			if target_id <= 0:
				return ERR_UNAVAILABLE
			run_state.protected_piece_ids.append(target_id)
			var piece: PieceInstanceState = run_state.get_piece_state(target_id)
			piece.is_protected = true
		_:
			return ERR_INVALID_PARAMETER
	return OK

func _apply_fusion(run_state: RunState, recipe_id: StringName) -> Error:
	var recipe: FusionRecipeDef = FusionRecipeDatabase.get_def(recipe_id)
	if recipe == null or not FusionRecipeDatabase.has_ingredients(run_state, recipe):
		return ERR_UNAVAILABLE
	var consumed: Array[int] = []
	for ingredient_id: StringName in recipe.ingredient_piece_def_ids:
		for piece: PieceInstanceState in run_state.player_roster:
			if piece.piece_def_id == ingredient_id and piece.instance_id not in consumed:
				consumed.append(piece.instance_id)
				break
	for instance_id: int in consumed:
		var error: Error = _remove_piece(run_state, instance_id)
		if error != OK:
			return error
	if run_state.allocate_piece(String(recipe.result_piece_def_id), false) == null:
		return ERR_OUT_OF_MEMORY
	if recipe.id not in run_state.owned_recipe_history:
		run_state.owned_recipe_history.append(recipe.id)
	return OK

func _remove_piece(run_state: RunState, instance_id: int) -> Error:
	var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
	if piece == null:
		return ERR_DOES_NOT_EXIST
	if piece.is_king:
		return ERR_UNAUTHORIZED
	run_state.active_piece_ids.erase(instance_id)
	run_state.reserve_piece_ids.erase(instance_id)
	run_state.protected_piece_ids.erase(instance_id)
	run_state.player_roster.erase(piece)
	return OK

func _resolve_interaction_node(run_state: RunState, progress: MapProgressService, payload: Dictionary) -> Error:
	run_state.pending_choice.clear()
	return progress.resolve_current_node(run_state, payload)

func _first_unprotected_non_king(run_state: RunState) -> int:
	for piece: PieceInstanceState in run_state.player_roster:
		if not piece.is_king and piece.instance_id not in run_state.protected_piece_ids:
			return piece.instance_id
	return 0

func _unowned_relic(run_state: RunState, rng: RunRngService, stream: StringName) -> StringName:
	var candidates: Array[StringName] = []
	for relic: StringName in RunContentDatabase.RELICS:
		if relic not in run_state.challenger_slots:
			candidates.append(relic)
	return candidates[rng.pick_index(stream, candidates.size())] if not candidates.is_empty() else &""

func _find_option(pending: Dictionary, choice_id: String) -> Dictionary:
	for value: Variant in pending.get("options", []) as Array:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == choice_id:
			return (value as Dictionary).duplicate(true)
	return {}

func _pending(type: String, title: String, description: String, options: Array[Dictionary], allow_leave: bool) -> Dictionary:
	return {"choice_version": 1, "type": type, "title": title, "description": description, "options": options, "allow_leave": allow_leave}

func _option(id: String, label: String, kind: String, data: Dictionary, enabled: bool = true) -> Dictionary:
	var payload: Dictionary = data.duplicate(true)
	payload["kind"] = kind
	return {"id": id, "label": label, "enabled": enabled, "payload": payload}

func _piece_label(piece: PieceInstanceState) -> String:
	return "%s #%d" % [_definition_label(String(piece.piece_def_id)), piece.instance_id]

func _definition_label(piece_id: String) -> String:
	return piece_id.replace("_", " ").capitalize()

class_name EventOfferGenerator
extends RefCounted

## Opens an event: picks one the player has not met this Run (and that suits the map
## layer), then resolves every choice so its card can name exactly what it gives, what
## it costs and which of your pieces it touches. A choice the player cannot take (no
## gold, no Pawn to arm, no item to give up...) stays visible but disabled, with why.

const EventDefType = preload("res://scripts/content/EventDef.gd")
const SEEN_KEY := "seen_events"

func generate(run_state: RunState, rng: RunRngService, reward_service: RunRewardService) -> Error:
	var event_id: StringName = pick_event(run_state, rng)
	if event_id.is_empty():
		return ERR_DOES_NOT_EXIST
	var definition: EventDefType = RunContentDatabase.event_def(event_id)
	if definition == null:
		return ERR_DOES_NOT_EXIST
	var seen: Array = run_state.run_statistics.get(SEEN_KEY, []) as Array
	seen.append(String(event_id))
	run_state.run_statistics[SEEN_KEY] = seen
	var options: Array[Dictionary] = []
	for entry: Dictionary in definition.options:
		options.append(_resolve_option(entry, run_state, rng, reward_service))
	if options.is_empty():
		# Older event data without options: the original gold choices.
		options.append(RunChoiceBuilder.option("safe_gold", "Take %d Gold" % definition.safe_gold, "gold", {"amount": definition.safe_gold}))
		options.append(RunChoiceBuilder.option("risky_gold", "Gain %d Gold" % definition.risky_gold, "gold", {"amount": definition.risky_gold}))
	run_state.pending_choice = RunChoiceBuilder.pending("event", definition.title, definition.description, options, false)
	run_state.pending_choice["event_id"] = String(event_id)
	return OK

## An event not yet met this Run whose layer has been reached; any event once all are seen.
func pick_event(run_state: RunState, rng: RunRngService) -> StringName:
	var all_ids: Array[StringName] = RunContentDatabase.event_ids()
	if all_ids.is_empty():
		return &""
	var seen: Array = run_state.run_statistics.get(SEEN_KEY, []) as Array
	var layer: int = _layer(run_state)
	var fresh: Array[StringName] = []
	for id: StringName in all_ids:
		var definition: EventDefType = RunContentDatabase.event_def(id)
		if definition != null and String(id) not in seen and layer >= definition.min_layer:
			fresh.append(id)
	var pool: Array[StringName] = fresh if not fresh.is_empty() else all_ids
	return pool[rng.pick_index(&"event_rng", pool.size())]

func _layer(run_state: RunState) -> int:
	if run_state.map_state == null:
		return 0
	var node: MapNodeState = run_state.map_state.get_node(run_state.current_node_id)
	return node.layer_index if node != null else 0

## Rolls the option's random reward now, so the card can name what it gives, and works
## out whether the player can take it.
func _resolve_option(entry: Dictionary, run_state: RunState, rng: RunRngService, reward_service: RunRewardService) -> Dictionary:
	var data: Dictionary = entry.duplicate(true)
	var label: String = str(data.get("label", data.get("id", "")))
	var resolved: Dictionary = _resolve_effect(data, run_state, rng, reward_service)
	var kind: String = str(resolved.get("kind", "nothing"))
	var blocked: String = str(resolved.get("blocked", ""))
	for key: String in resolved:
		data[key] = resolved[key]
	# Costs paid whatever the outcome (an item, the retry) are resolved the same way.
	var pay: Array = []
	for cost_value: Variant in data.get("pay", []) as Array:
		var cost: Dictionary = _resolve_effect((cost_value as Dictionary).duplicate(true), run_state, rng, reward_service)
		if blocked.is_empty():
			blocked = str(cost.get("blocked", ""))
		for key: String in ["target", "lost"]:
			if cost.has(key) and not data.has(key):
				data[key] = cost[key]
		pay.append(cost)
	if not pay.is_empty():
		data["pay"] = pay
	if data.has("fail"):
		data["fail"] = _resolve_effect((data["fail"] as Dictionary).duplicate(true), run_state, rng, reward_service)
	var affordable: bool = run_state.gold >= int(data.get("cost", 0))
	var enabled: bool = affordable and blocked.is_empty()
	for field: String in ["detail", "success_text", "fail_text"]:
		if data.has(field):
			data[field] = _fill(str(data[field]), data)
	label = _fill(label, data)
	if not blocked.is_empty():
		data["detail"] = blocked
	data.erase("id")
	data.erase("label")
	data.erase("kind")
	data.erase("blocked")
	return RunChoiceBuilder.option(str(entry.get("id", "")), label, kind, data, enabled)

## Turns a random or targeted effect into a concrete one. Adds "reward_name", "target"
## or "lost" for the card's text and "blocked" when the player cannot take it.
func _resolve_effect(effect: Dictionary, run_state: RunState, rng: RunRngService, reward_service: RunRewardService) -> Dictionary:
	var result: Dictionary = effect.duplicate(true)
	match str(effect.get("kind", "nothing")):
		"random_item":
			var items: Array[StringName] = RunContentDatabase.consumable_ids()
			result["kind"] = "item"
			result["item_id"] = String(items[rng.pick_index(&"event_rng", items.size())]) if not items.is_empty() else ""
			result["reward_name"] = RunContentDatabase.item_label(StringName(str(result["item_id"])))
			if run_state.challenger_slots.size() >= 6:
				result["blocked"] = "Your item slots are full."
		"random_relic":
			var relic: StringName = reward_service.unowned_relic(run_state, rng, &"event_rng")
			if relic.is_empty():
				result["kind"] = "gold"
				result["amount"] = 15
				result["reward_name"] = "15 Gold"
			else:
				result["kind"] = "relic"
				result["relic_id"] = String(relic)
				result["reward_name"] = RunContentDatabase.relic_label(relic)
				if run_state.challenger_slots.size() >= 6:
					result["blocked"] = "Your item slots are full."
		"random_piece":
			var pool: Array[String] = reward_service.piece_pool(str(effect.get("pool", "common")))
			result["kind"] = "piece"
			if str(effect.get("pool", "common")) == "rare":
				# Rare offers roll rarity too, so epics and legendaries do turn up.
				result["piece_def_id"] = RarityOdds.pick(pool, rng, &"event_rng", RarityOdds.run_progress(run_state) + RarityOdds.ELITE_BONUS)
			else:
				result["piece_def_id"] = pool[rng.pick_index(&"event_rng", pool.size())] if not pool.is_empty() else "pawn"
			result["reward_name"] = reward_service.definition_label(str(result["piece_def_id"]))
			if not run_state.has_room_for_piece():
				result["blocked"] = "Your army has no room for another piece."
		"piece":
			result["reward_name"] = reward_service.definition_label(str(effect.get("piece_def_id", "pawn")))
			if not run_state.has_room_for_piece():
				result["blocked"] = "Your army has no room for another piece."
		"train_best":
			var trainee: PieceInstanceState = RestOfferGenerator.best_trainee(run_state)
			result["kind"] = "train"
			if trainee == null:
				result["instance_id"] = 0
				result["blocked"] = "None of your pieces can grow through training."
			else:
				result["instance_id"] = trainee.instance_id
				result["piece_def_id"] = String(trainee.piece_def_id)
				result["target"] = reward_service.definition_label(String(trainee.piece_def_id))
		"arm_pawn":
			var pawn: PieceInstanceState = _first_piece(run_state, &"pawn")
			var commons: Array[String] = reward_service.piece_pool("common")
			commons.erase("pawn")
			result["kind"] = "transform"
			result["piece_def_id"] = commons[rng.pick_index(&"event_rng", commons.size())] if not commons.is_empty() else "knight"
			result["reward_name"] = reward_service.definition_label(str(result["piece_def_id"]))
			result["target"] = reward_service.definition_label("pawn")
			result["instance_id"] = pawn.instance_id if pawn != null else 0
			if pawn == null:
				result["blocked"] = "You have no Pawn to arm."
		"trade_weakest":
			var weakest: PieceInstanceState = _weakest_piece(run_state)
			var rares: Array[String] = reward_service.piece_pool("rare")
			result["kind"] = "transform"
			result["piece_def_id"] = RarityOdds.pick(rares, rng, &"event_rng", RarityOdds.run_progress(run_state) + RarityOdds.ELITE_BONUS) if not rares.is_empty() else "knight"
			result["reward_name"] = reward_service.definition_label(str(result["piece_def_id"]))
			result["instance_id"] = weakest.instance_id if weakest != null else 0
			result["target"] = reward_service.definition_label(String(weakest.piece_def_id)) if weakest != null else ""
			if weakest == null:
				result["blocked"] = "You need at least two pieces besides your King."
		"lose_item":
			var owned: Array[StringName] = []
			for slot: StringName in run_state.challenger_slots:
				var item: ChallengerItemDef = ChallengerItemDatabase.get_def(slot)
				if item != null and item.is_consumable():
					owned.append(slot)
			if owned.is_empty():
				result["blocked"] = "You carry no battle item to give."
			else:
				result["item_id"] = String(owned[rng.pick_index(&"event_rng", owned.size())])
				result["lost"] = RunContentDatabase.item_label(StringName(str(result["item_id"])))
		"lose_retry":
			if run_state.retries_left <= 0:
				result["blocked"] = "You have no retry left to give."
		"restore_retry":
			if run_state.has_full_retries():
				result["blocked"] = "Your retry is already full."
	return result

## {reward}, {target} and {lost} name what the choice gives, changes and takes.
func _fill(text: String, data: Dictionary) -> String:
	return text.replace("{reward}", str(data.get("reward_name", ""))).replace("{target}", str(data.get("target", ""))).replace("{lost}", str(data.get("lost", "")))

func _first_piece(run_state: RunState, piece_id: StringName) -> PieceInstanceState:
	for piece: PieceInstanceState in run_state.player_roster:
		if piece.piece_def_id == piece_id:
			return piece
	return null

## The cheapest piece besides the King, when the army has at least two of them.
func _weakest_piece(run_state: RunState) -> PieceInstanceState:
	var best: PieceInstanceState = null
	var best_value: int = 1000
	var count: int = 0
	for piece: PieceInstanceState in run_state.player_roster:
		if piece.is_king:
			continue
		count += 1
		var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id))
		var value: int = definition.base_value if definition != null else 1000
		if value < best_value:
			best_value = value
			best = piece
	return best if count >= 2 else null

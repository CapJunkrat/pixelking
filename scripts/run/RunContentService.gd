class_name RunContentService
extends RefCounted

## Compatibility facade and thin interaction coordinator.
## Concrete behavior lives in focused services under scripts/run/content.

## Node interactions the player may walk away from without choosing.
const LEAVABLE_TYPES: Array[String] = ["shop", "event", "rest"]
const INTERACTION_SCENE := AppSceneRoutes.RUN_INTERACTION

var fusion_service: FusionService
var reward_service: RunRewardService
var roster_choice_service: RunRosterChoiceService
var fusion_interaction_service: FusionInteractionService
var battle_outcome_service: BattleOutcomeService
var shop_generator: ShopOfferGenerator
var event_generator: EventOfferGenerator
var rest_generator: RestOfferGenerator
var summary_service: RunSummaryService
var slot_replace_service: SlotReplaceService

func _init(service: FusionService = null) -> void:
	fusion_service = service if service != null else FusionService.new()
	reward_service = RunRewardService.new()
	roster_choice_service = RunRosterChoiceService.new(reward_service)
	summary_service = RunSummaryService.new()
	fusion_interaction_service = FusionInteractionService.new(fusion_service)
	battle_outcome_service = BattleOutcomeService.new(fusion_service, reward_service, roster_choice_service, summary_service)
	shop_generator = ShopOfferGenerator.new()
	event_generator = EventOfferGenerator.new()
	rest_generator = RestOfferGenerator.new()
	slot_replace_service = SlotReplaceService.new()

func begin_current_node(run_state: RunState, rng: RunRngService) -> Error:
	if run_state == null or rng == null or run_state.map_state == null or not run_state.pending_choice.is_empty():
		return ERR_INVALID_DATA
	var node: MapNodeState = run_state.map_state.get_node(run_state.current_node_id)
	if node == null or run_state.resolved_node_payloads.has(String(node.node_id)):
		return ERR_UNAVAILABLE
	match node.node_type_id:
		&"shop":
			return shop_generator.generate(run_state, rng, fusion_service, reward_service)
		&"event":
			return event_generator.generate(run_state, rng, reward_service)
		&"rest":
			return rest_generator.generate(run_state, reward_service)
		_:
			return ERR_INVALID_PARAMETER

func apply_battle_victory(run_state: RunState, rng: RunRngService, progress: MapProgressService, deployment: DeploymentService) -> Error:
	return battle_outcome_service.apply_victory(run_state, rng, progress, deployment)

func apply_battle_draw(run_state: RunState, deployment: DeploymentService) -> Error:
	return battle_outcome_service.apply_draw(run_state, deployment)

func apply_battle_defeat(run_state: RunState, rng: RunRngService, deployment: DeploymentService) -> Error:
	return battle_outcome_service.apply_defeat(run_state, rng, deployment)

func submit(run_state: RunState, _rng: RunRngService, progress: MapProgressService, deployment: DeploymentService, choice_id: String) -> Error:
	if run_state == null or run_state.pending_choice.is_empty():
		return ERR_DOES_NOT_EXIST
	var pending: Dictionary = run_state.pending_choice
	var option: Dictionary = RunChoiceBuilder.find_option(pending, choice_id)
	if option.is_empty() or not bool(option.get("enabled", true)):
		return ERR_INVALID_PARAMETER
	var pending_type: String = str(pending.get("type", ""))
	var payload: Dictionary = option.get("payload", {}) as Dictionary
	match str(payload.get("kind", "")):
		SlotReplaceService.CANCEL:
			run_state.pending_choice = (pending.get("slot_return", {}) as Dictionary).duplicate(true)
			return OK
		SlotReplaceService.PICK:
			return _submit_slot_pick(run_state, _rng, progress, pending, StringName(str(payload.get("slot_id", ""))))
	match pending_type:
		"battle_reward":
			if str(payload.get("kind", "")) == "fusion":
				return fusion_interaction_service.stage(run_state, pending, choice_id, payload)
			if str(payload.get("kind", "")) == "piece" and not run_state.has_room_for_piece():
				roster_choice_service.stage_overflow(run_state, str(payload.get("piece_def_id", "")))
				return OK
			if SlotReplaceService.needs_room(run_state, payload):
				slot_replace_service.stage(run_state, pending, choice_id, payload)
				return OK
			var reward_error: Error = reward_service.apply(run_state, payload)
			if reward_error != OK:
				return reward_error
			run_state.pending_choice.clear()
			return OK
		"roster_overflow":
			return roster_choice_service.submit_overflow(run_state, payload)
		"shop":
			return _submit_shop(run_state, progress, pending, choice_id, payload)
		"event", "rest":
			# A relic or item with every slot full: pick what to give up first, before
			# anything is paid or rolled (so stepping back never re-rolls the event).
			if SlotReplaceService.needs_room(run_state, payload) and run_state.gold >= int(payload.get("cost", 0)):
				slot_replace_service.stage(run_state, pending, choice_id, payload)
				return OK
			return _submit_chance(run_state, _rng, progress, pending_type, choice_id, payload)
		"fusion_confirmation":
			return fusion_interaction_service.submit(run_state, progress, deployment, choice_id)
		_:
			return ERR_INVALID_PARAMETER

func _submit_chance(run_state: RunState, rng: RunRngService, progress: MapProgressService, pending_type: String, choice_id: String, payload: Dictionary) -> Error:
	var gold_before: int = run_state.gold
	var outcome: Dictionary = _apply_chance_effect(run_state, rng, payload)
	if int(outcome.get("error", OK)) != OK:
		return int(outcome["error"])
	run_state.run_statistics["last_outcome"] = str(outcome.get("text", ""))
	run_state.run_statistics["last_outcome_info"] = _outcome_info(run_state, payload, outcome, run_state.gold - gold_before)
	return _resolve_interaction_node(run_state, progress, {"outcome": pending_type, "choice": choice_id, "success": bool(outcome.get("success", true))})

## The player chose `slot_id` to give up for the relic or item of the staged option
## ("slot_source"): buy it, take the reward, or play out the event, giving the slot up
## only once the new one is really gained. Undone on any failure.
func _submit_slot_pick(run_state: RunState, rng: RunRngService, progress: MapProgressService, pending: Dictionary, slot_id: StringName) -> Error:
	var source: Dictionary = pending.get("slot_source", {}) as Dictionary
	var payload: Dictionary = (source.get("payload", {}) as Dictionary).duplicate(true)
	var choice_id: String = str(source.get("choice_id", ""))
	var pending_type: String = str(pending.get("type", ""))
	if not SlotReplaceService.can_give_up(run_state, slot_id):
		return ERR_UNAVAILABLE
	if pending_type in ["event", "rest"]:
		payload["give_up_slot"] = String(slot_id)
		return _submit_chance(run_state, rng, progress, pending_type, choice_id, payload)
	var price: int = int(payload.get("price", 0))
	if run_state.gold < price:
		return ERR_UNAVAILABLE
	var snapshot: Dictionary = run_state.to_dictionary()
	var error: Error = SlotReplaceService.give_up(run_state, slot_id)
	if error == OK:
		error = reward_service.apply(run_state, payload)
	if error != OK:
		run_state.load_from_dictionary(snapshot, false)
		return error
	run_state.gold -= price
	if pending_type == "shop":
		return _resolve_interaction_node(run_state, progress, {"outcome": "purchase", "choice": choice_id})
	run_state.pending_choice.clear()
	return OK

## Pays the option's cost, rolls its chance, applies the matching effect and returns
## {"error": Error, "success": bool, "text": String} with what the player is told.
func _apply_chance_effect(run_state: RunState, rng: RunRngService, payload: Dictionary) -> Dictionary:
	var cost: int = int(payload.get("cost", 0))
	if run_state.gold < cost:
		return {"error": ERR_UNAVAILABLE}
	var snapshot: int = run_state.gold
	var slots_snapshot: Array[StringName] = run_state.challenger_slots.duplicate()
	var retries_snapshot: int = run_state.retries_left
	run_state.gold -= cost
	for paid: Variant in payload.get("pay", []) as Array:
		if reward_service.apply(run_state, paid as Dictionary) != OK:
			run_state.gold = snapshot
			run_state.challenger_slots = slots_snapshot
			run_state.retries_left = retries_snapshot
			return {"error": ERR_UNAVAILABLE}
	var chance: float = float(payload.get("chance", 1.0))
	var success: bool = chance >= 1.0 or rng == null or rng.randi_range(&"event_rng", 0, 99) < int(roundf(chance * 100.0))
	var effect: Dictionary = payload if success else (payload.get("fail", {"kind": "nothing"}) as Dictionary)
	var text_template: String = str(payload.get("success_text" if success else "fail_text", ""))
	var named: String = str(payload.get("reward_name", ""))
	if str(effect.get("kind", "")) == "gold_and_desert":
		run_state.gold += int(effect.get("amount", 0))
		named = _desert(run_state, rng)
	else:
		# The slot picked to make room goes only when a relic or item really comes in.
		# Giving up the War Banner can move a piece to the reserve, so a failure from
		# here on restores the whole run, not only the slots.
		var before_give_up: Dictionary = {}
		if payload.has("give_up_slot") and SlotReplaceService.needs_room(run_state, effect):
			before_give_up = run_state.to_dictionary()
			if SlotReplaceService.give_up(run_state, StringName(str(payload["give_up_slot"]))) != OK:
				run_state.gold = snapshot
				run_state.challenger_slots = slots_snapshot
				run_state.retries_left = retries_snapshot
				return {"error": ERR_UNAVAILABLE}
		var error: Error = reward_service.apply(run_state, effect)
		if error != OK and not before_give_up.is_empty():
			run_state.load_from_dictionary(before_give_up, false)
		if error != OK:
			run_state.gold = snapshot
			run_state.challenger_slots = slots_snapshot
			run_state.retries_left = retries_snapshot
			return {"error": error}
	var text: String = text_template % named if "%s" in text_template else text_template
	return {"error": OK, "success": success, "text": text, "effect": effect}

## What the outcome card shows: whether luck held, the picture of what was gained, the
## gold change and anything given up.
func _outcome_info(run_state: RunState, payload: Dictionary, outcome: Dictionary, gold_delta: int) -> Dictionary:
	var effect: Dictionary = outcome.get("effect", {}) as Dictionary
	var info: Dictionary = {
		"success": bool(outcome.get("success", true)),
		"risky": float(payload.get("chance", 1.0)) < 1.0,
		"kind": str(effect.get("kind", "nothing")),
		"gold_delta": gold_delta,
	}
	for key: String in ["piece_def_id", "item_id", "relic_id"]:
		if effect.has(key):
			info[key] = str(effect[key])
	if info["kind"] == "train":
		var trained: PieceInstanceState = run_state.get_piece_state(int(effect.get("instance_id", 0)))
		if trained != null:
			info["piece_def_id"] = String(trained.piece_def_id)
	var lost: Array[String] = []
	for paid: Variant in payload.get("pay", []) as Array:
		match str((paid as Dictionary).get("kind", "")):
			"lose_item":
				lost.append(str((paid as Dictionary).get("lost", "an item")))
			"lose_retry":
				lost.append("your retry")
	info["lost"] = lost
	return info

## A random non-King piece leaves the army. Returns its name ("nobody" if none).
func _desert(run_state: RunState, rng: RunRngService) -> String:
	var candidates: Array[PieceInstanceState] = []
	for piece: PieceInstanceState in run_state.player_roster:
		if not piece.is_king:
			candidates.append(piece)
	if candidates.is_empty():
		return "nobody"
	var leaving: PieceInstanceState = candidates[rng.pick_index(&"event_rng", candidates.size()) if rng != null else 0]
	var name: String = reward_service.definition_label(String(leaving.piece_def_id))
	reward_service.remove_piece(run_state, leaving.instance_id)
	return name

## Walks away from a shop, event or rest site without choosing anything, so a node can
## never trap the player (no gold, nothing to sell, no piece that can grow...).
## Events and rest sites always allow it, also in saves made before they offered it.
func leave(run_state: RunState, progress: MapProgressService) -> Error:
	if run_state == null or run_state.pending_choice.is_empty():
		return ERR_DOES_NOT_EXIST
	var pending_type: String = str(run_state.pending_choice.get("type", ""))
	if pending_type not in LEAVABLE_TYPES:
		return ERR_UNAUTHORIZED
	if pending_type == "shop" and not bool(run_state.pending_choice.get("allow_leave", false)):
		return ERR_UNAUTHORIZED
	return _resolve_interaction_node(run_state, progress, {"outcome": "left_%s" % pending_type})

func _submit_shop(run_state: RunState, progress: MapProgressService, pending: Dictionary, choice_id: String, payload: Dictionary) -> Error:
	match str(payload.get("kind", "")):
		"shop_replace_cancel":
			run_state.pending_choice = RunRosterChoiceService._shop_offers(pending).duplicate(true)
			return OK
		"shop_replace_confirm":
			if run_state.gold < int(payload.get("price", 0)):
				return ERR_UNAVAILABLE
			roster_choice_service.stage_shop_replace_pick(run_state, pending, payload)
			return OK
		"shop_replace_pick":
			var buy_error: Error = roster_choice_service.buy_replacing(run_state, payload)
			if buy_error != OK:
				return buy_error
			return _resolve_interaction_node(run_state, progress, {"outcome": "purchase", "choice": str(payload.get("source_choice", choice_id))})
	var price: int = int(payload.get("price", 0))
	if run_state.gold < price:
		return ERR_UNAVAILABLE
	# No room for the recruit: buying it means letting one of your pieces go first.
	if str(payload.get("kind", "")) == "piece" and not run_state.has_room_for_piece():
		roster_choice_service.stage_shop_replace_confirm(run_state, pending, choice_id, payload)
		return OK
	# No slot for the relic or item: one has to be given up.
	if SlotReplaceService.needs_room(run_state, payload):
		slot_replace_service.stage(run_state, pending, choice_id, payload)
		return OK
	if str(payload.get("kind", "")) == "fusion":
		return fusion_interaction_service.stage(run_state, pending, choice_id, payload)
	var reward_error: Error = reward_service.apply(run_state, payload)
	if reward_error != OK:
		return reward_error
	run_state.gold -= price
	return _resolve_interaction_node(run_state, progress, {"outcome": "purchase", "choice": choice_id})

func _resolve_interaction_node(run_state: RunState, progress: MapProgressService, payload: Dictionary) -> Error:
	run_state.pending_choice.clear()
	return progress.resolve_current_node(run_state, payload)

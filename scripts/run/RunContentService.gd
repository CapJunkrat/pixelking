class_name RunContentService
extends RefCounted

## Compatibility facade and thin interaction coordinator.
## Concrete behavior lives in focused services under scripts/run/content.
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
	match pending_type:
		"battle_reward":
			if str(payload.get("kind", "")) == "fusion":
				return fusion_interaction_service.stage(run_state, pending, choice_id, payload)
			if str(payload.get("kind", "")) == "piece" and not run_state.has_room_for_piece():
				roster_choice_service.stage_overflow(run_state, str(payload.get("piece_def_id", "")))
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
			var outcome: Dictionary = _apply_chance_effect(run_state, _rng, payload)
			if int(outcome.get("error", OK)) != OK:
				return int(outcome["error"])
			run_state.run_statistics["last_outcome"] = str(outcome.get("text", ""))
			return _resolve_interaction_node(run_state, progress, {"outcome": pending_type, "choice": choice_id, "success": bool(outcome.get("success", true))})
		"fusion_confirmation":
			return fusion_interaction_service.submit(run_state, progress, deployment, choice_id)
		_:
			return ERR_INVALID_PARAMETER

## Pays the option's cost, rolls its chance, applies the matching effect and returns
## {"error": Error, "success": bool, "text": String} with what the player is told.
func _apply_chance_effect(run_state: RunState, rng: RunRngService, payload: Dictionary) -> Dictionary:
	var cost: int = int(payload.get("cost", 0))
	if run_state.gold < cost:
		return {"error": ERR_UNAVAILABLE}
	var snapshot: int = run_state.gold
	run_state.gold -= cost
	var chance: float = float(payload.get("chance", 1.0))
	var success: bool = chance >= 1.0 or rng == null or rng.randi_range(&"event_rng", 0, 99) < int(roundf(chance * 100.0))
	var effect: Dictionary = payload if success else (payload.get("fail", {"kind": "nothing"}) as Dictionary)
	var text_template: String = str(payload.get("success_text" if success else "fail_text", ""))
	var named: String = str(payload.get("reward_name", ""))
	if str(effect.get("kind", "")) == "gold_and_desert":
		run_state.gold += int(effect.get("amount", 0))
		named = _desert(run_state, rng)
	else:
		var error: Error = reward_service.apply(run_state, effect)
		if error != OK:
			run_state.gold = snapshot
			return {"error": error}
	var text: String = text_template % named if "%s" in text_template else text_template
	return {"error": OK, "success": success, "text": text}

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

func leave(run_state: RunState, progress: MapProgressService) -> Error:
	if run_state == null or run_state.pending_choice.is_empty():
		return ERR_DOES_NOT_EXIST
	if not bool(run_state.pending_choice.get("allow_leave", false)):
		return ERR_UNAUTHORIZED
	if str(run_state.pending_choice.get("type", "")) != "shop":
		return ERR_UNAUTHORIZED
	return _resolve_interaction_node(run_state, progress, {"outcome": "left_shop"})

func _submit_shop(run_state: RunState, progress: MapProgressService, pending: Dictionary, choice_id: String, payload: Dictionary) -> Error:
	var price: int = int(payload.get("price", 0))
	if run_state.gold < price:
		return ERR_UNAVAILABLE
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

class_name BattleOutcomeService
extends RefCounted

## Extra gold for beating an act's Boss (on top of the elite reward).
const BOSS_BONUS_GOLD := 20

var reward_generator: BattleRewardOfferGenerator
var roster_choice_service: RunRosterChoiceService
var summary_service: RunSummaryService
var fusion_service: FusionService
var reward_service: RunRewardService

func _init(
	p_fusion_service: FusionService,
	p_reward_service: RunRewardService,
	p_roster_choice_service: RunRosterChoiceService,
	p_summary_service: RunSummaryService
) -> void:
	fusion_service = p_fusion_service
	reward_service = p_reward_service
	roster_choice_service = p_roster_choice_service
	summary_service = p_summary_service
	reward_generator = BattleRewardOfferGenerator.new()

func apply_victory(run_state: RunState, rng: RunRngService, progress: MapProgressService, deployment: DeploymentService) -> Error:
	if run_state == null or rng == null or progress == null or deployment == null:
		return ERR_INVALID_PARAMETER
	var node: MapNodeState = run_state.map_state.get_node(run_state.current_node_id) if run_state.map_state != null else null
	var node_definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id) if node != null else null
	var encounter: EncounterDef = EncounterDefDatabase.for_node(run_state, node)
	if node_definition == null or not node_definition.is_battle or encounter == null:
		return ERR_INVALID_DATA
	var error: Error = progress.resolve_current_node(run_state, {"outcome": "victory", "gold_before_reward": run_state.gold})
	if error != OK:
		return error
	deployment.clear(run_state)
	run_state.run_statistics["battles_won"] = int(run_state.run_statistics.get("battles_won", 0)) + 1
	if encounter.is_boss:
		run_state.run_statistics["acts_cleared"] = run_state.act_index + 1
		# The last Boss of a standard journey: endless mode opens and the journey goes
		# straight on into Act 4 with the same army, items and gold.
		var journey_won: bool = run_state.is_final_act()
		if journey_won:
			run_state.mode = RunState.MODE_ENDLESS
			run_state.run_statistics["run_won"] = true
			run_state.run_statistics["endless_unlocked_now"] = true
		# An act's Boss falls: an elite-grade reward plus a purse, then the next act.
		run_state.gold += BOSS_BONUS_GOLD
		var reward_error: Error = reward_generator.generate(run_state, rng, fusion_service, reward_service, true)
		if reward_error == OK:
			run_state.pending_choice["title_key"] = "ENDLESS_UNLOCKED_TITLE" if journey_won else "ACT_CLEARED_TITLE"
			run_state.pending_choice["title_args"] = [run_state.act_index + 1]
			if journey_won:
				run_state.pending_choice["description_key"] = "ENDLESS_UNLOCKED_DESC"
				run_state.pending_choice["description_args"] = [run_state.act_index + 2]
			run_state.pending_choice["gold_awarded"] = int(run_state.pending_choice.get("gold_awarded", 0)) + BOSS_BONUS_GOLD
		return reward_error
	return reward_generator.generate(run_state, rng, fusion_service, reward_service, encounter.reward_tier == &"elite")

func apply_defeat(run_state: RunState, rng: RunRngService, deployment: DeploymentService) -> Error:
	if run_state == null or rng == null or deployment == null:
		return ERR_INVALID_PARAMETER
	run_state.failed_battles += 1
	run_state.run_statistics["battles_lost"] = int(run_state.run_statistics.get("battles_lost", 0)) + 1
	deployment.clear(run_state)
	if run_state.retries_left <= 0:
		summary_service.stage(run_state, false)
		return OK
	run_state.retries_left -= 1
	run_state.run_statistics["retries_used"] = int(run_state.run_statistics.get("retries_used", 0)) + 1
	return deployment.ensure_deployment(run_state)

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
	var node_definition: MapNodeDef = Content.map_node(node.node_type_id) if node != null else null
	var encounter: EncounterDef = EncounterGenerator.encounter_for_node(run_state, node)
	if node_definition == null or not node_definition.is_battle or encounter == null:
		return ERR_INVALID_DATA
	var error: Error = progress.resolve_current_node(run_state, {"outcome": "victory", "gold_before_reward": run_state.gold})
	if error != OK:
		return error
	deployment.clear(run_state)
	run_state.run_statistics["battles_won"] = int(run_state.run_statistics.get("battles_won", 0)) + 1
	if encounter.is_boss:
		# An act's Boss falls: an elite-grade reward plus a purse, then the next act. The
		# journey never ends here; after Act 3 the acts just keep getting harder.
		run_state.run_statistics["acts_cleared"] = run_state.act_index + 1
		run_state.run_statistics["boss_beaten"] = String(encounter.id)
		run_state.gold += BOSS_BONUS_GOLD
		var reward_error: Error = reward_generator.generate(run_state, rng, fusion_service, reward_service, true)
		if reward_error == OK:
			run_state.pending_choice["title_key"] = "ACT_CLEARED_TITLE"
			run_state.pending_choice["title_args"] = [run_state.act_index + 1]
			if run_state.act_index + 1 == RunState.ACT_COUNT:
				run_state.pending_choice["description_key"] = "ACT_3_CLEARED_DESC"
				run_state.pending_choice["description_args"] = [run_state.act_index + 2]
			run_state.pending_choice["gold_awarded"] = int(run_state.pending_choice.get("gold_awarded", 0)) + BOSS_BONUS_GOLD
		return reward_error
	return reward_generator.generate(run_state, rng, fusion_service, reward_service, encounter.reward_tier == &"elite")

## A draw is not a defeat: nothing is counted against the run and the retry is kept.
## The same battle (same node, same enemy army) is fought again after redeploying.
func apply_draw(run_state: RunState, deployment: DeploymentService) -> Error:
	if run_state == null or deployment == null:
		return ERR_INVALID_PARAMETER
	run_state.run_statistics["battles_drawn"] = int(run_state.run_statistics.get("battles_drawn", 0)) + 1
	deployment.clear(run_state)
	return deployment.ensure_deployment(run_state)

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

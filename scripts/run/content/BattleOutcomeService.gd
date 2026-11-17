class_name BattleOutcomeService
extends RefCounted

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
	var encounter: EncounterDef = EncounterDefDatabase.get_def(node_definition.encounter_def_id) if node_definition != null else null
	if node_definition == null or not node_definition.is_battle or encounter == null:
		return ERR_INVALID_DATA
	var error: Error = progress.resolve_current_node(run_state, {"outcome": "victory", "gold_before_reward": run_state.gold})
	if error != OK:
		return error
	deployment.clear(run_state)
	run_state.run_statistics["battles_won"] = int(run_state.run_statistics.get("battles_won", 0)) + 1
	if encounter.is_boss:
		summary_service.stage(run_state, true)
		return OK
	return reward_generator.generate(run_state, rng, fusion_service, reward_service, encounter.reward_tier == &"elite")

func apply_defeat(run_state: RunState, rng: RunRngService, deployment: DeploymentService) -> Error:
	if run_state == null or rng == null or deployment == null:
		return ERR_INVALID_PARAMETER
	run_state.failed_battles += 1
	run_state.remaining_failure_allowance = maxi(0, RunState.MAX_FAILURES - run_state.failed_battles)
	run_state.run_statistics["battles_lost"] = int(run_state.run_statistics.get("battles_lost", 0)) + 1
	deployment.clear(run_state)
	if run_state.failed_battles >= RunState.MAX_FAILURES:
		summary_service.stage(run_state, false)
		return OK
	var roster_error: Error = roster_choice_service.stage_defeat_choice(run_state, rng, deployment)
	if roster_error == ERR_DOES_NOT_EXIST:
		summary_service.stage(run_state, false)
		return OK
	return roster_error

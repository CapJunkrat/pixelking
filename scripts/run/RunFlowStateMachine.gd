class_name RunFlowStateMachine
extends RefCounted

const RunPhaseType = preload("res://scripts/run/RunPhase.gd")

const TRANSITIONS: Dictionary = {
	RunPhaseType.OPENING_DRAFT: [RunPhaseType.MAP],
	RunPhaseType.MAP: [RunPhaseType.NODE_SELECTED],
	RunPhaseType.NODE_SELECTED: [RunPhaseType.MAP, RunPhaseType.NODE_INTERACTION, RunPhaseType.DEPLOYMENT],
	RunPhaseType.NODE_INTERACTION: [RunPhaseType.MAP, RunPhaseType.FUSION_CONFIRMATION],
	RunPhaseType.DEPLOYMENT: [RunPhaseType.BATTLE_READY],
	RunPhaseType.BATTLE_READY: [RunPhaseType.DEPLOYMENT, RunPhaseType.BATTLE_ACTIVE],
	RunPhaseType.BATTLE_ACTIVE: [RunPhaseType.BATTLE_READY, RunPhaseType.DEPLOYMENT, RunPhaseType.POST_BATTLE_CHOICE, RunPhaseType.SACRIFICE, RunPhaseType.RUN_SUMMARY, RunPhaseType.MAP],
	RunPhaseType.POST_BATTLE_CHOICE: [RunPhaseType.MAP, RunPhaseType.ROSTER_OVERFLOW, RunPhaseType.FUSION_CONFIRMATION],
	RunPhaseType.ROSTER_OVERFLOW: [RunPhaseType.MAP],
	RunPhaseType.FUSION_CONFIRMATION: [RunPhaseType.POST_BATTLE_CHOICE, RunPhaseType.NODE_INTERACTION, RunPhaseType.MAP],
	RunPhaseType.SACRIFICE: [RunPhaseType.DEPLOYMENT, RunPhaseType.RUN_SUMMARY],
	RunPhaseType.RUN_SUMMARY: [],
}

func can_transition(from_phase: StringName, to_phase: StringName) -> bool:
	if from_phase == to_phase:
		return true
	if not RunPhaseType.is_valid(from_phase) or not RunPhaseType.is_valid(to_phase):
		return false
	var targets: Array = TRANSITIONS.get(from_phase, []) as Array
	return to_phase in targets

func transition(run_state: RunState, target_phase: StringName) -> Error:
	if run_state == null or not can_transition(run_state.phase, target_phase):
		return ERR_UNAVAILABLE
	var previous_phase: StringName = run_state.phase
	run_state.phase = target_phase
	if not run_state.is_phase_consistent():
		run_state.phase = previous_phase
		return ERR_INVALID_DATA
	return OK

func transition_to_derived_phase(run_state: RunState) -> Error:
	var target_phase: StringName = derive_phase(run_state)
	if target_phase.is_empty():
		return ERR_INVALID_DATA
	return transition(run_state, target_phase)

func derive_phase(run_state: RunState) -> StringName:
	if run_state == null:
		return &""
	if not run_state.pending_choice.is_empty():
		match str(run_state.pending_choice.get("type", "")):
			"opening_draft":
				return RunPhaseType.OPENING_DRAFT
			"shop", "event", "rest":
				return RunPhaseType.NODE_INTERACTION
			"battle_reward":
				return RunPhaseType.POST_BATTLE_CHOICE
			"roster_overflow":
				return RunPhaseType.ROSTER_OVERFLOW
			"fusion_confirmation":
				return RunPhaseType.FUSION_CONFIRMATION
			"sacrifice":
				return RunPhaseType.SACRIFICE
			"run_summary":
				return RunPhaseType.RUN_SUMMARY
			_:
				return &""
	if run_state.deployment_state != null:
		return RunPhaseType.BATTLE_READY if run_state.deployment_state.confirmed else RunPhaseType.DEPLOYMENT
	if not bool(run_state.run_statistics.get("opening_draft_complete", false)):
		return RunPhaseType.OPENING_DRAFT
	if run_state.map_state == null or run_state.current_node_id.is_empty():
		return RunPhaseType.MAP
	if run_state.resolved_node_payloads.has(String(run_state.current_node_id)):
		return RunPhaseType.MAP
	return RunPhaseType.NODE_SELECTED

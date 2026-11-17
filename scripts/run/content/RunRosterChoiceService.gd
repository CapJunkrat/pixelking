class_name RunRosterChoiceService
extends RefCounted

var reward_service: RunRewardService

func _init(p_reward_service: RunRewardService = null) -> void:
	reward_service = p_reward_service if p_reward_service != null else RunRewardService.new()

func stage_overflow(run_state: RunState, new_piece_def_id: String) -> void:
	var options: Array[Dictionary] = []
	for instance_id: int in run_state.reserve_piece_ids:
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		options.append(RunChoiceBuilder.option("replace_%d" % instance_id, "Replace %s" % reward_service.piece_label(piece), "replace_piece", {"instance_id": instance_id, "piece_def_id": new_piece_def_id}))
	options.append(RunChoiceBuilder.option("discard_new", "Decline %s" % reward_service.definition_label(new_piece_def_id), "discard_new", {}))
	run_state.pending_choice = RunChoiceBuilder.pending("roster_overflow", "Reserve Full", "Replace one reserve piece or decline the new recruit.", options, false)

func submit_overflow(run_state: RunState, payload: Dictionary) -> Error:
	var overflow_kind: String = str(payload.get("kind", ""))
	if overflow_kind == "discard_new":
		run_state.pending_choice.clear()
		return OK
	if overflow_kind != "replace_piece":
		return ERR_INVALID_PARAMETER
	var replaced_id: int = int(payload.get("instance_id", 0))
	var replacement_id: String = str(payload.get("piece_def_id", ""))
	var remove_error: Error = reward_service.remove_piece(run_state, replaced_id)
	if remove_error != OK or run_state.allocate_piece(replacement_id, false) == null:
		return ERR_UNAVAILABLE
	run_state.pending_choice.clear()
	return OK

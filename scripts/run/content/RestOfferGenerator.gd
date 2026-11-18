class_name RestOfferGenerator
extends RefCounted

const RestSiteDefType = preload("res://scripts/content/RestSiteDef.gd")

func generate(run_state: RunState, reward_service: RunRewardService) -> Error:
	var definition: RestSiteDefType = RunContentDatabase.rest_site()
	if definition == null:
		return ERR_DOES_NOT_EXIST
	var options: Array[Dictionary] = [
		RunChoiceBuilder.option("rest_gold", "Prepare supplies: %d Gold" % definition.supplies_gold, "gold", {"amount": definition.supplies_gold}),
		RunChoiceBuilder.option("rest_retry", RunRewardService.retry_label(run_state), "restore_retry", {}, not run_state.has_full_retries()),
	]
	var trainee: PieceInstanceState = _trainee(run_state)
	if trainee != null:
		options.append(RunChoiceBuilder.option("rest_train", "Drill %s" % reward_service.definition_label(String(trainee.piece_def_id)), "train", {"instance_id": trainee.instance_id, "piece_def_id": String(trainee.piece_def_id), "detail": "Counts as one capture toward growing stronger."}))
	else:
		options.append(RunChoiceBuilder.option("rest_train", "Drill a piece", "train", {"instance_id": 0, "detail": "None of your pieces can grow through drill."}, false))
	options[0]["payload"]["detail"] = "Gain %d Gold for the road ahead." % definition.supplies_gold
	options[1]["payload"]["detail"] = "Get your one retry back."
	run_state.pending_choice = RunChoiceBuilder.pending("rest", definition.title, definition.description, options, false)
	return OK

## The growing piece closest to its next form (Squire, Crystal Mage...).
func _trainee(run_state: RunState) -> PieceInstanceState:
	var best: PieceInstanceState = null
	var best_gap: int = 1000
	for piece: PieceInstanceState in run_state.player_roster:
		var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id))
		if definition == null or definition.evolve_at_captures <= 0:
			continue
		var gap: int = definition.evolve_at_captures - piece.capture_count
		if gap < best_gap:
			best_gap = gap
			best = piece
	return best

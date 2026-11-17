class_name RestOfferGenerator
extends RefCounted

const RestSiteDefType = preload("res://scripts/content/RestSiteDef.gd")

func generate(run_state: RunState, reward_service: RunRewardService) -> Error:
	var definition: RestSiteDefType = RunContentDatabase.rest_site()
	if definition == null:
		return ERR_DOES_NOT_EXIST
	var options: Array[Dictionary] = [
		RunChoiceBuilder.option("rest_gold", "Prepare supplies: %d Gold" % definition.supplies_gold, "gold", {"amount": definition.supplies_gold}),
		RunChoiceBuilder.option("rest_protect", "Protect one challenger", "protect", {}, reward_service.first_unprotected_non_king(run_state) > 0),
	]
	run_state.pending_choice = RunChoiceBuilder.pending("rest", definition.title, definition.description, options, false)
	return OK

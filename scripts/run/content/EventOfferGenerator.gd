class_name EventOfferGenerator
extends RefCounted

const EventDefType = preload("res://scripts/content/EventDef.gd")

func generate(run_state: RunState, rng: RunRngService, reward_service: RunRewardService) -> Error:
	var event_ids: Array[StringName] = RunContentDatabase.event_ids()
	if event_ids.is_empty():
		return ERR_DOES_NOT_EXIST
	var event_id: StringName = event_ids[rng.pick_index(&"event_rng", event_ids.size())]
	var definition: EventDefType = RunContentDatabase.event_def(event_id)
	if definition == null:
		return ERR_DOES_NOT_EXIST
	var options: Array[Dictionary] = [
		RunChoiceBuilder.option("safe_gold", "Take %d Gold" % definition.safe_gold, "gold", {"amount": definition.safe_gold}),
		RunChoiceBuilder.option("risky_gold", "Risk it: gain %d Gold" % definition.risky_gold, "gold", {"amount": definition.risky_gold}),
	]
	var relic: StringName = reward_service.unowned_relic(run_state, rng, &"event_rng")
	if definition.can_offer_relic and not relic.is_empty():
		options.append(RunChoiceBuilder.option("event_relic", "Claim %s" % RunContentDatabase.relic_label(relic), "relic", {"relic_id": String(relic)}, run_state.challenger_slots.size() < 6))
	run_state.pending_choice = RunChoiceBuilder.pending("event", definition.title, definition.description, options, false)
	return OK

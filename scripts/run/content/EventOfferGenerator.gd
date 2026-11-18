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
	var options: Array[Dictionary] = []
	for entry: Dictionary in definition.options:
		options.append(_resolve_option(entry, run_state, rng, reward_service))
	if options.is_empty():
		# Older event data without options: the original gold choices.
		options.append(RunChoiceBuilder.option("safe_gold", "Take %d Gold" % definition.safe_gold, "gold", {"amount": definition.safe_gold}))
		options.append(RunChoiceBuilder.option("risky_gold", "Gain %d Gold" % definition.risky_gold, "gold", {"amount": definition.risky_gold}))
	run_state.pending_choice = RunChoiceBuilder.pending("event", definition.title, definition.description, options, false)
	return OK

## Rolls the option's random reward now, so the card can name what it gives, and works
## out whether the player can afford it.
func _resolve_option(entry: Dictionary, run_state: RunState, rng: RunRngService, reward_service: RunRewardService) -> Dictionary:
	var data: Dictionary = entry.duplicate(true)
	var kind: String = str(data.get("kind", "nothing"))
	var label: String = str(data.get("label", data.get("id", "")))
	var enabled: bool = run_state.gold >= int(data.get("cost", 0))
	match kind:
		"random_item":
			var items: Array[StringName] = RunContentDatabase.consumable_ids()
			kind = "item"
			data["item_id"] = String(items[rng.pick_index(&"event_rng", items.size())]) if not items.is_empty() else ""
			data["reward_name"] = RunContentDatabase.item_label(StringName(str(data["item_id"])))
			enabled = enabled and run_state.challenger_slots.size() < 6
		"random_relic":
			var relic: StringName = reward_service.unowned_relic(run_state, rng, &"event_rng")
			if relic.is_empty():
				kind = "gold"
				data["amount"] = 15
				data["reward_name"] = "15 Gold"
			else:
				kind = "relic"
				data["relic_id"] = String(relic)
				data["reward_name"] = RunContentDatabase.relic_label(relic)
				enabled = enabled and run_state.challenger_slots.size() < 6
		"random_piece":
			var pool: Array[String] = reward_service.piece_pool(str(data.get("pool", "common")))
			kind = "piece"
			data["piece_def_id"] = pool[rng.pick_index(&"event_rng", pool.size())] if not pool.is_empty() else "pawn"
			data["reward_name"] = reward_service.definition_label(str(data["piece_def_id"]))
			enabled = enabled and run_state.has_room_for_piece()
		"restore_retry":
			enabled = enabled and not run_state.has_full_retries()
	data.erase("id")
	data.erase("label")
	data.erase("kind")
	return RunChoiceBuilder.option(str(entry.get("id", "")), label, kind, data, enabled)

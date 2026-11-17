class_name BattleRewardOfferGenerator
extends RefCounted

const BattleRewardTableDefType = preload("res://scripts/content/BattleRewardTableDef.gd")

func generate(run_state: RunState, rng: RunRngService, fusion_service: FusionService, reward_service: RunRewardService, elite: bool) -> Error:
	var table: BattleRewardTableDefType = RunContentDatabase.battle_reward_table()
	if table == null:
		return ERR_DOES_NOT_EXIST
	var minimum_gold: int = table.elite_gold_min if elite else table.normal_gold_min
	var maximum_gold: int = table.elite_gold_max if elite else table.normal_gold_max
	var gold_amount: int = rng.randi_range(&"reward_rng", minimum_gold, maximum_gold)
	var options: Array[Dictionary] = [RunChoiceBuilder.option("gold", "%d Gold" % gold_amount, "gold", {"amount": gold_amount})]
	var eligible_recipes: Array[FusionRecipeDef] = fusion_service.eligible_recipes(run_state)
	if not eligible_recipes.is_empty():
		var recipe: FusionRecipeDef = eligible_recipes[rng.pick_index(&"reward_rng", eligible_recipes.size())]
		options.append(RunChoiceBuilder.option("recipe_%s" % recipe.id, recipe.display_name, "fusion", {"recipe_id": String(recipe.id)}))
	var selected_piece_id: StringName = table.recruit_piece_ids[rng.pick_index(&"reward_rng", table.recruit_piece_ids.size())]
	var piece_id: String = String(selected_piece_id)
	var item_roll_matches: bool = (
		run_state.challenger_slots.size() < 6
		and rng.randi_range(&"reward_rng", 0, table.consumable_roll_sides - 1) == table.consumable_roll_hit
	)
	if item_roll_matches:
		var item_id: String = String(table.bonus_consumable_id)
		options.append(RunChoiceBuilder.option("item_%s" % item_id, reward_service.definition_label(item_id), "item", {"item_id": item_id}))
	else:
		options.append(RunChoiceBuilder.option("piece_%s" % piece_id, "Recruit %s" % reward_service.definition_label(piece_id), "piece", {"piece_def_id": piece_id}))
	while options.size() < 3:
		var relic: StringName = reward_service.unowned_relic(run_state, rng, &"reward_rng")
		if relic.is_empty():
			options.append(RunChoiceBuilder.option("small_gold_%d" % options.size(), "%d Gold" % table.fallback_gold, "gold", {"amount": table.fallback_gold}))
		else:
			options.append(RunChoiceBuilder.option("relic_%s" % relic, RunContentDatabase.relic_label(relic), "relic", {"relic_id": String(relic)}))
	run_state.pending_choice = RunChoiceBuilder.pending("battle_reward", table.title, table.description, options, false)
	return OK

class_name ShopOfferGenerator
extends RefCounted

const ShopPoolDefType = preload("res://scripts/content/ShopPoolDef.gd")

func generate(run_state: RunState, rng: RunRngService, fusion_service: FusionService, reward_service: RunRewardService) -> Error:
	var pool: ShopPoolDefType = RunContentDatabase.shop_pool()
	if pool == null:
		return ERR_DOES_NOT_EXIST
	var options: Array[Dictionary] = []
	var relic: StringName = reward_service.unowned_relic(run_state, rng, &"shop_rng")
	if not relic.is_empty():
		options.append(RunChoiceBuilder.option("buy_relic", "%s — %d Gold" % [RunContentDatabase.relic_label(relic), pool.relic_price], "relic", {"relic_id": String(relic), "price": pool.relic_price}, run_state.gold >= pool.relic_price and run_state.challenger_slots.size() < 6))
	var selected_piece_id: StringName = pool.recruit_piece_ids[rng.pick_index(&"shop_rng", pool.recruit_piece_ids.size())]
	var piece_id: String = String(selected_piece_id)
	options.append(RunChoiceBuilder.option("buy_piece", "%s — %d Gold" % [reward_service.definition_label(piece_id), pool.piece_price], "piece", {"piece_def_id": piece_id, "price": pool.piece_price}, run_state.gold >= pool.piece_price and run_state.reserve_piece_ids.size() < RunState.MAX_RESERVE_PIECES))
	var eligible_recipes: Array[FusionRecipeDef] = fusion_service.eligible_recipes(run_state)
	if not eligible_recipes.is_empty():
		var recipe: FusionRecipeDef = eligible_recipes[rng.pick_index(&"shop_rng", eligible_recipes.size())]
		options.append(RunChoiceBuilder.option("buy_recipe_%s" % recipe.id, "%s — %d Gold" % [recipe.display_name, pool.fusion_price], "fusion", {"recipe_id": String(recipe.id), "price": pool.fusion_price}, run_state.gold >= pool.fusion_price))
	if run_state.challenger_slots.size() < 6:
		var item_label: String = reward_service.definition_label(String(pool.consumable_id))
		options.append(RunChoiceBuilder.option("buy_bomb", "%s — %d Gold" % [item_label, pool.consumable_price], "item", {"item_id": String(pool.consumable_id), "price": pool.consumable_price}, run_state.gold >= pool.consumable_price))
	options.append(RunChoiceBuilder.option("buy_retry", "%s — %d Gold" % [RunRewardService.retry_label(run_state), pool.retry_price], "restore_retry", {"price": pool.retry_price}, run_state.gold >= pool.retry_price and not run_state.has_full_retries()))
	run_state.pending_choice = RunChoiceBuilder.pending("shop", pool.title, pool.description, options, true)
	return OK

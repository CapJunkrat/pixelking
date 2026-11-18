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
	# The shop draws from its own list and the reward list, so rarer pieces turn up too.
	var stock: Array = pool.recruit_piece_ids.duplicate()
	var table: BattleRewardTableDef = RunContentDatabase.battle_reward_table()
	if table != null:
		stock.append_array(table.recruit_piece_ids)
	var piece_id: String = RarityOdds.pick(stock, rng, &"shop_rng", RarityOdds.run_progress(run_state))
	var piece_price: int = roundi(pool.piece_price * RarityOdds.SHOP_PRICE_MULTIPLIER[RarityOdds.rarity_of(piece_id)])
	options.append(RunChoiceBuilder.option("buy_piece", "%s — %d Gold" % [reward_service.definition_label(piece_id), piece_price], "piece", {"piece_def_id": piece_id, "price": piece_price}, run_state.gold >= piece_price and run_state.has_room_for_piece()))
	var eligible_recipes: Array[FusionRecipeDef] = fusion_service.eligible_recipes(run_state)
	if not eligible_recipes.is_empty():
		var recipe: FusionRecipeDef = eligible_recipes[rng.pick_index(&"shop_rng", eligible_recipes.size())]
		options.append(RunChoiceBuilder.option("buy_recipe_%s" % recipe.id, "%s — %d Gold" % [RunContentDatabase.recipe_label(recipe), pool.fusion_price], "fusion", {"recipe_id": String(recipe.id), "price": pool.fusion_price}, run_state.gold >= pool.fusion_price))
	if run_state.challenger_slots.size() < 6:
		var consumables: Array[StringName] = RunContentDatabase.consumable_ids()
		var item_id: StringName = consumables[rng.pick_index(&"shop_rng", consumables.size())] if not consumables.is_empty() else pool.consumable_id
		var item_label: String = RunContentDatabase.item_label(item_id)
		options.append(RunChoiceBuilder.option("buy_bomb", "%s — %d Gold" % [item_label, pool.consumable_price], "item", {"item_id": String(item_id), "price": pool.consumable_price}, run_state.gold >= pool.consumable_price))
	options.append(RunChoiceBuilder.option("buy_retry", "%s — %d Gold" % [RunRewardService.retry_label(run_state), pool.retry_price], "restore_retry", {"price": pool.retry_price}, run_state.gold >= pool.retry_price and not run_state.has_full_retries()))
	run_state.pending_choice = RunChoiceBuilder.pending("shop", pool.title, pool.description, options, true)
	return OK

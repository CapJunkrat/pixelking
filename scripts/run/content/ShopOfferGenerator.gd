class_name ShopOfferGenerator
extends RefCounted

const ShopPoolDefType = preload("res://scripts/content/ShopPoolDef.gd")

func generate(run_state: RunState, rng: RunRngService, fusion_service: FusionService, reward_service: RunRewardService) -> Error:
	var pool: ShopPoolDefType = RunContentDatabase.shop_pool()
	if pool == null:
		return ERR_DOES_NOT_EXIST
	# Six wares every visit: two recruits, a relic, an item, a fusion blueprint and a
	# retry. A ware that cannot be offered is swapped (no relic or blueprint left: a
	# third recruit; retries already full: a second item).
	var options: Array[Dictionary] = []
	var stock: Array = pool.recruit_piece_ids.duplicate()
	var table: BattleRewardTableDef = RunContentDatabase.battle_reward_table()
	if table != null:
		stock.append_array(table.recruit_piece_ids)
	var offered_pieces: Array[String] = []
	for index: int in range(2):
		_add_piece(options, offered_pieces, stock, run_state, rng, reward_service, pool)
	var relic: StringName = reward_service.unowned_relic(run_state, rng, &"shop_rng")
	if not relic.is_empty():
		options.append(RunChoiceBuilder.option("buy_relic", "%s — %d Gold" % [RunContentDatabase.relic_label(relic), pool.relic_price], "relic", {"relic_id": String(relic), "price": pool.relic_price}, run_state.gold >= pool.relic_price and run_state.challenger_slots.size() < 6))
	else:
		_add_piece(options, offered_pieces, stock, run_state, rng, reward_service, pool)
	var offered_items: Array[StringName] = []
	_add_item(options, offered_items, run_state, rng, pool)
	var eligible_recipes: Array[FusionRecipeDef] = fusion_service.eligible_recipes(run_state)
	if not eligible_recipes.is_empty():
		var recipe: FusionRecipeDef = eligible_recipes[rng.pick_index(&"shop_rng", eligible_recipes.size())]
		options.append(RunChoiceBuilder.option("buy_recipe_%s" % recipe.id, "%s — %d Gold" % [RunContentDatabase.recipe_label(recipe), pool.fusion_price], "fusion", {"recipe_id": String(recipe.id), "price": pool.fusion_price}, run_state.gold >= pool.fusion_price))
	else:
		_add_piece(options, offered_pieces, stock, run_state, rng, reward_service, pool)
	if not run_state.has_full_retries():
		options.append(RunChoiceBuilder.option("buy_retry", "%s — %d Gold" % [RunRewardService.retry_label(run_state), pool.retry_price], "restore_retry", {"price": pool.retry_price}, run_state.gold >= pool.retry_price))
	else:
		_add_item(options, offered_items, run_state, rng, pool)
	run_state.pending_choice = RunChoiceBuilder.pending("shop", pool.title, pool.description, options, true)
	return OK

## A recruit not already on the shelf; rarer pieces cost more.
func _add_piece(options: Array[Dictionary], offered: Array[String], stock: Array, run_state: RunState, rng: RunRngService, reward_service: RunRewardService, pool: ShopPoolDefType) -> void:
	var piece_id: String = ""
	for attempt: int in range(8):
		piece_id = RarityOdds.pick(stock, rng, &"shop_rng", RarityOdds.run_progress(run_state))
		if piece_id not in offered:
			break
	if piece_id in offered:
		return
	offered.append(piece_id)
	var piece_price: int = roundi(pool.piece_price * RarityOdds.SHOP_PRICE_MULTIPLIER[RarityOdds.rarity_of(piece_id)])
	options.append(RunChoiceBuilder.option("buy_piece_%d" % offered.size(), "%s — %d Gold" % [reward_service.definition_label(piece_id), piece_price], "piece", {"piece_def_id": piece_id, "price": piece_price}, run_state.gold >= piece_price and run_state.has_room_for_piece()))

## A consumable not already on the shelf (sold out of room: shown but not buyable).
func _add_item(options: Array[Dictionary], offered: Array[StringName], run_state: RunState, rng: RunRngService, pool: ShopPoolDefType) -> void:
	var consumables: Array[StringName] = RunContentDatabase.consumable_ids()
	for item: StringName in offered:
		consumables.erase(item)
	var item_id: StringName = consumables[rng.pick_index(&"shop_rng", consumables.size())] if not consumables.is_empty() else pool.consumable_id
	offered.append(item_id)
	options.append(RunChoiceBuilder.option("buy_item_%d" % offered.size(), "%s — %d Gold" % [RunContentDatabase.item_label(item_id), pool.consumable_price], "item", {"item_id": String(item_id), "price": pool.consumable_price}, run_state.gold >= pool.consumable_price and run_state.challenger_slots.size() < 6))

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
	if &"lucky_coin" in run_state.challenger_slots:
		gold_amount += gold_amount / 2
	# Gold is always paid for a win; the choice is only between the extras below.
	run_state.gold += gold_amount
	if elite:
		return _elite_offer(run_state, rng, reward_service, gold_amount, table)
	var options: Array[Dictionary] = []
	var eligible_recipes: Array[FusionRecipeDef] = fusion_service.eligible_recipes(run_state)
	if not eligible_recipes.is_empty():
		var recipe: FusionRecipeDef = eligible_recipes[rng.pick_index(&"reward_rng", eligible_recipes.size())]
		options.append(RunChoiceBuilder.option("recipe_%s" % recipe.id, RunContentDatabase.recipe_label(recipe), "fusion", {"recipe_id": String(recipe.id)}))
	var progress: float = RarityOdds.run_progress(run_state) + (RarityOdds.ELITE_BONUS if elite else 0.0)
	var piece_id: String = RarityOdds.pick(table.recruit_piece_ids, rng, &"reward_rng", progress)
	var item_roll_matches: bool = (
		run_state.challenger_slots.size() < 6
		and rng.randi_range(&"reward_rng", 0, table.consumable_roll_sides - 1) == table.consumable_roll_hit
	)
	if item_roll_matches:
		var consumables: Array[StringName] = RunContentDatabase.consumable_ids()
		var item_id: String = String(consumables[rng.pick_index(&"reward_rng", consumables.size())]) if not consumables.is_empty() else String(table.bonus_consumable_id)
		options.append(RunChoiceBuilder.option("item_%s" % item_id, reward_service.definition_label(item_id), "item", {"item_id": item_id}))
	else:
		options.append(RunChoiceBuilder.option("piece_%s" % piece_id, "Recruit %s" % reward_service.definition_label(piece_id), "piece", {"piece_def_id": piece_id}))
	var offered_relics: Array[StringName] = []
	var tries: int = 0
	while options.size() < 3 and tries < 12:
		tries += 1
		var relic: StringName = reward_service.unowned_relic(run_state, rng, &"reward_rng")
		if not relic.is_empty() and relic not in offered_relics and run_state.challenger_slots.size() < 6:
			offered_relics.append(relic)
			options.append(RunChoiceBuilder.option("relic_%s" % relic, RunContentDatabase.relic_label(relic), "relic", {"relic_id": String(relic)}))
			continue
		# No relic left to offer: another recruit instead (never a gold option).
		var extra_id: String = RarityOdds.pick(table.recruit_piece_ids, rng, &"reward_rng", progress)
		var extra_option_id: String = "piece_%s" % extra_id
		if RunChoiceBuilder.find_option({"options": options}, extra_option_id).is_empty():
			options.append(RunChoiceBuilder.option(extra_option_id, "Recruit %s" % reward_service.definition_label(extra_id), "piece", {"piece_def_id": extra_id}))
	var pending: Dictionary = RunChoiceBuilder.pending("battle_reward", table.title, "+%d Gold earned. %s" % [gold_amount, table.description], options, false)
	pending["gold_awarded"] = gold_amount
	run_state.pending_choice = pending
	return OK

const ELITE_DESCRIPTION := "Choose one Epic piece to join your army."
const ELITE_CHOICES := 3

## An elite win (or a cleared act) offers three different Epic pieces; pick one.
func _elite_offer(run_state: RunState, rng: RunRngService, reward_service: RunRewardService, gold_amount: int, table: BattleRewardTableDefType) -> Error:
	var pool: Array[String] = epic_pool()
	var options: Array[Dictionary] = []
	while options.size() < ELITE_CHOICES and not pool.is_empty():
		var piece_id: String = pool[rng.pick_index(&"reward_rng", pool.size())]
		pool.erase(piece_id)
		options.append(RunChoiceBuilder.option("piece_%s" % piece_id, "Recruit %s" % reward_service.definition_label(piece_id), "piece", {"piece_def_id": piece_id}))
	var pending: Dictionary = RunChoiceBuilder.pending("battle_reward", table.title, "+%d Gold earned. %s" % [gold_amount, ELITE_DESCRIPTION], options, false)
	pending["gold_awarded"] = gold_amount
	run_state.pending_choice = pending
	return OK

## Every Epic piece a player can recruit (not a growth form such as Squire Lv4).
static func epic_pool() -> Array[String]:
	var result: Array[String] = []
	for definition: PieceDef in PieceDefDatabase.opening_draft_defs():
		if definition.rarity == PieceDef.Rarity.EPIC and not definition.is_king and definition.id not in result:
			result.append(definition.id)
	result.sort()
	return result

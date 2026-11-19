extends Node

func test_battle_reward_generation_remains_deterministic() -> void:
	var first_run: RunState = _base_run(123456)
	var second_run: RunState = _base_run(123456)
	var first_rng: RunRngService = _rng(first_run.run_seed)
	var second_rng: RunRngService = _rng(second_run.run_seed)
	var fusion_service: FusionService = FusionService.new()
	var reward_service: RunRewardService = RunRewardService.new()
	var generator: BattleRewardOfferGenerator = BattleRewardOfferGenerator.new()
	assert(generator.generate(first_run, first_rng, fusion_service, reward_service, false) == OK)
	assert(generator.generate(second_run, second_rng, fusion_service, reward_service, false) == OK)
	assert(first_run.pending_choice == second_run.pending_choice)
	assert(first_rng.snapshot_states() == second_rng.snapshot_states())
	assert(str(first_run.pending_choice.get("type", "")) == "battle_reward")
	assert(str(first_run.pending_choice.get("title", "")) == RunContentDatabase.battle_reward_table().title)
	assert((first_run.pending_choice.get("options", []) as Array).size() == 3)
	# Gold is paid at once; the three options are only extras, never gold.
	var table: BattleRewardTableDef = RunContentDatabase.battle_reward_table()
	assert(first_run.gold >= _base_run(123456).gold + table.normal_gold_min)
	assert(int(first_run.pending_choice.get("gold_awarded", 0)) == first_run.gold - _base_run(123456).gold)
	for option: Variant in first_run.pending_choice.get("options", []) as Array:
		assert(str(((option as Dictionary).get("payload", {}) as Dictionary).get("kind", "")) != "gold")

func test_elite_reward_offers_three_epic_pieces() -> void:
	var run_state: RunState = _base_run(424242)
	var generator: BattleRewardOfferGenerator = BattleRewardOfferGenerator.new()
	assert(generator.generate(run_state, _rng(run_state.run_seed), FusionService.new(), RunRewardService.new(), true) == OK)
	var options: Array = run_state.pending_choice.get("options", []) as Array
	assert(options.size() == 3)
	var seen: Array[String] = []
	for option_value: Variant in options:
		var payload: Dictionary = (option_value as Dictionary).get("payload", {}) as Dictionary
		var piece_id: String = str(payload.get("piece_def_id", ""))
		assert(str(payload.get("kind", "")) == "piece")
		assert(PieceDefDatabase.get_def(piece_id).rarity == PieceDef.Rarity.EPIC, "elite rewards are Epic pieces")
		assert(piece_id not in seen, "three different pieces")
		seen.append(piece_id)

func test_shop_and_event_use_catalog_order_and_values() -> void:
	var shop_run: RunState = _base_run(998877)
	shop_run.gold = 100
	var shop_rng: RunRngService = _rng(shop_run.run_seed)
	var reward_service: RunRewardService = RunRewardService.new()
	var shop_generator: ShopOfferGenerator = ShopOfferGenerator.new()
	var event_generator: EventOfferGenerator = EventOfferGenerator.new()
	assert(shop_generator.generate(shop_run, shop_rng, FusionService.new(), reward_service) == OK)
	assert(str(shop_run.pending_choice.get("title", "")) == RunContentDatabase.shop_pool().title)
	var shop_options: Array = shop_run.pending_choice.get("options", []) as Array
	assert(shop_options.size() == 6, "the shop always lays out six wares")
	var kinds: Array[String] = []
	for option_value: Variant in shop_options:
		kinds.append(str(((option_value as Dictionary).get("payload", {}) as Dictionary).get("kind", "")))
	assert(kinds.count("piece") >= 2 and kinds.count("item") >= 1)
	# Retries are full on a fresh Run, so a second item takes the retry's place.
	assert("restore_retry" not in kinds and kinds.count("item") == 2, "full retries swap the retry for a second item")
	var shop_piece: Dictionary = (shop_options[1] as Dictionary).get("payload", {}) as Dictionary
	var multiplier: float = RarityOdds.SHOP_PRICE_MULTIPLIER[RarityOdds.rarity_of(str(shop_piece.get("piece_def_id", "")))]
	assert(int(shop_piece.get("price", -1)) == roundi(RunContentDatabase.shop_pool().piece_price * multiplier), "rarer shop pieces cost more")
	var event_run: RunState = _base_run(445566)
	var event_rng: RunRngService = _rng(event_run.run_seed)
	assert(event_generator.generate(event_run, event_rng, reward_service) == OK)
	var selected_title: String = str(event_run.pending_choice.get("title", ""))
	var known_titles: Array[String] = []
	for event_id: StringName in RunContentDatabase.event_ids():
		known_titles.append(RunContentDatabase.event_def(event_id).title)
	assert(selected_title in known_titles)
	assert((event_run.pending_choice.get("options", []) as Array).size() == 3)

func test_shop_generates_an_immediately_eligible_fusion_recipe() -> void:
	var run_state: RunState = _base_run(667788)
	run_state.gold = 100
	run_state.allocate_piece("pawn", false)
	run_state.allocate_piece("knight", false)
	var generator: ShopOfferGenerator = ShopOfferGenerator.new()
	assert(generator.generate(run_state, _rng(run_state.run_seed), FusionService.new(), RunRewardService.new()) == OK)
	var found_recipe: bool = false
	for option_value: Variant in run_state.pending_choice.get("options", []) as Array:
		var option: Dictionary = option_value as Dictionary
		var payload: Dictionary = option.get("payload", {}) as Dictionary
		if str(payload.get("kind", "")) == "fusion":
			found_recipe = str(payload.get("recipe_id", "")) == "pawn_knight_lancer"
			assert(int(payload.get("price", -1)) == RunContentDatabase.shop_pool().fusion_price)
	assert(found_recipe)

func test_rest_site_uses_catalog_definition() -> void:
	var run_state: RunState = _base_run(112233)
	run_state.allocate_piece("pawn", false)
	var generator: RestOfferGenerator = RestOfferGenerator.new()
	assert(generator.generate(run_state, RunRewardService.new()) == OK)
	assert(str(run_state.pending_choice.get("title", "")) == RunContentDatabase.rest_site().title)
	var options: Array = run_state.pending_choice.get("options", []) as Array
	assert(int(((options[0] as Dictionary).get("payload", {}) as Dictionary).get("amount", -1)) == RunContentDatabase.rest_site().supplies_gold)

func _base_run(seed_value: int) -> RunState:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(seed_value)
	run_state.allocate_piece("king", true)
	return run_state

func _rng(seed_value: int) -> RunRngService:
	var rng: RunRngService = RunRngService.new()
	rng.initialize(seed_value)
	return rng

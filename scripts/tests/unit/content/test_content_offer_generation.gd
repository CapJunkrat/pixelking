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
	assert(str(first_run.pending_choice.get("title", "")) == Content.reward_table().title)
	assert((first_run.pending_choice.get("options", []) as Array).size() == 4)
	# Gold is paid at once; three extras follow, then gold instead of an extra.
	var table: BattleRewardTableDef = Content.reward_table()
	assert(first_run.gold >= _base_run(123456).gold + table.normal_gold_min)
	assert(int(first_run.pending_choice.get("gold_awarded", 0)) == first_run.gold - _base_run(123456).gold)
	var reward_options: Array = first_run.pending_choice.get("options", []) as Array
	for index: int in range(3):
		assert(str(((reward_options[index] as Dictionary).get("payload", {}) as Dictionary).get("kind", "")) != "gold")
	var take_gold: Dictionary = reward_options[3] as Dictionary
	assert(str(take_gold.get("id", "")) == "take_gold")
	assert(str((take_gold.get("payload", {}) as Dictionary).get("kind", "")) == "gold")
	assert(int((take_gold.get("payload", {}) as Dictionary).get("amount", 0)) == 12, "Act 1 normal battles offer 12 gold instead")

func test_take_gold_amount_grows_with_the_act() -> void:
	var run_state: RunState = _base_run(777)
	assert(BattleRewardOfferGenerator.take_gold_amount(run_state, false) == 12)
	assert(BattleRewardOfferGenerator.take_gold_amount(run_state, true) == 20)
	run_state.act_index = 2
	assert(BattleRewardOfferGenerator.take_gold_amount(run_state, false) == 18, "+3 per act past the first")
	assert(BattleRewardOfferGenerator.take_gold_amount(run_state, true) == 26)
	run_state.challenger_slots.append(&"lucky_coin")
	assert(BattleRewardOfferGenerator.take_gold_amount(run_state, false) == 18, "the Lucky Coin does not raise it")

func test_taking_gold_skips_the_piece() -> void:
	var run_state: RunState = _base_run(31337)
	var service: RunContentService = RunContentService.new()
	assert(BattleRewardOfferGenerator.new().generate(run_state, _rng(run_state.run_seed), FusionService.new(), RunRewardService.new(), false) == OK)
	var roster_before: int = run_state.player_roster.size()
	var gold_before: int = run_state.gold
	assert(service.submit(run_state, _rng(run_state.run_seed), MapProgressService.new(), DeploymentService.new(), "take_gold") == OK)
	assert(run_state.gold == gold_before + 12)
	assert(run_state.player_roster.size() == roster_before, "taking gold recruits nobody")
	assert(run_state.pending_choice.is_empty(), "the reward is settled")

func test_elite_reward_offers_three_epic_pieces() -> void:
	var run_state: RunState = _base_run(424242)
	var generator: BattleRewardOfferGenerator = BattleRewardOfferGenerator.new()
	assert(generator.generate(run_state, _rng(run_state.run_seed), FusionService.new(), RunRewardService.new(), true) == OK)
	var options: Array = run_state.pending_choice.get("options", []) as Array
	assert(options.size() == 4)
	assert(int(((options.pop_back() as Dictionary).get("payload", {}) as Dictionary).get("amount", 0)) == 20, "elite rewards end with 20 gold instead")
	var seen: Array[String] = []
	for option_value: Variant in options:
		var payload: Dictionary = (option_value as Dictionary).get("payload", {}) as Dictionary
		var piece_id: String = str(payload.get("piece_def_id", ""))
		assert(str(payload.get("kind", "")) == "piece")
		assert(Content.piece(piece_id).rarity == PieceDef.Rarity.EPIC, "elite rewards are Epic pieces")
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
	assert(str(shop_run.pending_choice.get("title", "")) == Content.shop_pool().title)
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
	assert(int(shop_piece.get("price", -1)) == roundi(Content.shop_pool().piece_price * multiplier), "rarer shop pieces cost more")
	var event_run: RunState = _base_run(445566)
	var event_rng: RunRngService = _rng(event_run.run_seed)
	assert(event_generator.generate(event_run, event_rng, reward_service) == OK)
	var selected_title: String = str(event_run.pending_choice.get("title", ""))
	var known_titles: Array[String] = []
	for event_id: StringName in Content.event_ids():
		known_titles.append(Content.event(event_id).title)
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
			assert(int(payload.get("price", -1)) == Content.shop_pool().fusion_price)
	assert(found_recipe)

func test_missing_fusion_materials() -> void:
	var run_state: RunState = _base_run(424242)
	assert(ShopOfferGenerator.missing_materials(run_state).is_empty(), "owning only the King starts no recipe")
	run_state.allocate_piece("pawn", false)
	var missing: Array[String] = ShopOfferGenerator.missing_materials(run_state)
	assert("knight" in missing and "king" not in missing and "pawn" not in missing, "a Pawn starts the Lancer: the Knight is missing")
	run_state.allocate_piece("knight", false)
	missing = ShopOfferGenerator.missing_materials(run_state)
	assert("knight" not in missing and "bishop" in missing and "rook" in missing, "a complete recipe needs nothing; the Knight starts others")

func test_shop_favors_missing_materials_even_late() -> void:
	# Late in Act 3 a Common is rare on the shelf, but a missing one still turns up often.
	var with_missing: int = 0
	var without_missing: int = 0
	for seed_value: int in range(120):
		for wants_pawn: bool in [true, false]:
			var run_state: RunState = _base_run(9000 + seed_value)
			run_state.act_index = 2
			run_state.gold = 100
			run_state.allocate_piece("knight" if wants_pawn else "sentry", false)
			assert(ShopOfferGenerator.new().generate(run_state, _rng(run_state.run_seed), FusionService.new(), RunRewardService.new()) == OK)
			for option_value: Variant in run_state.pending_choice.get("options", []) as Array:
				var payload: Dictionary = (option_value as Dictionary).get("payload", {}) as Dictionary
				if str(payload.get("kind", "")) == "piece" and str(payload.get("piece_def_id", "")) == "pawn":
					if wants_pawn:
						with_missing += 1
					else:
						without_missing += 1
	# A Knight leaves four pieces missing (Pawn, Bishop, Rook, Queen), so the Pawn gets
	# about a tenth of each recruit slot on top of its usual odds: roughly a third of shops.
	assert(with_missing >= 25, "a missing Pawn is offered in many late shops (%d of 120)" % with_missing)
	assert(with_missing > without_missing * 3, "far more often than when no recipe needs it (%d vs %d)" % [with_missing, without_missing])

func test_rest_site_uses_catalog_definition() -> void:
	var run_state: RunState = _base_run(112233)
	run_state.allocate_piece("pawn", false)
	var generator: RestOfferGenerator = RestOfferGenerator.new()
	assert(generator.generate(run_state, RunRewardService.new()) == OK)
	assert(str(run_state.pending_choice.get("title", "")) == Content.rest_site().title)
	var options: Array = run_state.pending_choice.get("options", []) as Array
	assert(int(((options[0] as Dictionary).get("payload", {}) as Dictionary).get("amount", -1)) == Content.rest_site().supplies_gold)

func _base_run(seed_value: int) -> RunState:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(seed_value)
	run_state.allocate_piece("king", true)
	return run_state

func _rng(seed_value: int) -> RunRngService:
	var rng: RunRngService = RunRngService.new()
	rng.initialize(seed_value)
	return rng

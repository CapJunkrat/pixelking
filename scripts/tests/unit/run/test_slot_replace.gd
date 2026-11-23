extends SceneTree

## With every relic and item slot full, a relic or item can still be bought, taken as a
## battle reward or won in an event: the player gives one up, or steps back for free.

var failures: int = 0

class FakeProgress extends MapProgressService:
	var resolved: Dictionary = {}
	func resolve_current_node(_run_state: RunState, payload: Dictionary) -> Error:
		resolved = payload.duplicate(true)
		return OK

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_shop_relic()
	_test_shop_item_replaces_a_relic()
	_test_battle_reward()
	_test_event_gives_up_only_on_success()
	_test_war_banner()
	_test_offers_stay_open()
	_finish()

const FULL_SLOTS: Array[StringName] = [&"iron_crown", &"freeze_charm", &"freeze_charm", &"royal_bomb", &"holy_water"]

func _full_run() -> RunState:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(31337)
	run_state.allocate_piece("king", true)
	run_state.allocate_piece("pawn", false)
	run_state.challenger_slots.assign(FULL_SLOTS)
	run_state.gold = 100
	return run_state

func _test_shop_relic() -> void:
	var run_state: RunState = _full_run()
	var offers: Array[Dictionary] = [RunChoiceBuilder.option("buy_relic", "Lucky Coin", "relic", {"relic_id": "lucky_coin", "price": 30})]
	run_state.pending_choice = RunChoiceBuilder.pending("shop", "Shop", "", offers, true)
	var service: RunContentService = RunContentService.new()
	var progress: FakeProgress = FakeProgress.new()
	_expect(service.submit(run_state, null, progress, null, "buy_relic") == OK, "a relic stays buyable with every slot full")
	_expect(run_state.pending_choice.has("slot_return") and run_state.gold == 100 and progress.resolved.is_empty(), "buying first asks what to give up, and charges nothing yet")
	_expect((run_state.pending_choice.get("options", []) as Array).size() == FULL_SLOTS.size() + 1, "every relic and item can be given up, plus a way back")
	var reloaded: RunState = RunState.new()
	reloaded.load_from_dictionary(run_state.to_dictionary(), false)
	_expect(reloaded.pending_choice.has("slot_return"), "the choice survives a save")
	_expect(service.submit(run_state, null, progress, null, "slot_cancel") == OK and RunChoiceBuilder.find_option(run_state.pending_choice, "buy_relic").size() > 0, "stepping back returns to the shop")
	_expect(run_state.gold == 100 and run_state.challenger_slots == FULL_SLOTS, "stepping back costs nothing and changes no slot")
	service.submit(run_state, null, progress, null, "buy_relic")
	_expect(service.submit(run_state, null, progress, null, "slot_drop_1") == OK, "picking a slot completes the purchase")
	_expect(&"lucky_coin" in run_state.challenger_slots and run_state.challenger_slots.count(&"freeze_charm") == 1 and run_state.challenger_slots.size() == 5, "the picked item goes and the relic comes in")
	_expect(run_state.gold == 70 and str(progress.resolved.get("choice", "")) == "buy_relic", "the price is paid once and the visit ends as a purchase")

func _test_shop_item_replaces_a_relic() -> void:
	var run_state: RunState = _full_run()
	var offers: Array[Dictionary] = [RunChoiceBuilder.option("buy_item_1", "Royal Bomb", "item", {"item_id": "royal_bomb", "price": 10})]
	run_state.pending_choice = RunChoiceBuilder.pending("shop", "Shop", "", offers, true)
	var service: RunContentService = RunContentService.new()
	service.submit(run_state, null, FakeProgress.new(), null, "buy_item_1")
	_expect(service.submit(run_state, null, FakeProgress.new(), null, "slot_drop_0") == OK, "an item can replace a relic")
	_expect(&"iron_crown" not in run_state.challenger_slots and run_state.challenger_slots.count(&"royal_bomb") == 2 and run_state.gold == 90, "the relic goes, the item comes in, paid once")

func _test_battle_reward() -> void:
	var run_state: RunState = _full_run()
	var options: Array[Dictionary] = [
		RunChoiceBuilder.option("relic_lucky_coin", "Lucky Coin", "relic", {"relic_id": "lucky_coin"}),
		RunChoiceBuilder.option("take_gold", "Gold", "gold", {"amount": 12}),
	]
	run_state.pending_choice = RunChoiceBuilder.pending("battle_reward", "Victory", "", options, false)
	var service: RunContentService = RunContentService.new()
	_expect(service.submit(run_state, null, FakeProgress.new(), null, "relic_lucky_coin") == OK and run_state.pending_choice.has("slot_return"), "a reward relic with every slot full asks what to give up")
	_expect(str(run_state.pending_choice.get("type", "")) == "battle_reward", "the choice stays a battle reward")
	_expect(service.submit(run_state, null, FakeProgress.new(), null, "slot_cancel") == OK and RunChoiceBuilder.find_option(run_state.pending_choice, "take_gold").size() > 0, "giving it up returns to the reward choice")
	service.submit(run_state, null, FakeProgress.new(), null, "relic_lucky_coin")
	_expect(service.submit(run_state, null, FakeProgress.new(), null, "slot_drop_4") == OK, "picking a slot takes the reward")
	_expect(&"lucky_coin" in run_state.challenger_slots and &"holy_water" not in run_state.challenger_slots and run_state.pending_choice.is_empty() and run_state.gold == 100, "the reward replaces the picked item for free")

func _event_run(chance: float) -> RunState:
	var run_state: RunState = _full_run()
	var options: Array[Dictionary] = [RunChoiceBuilder.option("gamble", "Gamble", "item", {
		"item_id": "royal_bomb", "cost": 5, "chance": chance, "fail": {"kind": "nothing"},
		"success_text": "Won", "fail_text": "Lost",
	})]
	run_state.pending_choice = RunChoiceBuilder.pending("event", "Event", "", options, true)
	return run_state

func _test_event_gives_up_only_on_success() -> void:
	var service: RunContentService = RunContentService.new()
	var rng: RunRngService = RunRngService.new()
	rng.initialize(5)
	var won: RunState = _event_run(1.0)
	_expect(service.submit(won, rng, FakeProgress.new(), null, "gamble") == OK and won.pending_choice.has("slot_return") and won.gold == 100, "an event item with every slot full asks first, before paying or rolling")
	_expect(service.submit(won, rng, FakeProgress.new(), null, "slot_cancel") == OK and RunChoiceBuilder.find_option(won.pending_choice, "gamble").size() > 0 and won.gold == 100, "stepping back returns to the event with nothing paid")
	service.submit(won, rng, FakeProgress.new(), null, "gamble")
	_expect(service.submit(won, rng, FakeProgress.new(), null, "slot_drop_0") == OK, "picking a slot plays out the event")
	_expect(&"iron_crown" not in won.challenger_slots and won.challenger_slots.count(&"royal_bomb") == 2 and won.gold == 95, "on success the picked relic makes room for the item")
	var lost: RunState = _event_run(0.0)
	service.submit(lost, rng, FakeProgress.new(), null, "gamble")
	_expect(service.submit(lost, rng, FakeProgress.new(), null, "slot_drop_0") == OK, "a failed gamble still resolves")
	_expect(lost.challenger_slots == FULL_SLOTS and lost.gold == 95, "on failure nothing is given up, only the cost is paid")

func _test_war_banner() -> void:
	var run_state: RunState = _full_run()
	run_state.challenger_slots[0] = &"war_banner"
	for index: int in range(5):
		run_state.allocate_piece("knight", false)
	_expect(run_state.active_piece_ids.size() == 7, "the War Banner fills a sixth place on the battle line")
	_expect(SlotReplaceService.can_give_up(run_state, &"war_banner") and SlotReplaceService.give_up(run_state, &"war_banner") == OK, "the War Banner can go while the reserve has room")
	_expect(run_state.active_piece_ids.size() == 6 and run_state.reserve_piece_ids.size() == 1 and run_state.is_valid(), "its extra piece moves to the reserve")
	var packed: RunState = _full_run()
	packed.challenger_slots[0] = &"war_banner"
	for index: int in range(11):
		packed.allocate_piece("knight", false)
	_expect(not SlotReplaceService.can_give_up(packed, &"war_banner"), "with the reserve full too, the War Banner cannot go")
	packed.pending_choice = RunChoiceBuilder.pending("shop", "Shop", "", [RunChoiceBuilder.option("buy_relic", "Lucky Coin", "relic", {"relic_id": "lucky_coin", "price": 30})] as Array[Dictionary], true)
	RunContentService.new().submit(packed, null, FakeProgress.new(), null, "buy_relic")
	var banner: Dictionary = RunChoiceBuilder.find_option(packed.pending_choice, "slot_drop_0")
	_expect(not bool(banner.get("enabled", true)) and str((banner.get("payload", {}) as Dictionary).get("detail_key", "")) == "SLOT_FULL_BANNER_BLOCKED", "it is shown disabled, saying why")

func _test_offers_stay_open() -> void:
	var run_state: RunState = _full_run()
	var rng: RunRngService = RunRngService.new()
	rng.initialize(77)
	ShopOfferGenerator.new().generate(run_state, rng, FusionService.new(), RunRewardService.new())
	var relic_open: bool = true
	var item_open: bool = true
	for option_value: Variant in run_state.pending_choice.get("options", []) as Array:
		var option: Dictionary = option_value as Dictionary
		match str((option.get("payload", {}) as Dictionary).get("kind", "")):
			"relic":
				relic_open = relic_open and bool(option.get("enabled", false))
			"item":
				item_open = item_open and bool(option.get("enabled", false))
	_expect(relic_open and item_open, "the shop's relic and items stay buyable with every slot full")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error("[FAIL] " + message)

func _finish() -> void:
	quit(1 if failures > 0 else 0)

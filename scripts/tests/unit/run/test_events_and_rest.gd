extends SceneTree

## Events offer real choices (costs, chances, rolled rewards) and the rest site can
## drill a growing piece.

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var reward: RunRewardService = RunRewardService.new()
	var generator: EventOfferGenerator = EventOfferGenerator.new()
	var content: RunContentService = RunContentService.new()
	for event_id: StringName in RunContentDatabase.event_ids():
		var definition: EventDef = RunContentDatabase.event_def(event_id)
		_expect(definition.options.size() >= 2, "%s offers at least two choices" % event_id)

	var run: RunState = _run_state()
	run.gold = 10
	var rng: RunRngService = RunRngService.new()
	rng.initialize(99)
	run.rng_stream_states = rng.snapshot_states()
	var merchant: Dictionary = {"id": "crate", "label": "Crate", "cost": 15, "kind": "random_item", "success_text": "Inside: %s."}
	var resolved: Dictionary = generator._resolve_option(merchant, run, rng, reward)
	_expect(str((resolved["payload"] as Dictionary).get("kind", "")) == "item" and not str((resolved["payload"] as Dictionary).get("item_id", "")).is_empty(), "a random item is rolled when the event opens")
	_expect(not bool(resolved["enabled"]), "a choice the player cannot afford is disabled")

	run.gold = 30
	var outcome: Dictionary = content._apply_chance_effect(run, rng, {"kind": "gold", "amount": 45, "cost": 5, "chance": 0.0, "fail": {"kind": "lose_gold", "amount": 8}, "success_text": "won", "fail_text": "lost"})
	_expect(int(outcome["error"]) == OK and not bool(outcome["success"]) and run.gold == 30 - 5 - 8, "a missed chance pays the cost and applies the failure")
	_expect(str(outcome["text"]) == "lost", "the player is told what happened")
	var pieces_before: int = run.player_roster.size()
	content._apply_chance_effect(run, rng, {"kind": "gold", "amount": 35, "chance": 0.0, "fail": {"kind": "gold_and_desert", "amount": 35}, "fail_text": "%s left"})
	_expect(run.player_roster.size() == pieces_before - 1 and run.gold == 17 + 35, "a deserter leaves but the gold is kept")

	var squire: PieceInstanceState = run.allocate_piece("squire", false)
	_expect(reward.apply(run, {"kind": "train", "instance_id": squire.instance_id}) == OK and squire.piece_def_id == &"squire_lv2", "drilling a Squire counts as its first capture and levels it")
	var rest: RestOfferGenerator = RestOfferGenerator.new()
	rest.generate(run, reward)
	_expect(bool(run.pending_choice.get("allow_leave", false)), "a rest site can be left without choosing")
	_test_walk_away(content)
	var drill: Dictionary = RunChoiceBuilder.find_option(run.pending_choice, "rest_train")
	_expect(bool(drill.get("enabled", false)) and int((drill["payload"] as Dictionary).get("instance_id", 0)) == squire.instance_id, "the rest site offers to drill the growing piece")
	_test_event_content(generator, content, reward)
	print("[PASS] Events and rest test" if not failed else "[FAIL] Events and rest test")
	quit(1 if failed else 0)

## Events touch the army: arm a Pawn, trade a recruit, train a growing piece, give up
## an item or the retry. Choices name what they touch and say why they are unavailable.
func _test_event_content(generator: EventOfferGenerator, content: RunContentService, reward: RunRewardService) -> void:
	var rng: RunRngService = RunRngService.new()
	rng.initialize(1234)
	var run: RunState = _run_state()
	run.gold = 100
	var pawn: PieceInstanceState = run.allocate_piece("pawn", false)

	var arm: Dictionary = generator._resolve_option({"id": "arm", "label": "Arm a Pawn", "detail": "Your {target} becomes a {reward}.", "cost": 15, "kind": "arm_pawn"}, run, rng, reward)
	var arm_payload: Dictionary = arm["payload"] as Dictionary
	_expect(bool(arm["enabled"]) and str(arm_payload["kind"]) == "transform" and int(arm_payload["instance_id"]) == pawn.instance_id, "arming targets one of your Pawns")
	_expect(not "{" in str(arm_payload["detail"]) and str(arm_payload["reward_name"]) in str(arm_payload["detail"]), "the card names the piece the Pawn becomes")
	var outcome: Dictionary = content._apply_chance_effect(run, rng, arm_payload)
	_expect(int(outcome["error"]) == OK and String(pawn.piece_def_id) == str(arm_payload["piece_def_id"]) and run.gold == 85, "the Pawn becomes that piece and the price is paid")

	var no_pawn: Dictionary = generator._resolve_option({"id": "arm", "label": "Arm", "detail": "x", "kind": "arm_pawn"}, run, rng, reward)
	_expect(not bool(no_pawn["enabled"]) and "Pawn" in str((no_pawn["payload"] as Dictionary)["detail"]), "with no Pawn the choice is disabled and says why")

	var sell_none: Dictionary = generator._resolve_option({"id": "sell", "label": "Sell your {lost}", "detail": "x", "kind": "gold", "amount": 20, "pay": [{"kind": "lose_item"}]}, run, rng, reward)
	_expect(not bool(sell_none["enabled"]), "giving up an item needs an item")
	run.challenger_slots.append(&"holy_water")
	var sell: Dictionary = generator._resolve_option({"id": "sell", "label": "Sell your {lost}", "detail": "x", "kind": "gold", "amount": 20, "pay": [{"kind": "lose_item"}]}, run, rng, reward)
	_expect(bool(sell["enabled"]) and RunContentDatabase.item_label(&"holy_water") in str(sell["label"]), "the card names the item it takes")
	content._apply_chance_effect(run, rng, sell["payload"] as Dictionary)
	_expect(&"holy_water" not in run.challenger_slots and run.gold == 105, "the item is given up for the gold")

	var blade: Dictionary = generator._resolve_option({"id": "blade", "label": "Blade", "detail": "x", "kind": "random_relic", "pay": [{"kind": "lose_retry"}]}, run, rng, reward)
	content._apply_chance_effect(run, rng, blade["payload"] as Dictionary)
	_expect(run.retries_left == 0 and run.challenger_slots.size() == 1, "the cursed blade costs the retry and gives a relic")
	var blade_again: Dictionary = generator._resolve_option({"id": "blade", "label": "Blade", "detail": "x", "kind": "random_relic", "pay": [{"kind": "lose_retry"}]}, run, rng, reward)
	_expect(not bool(blade_again["enabled"]), "without a retry the blade cannot be taken")

	var squire: PieceInstanceState = run.allocate_piece("squire", false)
	var spar: Dictionary = generator._resolve_option({"id": "spar", "label": "Drill your {target}", "detail": "x", "kind": "train_best", "times": 2}, run, rng, reward)
	_expect(int((spar["payload"] as Dictionary)["instance_id"]) == squire.instance_id and "Squire" in str(spar["label"]), "training picks the growing piece and names it")
	content._apply_chance_effect(run, rng, spar["payload"] as Dictionary)
	_expect(squire.capture_count == 2, "training twice counts two captures")

	var trade: Dictionary = generator._resolve_option({"id": "swap", "label": "Trade your {target}", "detail": "x", "kind": "trade_weakest"}, run, rng, reward)
	var trade_payload: Dictionary = trade["payload"] as Dictionary
	var traded: PieceInstanceState = run.get_piece_state(int(trade_payload["instance_id"]))
	_expect(bool(trade["enabled"]) and traded != null and not traded.is_king, "the trade offers your cheapest piece")
	content._apply_chance_effect(run, rng, trade_payload)
	_expect(PieceDefDatabase.get_def(String(traded.piece_def_id)).rarity != PieceDef.Rarity.COMMON, "the traded piece comes back rare")

	# Every event opens with resolved texts, and none repeats until all have been met.
	var tour: RunState = _run_state()
	tour.gold = 200
	var met: Array[String] = []
	var first_layer: int = 0
	for event_id: StringName in RunContentDatabase.event_ids():
		if RunContentDatabase.event_def(event_id).min_layer == 0:
			first_layer += 1
	_expect(first_layer >= 6 and first_layer < RunContentDatabase.event_ids().size(), "some events wait for later layers")
	for _index: int in range(first_layer):
		_expect(generator.generate(tour, rng, reward) == OK, "an event opens")
		var id: String = str(tour.pending_choice.get("event_id", ""))
		_expect(id not in met, "%s has not been met before this Run" % id)
		met.append(id)
		for option: Dictionary in tour.pending_choice["options"]:
			var shown: String = str(option["label"]) + str((option["payload"] as Dictionary).get("detail", ""))
			_expect(not "{" in shown, "%s/%s names everything it touches" % [id, option["id"]])
		tour.pending_choice.clear()

## Records the node as resolved without needing a whole map.
class StubProgress extends MapProgressService:
	var resolved_with: Dictionary = {}
	func resolve_current_node(_run_state: RunState, payload: Dictionary = {}) -> Error:
		resolved_with = payload
		return OK

## With no gold, nothing to sell and no piece that can grow, an event must still let
## the player go (it used to trap them).
func _test_walk_away(content: RunContentService) -> void:
	var broke: RunState = _run_state()
	broke.gold = 0
	var progress: StubProgress = StubProgress.new()
	broke.pending_choice = RunChoiceBuilder.pending("event", "Alchemist's Cart", "x", [RunChoiceBuilder.option("buy", "Buy", "item", {"item_id": "holy_water"}, false)], true)
	_expect(content.leave(broke, progress) == OK and broke.pending_choice.is_empty() and str(progress.resolved_with.get("outcome", "")) == "left_event", "a stuck event can always be walked away from")
	# Saves made before events offered leaving still let the player go.
	broke.pending_choice = RunChoiceBuilder.pending("event", "Old save", "x", [], false)
	_expect(content.leave(broke, progress) == OK, "an older saved event can be left too")
	broke.pending_choice = RunChoiceBuilder.pending("battle_reward", "Reward", "x", [], false)
	_expect(content.leave(broke, progress) == ERR_UNAUTHORIZED, "a battle reward still has to be chosen")

func _run_state() -> RunState:
	var run: RunState = RunState.new()
	run.initialize_new(5)
	run.allocate_piece("king", true)
	run.allocate_piece("knight", false)
	return run

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

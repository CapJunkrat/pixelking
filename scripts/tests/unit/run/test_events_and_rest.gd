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
	var drill: Dictionary = RunChoiceBuilder.find_option(run.pending_choice, "rest_train")
	_expect(bool(drill.get("enabled", false)) and int((drill["payload"] as Dictionary).get("instance_id", 0)) == squire.instance_id, "the rest site offers to drill the growing piece")
	print("[PASS] Events and rest test" if not failed else "[FAIL] Events and rest test")
	quit(1 if failed else 0)

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

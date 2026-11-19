extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_fusion()
	_test_defeat_and_retry()
	_test_motion_profiles()
	_test_slot_limits()
	_test_shop_buy_when_full()
	_test_enemy_rarity()
	_finish()

func _test_fusion() -> void:
	var run_state: RunState = _base_run()
	run_state.allocate_piece("pawn", false)
	run_state.allocate_piece("knight", false)
	var recipe: FusionRecipeDef = FusionRecipeDatabase.get_def(&"pawn_knight_lancer")
	var service: FusionService = FusionService.new()
	var plan: FusionPlan = service.create_plan(run_state, &"pawn_knight_lancer")
	_expect(recipe != null and plan != null, "fusion service plans exact owned ingredients")
	var method_result: Error = service.confirm(run_state, plan)
	_expect(method_result == OK, "eligible fusion succeeds")
	_expect(_piece_count(run_state, &"lancer") == 1 and _piece_count(run_state, &"pawn") == 0, "fusion consumes materials and creates an independent product")
	_expect(&"pawn_knight_lancer" in run_state.owned_recipe_history, "fusion history is persisted")
	_expect(run_state.is_valid(), "fusion preserves RunState invariants")

func _test_defeat_and_retry() -> void:
	var run_state: RunState = _base_run()
	run_state.allocate_piece("pawn", false)
	run_state.allocate_piece("knight", false)
	var rng: RunRngService = RunRngService.new()
	rng.initialize(run_state.run_seed)
	run_state.rng_stream_states = rng.snapshot_states()
	var service: RunContentService = RunContentService.new()
	var deployment: DeploymentService = DeploymentService.new()
	var before_count: int = run_state.player_roster.size()
	_expect(run_state.retries_left == 1, "a new run starts with exactly one retry")
	service.apply_battle_defeat(run_state, rng, deployment)
	_expect(run_state.failed_battles == 1 and run_state.retries_left == 0, "first defeat spends the retry")
	_expect(str(run_state.pending_choice.get("type", "")) != "run_summary", "first defeat does not end the run")
	_expect(run_state.player_roster.size() == before_count, "defeat never removes a piece")
	run_state.deployment_state = null
	service.apply_battle_defeat(run_state, rng, deployment)
	_expect(str(run_state.pending_choice.get("type", "")) == "run_summary" and run_state.failed_battles == 2, "second defeat without a retry ends the run")
	_expect(run_state.player_roster.size() == before_count, "ending the run still keeps the roster intact")
	var reward: RunRewardService = RunRewardService.new()
	var restore_run: RunState = _base_run()
	_expect(reward.apply(restore_run, {"kind": "restore_retry"}) == ERR_UNAVAILABLE and restore_run.retries_left == 1, "restoring a full retry is refused and stays at one")
	restore_run.retries_left = 0
	_expect(reward.apply(restore_run, {"kind": "restore_retry"}) == OK and restore_run.retries_left == 1, "restoring a spent retry sets it back to one")
	_expect(reward.apply(restore_run, {"kind": "restore_retry"}) == ERR_UNAVAILABLE and restore_run.retries_left == 1, "retries never exceed one")
	var legacy: Dictionary = restore_run.to_dictionary()
	legacy.erase("retries_left")
	legacy["remaining_failure_allowance"] = 1
	var migrated: RunState = RunState.new()
	migrated.load_from_dictionary(legacy)
	_expect(migrated.retries_left == 0, "old saves on their last allowed defeat migrate to no retry")
	legacy["remaining_failure_allowance"] = 3
	migrated.load_from_dictionary(legacy)
	_expect(migrated.retries_left == 1, "old saves with spare defeats migrate to one retry")

func _test_motion_profiles() -> void:
	for id: String in PieceDefDatabase.all_ids():
		var definition: PieceDef = PieceDefDatabase.get_def(id)
		_expect(definition.motion_profile != null and definition.motion_profile.is_valid(), "%s has a reusable visual MotionProfile" % id)
	_expect(PieceDefDatabase.get_def("lancer").motion_profile == PieceMotionProfileDatabase.get_profile(&"knight"), "fusion pieces inherit an existing profile")

class FakeProgress extends MapProgressService:
	var resolved: Dictionary = {}
	func resolve_current_node(_run_state: RunState, payload: Dictionary) -> Error:
		resolved = payload.duplicate(true)
		return OK

func _test_slot_limits() -> void:
	var run_state: RunState = _base_run()
	for index: int in range(RunState.MAX_CHALLENGER_SLOTS - 1):
		run_state.challenger_slots.append(&"war_banner" if index == 0 else &"freeze_charm")
	_expect(run_state.has_challenger_room(), "four of five relic and item slots leave room")
	run_state.challenger_slots.append(&"freeze_charm")
	_expect(not run_state.has_challenger_room(), "relic and item slots stop at five, War Banner or not")
	_expect(run_state.max_active_pieces() == RunState.MAX_ACTIVE_NON_KING_PIECES + 1 and RunState.MAX_RESERVE_PIECES == 5, "the War Banner widens only the battle line, never the reserve")

func _test_shop_buy_when_full() -> void:
	var run_state: RunState = _base_run()
	for index: int in range(RunState.MAX_ACTIVE_NON_KING_PIECES + RunState.MAX_RESERVE_PIECES):
		run_state.allocate_piece("pawn" if index < 5 else "knight", false)
	_expect(not run_state.has_room_for_piece(), "battle line and reserve are full")
	run_state.gold = 50
	var offers: Array[Dictionary] = [RunChoiceBuilder.option("buy_piece_1", "Bishop — 12 Gold", "piece", {"piece_def_id": "bishop", "price": 12})]
	var shop: Dictionary = RunChoiceBuilder.pending("shop", "Shop", "", offers, true)
	run_state.pending_choice = shop.duplicate(true)
	var service: RunContentService = RunContentService.new()
	var progress: FakeProgress = FakeProgress.new()
	_expect(service.submit(run_state, null, progress, null, "buy_piece_1") == OK, "a recruit stays buyable with the party full")
	_expect(run_state.pending_choice.has("shop_return") and run_state.gold == 50 and progress.resolved.is_empty(), "buying first asks to let a piece go, and charges nothing yet")
	var reloaded: RunState = RunState.new()
	reloaded.load_from_dictionary(run_state.to_dictionary(), false)
	_expect(run_state._pending_choice_is_valid() and reloaded.pending_choice.has("shop_return"), "the party-full prompt survives a save")
	_expect(service.submit(run_state, null, progress, null, "shop_replace_cancel") == OK and RunChoiceBuilder.find_option(run_state.pending_choice, "buy_piece_1").size() > 0 and not run_state.pending_choice.has("shop_return"), "cancelling returns to the shop")
	service.submit(run_state, null, progress, null, "buy_piece_1")
	_expect(service.submit(run_state, null, progress, null, "shop_replace_confirm") == OK, "confirming opens the choice of a piece to let go")
	var options: Array = run_state.pending_choice.get("options", []) as Array
	_expect(options.size() == 11, "every piece but the King can be let go, plus a way back")
	var victim: int = run_state.active_piece_ids[1]
	_expect(service.submit(run_state, null, progress, null, "shop_replace_%d" % victim) == OK, "picking a piece completes the purchase")
	_expect(run_state.get_piece_state(victim) == null and _piece_count(run_state, &"bishop") == 1 and run_state.gold == 38, "the chosen piece leaves, the recruit joins and the price is paid")
	_expect(str(progress.resolved.get("choice", "")) == "buy_piece_1" and run_state.pending_choice.is_empty(), "the shop visit ends as an ordinary purchase")
	var bishop_active: bool = false
	for instance_id: int in run_state.active_piece_ids:
		bishop_active = bishop_active or run_state.get_piece_state(instance_id).piece_def_id == &"bishop"
	_expect(bishop_active, "the recruit takes the freed place on the battle line")

func _test_enemy_rarity() -> void:
	var pawns_by_act: Array[int] = [0, 0, 0]
	var rare_by_act: Array[int] = [0, 0, 0]
	for act: int in range(3):
		for seed_value: int in range(40):
			var stage: float = (float(act) + 0.5) / 3.0
			for placement: Dictionary in EncounterGenerator.generate_at(&"normal", stage, false, seed_value, 0, act):
				var id: String = str(placement["piece_def_id"])
				if id == "pawn":
					pawns_by_act[act] += 1
				elif id != "king" and PieceDefDatabase.get_def(id).rarity >= PieceDef.Rarity.EPIC:
					rare_by_act[act] += 1
	_expect(pawns_by_act[1] <= 40 and pawns_by_act[2] <= 40, "from Act 2 on, a normal battle has at most one pawn")
	_expect(rare_by_act[2] > rare_by_act[1] and rare_by_act[1] > rare_by_act[0], "each act fields more epic and legendary pieces than the last")
	var boss: Array[Dictionary] = []
	for x: int in range(3):
		boss.append({"placement_id": "p%d" % x, "piece_def_id": "pawn", "position": {"x": 4 + x, "y": 6}})
	boss.append({"placement_id": "k", "piece_def_id": "king", "position": {"x": 5, "y": 7}})
	var act_one: Array[Dictionary] = EncounterGenerator.upgrade_boss_pawns(boss, 0, 7)
	var act_two: Array[Dictionary] = EncounterGenerator.upgrade_boss_pawns(boss, 1, 7)
	var pawns_one: int = 0
	var pawns_two: int = 0
	for index: int in range(boss.size()):
		pawns_one += 1 if act_one[index]["piece_def_id"] == "pawn" else 0
		pawns_two += 1 if act_two[index]["piece_def_id"] == "pawn" else 0
		_expect(act_two[index]["position"] == boss[index]["position"], "upgraded Boss pieces keep their squares")
	_expect(pawns_one == 3 and pawns_two == 1, "Act 1 Bosses keep their pawns; later Bosses keep only one")

func _base_run() -> RunState:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(998877)
	run_state.allocate_piece("king", true)
	return run_state

func _piece_count(run_state: RunState, id: StringName) -> int:
	var count: int = 0
	for piece: PieceInstanceState in run_state.player_roster:
		if piece.piece_def_id == id:
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)

func _finish() -> void:
	if failures == 0:
		print("[PASS] Run content systems test")
		quit(0)
	else:
		print("[FAIL] Run content systems test")
		quit(1)

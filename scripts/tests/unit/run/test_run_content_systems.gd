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
	var recipe: FusionRecipeDef = Content.recipe(&"pawn_knight_lancer")
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
	service.apply_battle_draw(run_state, deployment)
	_expect(run_state.retries_left == 0 and run_state.failed_battles == 1, "a draw spends nothing and counts no failure")
	_expect(str(run_state.pending_choice.get("type", "")) != "run_summary", "a draw with no retry left does not end the run")
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
	for id: String in Content.piece_ids():
		var definition: PieceDef = Content.piece(id)
		_expect(definition.motion_profile != null and definition.motion_profile.is_valid(), "%s has a reusable visual MotionProfile" % id)
	_expect(Content.piece("lancer").motion_profile == Content.motion_profile(&"knight"), "fusion pieces inherit an existing profile")

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
				elif id != "king" and Content.piece(id).rarity >= PieceDef.Rarity.EPIC:
					rare_by_act[act] += 1
	_expect(pawns_by_act[0] > 0 and pawns_by_act[1] == 0 and pawns_by_act[2] == 0, "from Act 2 on, a normal battle has no pawns")
	_expect(rare_by_act[2] > rare_by_act[1] and rare_by_act[1] > rare_by_act[0], "each act fields more epic and legendary pieces than the last")
	_test_enemy_rarity_floor()
	_test_enemy_fusions()
	_test_enemy_army_size()
	var boss: Array[Dictionary] = []
	for x: int in range(3):
		boss.append({"placement_id": "p%d" % x, "piece_def_id": "pawn", "position": {"x": 4 + x, "y": 6}})
	boss.append({"placement_id": "r", "piece_def_id": "rook", "position": {"x": 3, "y": 7}})
	boss.append({"placement_id": "k", "piece_def_id": "king", "position": {"x": 5, "y": 7}})
	var act_one: Array[Dictionary] = EncounterGenerator.upgrade_boss_pawns(boss, 0, 7)
	var act_two: Array[Dictionary] = EncounterGenerator.upgrade_boss_pawns(boss, 1, 7)
	var act_four: Array[Dictionary] = EncounterGenerator.upgrade_boss_pawns(boss, 3, 7)
	var pawns_one: int = 0
	var pawns_two: int = 0
	for index: int in range(boss.size()):
		pawns_one += 1 if act_one[index]["piece_def_id"] == "pawn" else 0
		pawns_two += 1 if act_two[index]["piece_def_id"] == "pawn" else 0
		_expect(act_two[index]["position"] == boss[index]["position"], "upgraded Boss pieces keep their squares")
		_expect(EncounterGenerator.meets_rarity_floor(str(act_two[index]["piece_def_id"]), 1), "Act 2 Boss pieces are Rare or better")
		_expect(EncounterGenerator.meets_rarity_floor(str(act_four[index]["piece_def_id"]), 3), "Act 4 Boss pieces are Epic or better")
	_expect(pawns_one == 3 and act_one[3]["piece_def_id"] == "rook", "Act 1 Bosses keep their army")
	_expect(pawns_two == 0 and act_two[3]["piece_def_id"] == "rook", "Act 2 Bosses lose every pawn but keep their Rares")
	_expect(act_four[3]["piece_def_id"] != "rook" and act_four[4]["piece_def_id"] == "king", "Act 4 Bosses swap their Rares too, never the King")

## From Act 2 on the army size is fixed by act, whatever the pieces cost: Act 2 always
## fields 4 (normal) and 5 (elite) pieces besides the King, later acts more.
func _test_enemy_army_size() -> void:
	var sizes_ok: bool = true
	for act: int in range(1, 5):
		for tier: StringName in [&"normal", &"elite"]:
			var size_range: Array = EncounterGenerator.army_size(tier, act)
			for seed_value: int in range(30):
				for local: float in [0.0, 0.9]:
					var army: Array[Dictionary] = EncounterGenerator.generate_at(tier, (float(act) + local) / 3.0, false, seed_value, 8, act)
					var count: int = army.size() - 1
					sizes_ok = sizes_ok and count >= int(size_range[0]) and count <= int(size_range[1])
	_expect(sizes_ok, "from Act 2 on, every generated army has the act's size")
	_expect(EncounterGenerator.army_size(&"normal", 1) == [4, 4] and EncounterGenerator.army_size(&"elite", 1) == [5, 5], "Act 2 fields 4 pieces (normal) and 5 (elite)")
	_expect(EncounterGenerator.army_size(&"normal", 2) == [4, 5] and EncounterGenerator.army_size(&"elite", 4) == [6, 7], "later acts field more")
	_expect(EncounterGenerator.army_size(&"normal", 0).is_empty(), "Act 1 still buys from the strength budget")
	var small_boss: Array[Dictionary] = [
		{"placement_id": "k", "piece_def_id": "king", "position": {"x": 5, "y": 7}},
		{"placement_id": "r", "piece_def_id": "rook", "position": {"x": 5, "y": 6}},
	]
	_expect(EncounterGenerator.fill_boss_army(small_boss, 0, 3).size() == 2, "Act 1 Bosses are never topped up")
	var filled: Array[Dictionary] = EncounterGenerator.fill_boss_army(small_boss, 1, 3)
	var squares: Dictionary = {}
	var fill_ok: bool = filled.size() - 1 == 5
	for placement: Dictionary in filled:
		var square: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
		fill_ok = fill_ok and DeploymentState.is_enemy_zone(square, 8) and not squares.has(square) and EncounterGenerator.meets_rarity_floor(str(placement["piece_def_id"]), 1)
		squares[square] = true
	_expect(fill_ok, "an Act 2 Boss army is topped up to 5 pieces on free enemy squares, above the rarity floor")

## Epic fusion results join enemy armies at Act 3, every fusion result at Act 5, fused
## Kings never.
func _test_enemy_fusions() -> void:
	_expect(EncounterGenerator.fusion_enemies(1).is_empty(), "no fusion results before Act 3")
	_expect("lancer" in EncounterGenerator.fusion_enemies(2) and "swift_courier" not in EncounterGenerator.fusion_enemies(2), "Act 3 adds the Epic fusion results only")
	var late: Array[String] = EncounterGenerator.fusion_enemies(4)
	var all_fused: bool = true
	for id: String in ["lancer", "swift_courier", "blast_catapult", "sky_archer", "flame_phoenix", "thousand_faces", "archmage", "stone_giant"]:
		all_fused = all_fused and id in late
	_expect(all_fused, "Act 5 adds every fusion result")
	_expect("war_king" not in late and "shadow_king" not in late and "shield_king" not in late, "fused Kings never join an enemy army")
	var seen: Dictionary = {}
	for act: int in range(5):
		var stage: float = (float(act) + 0.5) / 3.0
		for seed_value: int in range(150):
			for tier: StringName in [&"normal", &"elite"]:
				for placement: Dictionary in EncounterGenerator.generate_at(tier, stage, false, seed_value, 10, act):
					seen["%d:%s" % [act, placement["piece_def_id"]]] = true
	_expect(not seen.has("1:lancer") and seen.has("2:lancer"), "the Lancer first appears in Act 3")
	var mythic_early: bool = false
	var mythic_late: int = 0
	for id: String in ["swift_courier", "blast_catapult", "sky_archer", "flame_phoenix", "thousand_faces"]:
		for act: int in range(4):
			mythic_early = mythic_early or seen.has("%d:%s" % [act, id])
		mythic_late += 1 if seen.has("4:%s" % id) else 0
	_expect(not mythic_early and mythic_late == 5, "the Mythic fusion results first appear in Act 5 (%d of 5 seen)" % mythic_late)

## Commons stop at Act 2 and Rares at Act 4, in every kind of enemy army, and the King
## still has a piece in front of it.
func _test_enemy_rarity_floor() -> void:
	var floor_ok: Array[bool] = [true, true, true, true, true]
	var guarded: bool = true
	for act: int in range(5):
		var stage: float = (float(act) + 0.5) / 3.0
		for seed_value: int in range(30):
			for tier: StringName in [&"normal", &"elite"]:
				var king_square: Vector2i = Vector2i(-1, -1)
				var squares: Dictionary = {}
				for placement: Dictionary in EncounterGenerator.generate_at(tier, stage, act == 0, seed_value, 8, act):
					var square: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
					squares[square] = true
					if str(placement["piece_def_id"]) == "king":
						king_square = square
					elif not EncounterGenerator.meets_rarity_floor(str(placement["piece_def_id"]), act):
						floor_ok[act] = false
				# (An early Act 1 elite can spend its whole capped budget on the captain.)
				if act >= 1:
					guarded = guarded and squares.has(king_square + Vector2i(0, -1))
		if act >= RunState.ACT_COUNT:
			for boss: EncounterDef in EncounterGenerator.bosses_for_act(act):
				var army: Array[Dictionary] = EncounterGenerator.upgrade_boss_pawns(boss.enemy_placements, act, 5)
				army = EncounterGenerator.reinforce(army, 12, 5, act)
				for placement: Dictionary in army:
					if not EncounterGenerator.meets_rarity_floor(str(placement["piece_def_id"]), act):
						floor_ok[act] = false
	_expect(EncounterGenerator.min_rarity(0) == PieceDef.Rarity.COMMON and EncounterGenerator.min_rarity(1) == PieceDef.Rarity.RARE and EncounterGenerator.min_rarity(2) == PieceDef.Rarity.RARE and EncounterGenerator.min_rarity(3) == PieceDef.Rarity.EPIC and EncounterGenerator.min_rarity(5) == PieceDef.Rarity.EPIC, "the rarity floor rises at Act 2 and Act 4")
	for act: int in range(5):
		_expect(floor_ok[act], "Act %d enemy armies respect the rarity floor" % (act + 1))
	_expect(guarded, "from Act 2 on, the enemy King always has a piece in front of it")

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

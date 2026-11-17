extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_fusion()
	_test_defeat_and_retry()
	_test_motion_profiles()
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

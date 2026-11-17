extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_fusion()
	_test_defeat_and_sacrifice()
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

func _test_defeat_and_sacrifice() -> void:
	var run_state: RunState = _base_run()
	var first: PieceInstanceState = run_state.allocate_piece("pawn", false)
	run_state.allocate_piece("knight", false)
	var rng: RunRngService = RunRngService.new()
	rng.initialize(run_state.run_seed)
	run_state.rng_stream_states = rng.snapshot_states()
	var service: RunContentService = RunContentService.new()
	var deployment: DeploymentService = DeploymentService.new()
	_expect(service.apply_battle_defeat(run_state, rng, deployment) == OK, "first defeat stages sacrifice")
	_expect(run_state.failed_battles == 1 and str(run_state.pending_choice.get("type", "")) == "sacrifice", "defeat count and sacrifice offer are authoritative")
	var options: Array = run_state.pending_choice.get("options", []) as Array
	var chosen: String = str((options[0] as Dictionary).get("id", ""))
	var before_count: int = run_state.player_roster.size()
	var progress: MapProgressService = MapProgressService.new()
	var submit_error: Error = service.submit(run_state, rng, progress, deployment, chosen)
	_expect(submit_error != OK, "sacrifice cannot redeploy without an encounter fixture")
	_expect(run_state.player_roster.size() == before_count - 1, "sacrifice removes exactly one non-king piece on transaction clone")
	var protected_run: RunState = _base_run()
	var protected_piece: PieceInstanceState = protected_run.allocate_piece("pawn", false)
	protected_run.protected_piece_ids.append(protected_piece.instance_id)
	protected_piece.is_protected = true
	var protected_rng: RunRngService = RunRngService.new()
	protected_rng.initialize(protected_run.run_seed)
	protected_run.rng_stream_states = protected_rng.snapshot_states()
	service.apply_battle_defeat(protected_run, protected_rng, deployment)
	_expect(protected_run.pending_choice.is_empty() and protected_run.protected_piece_ids.is_empty(), "protection skips one sacrifice and is consumed")
	var final_run: RunState = _base_run()
	final_run.allocate_piece("bishop", false)
	var final_rng: RunRngService = RunRngService.new()
	final_rng.initialize(final_run.run_seed)
	final_run.rng_stream_states = final_rng.snapshot_states()
	final_run.failed_battles = 2
	final_run.remaining_failure_allowance = 1
	service.apply_battle_defeat(final_run, final_rng, deployment)
	_expect(str(final_run.pending_choice.get("type", "")) == "run_summary" and final_run.failed_battles == 3, "third defeat ends the run without sacrifice")

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

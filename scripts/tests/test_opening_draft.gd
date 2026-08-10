extends SceneTree

var failed: bool = false

func _init() -> void:
	var service_script: Script = load("res://scripts/run/OpeningDraftService.gd") as Script
	var service: RefCounted = service_script.new() as RefCounted
	var pair_a: Dictionary = _new_run_pair(1357911)
	var pair_b: Dictionary = _new_run_pair(1357911)
	var run_a: RunState = pair_a["run"] as RunState
	var run_b: RunState = pair_b["run"] as RunState
	var rng_a: RunRngService = pair_a["rng"] as RunRngService
	var rng_b: RunRngService = pair_b["rng"] as RunRngService
	var before_states: Dictionary = rng_a.snapshot_states()
	_expect(int(service.call("ensure_pending_choice", run_a, rng_a)) == OK, "opening draft creates round one")
	_expect(int(service.call("ensure_pending_choice", run_b, rng_b)) == OK, "same-seed comparison draft creates")
	var candidates_a: Array = run_a.pending_choice.get("candidate_piece_def_ids", []) as Array
	var candidates_b: Array = run_b.pending_choice.get("candidate_piece_def_ids", []) as Array
	_expect(candidates_a == candidates_b, "same seed produces identical opening candidates")
	_expect(candidates_a.size() == 3 and _unique_count(candidates_a) == 3, "offer contains three unique candidates")
	_expect(_contains_rare(candidates_a), "offer guarantees at least one Rare piece")
	_expect(_all_opening_eligible(candidates_a), "offer contains only Common/Rare opening pieces")
	var after_states: Dictionary = rng_a.snapshot_states()
	_expect(before_states["map_rng"] == after_states["map_rng"], "draft does not consume map RNG")
	_expect(before_states["shop_rng"] == after_states["shop_rng"], "draft does not consume shop RNG")

	var persisted_candidates: Array = candidates_a.duplicate()
	var persisted_reward_state: int = int(after_states["reward_rng"])
	_expect(int(service.call("ensure_pending_choice", run_a, rng_a)) == OK, "ensuring an existing offer succeeds")
	_expect((run_a.pending_choice.get("candidate_piece_def_ids", []) as Array) == persisted_candidates, "existing offer never rerolls")
	_expect(int(rng_a.snapshot_states()["reward_rng"]) == persisted_reward_state, "existing offer does not consume RNG")

	var before_invalid: Dictionary = run_a.to_dictionary()
	var invalid_rng: Dictionary = rng_a.snapshot_states()
	_expect(int(service.call("apply_choice", run_a, rng_a, "king")) != OK, "invalid candidate selection is rejected")
	_expect(run_a.to_dictionary() == before_invalid and rng_a.snapshot_states() == invalid_rng, "invalid selection changes no Run or RNG state")

	var round_trip_data: Dictionary = run_a.to_dictionary()
	var restored: RunState = RunState.new()
	_expect(restored.load_from_dictionary(round_trip_data), "pending opening offer survives RunState round-trip")
	_expect(restored.pending_choice == run_a.pending_choice, "round-trip preserves exact candidate order")
	var malformed_data: Dictionary = round_trip_data.duplicate(true)
	var malformed_choice: Dictionary = (malformed_data["pending_choice"] as Dictionary).duplicate(true)
	malformed_choice["candidate_piece_def_ids"] = ["pawn", "pawn", "bishop"]
	malformed_data["pending_choice"] = malformed_choice
	var malformed_state: RunState = RunState.new()
	_expect(not malformed_state.load_from_dictionary(malformed_data), "duplicate or no-Rare persisted offers are rejected")

	for round_index: int in range(3):
		var current_candidates: Array = run_a.pending_choice.get("candidate_piece_def_ids", []) as Array
		_expect(not current_candidates.is_empty(), "round %d has candidates" % (round_index + 1))
		if current_candidates.is_empty():
			break
		_expect(int(service.call("apply_choice", run_a, rng_a, str(current_candidates[0]))) == OK, "round %d selection succeeds" % (round_index + 1))
	_expect(bool(service.call("is_complete", run_a)), "draft completes after three selections")
	_expect(run_a.pending_choice.is_empty(), "completed draft clears pending choice")
	_expect(run_a.player_roster.size() == 4 and run_a.reserve_piece_ids.size() == 3, "draft creates King plus three reserve pieces")
	_expect(run_a.is_valid(), "completed draft leaves a valid RunState")
	_finish()

func _new_run_pair(seed_value: int) -> Dictionary:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(seed_value, RunState.MODE_STANDARD)
	run_state.allocate_piece("king", true)
	var rng: RunRngService = RunRngService.new()
	rng.initialize(seed_value)
	run_state.rng_stream_states = rng.snapshot_states()
	return {"run": run_state, "rng": rng}

func _unique_count(values: Array) -> int:
	var unique: Dictionary = {}
	for value: Variant in values:
		unique[str(value)] = true
	return unique.size()

func _contains_rare(ids: Array) -> bool:
	for id_value: Variant in ids:
		var definition: PieceDef = PieceDefDatabase.get_def(str(id_value))
		if definition != null and definition.rarity >= PieceDef.Rarity.RARE:
			return true
	return false

func _all_opening_eligible(ids: Array) -> bool:
	for id_value: Variant in ids:
		var definition: PieceDef = PieceDefDatabase.get_def(str(id_value))
		if definition == null or not definition.is_valid_opening_draft_piece():
			return false
	return true

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _finish() -> void:
	print("[PASS] Opening draft test" if not failed else "[FAIL] Opening draft test")
	quit(1 if failed else 0)

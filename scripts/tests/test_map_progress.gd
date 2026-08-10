extends SceneTree

var failed: bool = false

func _init() -> void:
	var incomplete_pair: Dictionary = _new_run_pair(9182, false)
	var service: MapProgressService = MapProgressService.new()
	_expect(
		service.ensure_map(incomplete_pair["run"] as RunState, incomplete_pair["rng"] as RunRngService) == ERR_UNAVAILABLE,
		"map generation is unavailable before the opening draft completes"
	)

	var pair: Dictionary = _new_run_pair(9182, true)
	var run_state: RunState = pair["run"] as RunState
	var rng: RunRngService = pair["rng"] as RunRngService
	_expect(service.ensure_map(run_state, rng) == OK, "completed draft can generate its route map")
	var persisted_map: Dictionary = run_state.map_state.to_dictionary()
	var persisted_rng: Dictionary = rng.snapshot_states()
	_expect(service.ensure_map(run_state, rng) == OK, "ensuring an existing route succeeds")
	_expect(run_state.map_state.to_dictionary() == persisted_map, "existing route never regenerates")
	_expect(rng.snapshot_states() == persisted_rng, "existing route consumes no additional RNG")

	var first_choices: Array[StringName] = service.available_node_ids(run_state)
	_expect(first_choices.size() >= 2 and first_choices.size() <= 3, "all first-layer nodes are initially selectable")
	var before_invalid: Dictionary = run_state.to_dictionary()
	_expect(service.select_node(run_state, rng, run_state.map_state.nodes_in_layer(run_state.map_state.total_layers - 1)[0].node_id) != OK, "future Boss cannot be selected early")
	_expect(run_state.to_dictionary() == before_invalid, "invalid route selection has no side effects")

	var first_node_id: StringName = first_choices[0]
	_expect(service.select_node(run_state, rng, first_node_id) == OK, "first route node can be selected")
	_expect(run_state.current_node_id == first_node_id and run_state.visited_node_ids == [first_node_id], "selection locks and records the route node")
	_expect(service.available_node_ids(run_state) == [first_node_id], "unresolved current node is the only resumable choice")
	_expect(service.resolve_current_node(run_state, {"outcome": "prototype_success"}) == OK, "current node resolution is recorded")
	var first_node: MapNodeState = run_state.map_state.get_node(first_node_id)
	var next_choices: Array[StringName] = service.available_node_ids(run_state)
	_expect(next_choices == first_node.outgoing_node_ids, "resolved node unlocks only connected next-layer nodes")
	_expect(service.select_node(run_state, rng, next_choices[0]) == OK, "connected next node can be selected")
	_expect(run_state.visited_node_ids.size() == 2, "route history advances monotonically")
	_expect(run_state.is_valid(), "selected route remains a valid RunState")

	run_state.rng_stream_states = rng.snapshot_states()
	var restored: RunState = RunState.new()
	_expect(restored.load_from_dictionary(run_state.to_dictionary()), "RunState round-trip preserves generated map and route progress")
	_expect(restored.map_state.to_dictionary() == run_state.map_state.to_dictionary(), "RunState restores exact map topology")
	_expect(restored.visited_node_ids == run_state.visited_node_ids, "RunState restores the locked route")
	var malformed_data: Dictionary = run_state.to_dictionary().duplicate(true)
	malformed_data["resolved_node_payloads"] = {}
	var malformed: RunState = RunState.new()
	_expect(not malformed.load_from_dictionary(malformed_data), "RunState rejects a route that skipped unresolved progress")
	_finish()

func _new_run_pair(seed_value: int, complete_draft: bool) -> Dictionary:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(seed_value, RunState.MODE_STANDARD)
	run_state.allocate_piece("king", true)
	var rng: RunRngService = RunRngService.new()
	rng.initialize(seed_value)
	run_state.rng_stream_states = rng.snapshot_states()
	if complete_draft:
		var draft: OpeningDraftService = OpeningDraftService.new()
		draft.ensure_pending_choice(run_state, rng)
		for _round_index: int in range(3):
			var candidates: Array = run_state.pending_choice.get("candidate_piece_def_ids", []) as Array
			draft.apply_choice(run_state, rng, str(candidates[0]))
		run_state.rng_stream_states = rng.snapshot_states()
	return {"run": run_state, "rng": rng}

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _finish() -> void:
	print("[PASS] Map progress test" if not failed else "[FAIL] Map progress test")
	quit(1 if failed else 0)

extends SceneTree

var failed: bool = false

func _init() -> void:
	_test_roster_capacity()
	_test_deployment_state()
	_finish()

func _test_roster_capacity() -> void:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(1111, RunState.MODE_STANDARD)
	var king: PieceInstanceState = run_state.allocate_piece("king", true)
	var first_wave: Array[int] = []
	for piece_id: String in ["pawn", "knight", "bishop", "rook", "queen"]:
		var piece: PieceInstanceState = run_state.allocate_piece(piece_id, false)
		first_wave.append(piece.instance_id)
	var roster: RosterService = RosterService.new()
	for instance_id: int in first_wave:
		_expect(roster.move_to_active(run_state, instance_id) == OK, "non-King piece moves into an active slot")
	_expect(run_state.active_piece_ids.size() == 6, "King plus five non-King pieces can be active")
	for piece_id: String in ["pawn", "knight", "bishop", "rook", "queen"]:
		run_state.allocate_piece(piece_id, false)
	_expect(run_state.reserve_piece_ids.size() == 5, "reserve stores at most five pieces")
	_expect(roster.move_to_active(run_state, run_state.reserve_piece_ids[0]) == ERR_UNAVAILABLE, "sixth non-King active piece is rejected")
	_expect(roster.move_to_reserve(run_state, king.instance_id) == ERR_UNAUTHORIZED, "King can never move to reserve")
	_expect(roster.move_to_reserve(run_state, first_wave[0]) == ERR_UNAVAILABLE, "full reserve rejects another piece")
	_expect(run_state.is_valid(), "full active and reserve capacities remain valid")

func _test_deployment_state() -> void:
	var pair: Dictionary = _completed_run_pair(42424242)
	var run_state: RunState = pair["run"] as RunState
	var rng: RunRngService = pair["rng"] as RunRngService
	var roster: RosterService = RosterService.new()
	for instance_id: int in run_state.reserve_piece_ids.duplicate():
		roster.move_to_active(run_state, instance_id)
	var map_progress: MapProgressService = MapProgressService.new()
	map_progress.ensure_map(run_state, rng)
	var battle_node_id: StringName = _advance_to_battle(run_state, rng, map_progress)
	_expect(not battle_node_id.is_empty(), "test route reaches a battle node")
	var deployment_service: DeploymentService = DeploymentService.new()
	_expect(deployment_service.ensure_deployment(run_state) == OK, "battle node creates a deployment snapshot")
	var deployment: DeploymentState = run_state.deployment_state
	_expect(deployment != null and deployment.is_valid(run_state), "deployment snapshot is valid")
	_expect(deployment.player_positions.size() == run_state.active_piece_ids.size(), "every active piece receives one deployment position")
	_expect(_all_players_in_two_rows(run_state), "all player pieces deploy within the two player rows")
	_expect(_enemy_king_visible(deployment), "complete enemy setup includes a visible King")
	var king_id: int = run_state.active_piece_ids[0]
	var source: Vector2i = deployment.player_position(king_id)
	var swap_target: Vector2i = Vector2i(0, 0) if source != Vector2i(0, 0) else Vector2i(1, 0)
	var previous_occupant: int = deployment.player_at(swap_target)
	_expect(deployment_service.move_piece(run_state, king_id, swap_target) == OK, "King can move freely within deployment rows")
	_expect(deployment.player_position(king_id) == swap_target, "King deployment move is stored")
	if previous_occupant > 0:
		_expect(deployment.player_position(previous_occupant) == source, "moving onto a friendly piece swaps positions")
	_expect(deployment_service.move_piece(run_state, king_id, Vector2i(0, 2)) == ERR_INVALID_PARAMETER, "deployment rejects squares outside player rows")
	_expect(deployment_service.confirm(run_state) == OK and deployment.confirmed, "valid deployment can be confirmed")
	run_state.rng_stream_states = rng.snapshot_states()
	var restored: RunState = RunState.new()
	_expect(restored.load_from_dictionary(run_state.to_dictionary()), "RunState round-trip preserves pre-battle deployment")
	_expect(restored.deployment_state.to_dictionary() == deployment.to_dictionary(), "deployment positions restore exactly")
	var malformed_data: Dictionary = run_state.to_dictionary().duplicate(true)
	var malformed_deployment: Dictionary = (malformed_data["deployment_state"] as Dictionary).duplicate(true)
	var malformed_positions: Dictionary = (malformed_deployment["player_positions"] as Dictionary).duplicate(true)
	malformed_positions[str(king_id)] = DeploymentState.position_value(Vector2i(0, 2))
	malformed_deployment["player_positions"] = malformed_positions
	malformed_data["deployment_state"] = malformed_deployment
	var malformed: RunState = RunState.new()
	_expect(not malformed.load_from_dictionary(malformed_data), "RunState rejects illegal persisted King deployment")

func _completed_run_pair(seed_value: int) -> Dictionary:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(seed_value, RunState.MODE_STANDARD)
	run_state.allocate_piece("king", true)
	var rng: RunRngService = RunRngService.new()
	rng.initialize(seed_value)
	run_state.rng_stream_states = rng.snapshot_states()
	var draft: OpeningDraftService = OpeningDraftService.new()
	draft.ensure_pending_choice(run_state, rng)
	for _round_index: int in range(3):
		var candidates: Array = run_state.pending_choice.get("candidate_piece_def_ids", []) as Array
		draft.apply_choice(run_state, rng, str(candidates[0]))
	run_state.rng_stream_states = rng.snapshot_states()
	return {"run": run_state, "rng": rng}

func _advance_to_battle(run_state: RunState, rng: RunRngService, progress: MapProgressService) -> StringName:
	for _layer_index: int in range(run_state.map_state.total_layers):
		var available: Array[StringName] = progress.available_node_ids(run_state)
		for node_id: StringName in available:
			var node: MapNodeState = run_state.map_state.get_node(node_id)
			if MapNodeDefDatabase.get_def(node.node_type_id).is_battle:
				progress.select_node(run_state, rng, node_id)
				return node_id
		if available.is_empty():
			break
		progress.select_node(run_state, rng, available[0])
		progress.resolve_current_node(run_state, {"outcome": "test_placeholder"})
	return &""

func _all_players_in_two_rows(run_state: RunState) -> bool:
	for instance_id: int in run_state.active_piece_ids:
		var position: Vector2i = run_state.deployment_state.player_position(instance_id)
		if position.y < 0 or position.y > 1:
			return false
	return true

func _enemy_king_visible(deployment: DeploymentState) -> bool:
	for placement: Dictionary in deployment.enemy_placements:
		if str(placement.get("piece_def_id", "")) == "king":
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _finish() -> void:
	print("[PASS] Roster and deployment test" if not failed else "[FAIL] Roster and deployment test")
	quit(1 if failed else 0)

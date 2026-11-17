extends Node

func test_normal_fusion_uses_exact_planned_instances() -> void:
	var run_state: RunState = _base_run()
	var pawn: PieceInstanceState = run_state.allocate_piece("pawn", false)
	var knight: PieceInstanceState = run_state.allocate_piece("knight", false)
	var extra_pawn: PieceInstanceState = run_state.allocate_piece("pawn", false)
	var service: FusionService = FusionService.new()
	var plan: FusionPlan = service.create_plan(run_state, &"pawn_knight_lancer")
	assert(plan != null)
	assert(plan.ingredient_instance_ids == [pawn.instance_id, knight.instance_id])
	assert(service.confirm(run_state, plan) == OK)
	assert(run_state.get_piece_state(pawn.instance_id) == null)
	assert(run_state.get_piece_state(knight.instance_id) == null)
	assert(run_state.get_piece_state(extra_pawn.instance_id) != null)
	assert(_piece_count(run_state, &"lancer") == 1)
	assert(&"pawn_knight_lancer" in run_state.owned_recipe_history)
	assert(run_state.is_valid())

func test_fusion_capacity_is_preflighted() -> void:
	var blocked: RunState = _base_run()
	var active_pawn: PieceInstanceState = blocked.allocate_piece("pawn", false)
	var active_knight: PieceInstanceState = blocked.allocate_piece("knight", false)
	blocked.move_piece_to_active(active_pawn.instance_id)
	blocked.move_piece_to_active(active_knight.instance_id)
	for _index: int in range(RunState.MAX_RESERVE_PIECES):
		blocked.allocate_piece("bishop", false)
	var service: FusionService = FusionService.new()
	assert(service.create_plan(blocked, &"pawn_knight_lancer") == null)
	var allowed: RunState = _base_run()
	allowed.allocate_piece("pawn", false)
	var allowed_knight: PieceInstanceState = allowed.allocate_piece("knight", false)
	allowed.move_piece_to_active(allowed_knight.instance_id)
	for _index: int in range(RunState.MAX_RESERVE_PIECES - 1):
		allowed.allocate_piece("bishop", false)
	assert(allowed.reserve_piece_ids.size() == RunState.MAX_RESERVE_PIECES)
	assert(service.create_plan(allowed, &"pawn_knight_lancer") != null)

func test_king_fusion_preserves_unique_king_instance_identity() -> void:
	var run_state: RunState = _base_run()
	var original_king: PieceInstanceState = _king(run_state)
	var pawn: PieceInstanceState = run_state.allocate_piece("pawn", false)
	var recipe: FusionRecipeDef = FusionRecipeDef.new()
	recipe.id = &"test_king_ascension"
	recipe.ingredient_piece_def_ids = [&"king", &"pawn"]
	recipe.result_piece_def_id = &"king"
	var deployment_service: DeploymentService = _prepare_battle_deployment(run_state)
	assert(run_state.deployment_state != null)
	assert(deployment_service.move_piece(run_state, original_king.instance_id, Vector2i(4, 0)) == OK)
	var service: FusionService = FusionService.new()
	var plan: FusionPlan = service.create_plan_for_recipe(run_state, recipe)
	assert(plan != null and plan.result_is_king)
	assert(plan.preserved_king_instance_id == original_king.instance_id)
	assert(service.confirm(run_state, plan, deployment_service, recipe) == OK)
	var resulting_king: PieceInstanceState = _king(run_state)
	assert(resulting_king != null and resulting_king.instance_id == original_king.instance_id)
	assert(resulting_king.instance_id in run_state.active_piece_ids)
	assert(run_state.deployment_state.player_position(resulting_king.instance_id) == Vector2i(4, 0))
	assert(not run_state.deployment_state.confirmed)
	assert(run_state.get_piece_state(pawn.instance_id) == null)
	assert(run_state.is_valid())

func test_fusion_products_can_be_used_in_higher_tier_recipes() -> void:
	var run_state: RunState = _base_run()
	run_state.allocate_piece("pawn", false)
	run_state.allocate_piece("knight", false)
	var service: FusionService = FusionService.new()
	var first_plan: FusionPlan = service.create_plan(run_state, &"pawn_knight_lancer")
	assert(service.confirm(run_state, first_plan) == OK)
	run_state.allocate_piece("rook", false)
	var higher_recipe: FusionRecipeDef = FusionRecipeDef.new()
	higher_recipe.id = &"test_lancer_rook_archmage"
	higher_recipe.ingredient_piece_def_ids = [&"lancer", &"rook"]
	higher_recipe.result_piece_def_id = &"archmage"
	var higher_plan: FusionPlan = service.create_plan_for_recipe(run_state, higher_recipe)
	assert(higher_plan != null)
	assert(service.confirm(run_state, higher_plan, null, higher_recipe) == OK)
	assert(_piece_count(run_state, &"lancer") == 0)
	assert(_piece_count(run_state, &"archmage") == 1)
	assert(run_state.is_valid())

func test_tampered_plan_is_rejected_without_mutation() -> void:
	var run_state: RunState = _base_run()
	run_state.allocate_piece("pawn", false)
	run_state.allocate_piece("knight", false)
	var service: FusionService = FusionService.new()
	var plan: FusionPlan = service.create_plan(run_state, &"pawn_knight_lancer")
	var before: Dictionary = run_state.to_dictionary()
	plan.ingredient_instance_ids[0] = 999999
	assert(service.confirm(run_state, plan) != OK)
	assert(run_state.to_dictionary() == before)

func _prepare_battle_deployment(run_state: RunState) -> DeploymentService:
	run_state.run_statistics["opening_draft_complete"] = true
	run_state.phase = RunPhase.MAP
	var rng: RunRngService = RunRngService.new()
	rng.initialize(run_state.run_seed)
	var progress: MapProgressService = MapProgressService.new()
	assert(progress.ensure_map(run_state, rng) == OK)
	for _layer_index: int in range(run_state.map_state.total_layers):
		var available: Array[StringName] = progress.available_node_ids(run_state)
		assert(not available.is_empty())
		var selected_id: StringName = available[0]
		for node_id: StringName in available:
			var candidate: MapNodeState = run_state.map_state.get_node(node_id)
			if MapNodeDefDatabase.get_def(candidate.node_type_id).is_battle:
				selected_id = node_id
				break
		assert(progress.select_node(run_state, rng, selected_id) == OK)
		run_state.phase = RunPhase.NODE_SELECTED
		var selected: MapNodeState = run_state.map_state.get_node(selected_id)
		if MapNodeDefDatabase.get_def(selected.node_type_id).is_battle:
			var deployment_service: DeploymentService = DeploymentService.new()
			assert(deployment_service.ensure_deployment(run_state) == OK)
			run_state.phase = RunPhase.DEPLOYMENT
			return deployment_service
		assert(progress.resolve_current_node(run_state, {"outcome": "test_setup"}) == OK)
		run_state.phase = RunPhase.MAP
	assert(false, "test map does not expose a battle")
	return DeploymentService.new()

func _base_run() -> RunState:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(778899)
	run_state.allocate_piece("king", true)
	return run_state

func _king(run_state: RunState) -> PieceInstanceState:
	for piece: PieceInstanceState in run_state.player_roster:
		if piece.is_king:
			return piece
	return null

func _piece_count(run_state: RunState, id: StringName) -> int:
	var count: int = 0
	for piece: PieceInstanceState in run_state.player_roster:
		if piece.piece_def_id == id:
			count += 1
	return count

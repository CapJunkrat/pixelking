extends Node

class FakeMapProgressService:
	extends MapProgressService
	var resolved: bool = false

	func resolve_current_node(run_state: RunState, payload: Dictionary) -> Error:
		resolved = true
		return super.resolve_current_node(run_state, payload)

func test_reward_fusion_preview_cancel_and_confirm() -> void:
	var run_state: RunState = _fusion_ready_run("battle_reward")
	var service: RunContentService = RunContentService.new(FusionService.new())
	var original: Dictionary = _fusion_offer("battle_reward", 0)
	run_state.pending_choice = original.duplicate(true)
	var before_roster: Dictionary = run_state.to_dictionary()
	assert(service.submit(run_state, _rng(), FakeMapProgressService.new(), DeploymentService.new(), "recipe_offer") == OK)
	run_state.phase = RunPhase.FUSION_CONFIRMATION
	assert(str(run_state.pending_choice.get("type", "")) == "fusion_confirmation")
	var preview_text: String = str(run_state.pending_choice.get("description", ""))
	assert("Pawn" in preview_text and "Knight" in preview_text)
	assert("Creates: Lancer" in preview_text and "MOVE" in preview_text and "Battle line" in preview_text)
	assert(_piece_count(run_state, &"pawn") == 1 and _piece_count(run_state, &"knight") == 1)
	assert(run_state.is_valid())
	var restored: RunState = RunState.new()
	assert(restored.load_from_dictionary(run_state.to_dictionary()))
	assert(restored.pending_choice == run_state.pending_choice)
	assert(service.submit(run_state, _rng(), FakeMapProgressService.new(), DeploymentService.new(), "cancel_fusion") == OK)
	run_state.phase = RunPhase.POST_BATTLE_CHOICE
	assert(run_state.pending_choice == original)
	assert(run_state.player_roster.size() == (before_roster.get("player_roster", []) as Array).size())
	assert(service.submit(run_state, _rng(), FakeMapProgressService.new(), DeploymentService.new(), "recipe_offer") == OK)
	run_state.phase = RunPhase.FUSION_CONFIRMATION
	assert(service.submit(run_state, _rng(), FakeMapProgressService.new(), DeploymentService.new(), "confirm_fusion") == OK)
	run_state.phase = RunPhase.MAP
	assert(run_state.pending_choice.is_empty())
	assert(_piece_count(run_state, &"lancer") == 1)
	assert(_piece_count(run_state, &"pawn") == 0 and _piece_count(run_state, &"knight") == 0)
	assert(run_state.is_valid())

func test_shop_fusion_deducts_only_after_confirmation() -> void:
	var run_state: RunState = _fusion_ready_run("shop")
	run_state.gold = 100
	var service: RunContentService = RunContentService.new(FusionService.new())
	var original: Dictionary = _fusion_offer("shop", 40)
	run_state.pending_choice = original.duplicate(true)
	var progress: FakeMapProgressService = FakeMapProgressService.new()
	assert(service.submit(run_state, _rng(), progress, DeploymentService.new(), "recipe_offer") == OK)
	run_state.phase = RunPhase.FUSION_CONFIRMATION
	assert(run_state.gold == 100)
	assert(not progress.resolved)
	assert(service.submit(run_state, _rng(), progress, DeploymentService.new(), "cancel_fusion") == OK)
	run_state.phase = RunPhase.NODE_INTERACTION
	assert(run_state.gold == 100 and run_state.pending_choice == original)
	assert(service.submit(run_state, _rng(), progress, DeploymentService.new(), "recipe_offer") == OK)
	run_state.phase = RunPhase.FUSION_CONFIRMATION
	assert(service.submit(run_state, _rng(), progress, DeploymentService.new(), "confirm_fusion") == OK)
	run_state.phase = RunPhase.MAP
	assert(run_state.gold == 60)
	assert(progress.resolved)
	assert(run_state.pending_choice.is_empty())
	assert(_piece_count(run_state, &"lancer") == 1)

func test_fusion_preview_survives_active_run_save_and_load() -> void:
	var save_path: String = "user://test_fusion_preview.save"
	var save_service: ActiveRunSaveService = ActiveRunSaveService.new(save_path)
	save_service.delete()
	var run_state: RunState = _fusion_ready_run("battle_reward")
	var service: RunContentService = RunContentService.new(FusionService.new())
	run_state.pending_choice = _fusion_offer("battle_reward", 0)
	assert(service.submit(run_state, _rng(), FakeMapProgressService.new(), DeploymentService.new(), "recipe_offer") == OK)
	run_state.phase = RunPhase.FUSION_CONFIRMATION
	assert(save_service.save(run_state) == OK)
	var restored: RunState = save_service.load_run()
	assert(restored != null)
	assert(restored.pending_choice == run_state.pending_choice)
	assert(save_service.delete() == OK)

func test_shop_confirmation_rechecks_gold_without_consuming_materials() -> void:
	var run_state: RunState = _fusion_ready_run("shop")
	run_state.gold = 40
	var service: RunContentService = RunContentService.new(FusionService.new())
	run_state.pending_choice = _fusion_offer("shop", 40)
	assert(service.submit(run_state, _rng(), FakeMapProgressService.new(), DeploymentService.new(), "recipe_offer") == OK)
	run_state.phase = RunPhase.FUSION_CONFIRMATION
	run_state.gold = 0
	var before: Dictionary = run_state.to_dictionary()
	assert(service.submit(run_state, _rng(), FakeMapProgressService.new(), DeploymentService.new(), "confirm_fusion") == ERR_UNAVAILABLE)
	assert(run_state.to_dictionary() == before)

func _fusion_ready_run(source_type: String) -> RunState:
	var run_state: RunState = RunState.new()
	run_state.initialize_new(123456)
	run_state.allocate_piece("king", true)
	run_state.allocate_piece("pawn", false)
	run_state.allocate_piece("knight", false)
	run_state.run_statistics["opening_draft_complete"] = true
	run_state.phase = RunPhase.MAP
	var rng: RunRngService = _rng()
	var progress: MapProgressService = MapProgressService.new()
	assert(progress.ensure_map(run_state, rng) == OK)
	for _layer_index: int in range(run_state.map_state.total_layers):
		var available: Array[StringName] = progress.available_node_ids(run_state)
		assert(not available.is_empty())
		var selected_id: StringName = available[0]
		if source_type == "shop":
			for node_id: StringName in available:
				if _leads_to_shop(run_state.map_state, node_id):
					selected_id = node_id
					break
		assert(progress.select_node(run_state, rng, selected_id) == OK)
		run_state.phase = RunPhase.NODE_SELECTED
		var selected: MapNodeState = run_state.map_state.get_node(selected_id)
		if source_type == "shop" and selected.node_type_id == &"shop":
			run_state.phase = RunPhase.NODE_INTERACTION
			return run_state
		assert(progress.resolve_current_node(run_state, {"outcome": "test_setup"}) == OK)
		run_state.phase = RunPhase.MAP
		if source_type == "battle_reward":
			run_state.phase = RunPhase.POST_BATTLE_CHOICE
			return run_state
	assert(false, "test map does not expose the requested fusion source")
	return run_state

func _fusion_offer(type: String, price: int) -> Dictionary:
	return {
		"choice_version": 1,
		"type": type,
		"title": "Original Offers",
		"description": "Saved candidates",
		"allow_leave": type == "shop",
		"options": [{
			"id": "recipe_offer",
			"label": "Lancer Blueprint",
			"enabled": true,
			"payload": {"kind": "fusion", "recipe_id": "pawn_knight_lancer", "price": price},
		}],
	}

func _rng() -> RunRngService:
	var rng: RunRngService = RunRngService.new()
	rng.initialize(123456)
	return rng

func _piece_count(run_state: RunState, id: StringName) -> int:
	var count: int = 0
	for piece: PieceInstanceState in run_state.player_roster:
		if piece.piece_def_id == id:
			count += 1
	return count

## Whether the shop can still be reached through `node_id` (the node itself or later).
func _leads_to_shop(map_state: MapState, node_id: StringName) -> bool:
	var node: MapNodeState = map_state.get_node(node_id)
	if node == null:
		return false
	if node.node_type_id == &"shop":
		return true
	for next_id: StringName in node.outgoing_node_ids:
		if _leads_to_shop(map_state, next_id):
			return true
	return false

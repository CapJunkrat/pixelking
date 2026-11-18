class_name DeploymentService
extends RefCounted

func ensure_deployment(run_state: RunState) -> Error:
	if not _can_deploy(run_state):
		return ERR_UNAVAILABLE
	if run_state.deployment_state != null:
		if run_state.deployment_state.board_size == BoardState.DEFAULT_SIZE:
			return OK if run_state.deployment_state.is_valid(run_state) else ERR_INVALID_DATA
		# Development saves from the former 5x5 prototype are safely rebuilt.
		run_state.deployment_state = null
	var current: MapNodeState = run_state.map_state.get_node(run_state.current_node_id)
	var encounter: EncounterDef = EncounterDefDatabase.for_node(run_state, current)
	if encounter == null:
		return ERR_DOES_NOT_EXIST
	var deployment: DeploymentState = DeploymentState.new()
	deployment.encounter_id = run_state.current_encounter_id
	deployment.board_size = encounter.board_size
	deployment.enemy_placements = encounter.placement_copies()
	if encounter.procedural and run_state.map_state != null:
		deployment.enemy_placements = EncounterGenerator.generate_at(
			encounter.reward_tier,
			run_state.run_stage(),
			run_state.act_index == 0 and current.layer_index < EncounterGenerator.EARLY_LAYERS,
			run_state.current_encounter_seed,
			EncounterGenerator.player_strength(run_state))
	elif encounter.is_boss and run_state.act_index >= RunState.ACT_COUNT:
		# Endless: each act past the third brings the Boss more reinforcements.
		deployment.enemy_placements = EncounterGenerator.reinforce(
			deployment.enemy_placements,
			(run_state.act_index - RunState.ACT_COUNT + 1) * 6,
			run_state.current_encounter_seed)
	if current != null and run_state.map_state != null:
		deployment.rocks = RockLayout.generate(run_state.current_encounter_seed, current.layer_index, run_state.map_state.total_layers, deployment.board_size)
	run_state.deployment_state = deployment
	var sync_error: Error = synchronize_with_roster(run_state)
	if sync_error != OK:
		run_state.deployment_state = null
		return sync_error
	return OK

## Lays out the active pieces with the automatic formation (DeploymentFormation).
func synchronize_with_roster(run_state: RunState) -> Error:
	if run_state == null or run_state.deployment_state == null:
		return ERR_DOES_NOT_EXIST
	var deployment: DeploymentState = run_state.deployment_state
	deployment.player_positions = {}
	var formation: Dictionary = DeploymentFormation.arrange(run_state, deployment.board_size, _chosen_squares(run_state, deployment.board_size))
	for instance_id: int in run_state.active_piece_ids:
		var position: Vector2i = formation.get(instance_id, Vector2i(-1, -1))
		if position == Vector2i(-1, -1):
			return ERR_OUT_OF_MEMORY
		deployment.set_player_position(instance_id, position)
	deployment.confirmed = false
	return OK if deployment.is_valid(run_state) else ERR_INVALID_DATA

func move_piece(run_state: RunState, instance_id: int, target: Vector2i) -> Error:
	if run_state == null or run_state.deployment_state == null or instance_id not in run_state.active_piece_ids:
		return ERR_INVALID_PARAMETER
	var deployment: DeploymentState = run_state.deployment_state
	if not DeploymentState.is_player_zone(target, deployment.board_size):
		return ERR_INVALID_PARAMETER
	var source: Vector2i = deployment.player_position(instance_id)
	if source == Vector2i(-1, -1):
		return ERR_INVALID_DATA
	var occupant_id: int = deployment.player_at(target)
	deployment.set_player_position(instance_id, target)
	run_state.preferred_positions[str(instance_id)] = DeploymentState.position_value(target)
	if occupant_id > 0 and occupant_id != instance_id:
		deployment.set_player_position(occupant_id, source)
		run_state.preferred_positions[str(occupant_id)] = DeploymentState.position_value(source)
	deployment.confirmed = false
	return OK if deployment.is_valid(run_state) else ERR_INVALID_DATA

## Forgets every hand-placed square and lays the army out automatically again.
func reset_formation(run_state: RunState) -> Error:
	if run_state == null:
		return ERR_DOES_NOT_EXIST
	run_state.preferred_positions = {}
	return synchronize_with_roster(run_state) if run_state.deployment_state != null else OK

## The player's remembered squares that still fit: active pieces, own corner, no clashes.
func _chosen_squares(run_state: RunState, board_size: int) -> Dictionary:
	var result: Dictionary = {}
	var taken: Dictionary = {}
	for instance_id: int in run_state.active_piece_ids:
		var value: Variant = run_state.preferred_positions.get(str(instance_id), null)
		if value == null:
			continue
		var square: Vector2i = DeploymentState.position_from_value(value)
		if not DeploymentState.is_player_zone(square, board_size) or taken.has(square):
			continue
		taken[square] = true
		result[instance_id] = square
	return result

func confirm(run_state: RunState) -> Error:
	if run_state == null or run_state.deployment_state == null or not run_state.deployment_state.is_valid(run_state):
		return ERR_INVALID_DATA
	run_state.deployment_state.confirmed = true
	return OK

func clear(run_state: RunState) -> void:
	if run_state != null:
		run_state.deployment_state = null

func _can_deploy(run_state: RunState) -> bool:
	if run_state == null or run_state.map_state == null or run_state.current_node_id.is_empty():
		return false
	if run_state.resolved_node_payloads.has(String(run_state.current_node_id)):
		return false
	var current: MapNodeState = run_state.map_state.get_node(run_state.current_node_id)
	var node_definition: MapNodeDef = MapNodeDefDatabase.get_def(current.node_type_id) if current != null else null
	return (
		node_definition != null
		and node_definition.is_battle
		and EncounterDefDatabase.has_def(node_definition.encounter_def_id)
		and not run_state.current_encounter_id.is_empty()
	)


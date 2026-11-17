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
	var node_definition: MapNodeDef = MapNodeDefDatabase.get_def(current.node_type_id) if current != null else null
	var encounter: EncounterDef = EncounterDefDatabase.get_def(node_definition.encounter_def_id) if node_definition != null else null
	if encounter == null:
		return ERR_DOES_NOT_EXIST
	var deployment: DeploymentState = DeploymentState.new()
	deployment.encounter_id = run_state.current_encounter_id
	deployment.board_size = encounter.board_size
	deployment.enemy_placements = encounter.placement_copies()
	run_state.deployment_state = deployment
	var sync_error: Error = synchronize_with_roster(run_state)
	if sync_error != OK:
		run_state.deployment_state = null
		return sync_error
	return OK

func synchronize_with_roster(run_state: RunState) -> Error:
	if run_state == null or run_state.deployment_state == null:
		return ERR_DOES_NOT_EXIST
	var deployment: DeploymentState = run_state.deployment_state
	var synchronized: Dictionary = {}
	var occupied: Dictionary = {}
	for instance_id: int in run_state.active_piece_ids:
		var old_position: Vector2i = deployment.player_position(instance_id)
		if old_position != Vector2i(-1, -1) and old_position.y <= 1 and not occupied.has(old_position):
			synchronized[str(instance_id)] = DeploymentState.position_value(old_position)
			occupied[old_position] = true
	deployment.player_positions = synchronized
	for instance_id: int in run_state.active_piece_ids:
		if deployment.player_positions.has(str(instance_id)):
			continue
		var piece: PieceInstanceState = run_state.get_piece_state(instance_id)
		var preferred: Vector2i = Vector2i(floori(float(deployment.board_size) / 2.0), 0) if piece != null and piece.is_king else Vector2i(-1, -1)
		var position: Vector2i = preferred if preferred != Vector2i(-1, -1) and not occupied.has(preferred) else _first_open_player_square(deployment.board_size, occupied)
		if position == Vector2i(-1, -1):
			return ERR_OUT_OF_MEMORY
		deployment.set_player_position(instance_id, position)
		occupied[position] = true
	deployment.confirmed = false
	return OK if deployment.is_valid(run_state) else ERR_INVALID_DATA

func move_piece(run_state: RunState, instance_id: int, target: Vector2i) -> Error:
	if run_state == null or run_state.deployment_state == null or instance_id not in run_state.active_piece_ids:
		return ERR_INVALID_PARAMETER
	var deployment: DeploymentState = run_state.deployment_state
	if target.x < 0 or target.x >= deployment.board_size or target.y < 0 or target.y > 1:
		return ERR_INVALID_PARAMETER
	var source: Vector2i = deployment.player_position(instance_id)
	if source == Vector2i(-1, -1):
		return ERR_INVALID_DATA
	var occupant_id: int = deployment.player_at(target)
	deployment.set_player_position(instance_id, target)
	if occupant_id > 0 and occupant_id != instance_id:
		deployment.set_player_position(occupant_id, source)
	deployment.confirmed = false
	return OK if deployment.is_valid(run_state) else ERR_INVALID_DATA

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

func _first_open_player_square(board_size: int, occupied: Dictionary) -> Vector2i:
	for y_position: int in range(2):
		for x_position: int in range(board_size):
			var position: Vector2i = Vector2i(x_position, y_position)
			if not occupied.has(position):
				return position
	return Vector2i(-1, -1)

class_name RunTestFixture
extends RefCounted

static func create_drafted_run(manager: AppRunManager, seed_value: int = 42424242) -> Error:
	if manager == null or not manager.create_run(seed_value, RunState.MODE_STANDARD, true):
		return ERR_CANT_CREATE
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		if candidates.is_empty():
			return ERR_INVALID_DATA
		var error: Error = manager.submit_opening_draft_choice(str(candidates[0]))
		if error != OK:
			return error
	return manager.ensure_run_map()

static func first_battle_node_id(manager: AppRunManager) -> StringName:
	if manager == null or manager.current_run == null:
		return &""
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		var definition: MapNodeDef = Content.map_node(node.node_type_id) if node != null else null
		if definition != null and definition.is_battle:
			return node_id
	return &""

static func select_first_battle(manager: AppRunManager) -> Error:
	var node_id: StringName = first_battle_node_id(manager)
	return ERR_DOES_NOT_EXIST if node_id.is_empty() else manager.select_map_node(node_id)

static func prepare_confirmed_battle(manager: AppRunManager, activate_reserves: bool = false) -> Error:
	if manager == null or manager.current_run == null:
		return ERR_DOES_NOT_EXIST
	if activate_reserves:
		for instance_id: int in manager.current_run.reserve_piece_ids.duplicate():
			var roster_error: Error = manager.move_roster_piece(instance_id, true)
			if roster_error != OK:
				return roster_error
	var error: Error = select_first_battle(manager)
	if error != OK:
		return error
	error = manager.begin_deployment()
	if error != OK:
		return error
	return manager.confirm_deployment()

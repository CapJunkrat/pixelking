class_name MapProgressService
extends RefCounted

const ENCOUNTER_RNG_STREAM: StringName = &"encounter_rng"

var map_generator: MapGenerator = MapGenerator.new()

func ensure_map(run_state: RunState, rng: RunRngService) -> Error:
	if run_state == null or rng == null or not run_state.is_valid():
		return ERR_INVALID_DATA
	if not bool(run_state.run_statistics.get("opening_draft_complete", false)):
		return ERR_UNAVAILABLE
	if run_state.map_state != null:
		return OK if run_state.map_state.is_valid() else ERR_INVALID_DATA
	var generated: MapState = map_generator.generate(Content.standard_map_template(), rng, run_state.act_index)
	if generated == null:
		return ERR_CANT_CREATE
	run_state.map_state = generated
	run_state.current_map_id = generated.map_id
	return OK

func available_node_ids(run_state: RunState) -> Array[StringName]:
	var result: Array[StringName] = []
	if run_state == null or run_state.map_state == null or not run_state.map_state.is_valid():
		return result
	if run_state.visited_node_ids.is_empty():
		for node: MapNodeState in run_state.map_state.nodes_in_layer(0):
			result.append(node.node_id)
		return result
	if not is_current_node_resolved(run_state):
		result.append(run_state.current_node_id)
		return result
	var current: MapNodeState = run_state.map_state.get_node(run_state.current_node_id)
	if current != null:
		result.append_array(current.outgoing_node_ids)
	return result

## Whether the run stands on the beaten Boss of its act, ready for the next act.
func is_act_cleared(run_state: RunState) -> bool:
	if run_state == null or run_state.map_state == null or not is_current_node_resolved(run_state):
		return false
	var node: MapNodeState = run_state.map_state.get_node(run_state.current_node_id)
	return node != null and node.node_type_id == &"boss"

## Starts the next act: a fresh map; the army, items and gold carry over.
func advance_act(run_state: RunState, rng: RunRngService) -> Error:
	if not is_act_cleared(run_state):
		return ERR_UNAVAILABLE
	run_state.act_index += 1
	run_state.map_state = null
	run_state.current_map_id = &""
	run_state.current_node_id = &""
	run_state.visited_node_ids.clear()
	run_state.resolved_node_payloads.clear()
	run_state.current_encounter_id = &""
	run_state.current_encounter_seed = 0
	return ensure_map(run_state, rng)

func select_node(run_state: RunState, rng: RunRngService, node_id: StringName) -> Error:
	if run_state == null or rng == null or run_state.map_state == null or not run_state.is_valid():
		return ERR_INVALID_DATA
	var available: Array[StringName] = available_node_ids(run_state)
	if node_id not in available:
		return ERR_INVALID_PARAMETER
	if node_id == run_state.current_node_id:
		return OK
	var selected: MapNodeState = run_state.map_state.get_node(node_id)
	if selected == null:
		return ERR_DOES_NOT_EXIST
	run_state.current_node_id = node_id
	run_state.visited_node_ids.append(node_id)
	var node_definition: MapNodeDef = Content.map_node(selected.node_type_id)
	if node_definition != null and node_definition.is_battle:
		run_state.current_encounter_id = StringName("encounter.%s.layer_%d" % [selected.node_type_id, selected.layer_index])
		run_state.current_encounter_seed = rng.randi(ENCOUNTER_RNG_STREAM)
	else:
		run_state.current_encounter_id = &""
		run_state.current_encounter_seed = 0
	return OK

func resolve_current_node(run_state: RunState, payload: Dictionary) -> Error:
	if run_state == null or run_state.map_state == null or run_state.current_node_id.is_empty():
		return ERR_INVALID_DATA
	if run_state.current_node_id not in run_state.visited_node_ids:
		return ERR_INVALID_DATA
	var key: String = String(run_state.current_node_id)
	if run_state.resolved_node_payloads.has(key):
		return ERR_ALREADY_EXISTS
	var stored_payload: Dictionary = payload.duplicate(true)
	stored_payload["node_id"] = key
	stored_payload["node_type_id"] = String(run_state.map_state.get_node(run_state.current_node_id).node_type_id)
	run_state.resolved_node_payloads[key] = stored_payload
	return OK

func is_current_node_resolved(run_state: RunState) -> bool:
	return (
		run_state != null
		and not run_state.current_node_id.is_empty()
		and run_state.resolved_node_payloads.has(String(run_state.current_node_id))
	)

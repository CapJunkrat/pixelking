extends SceneTree

var failed: bool = false

func _init() -> void:
	var template: MapTemplateDef = MapTemplateDatabase.standard()
	_expect(template != null and template.is_valid(), "standard map template is data-driven and valid")
	_expect(_all_node_definitions_public(), "every map node definition exposes full public information")

	var pair_a: Dictionary = _generate(246813579)
	var pair_b: Dictionary = _generate(246813579)
	var map_a: MapState = pair_a["map"] as MapState
	var map_b: MapState = pair_b["map"] as MapState
	_expect(map_a != null and map_b != null, "standard maps generate")
	if map_a == null or map_b == null:
		_finish()
		return
	_expect(map_a.to_dictionary() == map_b.to_dictionary(), "same seed generates the identical route map")
	_expect(map_a.is_valid(), "generated route map validates")
	_expect(map_a.total_layers >= 6 and map_a.total_layers <= 8, "route map contains 6 to 8 layers")
	_expect(_normal_layer_widths_are_valid(map_a), "every non-Boss layer contains 2 to 3 nodes")
	_expect(map_a.node_type_count(&"elite_battle") >= 1, "route guarantees an elite battle")
	_expect(map_a.node_type_count(&"shop") >= 1, "route guarantees a shop")
	_expect(map_a.node_type_count(&"rest") >= 1, "route guarantees a rest node")
	_expect(_has_single_final_boss(map_a), "final layer contains exactly one Boss")
	_expect(_all_nodes_connect_forward(map_a), "all route connections advance exactly one layer")
	_expect(_all_nodes_reachable(map_a), "every generated node is reachable from the first layer")

	var states_before: Dictionary = pair_a["states_before"] as Dictionary
	var states_after: Dictionary = pair_a["states_after"] as Dictionary
	_expect(states_before["reward_rng"] == states_after["reward_rng"], "map generation does not consume reward RNG")
	_expect(states_before["encounter_rng"] == states_after["encounter_rng"], "map generation does not consume encounter RNG")
	_expect(states_before["map_rng"] != states_after["map_rng"], "map generation consumes only map RNG")

	var restored: MapState = MapState.new()
	_expect(restored.load_from_dictionary(map_a.to_dictionary()), "generated map survives a dictionary round-trip")
	_expect(restored.to_dictionary() == map_a.to_dictionary(), "map round-trip preserves nodes and connections exactly")
	var malformed_data: Dictionary = map_a.to_dictionary().duplicate(true)
	var malformed_nodes: Array = malformed_data["nodes"] as Array
	var malformed_node: Dictionary = (malformed_nodes[0] as Dictionary).duplicate(true)
	malformed_node["outgoing_node_ids"] = [String((map_a.nodes_in_layer(map_a.total_layers - 1)[0]).node_id)]
	malformed_nodes[0] = malformed_node
	var malformed: MapState = MapState.new()
	_expect(not malformed.load_from_dictionary(malformed_data), "map validation rejects connections that skip layers")

	var varied: bool = false
	for seed_value: int in range(100, 116):
		var generated_pair: Dictionary = _generate(seed_value)
		var generated: MapState = generated_pair["map"] as MapState
		_expect(generated != null and generated.is_valid(), "seed %d generates a valid guaranteed route" % seed_value)
		if generated != null and generated.to_dictionary() != map_a.to_dictionary():
			varied = true
	_expect(varied, "different seeds can generate different maps")
	_finish()

func _generate(seed_value: int) -> Dictionary:
	var rng: RunRngService = RunRngService.new()
	rng.initialize(seed_value)
	var states_before: Dictionary = rng.snapshot_states()
	var generator: MapGenerator = MapGenerator.new()
	var map_state: MapState = generator.generate(MapTemplateDatabase.standard(), rng)
	return {
		"map": map_state,
		"states_before": states_before,
		"states_after": rng.snapshot_states(),
	}

func _all_node_definitions_public() -> bool:
	for definition: MapNodeDef in MapNodeDefDatabase.all_defs():
		if definition == null or not definition.is_valid():
			return false
	return MapNodeDefDatabase.all_defs().size() == 6

func _normal_layer_widths_are_valid(map_state: MapState) -> bool:
	for layer_index: int in range(map_state.total_layers - 1):
		var count: int = map_state.nodes_in_layer(layer_index).size()
		if count < 2 or count > 3:
			return false
	return true

func _has_single_final_boss(map_state: MapState) -> bool:
	var final_nodes: Array[MapNodeState] = map_state.nodes_in_layer(map_state.total_layers - 1)
	return final_nodes.size() == 1 and final_nodes[0].node_type_id == &"boss"

func _all_nodes_connect_forward(map_state: MapState) -> bool:
	for node: MapNodeState in map_state.nodes:
		for target_id: StringName in node.outgoing_node_ids:
			var target: MapNodeState = map_state.get_node(target_id)
			if target == null or target.layer_index != node.layer_index + 1:
				return false
	return true

func _all_nodes_reachable(map_state: MapState) -> bool:
	var reached: Dictionary = {}
	var frontier: Array[StringName] = []
	for start_node: MapNodeState in map_state.nodes_in_layer(0):
		frontier.append(start_node.node_id)
	while not frontier.is_empty():
		var node_id: StringName = frontier.pop_front()
		if reached.has(node_id):
			continue
		reached[node_id] = true
		var node: MapNodeState = map_state.get_node(node_id)
		if node != null:
			frontier.append_array(node.outgoing_node_ids)
	return reached.size() == map_state.nodes.size()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _finish() -> void:
	print("[PASS] Map generation test" if not failed else "[FAIL] Map generation test")
	quit(1 if failed else 0)

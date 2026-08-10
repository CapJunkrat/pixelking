class_name MapGenerator
extends RefCounted

const RNG_STREAM: StringName = &"map_rng"

func generate(template: MapTemplateDef, rng: RunRngService) -> MapState:
	if template == null or rng == null or not template.is_valid() or not rng.has_stream(RNG_STREAM):
		return null
	var generated: MapState = MapState.new()
	generated.map_id = StringName("map.%s" % String(template.id))
	generated.template_id = template.id
	generated.total_layers = rng.randi_range(RNG_STREAM, template.min_layers, template.max_layers)
	_create_skeleton(generated, template, rng)
	_assign_node_types(generated, template, rng)
	_connect_layers(generated)
	return generated if generated.is_valid() else null

func _create_skeleton(map_state: MapState, template: MapTemplateDef, rng: RunRngService) -> void:
	for layer_index: int in range(map_state.total_layers):
		var node_count: int = 1 if layer_index == map_state.total_layers - 1 else rng.randi_range(
			RNG_STREAM,
			template.min_nodes_per_layer,
			template.max_nodes_per_layer
		)
		for lane_index: int in range(node_count):
			var node_id: StringName = StringName("%s.layer_%02d.node_%d" % [map_state.map_id, layer_index, lane_index])
			map_state.nodes.append(MapNodeState.new(node_id, layer_index, lane_index))

func _assign_node_types(map_state: MapState, template: MapTemplateDef, rng: RunRngService) -> void:
	var boss: MapNodeState = map_state.nodes_in_layer(map_state.total_layers - 1)[0]
	boss.node_type_id = template.boss_node_type_id
	var unassigned: Array[MapNodeState] = []
	for node: MapNodeState in map_state.nodes:
		if node != boss:
			unassigned.append(node)
	for guaranteed_type_id: StringName in template.guaranteed_node_type_ids:
		var candidates: Array[MapNodeState] = _guarantee_candidates(unassigned, guaranteed_type_id, map_state.total_layers)
		if candidates.is_empty():
			return
		var selected_index: int = rng.pick_index(RNG_STREAM, candidates.size())
		var selected: MapNodeState = candidates[selected_index]
		selected.node_type_id = guaranteed_type_id
		unassigned.erase(selected)
	for node: MapNodeState in unassigned:
		node.node_type_id = _weighted_filler_type(template, rng)

func _guarantee_candidates(
	unassigned: Array[MapNodeState],
	node_type_id: StringName,
	total_layers: int
) -> Array[MapNodeState]:
	var result: Array[MapNodeState] = []
	for node: MapNodeState in unassigned:
		if node.layer_index <= 0:
			continue
		if node_type_id == &"elite_battle" and node.layer_index < floori(float(total_layers) / 2.0):
			continue
		result.append(node)
	return result

func _weighted_filler_type(template: MapTemplateDef, rng: RunRngService) -> StringName:
	var total_weight: int = 0
	for node_type_id: StringName in template.filler_node_type_ids:
		var definition: MapNodeDef = MapNodeDefDatabase.get_def(node_type_id)
		if definition != null:
			total_weight += definition.generation_weight
	if total_weight <= 0:
		return &""
	var roll: int = rng.randi_range(RNG_STREAM, 1, total_weight)
	var cursor: int = 0
	for node_type_id: StringName in template.filler_node_type_ids:
		var definition: MapNodeDef = MapNodeDefDatabase.get_def(node_type_id)
		if definition == null:
			continue
		cursor += definition.generation_weight
		if roll <= cursor:
			return node_type_id
	return template.filler_node_type_ids[-1]

func _connect_layers(map_state: MapState) -> void:
	for layer_index: int in range(map_state.total_layers - 1):
		var current_layer: Array[MapNodeState] = map_state.nodes_in_layer(layer_index)
		var next_layer: Array[MapNodeState] = map_state.nodes_in_layer(layer_index + 1)
		for node: MapNodeState in current_layer:
			var first_target: int = node.lane_index % next_layer.size()
			node.outgoing_node_ids.append(next_layer[first_target].node_id)
			if next_layer.size() > 1:
				var second_target: int = (node.lane_index + 1) % next_layer.size()
				if second_target != first_target:
					node.outgoing_node_ids.append(next_layer[second_target].node_id)

class_name MapState
extends RefCounted

const CURRENT_VERSION := 1

var map_version: int = CURRENT_VERSION
var map_id: StringName = &""
var template_id: StringName = &""
var total_layers: int = 0
var nodes: Array[MapNodeState] = []

func get_node(node_id: StringName) -> MapNodeState:
	for node: MapNodeState in nodes:
		if node.node_id == node_id:
			return node
	return null

func nodes_in_layer(layer_index: int) -> Array[MapNodeState]:
	var result: Array[MapNodeState] = []
	for node: MapNodeState in nodes:
		if node.layer_index == layer_index:
			result.append(node)
	result.sort_custom(func(a: MapNodeState, b: MapNodeState) -> bool: return a.lane_index < b.lane_index)
	return result

func node_type_count(node_type_id: StringName) -> int:
	var count: int = 0
	for node: MapNodeState in nodes:
		if node.node_type_id == node_type_id:
			count += 1
	return count

func is_valid() -> bool:
	if map_version != CURRENT_VERSION or map_id.is_empty() or template_id.is_empty() or nodes.is_empty():
		return false
	var template: MapTemplateDef = Content.map_template(template_id)
	if template == null or not template.is_valid():
		return false
	if total_layers < template.min_layers or total_layers > template.max_layers:
		return false
	var by_id: Dictionary = {}
	var incoming_counts: Dictionary = {}
	for node: MapNodeState in nodes:
		if node == null or not node.is_valid(total_layers) or by_id.has(node.node_id):
			return false
		by_id[node.node_id] = node
		incoming_counts[node.node_id] = 0
	for layer_index: int in range(total_layers):
		var layer_nodes: Array[MapNodeState] = nodes_in_layer(layer_index)
		var expected_count: int = 1 if layer_index == total_layers - 1 else layer_nodes.size()
		if layer_index < total_layers - 1 and (expected_count < template.min_nodes_per_layer or expected_count > template.max_nodes_per_layer):
			return false
		if layer_index == total_layers - 1 and (layer_nodes.size() != 1 or layer_nodes[0].node_type_id != template.boss_node_type_id):
			return false
		for lane_index: int in range(layer_nodes.size()):
			if layer_nodes[lane_index].lane_index != lane_index:
				return false
	for node: MapNodeState in nodes:
		if node.layer_index == total_layers - 1:
			if not node.outgoing_node_ids.is_empty():
				return false
			continue
		if node.outgoing_node_ids.is_empty():
			return false
		for target_id: StringName in node.outgoing_node_ids:
			var target: MapNodeState = by_id.get(target_id, null) as MapNodeState
			if target == null or target.layer_index != node.layer_index + 1:
				return false
			incoming_counts[target_id] = int(incoming_counts[target_id]) + 1
	for node: MapNodeState in nodes:
		if node.layer_index > 0 and int(incoming_counts[node.node_id]) <= 0:
			return false
	for required_type_id: StringName in template.guaranteed_node_type_ids:
		if node_type_count(required_type_id) <= 0:
			return false
	return true

func to_dictionary() -> Dictionary:
	var node_data: Array[Dictionary] = []
	for node: MapNodeState in nodes:
		node_data.append(node.to_dictionary())
	return {
		"map_version": map_version,
		"map_id": String(map_id),
		"template_id": String(template_id),
		"total_layers": total_layers,
		"nodes": node_data,
	}

func load_from_dictionary(data: Dictionary) -> bool:
	if int(data.get("map_version", -1)) != CURRENT_VERSION:
		return false
	map_version = CURRENT_VERSION
	map_id = StringName(str(data.get("map_id", "")))
	template_id = StringName(str(data.get("template_id", "")))
	total_layers = int(data.get("total_layers", 0))
	nodes.clear()
	var node_values: Variant = data.get("nodes", [])
	if not node_values is Array:
		return false
	for node_value: Variant in node_values as Array:
		if not node_value is Dictionary:
			return false
		var node: MapNodeState = MapNodeState.new()
		if not node.load_from_dictionary(node_value as Dictionary, total_layers):
			return false
		nodes.append(node)
	return is_valid()

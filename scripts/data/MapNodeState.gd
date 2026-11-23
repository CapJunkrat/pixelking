class_name MapNodeState
extends RefCounted

var node_id: StringName = &""
var layer_index: int = -1
var lane_index: int = -1
var node_type_id: StringName = &""
var outgoing_node_ids: Array[StringName] = []

func _init(
	id_value: StringName = &"",
	layer_value: int = -1,
	lane_value: int = -1,
	type_value: StringName = &""
) -> void:
	node_id = id_value
	layer_index = layer_value
	lane_index = lane_value
	node_type_id = type_value

func is_valid(total_layers: int) -> bool:
	return (
		not node_id.is_empty()
		and layer_index >= 0
		and layer_index < total_layers
		and lane_index >= 0
		and Content.map_node(node_type_id) != null
		and _unique_count(outgoing_node_ids) == outgoing_node_ids.size()
	)

func to_dictionary() -> Dictionary:
	var outgoing: Array[String] = []
	for target_id: StringName in outgoing_node_ids:
		outgoing.append(String(target_id))
	return {
		"node_id": String(node_id),
		"layer_index": layer_index,
		"lane_index": lane_index,
		"node_type_id": String(node_type_id),
		"outgoing_node_ids": outgoing,
	}

func load_from_dictionary(data: Dictionary, total_layers: int) -> bool:
	node_id = StringName(str(data.get("node_id", "")))
	layer_index = int(data.get("layer_index", -1))
	lane_index = int(data.get("lane_index", -1))
	node_type_id = StringName(str(data.get("node_type_id", "")))
	outgoing_node_ids.clear()
	var outgoing_value: Variant = data.get("outgoing_node_ids", [])
	if not outgoing_value is Array:
		return false
	for target_value: Variant in outgoing_value as Array:
		outgoing_node_ids.append(StringName(str(target_value)))
	return is_valid(total_layers)

func _unique_count(values: Array[StringName]) -> int:
	var unique: Dictionary = {}
	for value: StringName in values:
		unique[value] = true
	return unique.size()

class_name MapTemplateDef
extends Resource

@export var id: StringName = &""
@export_range(2, 20, 1) var min_layers: int = 6
@export_range(2, 20, 1) var max_layers: int = 8
@export_range(1, 5, 1) var min_nodes_per_layer: int = 2
@export_range(1, 5, 1) var max_nodes_per_layer: int = 3
@export var boss_node_type_id: StringName = &"boss"
@export var guaranteed_node_type_ids: Array[StringName] = []
@export var filler_node_type_ids: Array[StringName] = []

func is_valid() -> bool:
	if id.is_empty() or min_layers < 2 or max_layers < min_layers:
		return false
	if min_nodes_per_layer < 1 or max_nodes_per_layer < min_nodes_per_layer:
		return false
	if boss_node_type_id.is_empty() or guaranteed_node_type_ids.is_empty() or filler_node_type_ids.is_empty():
		return false
	var unique_ids: Dictionary = {}
	for node_type_id: StringName in guaranteed_node_type_ids + filler_node_type_ids + [boss_node_type_id]:
		if node_type_id.is_empty() or not MapNodeDefDatabase.has_def(node_type_id):
			return false
		unique_ids[node_type_id] = true
	return unique_ids.size() >= 4

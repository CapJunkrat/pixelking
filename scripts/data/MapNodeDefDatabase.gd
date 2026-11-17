class_name MapNodeDefDatabase
extends RefCounted

## Compatibility query facade. Formal map-node content is owned by ContentCatalog.
static func get_def(id: StringName) -> MapNodeDef:
	var registry: ContentRegistry = DefaultContent.registry()
	return registry.map_node(id) if registry != null else null

static func has_def(id: StringName) -> bool:
	return get_def(id) != null

static func all_defs() -> Array[MapNodeDef]:
	var registry: ContentRegistry = DefaultContent.registry()
	return registry.ordered_map_nodes() if registry != null else []

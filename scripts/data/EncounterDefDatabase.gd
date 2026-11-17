class_name EncounterDefDatabase
extends RefCounted

static func get_def(id: StringName) -> EncounterDef:
	var registry: ContentRegistry = DefaultContent.registry()
	return registry.encounter(id) if registry != null else null

static func has_def(id: StringName) -> bool:
	return get_def(id) != null

static func all_defs() -> Array[EncounterDef]:
	var registry: ContentRegistry = DefaultContent.registry()
	return registry.ordered_encounters() if registry != null else []

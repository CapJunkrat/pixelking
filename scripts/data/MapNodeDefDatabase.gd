class_name MapNodeDefDatabase
extends RefCounted

const DEFINITIONS: Array[MapNodeDef] = [
	preload("res://resources/map/nodes/normal_battle.tres"),
	preload("res://resources/map/nodes/elite_battle.tres"),
	preload("res://resources/map/nodes/shop.tres"),
	preload("res://resources/map/nodes/event.tres"),
	preload("res://resources/map/nodes/rest.tres"),
	preload("res://resources/map/nodes/boss.tres"),
]

static var _cache: Dictionary = {}

static func get_def(id: StringName) -> MapNodeDef:
	_ensure_cache()
	return _cache.get(id, null) as MapNodeDef

static func has_def(id: StringName) -> bool:
	_ensure_cache()
	return _cache.has(id)

static func all_defs() -> Array[MapNodeDef]:
	var result: Array[MapNodeDef] = []
	result.assign(DEFINITIONS)
	return result

static func _ensure_cache() -> void:
	if not _cache.is_empty():
		return
	for definition: MapNodeDef in DEFINITIONS:
		if definition != null and definition.is_valid():
			_cache[definition.id] = definition

class_name ChallengerItemDatabase
extends RefCounted

const DefaultContentType = preload("res://scripts/content/DefaultContent.gd")

static func get_def(id: StringName) -> ChallengerItemDef:
	return DefaultContentType.registry().challenger_item(id)

static func all_defs() -> Array[ChallengerItemDef]:
	return DefaultContentType.registry().ordered_challenger_items()

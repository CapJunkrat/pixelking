class_name PieceDefDatabase
extends RefCounted

const DefaultContentType = preload("res://scripts/content/DefaultContent.gd")

static func get_def(id: String) -> PieceDef:
	return DefaultContentType.registry().piece(StringName(id))

static func has_def(id: String) -> bool:
	return get_def(id) != null

static func all_ids() -> Array[String]:
	return DefaultContentType.registry().piece_ids()

static func opening_draft_defs() -> Array[PieceDef]:
	return DefaultContentType.registry().opening_draft_pieces()


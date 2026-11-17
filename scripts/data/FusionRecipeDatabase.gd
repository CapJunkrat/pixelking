class_name FusionRecipeDatabase
extends RefCounted

const DefaultContentType = preload("res://scripts/content/DefaultContent.gd")

static func get_def(id: StringName) -> FusionRecipeDef:
	return DefaultContentType.registry().recipe(id)

static func all_defs() -> Array[FusionRecipeDef]:
	return DefaultContentType.registry().ordered_recipes()


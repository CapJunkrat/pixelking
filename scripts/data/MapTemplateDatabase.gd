class_name MapTemplateDatabase
extends RefCounted

const STANDARD_TEMPLATE: MapTemplateDef = preload("res://resources/map/templates/standard_region.tres")

static func get_def(id: StringName) -> MapTemplateDef:
	return STANDARD_TEMPLATE if id == STANDARD_TEMPLATE.id else null

static func standard() -> MapTemplateDef:
	return STANDARD_TEMPLATE

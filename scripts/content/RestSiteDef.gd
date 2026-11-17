class_name RestSiteDef
extends Resource

@export var id: StringName = &"standard_camp"
@export var title: String = "Camp"
@export_multiline var description: String = "Choose one preparation before continuing."
@export var supplies_gold: int = 10

func is_valid() -> bool:
	return not id.is_empty() and supplies_gold >= 0

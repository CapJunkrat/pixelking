class_name EventDef
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = "A short risk-and-reward encounter."
@export var safe_gold: int = 12
@export var risky_gold: int = 25
@export var can_offer_relic: bool = true

func is_valid() -> bool:
	return not id.is_empty() and not title.is_empty() and safe_gold >= 0 and risky_gold >= 0

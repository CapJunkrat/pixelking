class_name ChallengerItemDef
extends Resource

enum UsageMode {
	PERSISTENT,
	CONSUMABLE,
}

@export var id: StringName
@export var display_name_key: StringName
@export var description_key: StringName
@export var icon: Texture2D
@export var usage_mode: UsageMode = UsageMode.PERSISTENT
@export var effect_type: StringName = &"noop"
@export var effect_priority: int = 0
@export var effect_payload: Dictionary = {}

func is_consumable() -> bool:
	return usage_mode == UsageMode.CONSUMABLE

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

func is_consumable() -> bool:
	return usage_mode == UsageMode.CONSUMABLE

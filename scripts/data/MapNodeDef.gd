class_name MapNodeDef
extends Resource

@export var id: StringName = &""
@export var display_name_key: StringName = &""
@export var description_key: StringName = &""
@export var enemy_hint_key: StringName = &""
@export var reward_hint_key: StringName = &""
@export var icon_text: String = "?"
@export var is_battle: bool = false
@export_range(0, 100, 1) var generation_weight: int = 0

func is_valid() -> bool:
	return (
		not id.is_empty()
		and not display_name_key.is_empty()
		and not description_key.is_empty()
		and not enemy_hint_key.is_empty()
		and not reward_hint_key.is_empty()
		and not icon_text.is_empty()
		and generation_weight >= 0
	)

class_name BattleRewardTableDef
extends Resource

@export var id: StringName = &"default_battle_reward"
@export var title: String = "Victory Reward"
@export_multiline var description: String = "Choose one extra reward. Offers are saved and cannot be rerolled."
@export var normal_gold_min: int = 10
@export var normal_gold_max: int = 20
@export var elite_gold_min: int = 18
@export var elite_gold_max: int = 30
@export var recruit_piece_ids: Array[StringName] = []
@export var bonus_consumable_id: StringName = &"royal_bomb"
@export_range(1, 100, 1) var consumable_roll_sides: int = 3
@export_range(0, 99, 1) var consumable_roll_hit: int = 0
@export var fallback_gold: int = 8

func is_valid() -> bool:
	return (
		not id.is_empty()
		and normal_gold_min >= 0
		and normal_gold_max >= normal_gold_min
		and elite_gold_min >= 0
		and elite_gold_max >= elite_gold_min
		and not recruit_piece_ids.is_empty()
		and consumable_roll_sides > 0
		and consumable_roll_hit < consumable_roll_sides
		and fallback_gold >= 0
	)

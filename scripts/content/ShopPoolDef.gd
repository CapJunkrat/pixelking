class_name ShopPoolDef
extends Resource

@export var id: StringName = &"standard_shop"
@export var title: String = "Royal Market"
@export_multiline var description: String = "Purchase one offer or leave. Inventory is fixed for this visit."
@export var recruit_piece_ids: Array[StringName] = []
@export var consumable_id: StringName = &"royal_bomb"
@export var relic_price: int = 35
@export var piece_price: int = 25
@export var consumable_price: int = 20
@export var retry_price: int = 15
@export var fusion_price: int = 40

func is_valid() -> bool:
	return (
		not id.is_empty()
		and not recruit_piece_ids.is_empty()
		and not consumable_id.is_empty()
		and relic_price >= 0
		and piece_price >= 0
		and consumable_price >= 0
		and retry_price >= 0
		and fusion_price >= 0
	)

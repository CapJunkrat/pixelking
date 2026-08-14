class_name ChallengerItemDatabase
extends RefCounted

static var _cache: Dictionary = {}

static func get_def(id: StringName) -> ChallengerItemDef:
	if _cache.is_empty():
		_build()
	return _cache.get(id, null) as ChallengerItemDef

static func _build() -> void:
	var icon_paths: Dictionary = {
		&"iron_crown": "res://assets/generated/relic_iron_crown_frame_0.png",
		&"lucky_coin": "res://assets/generated/relic_lucky_coin_frame_0.png",
		&"war_banner": "res://assets/generated/relic_war_banner_v2_frame_0.png",
		&"glass_feather": "res://assets/generated/relic_glass_feather_frame_0.png",
	}
	for relic_id: StringName in RunContentDatabase.RELICS:
		var definition: ChallengerItemDef = ChallengerItemDef.new()
		definition.id = relic_id
		definition.display_name_key = StringName("ITEM_%s_NAME" % String(relic_id).to_upper())
		definition.description_key = StringName("ITEM_%s_DESC" % String(relic_id).to_upper())
		definition.icon = load(str(icon_paths.get(relic_id, ""))) as Texture2D
		definition.usage_mode = ChallengerItemDef.UsageMode.PERSISTENT
		definition.effect_type = &"noop"
		_cache[relic_id] = definition
	var bomb: ChallengerItemDef = ChallengerItemDef.new()
	bomb.id = &"royal_bomb"
	bomb.display_name_key = &"ITEM_ROYAL_BOMB_NAME"
	bomb.description_key = &"ITEM_ROYAL_BOMB_DESC"
	bomb.icon = load("res://assets/generated/consumable_royal_bomb_frame_0.png") as Texture2D
	bomb.usage_mode = ChallengerItemDef.UsageMode.CONSUMABLE
	bomb.effect_type = &"remove_piece"
	bomb.effect_priority = 10
	_cache[bomb.id] = bomb

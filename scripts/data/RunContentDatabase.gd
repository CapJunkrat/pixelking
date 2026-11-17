class_name RunContentDatabase
extends RefCounted

const DefaultContentType = preload("res://scripts/content/DefaultContent.gd")
const BattleRewardTableDefType = preload("res://scripts/content/BattleRewardTableDef.gd")
const ShopPoolDefType = preload("res://scripts/content/ShopPoolDef.gd")
const EventDefType = preload("res://scripts/content/EventDef.gd")
const RestSiteDefType = preload("res://scripts/content/RestSiteDef.gd")

static func relic_ids() -> Array[StringName]:
	return DefaultContentType.registry().relic_ids()

static func consumable_ids() -> Array[StringName]:
	return DefaultContentType.registry().consumable_ids()

static func event_ids() -> Array[StringName]:
	return DefaultContentType.registry().event_ids()

static func event_def(id: StringName) -> EventDefType:
	return DefaultContentType.registry().event(id)

static func battle_reward_table() -> BattleRewardTableDefType:
	return DefaultContentType.registry().reward_table()

static func shop_pool() -> ShopPoolDefType:
	return DefaultContentType.registry().default_shop_pool()

static func rest_site() -> RestSiteDefType:
	return DefaultContentType.registry().default_rest_site()

static func relic_label(id: StringName) -> String:
	return String(id).replace("_", " ").capitalize()

static func is_relic(id: StringName) -> bool:
	return id in relic_ids()

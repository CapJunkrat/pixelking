class_name RunContentDatabase
extends RefCounted

const RELICS: Array[StringName] = [&"iron_crown", &"lucky_coin", &"war_banner", &"glass_feather"]
const CONSUMABLES: Array[StringName] = [&"royal_bomb"]
const EVENTS: Array[StringName] = [&"wandering_merchant", &"ancient_shrine", &"lost_patrol", &"golden_fork"]

static func relic_label(id: StringName) -> String:
	return String(id).replace("_", " ").capitalize()

static func is_relic(id: StringName) -> bool:
	return id in RELICS

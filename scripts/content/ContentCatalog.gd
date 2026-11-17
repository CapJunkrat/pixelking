class_name ContentCatalog
extends Resource

const BattleRewardTableDefType = preload("res://scripts/content/BattleRewardTableDef.gd")
const ShopPoolDefType = preload("res://scripts/content/ShopPoolDef.gd")
const EventDefType = preload("res://scripts/content/EventDef.gd")
const RestSiteDefType = preload("res://scripts/content/RestSiteDef.gd")
const EncounterDefType = preload("res://scripts/content/EncounterDef.gd")

@export var catalog_id: StringName = &"pixelking.default"
@export var content_version: int = 1
@export var motion_profiles: Array[PieceMotionProfile] = []
@export var pieces: Array[PieceDef] = []
@export var fusion_recipes: Array[FusionRecipeDef] = []
@export var challenger_items: Array[ChallengerItemDef] = []
@export var battle_reward_table: BattleRewardTableDefType
@export var shop_pool: ShopPoolDefType
@export var events: Array[EventDefType] = []
@export var rest_site: RestSiteDefType
@export var map_node_defs: Array[MapNodeDef] = []
@export var map_templates: Array[MapTemplateDef] = []
@export var encounters: Array[EncounterDefType] = []

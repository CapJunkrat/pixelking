class_name ContentRegistry
extends RefCounted

const ContentCatalogType = preload("res://scripts/content/ContentCatalog.gd")
const BattleRewardTableDefType = preload("res://scripts/content/BattleRewardTableDef.gd")
const ShopPoolDefType = preload("res://scripts/content/ShopPoolDef.gd")
const EventDefType = preload("res://scripts/content/EventDef.gd")
const RestSiteDefType = preload("res://scripts/content/RestSiteDef.gd")
const EncounterDefType = preload("res://scripts/content/EncounterDef.gd")

var catalog: ContentCatalogType
var validation_errors: PackedStringArray = PackedStringArray()
var _pieces_by_id: Dictionary = {}
var _motion_profiles_by_id: Dictionary = {}
var _recipes_by_id: Dictionary = {}
var _items_by_id: Dictionary = {}
var _events_by_id: Dictionary = {}
var _map_nodes_by_id: Dictionary = {}
var _map_templates_by_id: Dictionary = {}
var _encounters_by_id: Dictionary = {}

func _init(source_catalog: ContentCatalogType) -> void:
	catalog = source_catalog
	_rebuild_indexes()

func is_valid() -> bool:
	return validation_errors.is_empty()

func piece(id: StringName) -> PieceDef:
	return _pieces_by_id.get(id, null) as PieceDef

func piece_ids() -> Array[String]:
	var result: Array[String] = []
	for id_value: Variant in _pieces_by_id.keys():
		result.append(String(id_value))
	result.sort()
	return result

func ordered_pieces() -> Array[PieceDef]:
	return catalog.pieces.duplicate() if catalog != null else []

func opening_draft_pieces() -> Array[PieceDef]:
	var result: Array[PieceDef] = []
	for definition: PieceDef in ordered_pieces():
		if definition != null and definition.is_valid_opening_draft_piece():
			result.append(definition)
	return result

func motion_profile(id: StringName) -> PieceMotionProfile:
	return _motion_profiles_by_id.get(id, null) as PieceMotionProfile

func recipe(id: StringName) -> FusionRecipeDef:
	return _recipes_by_id.get(id, null) as FusionRecipeDef

func ordered_recipes() -> Array[FusionRecipeDef]:
	return catalog.fusion_recipes.duplicate() if catalog != null else []

func challenger_item(id: StringName) -> ChallengerItemDef:
	return _items_by_id.get(id, null) as ChallengerItemDef

func ordered_challenger_items() -> Array[ChallengerItemDef]:
	return catalog.challenger_items.duplicate() if catalog != null else []

func relic_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: ChallengerItemDef in ordered_challenger_items():
		if definition != null and not definition.is_consumable():
			result.append(definition.id)
	return result

func consumable_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: ChallengerItemDef in ordered_challenger_items():
		if definition != null and definition.is_consumable():
			result.append(definition.id)
	return result

func event(id: StringName) -> EventDefType:
	return _events_by_id.get(id, null) as EventDefType

func ordered_events() -> Array[EventDefType]:
	return catalog.events.duplicate() if catalog != null else []

func event_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: EventDefType in ordered_events():
		if definition != null:
			result.append(definition.id)
	return result

func map_node(id: StringName) -> MapNodeDef:
	return _map_nodes_by_id.get(id, null) as MapNodeDef

func ordered_map_nodes() -> Array[MapNodeDef]:
	return catalog.map_node_defs.duplicate() if catalog != null else []

func map_template(id: StringName) -> MapTemplateDef:
	return _map_templates_by_id.get(id, null) as MapTemplateDef

func ordered_map_templates() -> Array[MapTemplateDef]:
	return catalog.map_templates.duplicate() if catalog != null else []

func encounter(id: StringName) -> EncounterDefType:
	return _encounters_by_id.get(id, null) as EncounterDefType

func ordered_encounters() -> Array[EncounterDefType]:
	return catalog.encounters.duplicate() if catalog != null else []

func reward_table() -> BattleRewardTableDefType:
	return catalog.battle_reward_table if catalog != null else null

func default_shop_pool() -> ShopPoolDefType:
	return catalog.shop_pool if catalog != null else null

func default_rest_site() -> RestSiteDefType:
	return catalog.rest_site if catalog != null else null

func _rebuild_indexes() -> void:
	validation_errors.clear()
	_pieces_by_id.clear()
	_motion_profiles_by_id.clear()
	_recipes_by_id.clear()
	_items_by_id.clear()
	_events_by_id.clear()
	_map_nodes_by_id.clear()
	_map_templates_by_id.clear()
	_encounters_by_id.clear()
	if catalog == null:
		validation_errors.append("Content catalog is missing")
		return
	if catalog.catalog_id.is_empty():
		validation_errors.append("Content catalog ID is empty")
	if catalog.content_version <= 0:
		validation_errors.append("Content catalog version must be positive")
	_index_motion_profiles()
	_index_pieces()
	_index_recipes()
	_index_items()
	_index_events()
	_index_encounters()
	_index_map_nodes()
	_index_map_templates()
	_validate_tables()

func _index_motion_profiles() -> void:
	for definition: PieceMotionProfile in catalog.motion_profiles:
		if definition == null or not definition.is_valid():
			validation_errors.append("Invalid motion profile")
			continue
		if _motion_profiles_by_id.has(definition.id):
			validation_errors.append("Duplicate motion profile ID: %s" % definition.id)
			continue
		_motion_profiles_by_id[definition.id] = definition

func _index_pieces() -> void:
	for definition: PieceDef in catalog.pieces:
		if definition == null or definition.id.is_empty():
			validation_errors.append("Invalid piece definition")
			continue
		var id: StringName = StringName(definition.id)
		if _pieces_by_id.has(id):
			validation_errors.append("Duplicate piece ID: %s" % id)
			continue
		if definition.display_name_key.is_empty() or definition.movement_profile == null or definition.motion_profile == null:
			validation_errors.append("Piece %s is missing required data" % id)
		if definition.motion_profile != null and not _motion_profiles_by_id.has(definition.motion_profile.id):
			validation_errors.append("Piece %s references an unregistered motion profile" % id)
		_pieces_by_id[id] = definition

func _index_recipes() -> void:
	for definition: FusionRecipeDef in catalog.fusion_recipes:
		if definition == null or definition.id.is_empty():
			validation_errors.append("Invalid fusion recipe")
			continue
		if _recipes_by_id.has(definition.id):
			validation_errors.append("Duplicate fusion recipe ID: %s" % definition.id)
			continue
		var result_definition: PieceDef = piece(definition.result_piece_def_id)
		if definition.ingredient_piece_def_ids.size() < 2 or result_definition == null:
			validation_errors.append("Fusion recipe %s has invalid result or ingredients" % definition.id)
		if definition.display_name_key.is_empty() or definition.description_key.is_empty():
			validation_errors.append("Fusion recipe %s is missing localization keys" % definition.id)
		var king_ingredient_count: int = 0
		for ingredient_id: StringName in definition.ingredient_piece_def_ids:
			var ingredient_definition: PieceDef = piece(ingredient_id)
			if ingredient_definition == null:
				validation_errors.append("Fusion recipe %s references missing piece %s" % [definition.id, ingredient_id])
			elif ingredient_definition.is_king:
				king_ingredient_count += 1
		if result_definition != null:
			if result_definition.is_king and king_ingredient_count != 1:
				validation_errors.append("King fusion recipe %s must consume exactly one King" % definition.id)
			elif not result_definition.is_king and king_ingredient_count != 0:
				validation_errors.append("Non-King fusion recipe %s cannot consume a King" % definition.id)
		_recipes_by_id[definition.id] = definition

func _index_items() -> void:
	for definition: ChallengerItemDef in catalog.challenger_items:
		if definition == null or definition.id.is_empty():
			validation_errors.append("Invalid challenger item")
			continue
		if _items_by_id.has(definition.id):
			validation_errors.append("Duplicate challenger item ID: %s" % definition.id)
			continue
		if definition.display_name_key.is_empty() or definition.description_key.is_empty() or definition.icon == null:
			validation_errors.append("Challenger item %s is missing required data" % definition.id)
		_items_by_id[definition.id] = definition

func _index_events() -> void:
	for definition: EventDefType in catalog.events:
		if definition == null or not definition.is_valid():
			validation_errors.append("Invalid event definition")
			continue
		if _events_by_id.has(definition.id):
			validation_errors.append("Duplicate event ID: %s" % definition.id)
			continue
		_events_by_id[definition.id] = definition

func _index_encounters() -> void:
	for definition: EncounterDefType in catalog.encounters:
		if definition == null or not definition.is_valid():
			validation_errors.append("Invalid encounter definition")
			continue
		if _encounters_by_id.has(definition.id):
			validation_errors.append("Duplicate encounter ID: %s" % definition.id)
			continue
		for placement: Dictionary in definition.enemy_placements:
			var piece_id: StringName = StringName(str(placement.get("piece_def_id", "")))
			if piece(piece_id) == null:
				validation_errors.append("Encounter %s references missing piece %s" % [definition.id, piece_id])
		_encounters_by_id[definition.id] = definition

func _index_map_nodes() -> void:
	for definition: MapNodeDef in catalog.map_node_defs:
		if definition == null or not definition.is_valid():
			validation_errors.append("Invalid map node definition")
			continue
		if _map_nodes_by_id.has(definition.id):
			validation_errors.append("Duplicate map node ID: %s" % definition.id)
			continue
		if definition.is_battle and encounter(definition.encounter_def_id) == null:
			validation_errors.append("Map node %s references missing encounter %s" % [definition.id, definition.encounter_def_id])
		_map_nodes_by_id[definition.id] = definition

func _index_map_templates() -> void:
	for definition: MapTemplateDef in catalog.map_templates:
		if definition == null or definition.id.is_empty() or definition.min_layers < 2 or definition.max_layers < definition.min_layers:
			validation_errors.append("Invalid map template definition")
			continue
		if _map_templates_by_id.has(definition.id):
			validation_errors.append("Duplicate map template ID: %s" % definition.id)
			continue
		if definition.min_nodes_per_layer < 1 or definition.max_nodes_per_layer < definition.min_nodes_per_layer:
			validation_errors.append("Map template %s has invalid layer width" % definition.id)
		var referenced_ids: Array[StringName] = []
		referenced_ids.append_array(definition.guaranteed_node_type_ids)
		referenced_ids.append_array(definition.filler_node_type_ids)
		referenced_ids.append(definition.boss_node_type_id)
		for node_type_id: StringName in referenced_ids:
			if map_node(node_type_id) == null:
				validation_errors.append("Map template %s references missing node type %s" % [definition.id, node_type_id])
		_map_templates_by_id[definition.id] = definition

func _validate_tables() -> void:
	var reward: BattleRewardTableDefType = reward_table()
	if reward == null or not reward.is_valid():
		validation_errors.append("Battle reward table is invalid")
	else:
		for piece_id: StringName in reward.recruit_piece_ids:
			if piece(piece_id) == null:
				validation_errors.append("Battle reward table references missing piece %s" % piece_id)
		var reward_item: ChallengerItemDef = challenger_item(reward.bonus_consumable_id)
		if reward_item == null or not reward_item.is_consumable():
			validation_errors.append("Battle reward table references an invalid consumable")
	var shop: ShopPoolDefType = default_shop_pool()
	if shop == null or not shop.is_valid():
		validation_errors.append("Shop pool is invalid")
	else:
		for piece_id: StringName in shop.recruit_piece_ids:
			if piece(piece_id) == null:
				validation_errors.append("Shop pool references missing piece %s" % piece_id)
		var shop_item: ChallengerItemDef = challenger_item(shop.consumable_id)
		if shop_item == null or not shop_item.is_consumable():
			validation_errors.append("Shop pool references an invalid consumable")
	var rest: RestSiteDefType = default_rest_site()
	if rest == null or not rest.is_valid():
		validation_errors.append("Rest site definition is invalid")

class_name Content
extends RefCounted

## The one way the game looks up its content: pieces, recipes, items, events, map
## nodes, encounters and the run tables, all by stable id. Everything comes from the
## registry built over res://resources/content/default_catalog.tres (DefaultContent);
## this class only gives the lookups short names. Rules for adding content live in
## docs/CONTENT_ARCHITECTURE.md.
##
## A lookup of an unknown id returns null (or an empty list) instead of failing, so a
## stale id in an old save degrades the way the caller decides.

const STANDARD_MAP_TEMPLATE_ID: StringName = &"standard_region"
## Motion used for a piece whose own profile is missing.
const FALLBACK_MOTION_PROFILE_ID: StringName = &"queen"

static func registry() -> ContentRegistry:
	return DefaultContent.registry()

# --- pieces -------------------------------------------------------------------

static func piece(id: StringName) -> PieceDef:
	var source: ContentRegistry = registry()
	return source.piece(id) if source != null else null

static func piece_ids() -> Array[String]:
	var source: ContentRegistry = registry()
	return source.piece_ids() if source != null else []

static func opening_draft_pieces() -> Array[PieceDef]:
	var source: ContentRegistry = registry()
	return source.opening_draft_pieces() if source != null else []

static func motion_profile(id: StringName) -> PieceMotionProfile:
	var source: ContentRegistry = registry()
	if source == null:
		return null
	var profile: PieceMotionProfile = source.motion_profile(id)
	return profile if profile != null else source.motion_profile(FALLBACK_MOTION_PROFILE_ID)

# --- fusion -------------------------------------------------------------------

static func recipe(id: StringName) -> FusionRecipeDef:
	var source: ContentRegistry = registry()
	return source.recipe(id) if source != null else null

static func recipes() -> Array[FusionRecipeDef]:
	var source: ContentRegistry = registry()
	return source.ordered_recipes() if source != null else []

# --- relics and items -----------------------------------------------------------

static func challenger_item(id: StringName) -> ChallengerItemDef:
	var source: ContentRegistry = registry()
	return source.challenger_item(id) if source != null else null

static func challenger_items() -> Array[ChallengerItemDef]:
	var source: ContentRegistry = registry()
	return source.ordered_challenger_items() if source != null else []

static func relic_ids() -> Array[StringName]:
	var source: ContentRegistry = registry()
	return source.relic_ids() if source != null else []

static func consumable_ids() -> Array[StringName]:
	var source: ContentRegistry = registry()
	return source.consumable_ids() if source != null else []

static func is_relic(id: StringName) -> bool:
	return id in relic_ids()

# --- events ---------------------------------------------------------------------

static func event(id: StringName) -> EventDef:
	var source: ContentRegistry = registry()
	return source.event(id) if source != null else null

static func event_ids() -> Array[StringName]:
	var source: ContentRegistry = registry()
	return source.event_ids() if source != null else []

# --- map ------------------------------------------------------------------------

static func map_node(id: StringName) -> MapNodeDef:
	var source: ContentRegistry = registry()
	return source.map_node(id) if source != null else null

static func map_nodes() -> Array[MapNodeDef]:
	var source: ContentRegistry = registry()
	return source.ordered_map_nodes() if source != null else []

static func map_template(id: StringName) -> MapTemplateDef:
	var source: ContentRegistry = registry()
	return source.map_template(id) if source != null else null

static func standard_map_template() -> MapTemplateDef:
	return map_template(STANDARD_MAP_TEMPLATE_ID)

# --- encounters -----------------------------------------------------------------

static func encounter(id: StringName) -> EncounterDef:
	var source: ContentRegistry = registry()
	return source.encounter(id) if source != null else null

static func encounters() -> Array[EncounterDef]:
	var source: ContentRegistry = registry()
	return source.ordered_encounters() if source != null else []

## Every Boss that can lead an act, by id.
static func boss_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition: EncounterDef in encounters():
		if definition.is_boss and definition.act > 0:
			ids.append(String(definition.id))
	return ids

# --- run tables -----------------------------------------------------------------

static func reward_table() -> BattleRewardTableDef:
	var source: ContentRegistry = registry()
	return source.reward_table() if source != null else null

static func shop_pool() -> ShopPoolDef:
	var source: ContentRegistry = registry()
	return source.default_shop_pool() if source != null else null

static func rest_site() -> RestSiteDef:
	var source: ContentRegistry = registry()
	return source.default_rest_site() if source != null else null

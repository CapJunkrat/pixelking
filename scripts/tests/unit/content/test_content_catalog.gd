extends Node

const ContentRegistryType = preload("res://scripts/content/ContentRegistry.gd")
const ContentCatalogType = preload("res://scripts/content/ContentCatalog.gd")
const CATALOG_PATH: String = "res://resources/content/default_catalog.tres"

func test_default_catalog_is_valid_and_resource_backed() -> void:
	var catalog: ContentCatalogType = load(CATALOG_PATH) as ContentCatalogType
	var registry: ContentRegistryType = ContentRegistryType.new(catalog)
	assert(registry.is_valid(), "Default ContentCatalog must pass cross-reference validation: %s" % registry.validation_errors)
	assert(registry.piece_ids() == ["antelope", "archmage", "assassin", "bishop", "blast_catapult", "bowman", "catapult", "centaur", "chameleon", "crystal_mage", "echo", "ember_bird", "falconer", "flame_phoenix", "gargoyle", "gorgon", "gryphon", "king", "knight", "lancer", "lantern_bearer", "manticore", "martyr", "pawn", "portal_mage", "powder_keg", "queen", "ranger", "rook", "royal_guard", "sentry", "shadow_king", "shield_king", "sky_archer", "squire", "squire_lv2", "squire_lv3", "squire_lv4", "stand_in", "stone_giant", "sun_moon_monk", "swift_courier", "thousand_faces", "tide_knight", "tide_knight_ebb", "unicorn_cavalry", "vanguard", "war_king"])
	assert(registry.piece(&"pawn") != null)
	assert(registry.piece(&"pawn").resource_path.ends_with("pieces/pawn.tres"))
	assert(registry.piece(&"lancer").motion_profile == registry.motion_profile(&"knight"))
	assert(registry.ordered_recipes().size() == 14)
	assert(registry.recipe(&"pawn_knight_lancer") != null)
	assert(registry.relic_ids() == [&"iron_crown", &"lucky_coin", &"war_banner", &"glass_feather"])
	assert(registry.consumable_ids() == [&"royal_bomb", &"holy_water", &"freeze_charm", &"second_wind"])
	assert(registry.event_ids() == [&"wandering_merchant", &"ancient_shrine", &"lost_patrol", &"golden_fork"])
	assert(registry.reward_table() != null and registry.reward_table().recruit_piece_ids[0] == &"pawn")
	assert(registry.default_shop_pool() != null and registry.default_shop_pool().piece_price == 25)
	assert(registry.ordered_map_nodes().size() == 6)
	assert(registry.map_template(&"standard_region") != null)
	assert(registry.ordered_encounters().size() == 3)
	assert(registry.map_node(&"boss").encounter_def_id == &"boss_royal_guard")
	assert(registry.encounter(&"boss_royal_guard").enemy_placements.size() == 12)

func test_special_pieces_are_deployed_across_enemy_encounters() -> void:
	var catalog: ContentCatalogType = load(CATALOG_PATH) as ContentCatalogType
	var registry: ContentRegistryType = ContentRegistryType.new(catalog)
	var deployed_specials: Dictionary = {}
	for encounter: EncounterDef in registry.ordered_encounters():
		var occupied: Dictionary = {}
		var king_count: int = 0
		for placement: Dictionary in encounter.enemy_placements:
			var piece_id: String = str(placement.get("piece_def_id", ""))
			var position: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
			assert(not occupied.has(position), "%s must not overlap enemy positions" % encounter.id)
			occupied[position] = true
			if piece_id == "king":
				king_count += 1
			if piece_id in ["assassin", "royal_guard", "catapult", "bowman", "portal_mage", "unicorn_cavalry", "centaur", "manticore", "gryphon", "gorgon"]:
				deployed_specials[piece_id] = true
		assert(king_count == 1, "%s must deploy exactly one enemy King" % encounter.id)
	assert(deployed_specials.size() == 10, "Every new special piece must appear in a formal encounter")
	assert(str(registry.encounter(&"boss_royal_guard").enemy_placements[3].get("piece_def_id")) == "royal_guard")

func test_enemy_ai_can_act_in_every_special_encounter() -> void:
	var catalog: ContentCatalogType = load(CATALOG_PATH) as ContentCatalogType
	var registry: ContentRegistryType = ContentRegistryType.new(catalog)
	var selector: EnemyMoveSelector = EnemyMoveSelector.new()
	for encounter: EncounterDef in registry.ordered_encounters():
		var board: BoardState = BoardState.new(encounter.board_size, false)
		board.clear_for_setup()
		assert(board.place_piece_for_setup(Vector2i(4, 0), ChessPiece.new(registry.piece(&"king"), GameRules.PieceColor.WHITE)))
		assert(board.place_piece_for_setup(Vector2i(3, 1), ChessPiece.new(registry.piece(&"pawn"), GameRules.PieceColor.WHITE)))
		for placement: Dictionary in encounter.enemy_placements:
			var piece_id: StringName = StringName(str(placement.get("piece_def_id", "")))
			var position: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
			assert(board.place_piece_for_setup(position, ChessPiece.new(registry.piece(piece_id), GameRules.PieceColor.BLACK)))
		assert(board.finalize_setup(GameRules.PieceColor.BLACK))
		var action: MoveAction = selector.choose_action(board, GameRules.PieceColor.BLACK)
		assert(action != null, "%s special roster must expose a legal AI action" % encounter.id)
		if action != null:
			var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
			assert(processor.execute(action).success, "%s AI action must execute through the formal command processor" % encounter.id)

func test_catalog_requires_stable_catalog_metadata() -> void:
	var catalog: ContentCatalogType = load(CATALOG_PATH) as ContentCatalogType
	var empty_id_catalog: ContentCatalogType = catalog.duplicate() as ContentCatalogType
	empty_id_catalog.catalog_id = &""
	var empty_id_registry: ContentRegistryType = ContentRegistryType.new(empty_id_catalog)
	assert(not empty_id_registry.is_valid())
	var invalid_version_catalog: ContentCatalogType = catalog.duplicate() as ContentCatalogType
	invalid_version_catalog.content_version = 0
	var invalid_version_registry: ContentRegistryType = ContentRegistryType.new(invalid_version_catalog)
	assert(not invalid_version_registry.is_valid())

func test_catalog_rejects_duplicate_stable_ids() -> void:
	var catalog: ContentCatalogType = load(CATALOG_PATH) as ContentCatalogType
	var registry: ContentRegistryType = ContentRegistryType.new(catalog)
	var duplicate_catalog: ContentCatalogType = registry.catalog.duplicate() as ContentCatalogType
	duplicate_catalog.pieces = registry.catalog.pieces.duplicate()
	duplicate_catalog.pieces.append(registry.catalog.pieces[0])
	var invalid_registry: ContentRegistryType = ContentRegistryType.new(duplicate_catalog)
	assert(not invalid_registry.is_valid())

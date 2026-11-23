extends Node

const ContentRegistryType = preload("res://scripts/content/ContentRegistry.gd")
const ContentCatalogType = preload("res://scripts/content/ContentCatalog.gd")
const CATALOG_PATH: String = "res://resources/content/default_catalog.tres"

func test_default_catalog_is_valid_and_resource_backed() -> void:
	var catalog: ContentCatalogType = load(CATALOG_PATH) as ContentCatalogType
	var registry: ContentRegistryType = ContentRegistryType.new(catalog)
	assert(registry.is_valid(), "Default ContentCatalog must pass cross-reference validation: %s" % registry.validation_errors)
	assert(registry.piece_ids() == ["antelope", "archmage", "assassin", "bishop", "blast_catapult", "bowman", "catapult", "centaur", "chameleon", "crystal_mage", "echo", "ember_bird", "ember_egg", "falconer", "flame_phoenix", "gargoyle", "gorgon", "gryphon", "king", "knight", "lancer", "lantern_bearer", "manticore", "martyr", "pawn", "phoenix_egg", "portal_mage", "powder_keg", "queen", "ranger", "rook", "royal_guard", "sentry", "shadow_king", "shield_king", "sky_archer", "squire", "squire_lv2", "squire_lv3", "squire_lv4", "stand_in", "stone_giant", "sun_moon_monk", "swift_courier", "thousand_faces", "tide_knight", "tide_knight_ebb", "unicorn_cavalry", "vanguard", "war_king"])
	assert(registry.piece(&"pawn") != null)
	assert(registry.piece(&"pawn").resource_path.ends_with("pieces/pawn.tres"))
	assert(registry.piece(&"lancer").motion_profile == registry.motion_profile(&"knight"))
	assert(registry.ordered_recipes().size() == 14)
	assert(registry.recipe(&"pawn_knight_lancer") != null)
	assert(registry.relic_ids() == [&"iron_crown", &"lucky_coin", &"war_banner", &"glass_feather"])
	assert(registry.consumable_ids() == [&"royal_bomb", &"holy_water", &"freeze_charm", &"second_wind"])
	assert(registry.event_ids().size() == 12 and registry.event_ids().slice(0, 4) == [&"wandering_merchant", &"ancient_shrine", &"lost_patrol", &"golden_fork"])
	assert(registry.reward_table() != null and registry.reward_table().recruit_piece_ids[0] == &"pawn")
	assert(registry.default_shop_pool() != null and registry.default_shop_pool().piece_price == 25)
	assert(registry.ordered_map_nodes().size() == 6)
	assert(registry.map_template(&"standard_region") != null)
	assert(registry.ordered_encounters().size() == 11)
	for act: int in range(3):
		assert(EncounterGenerator.bosses_for_act(act).size() == 3)
	assert(EncounterGenerator.bosses_for_act(3).size() == 9)
	# Journeys have no last act; Bosses past Act 3 bring reinforcements.
	assert(Content.boss_ids().size() == 9)
	for boss: EncounterDef in EncounterGenerator.bosses_for_act(0) + EncounterGenerator.bosses_for_act(1) + EncounterGenerator.bosses_for_act(2):
		assert(boss.is_valid())
		var reinforced: Array[Dictionary] = EncounterGenerator.reinforce(boss.enemy_placements, 12, 77)
		assert(reinforced.size() > boss.enemy_placements.size())
		var squares: Dictionary = {}
		for placement: Dictionary in reinforced:
			var square: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
			assert(DeploymentState.is_enemy_zone(square, 8) and not squares.has(square))
			squares[square] = true
	assert(registry.map_node(&"boss").encounter_def_id == &"boss_royal_guard")
	assert(registry.encounter(&"boss_royal_guard").enemy_placements.size() == 8)

func test_special_pieces_are_deployed_across_enemy_encounters() -> void:
	# Normal and elite armies are generated, so every special piece must be reachable
	# through the generator's pools or elite captains.
	var reachable: Dictionary = {}
	for band: Dictionary in EncounterGenerator.POOLS:
		for id: String in band["ids"]:
			reachable[id] = true
	for id: String in EncounterGenerator.ELITE_CAPTAINS:
		reachable[id] = true
	for piece_id: String in ["assassin", "royal_guard", "catapult", "bowman", "portal_mage", "unicorn_cavalry", "centaur", "manticore", "gryphon", "gorgon"]:
		assert(reachable.has(piece_id), "%s must appear in generated encounters" % piece_id)
	# Every generated army has one King with a piece standing right in front of it.
	for layer: int in range(6):
		for tier: StringName in [&"normal", &"elite"]:
			var army: Array[Dictionary] = EncounterGenerator.generate(tier, layer, 7, 1234 + layer, 10)
			var squares: Dictionary = {}
			var king_square: Vector2i = Vector2i(-1, -1)
			for placement: Dictionary in army:
				var square: Vector2i = DeploymentState.position_from_value(placement.get("position", {}))
				assert(not squares.has(square), "generated pieces never overlap")
				squares[square] = true
				if str(placement.get("piece_def_id", "")) == "king":
					king_square = square
			assert(king_square.x >= 0 and squares.has(king_square + Vector2i(0, -1)), "the enemy King is guarded at layer %d" % layer)
	assert(str(registry_boss_king()) == "king")

func registry_boss_king() -> String:
	var catalog: ContentCatalogType = load(CATALOG_PATH) as ContentCatalogType
	var registry: ContentRegistryType = ContentRegistryType.new(catalog)
	for placement: Dictionary in registry.encounter(&"boss_royal_guard").enemy_placements:
		if DeploymentState.position_from_value(placement.get("position", {})) == Vector2i(5, 7):
			return str(placement.get("piece_def_id", ""))
	return ""

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

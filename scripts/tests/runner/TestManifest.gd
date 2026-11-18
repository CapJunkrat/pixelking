class_name TestManifest
extends RefCounted

## Explicit inventory: every automated test belongs to exactly one layer and domain.
## kind is either "scene_tree" (self-running process) or "node_methods".
## "serial": true  shares state with other tests (user://settings.cfg), so it never runs
##                 alongside them. "slow": true  is skipped by run_all_tests --quick.
const TESTS = [
	{"path": "res://scripts/tests/unit/chess/test_chess_rules.gd", "layer": "unit", "domain": "chess", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/chess/test_permissive_moves.gd", "layer": "unit", "domain": "chess", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/chess/test_ouroboros_piece_rules.gd", "layer": "unit", "domain": "chess", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/chess/test_new_piece_rules.gd", "layer": "unit", "domain": "chess", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/test_architecture/test_manifest_integrity.gd", "layer": "unit", "domain": "test_architecture", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/content/test_content_catalog.gd", "layer": "unit", "domain": "content", "kind": "node_methods"},
	{"path": "res://scripts/tests/unit/content/test_rarity_odds.gd", "layer": "unit", "domain": "content", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/content/test_content_offer_generation.gd", "layer": "unit", "domain": "content", "kind": "node_methods"},
	{"path": "res://scripts/tests/unit/battle/test_battle_command_processor.gd", "layer": "unit", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/battle/test_battle_effect_queue.gd", "layer": "unit", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/battle/test_items.gd", "layer": "unit", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/battle/test_battle_events.gd", "layer": "unit", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/battle/test_battle_presentation.gd", "layer": "unit", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/battle/test_battle_terminal_authority.gd", "layer": "unit", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/battle/test_battle_turn_coordinator.gd", "layer": "unit", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_events_and_rest.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_fusion_service.gd", "layer": "unit", "domain": "run", "kind": "node_methods"},
	{"path": "res://scripts/tests/unit/run/test_map_generation.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_map_progress.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_opening_draft.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_roster_deployment.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_run_content_systems.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_run_flow_state_machine.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_run_rng.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/unit/run/test_run_state.gd", "layer": "unit", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/battle/test_atomic_run_item_use.gd", "layer": "integration", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/battle/test_battle_item_window.gd", "layer": "integration", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/battle/test_battle_run_integration.gd", "layer": "integration", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/battle/test_battle_run_result_failure.gd", "layer": "integration", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/battle/test_run_battle_setup.gd", "layer": "integration", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/persistence/test_active_run_save.gd", "layer": "integration", "domain": "persistence", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/persistence/test_settings_persistence.gd", "layer": "integration", "domain": "persistence", "kind": "scene_tree", "serial": true},
	{"path": "res://scripts/tests/integration/run/test_fusion_interaction.gd", "layer": "integration", "domain": "run", "kind": "node_methods"},
	{"path": "res://scripts/tests/integration/run/test_map_manager.gd", "layer": "integration", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/run/test_roster_manager.gd", "layer": "integration", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/integration/run/test_run_manager.gd", "layer": "integration", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_audio_settings.gd", "layer": "scene", "domain": "ui", "kind": "scene_tree", "serial": true},
	{"path": "res://scripts/tests/scenes/test_battle_scene.gd", "layer": "scene", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_piece_info.gd", "layer": "scene", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_strike_presentation.gd", "layer": "scene", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_strike_special_pieces.gd", "layer": "scene", "domain": "battle", "kind": "scene_tree", "slow": true},
	{"path": "res://scripts/tests/scenes/test_strike_new_pieces_1.gd", "layer": "scene", "domain": "battle", "kind": "scene_tree", "slow": true},
	{"path": "res://scripts/tests/scenes/test_strike_new_pieces_2.gd", "layer": "scene", "domain": "battle", "kind": "scene_tree", "slow": true},
	{"path": "res://scripts/tests/scenes/test_strike_new_pieces_3.gd", "layer": "scene", "domain": "battle", "kind": "scene_tree", "slow": true},
	{"path": "res://scripts/tests/scenes/test_strike_new_pieces_4.gd", "layer": "scene", "domain": "battle", "kind": "scene_tree", "slow": true},
	{"path": "res://scripts/tests/scenes/test_codex_debug.gd", "layer": "scene", "domain": "ui", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_prebattle_scene.gd", "layer": "scene", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_fusion_interaction_scene.gd", "layer": "scene", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_main_menu_intro.gd", "layer": "scene", "domain": "ui", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_opening_draft_scene.gd", "layer": "scene", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_path_map_scene.gd", "layer": "scene", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_roster_scene.gd", "layer": "scene", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/scenes/test_responsive_safe_area.gd", "layer": "scene", "domain": "ui", "kind": "scene_tree"},
	{"path": "res://scripts/tests/smoke/test_autoload_smoke.gd", "layer": "smoke", "domain": "app", "kind": "scene_tree", "serial": true},
	{"path": "res://scripts/tests/smoke/test_boss_piece_skin_fallback.gd", "layer": "smoke", "domain": "assets", "kind": "scene_tree"},
	{"path": "res://scripts/tests/smoke/test_challenger_item_icons.gd", "layer": "smoke", "domain": "assets", "kind": "scene_tree"},
	{"path": "res://scripts/tests/smoke/test_localization_smoke.gd", "layer": "smoke", "domain": "localization", "kind": "scene_tree", "serial": true},
	{"path": "res://scripts/tests/smoke/test_new_piece_visual_contract.gd", "layer": "smoke", "domain": "assets", "kind": "scene_tree"},
	{"path": "res://scripts/tests/smoke/test_piece_skin.gd", "layer": "smoke", "domain": "assets", "kind": "scene_tree"},
	{"path": "res://scripts/tests/smoke/test_scene_routes.gd", "layer": "smoke", "domain": "navigation", "kind": "scene_tree"},
	{"path": "res://scripts/tests/smoke/test_ui_theme_font.gd", "layer": "smoke", "domain": "assets", "kind": "scene_tree"},
	{"path": "res://scripts/tests/characterization/test_legacy_battle_events.gd", "layer": "characterization", "domain": "legacy", "kind": "scene_tree"},
	{"path": "res://scripts/tests/e2e/test_complete_run_flow.gd", "layer": "e2e", "domain": "run", "kind": "scene_tree"},
	{"path": "res://scripts/tests/e2e/test_debug_victory.gd", "layer": "e2e", "domain": "battle", "kind": "scene_tree"},
	{"path": "res://scripts/tests/e2e/test_main_menu_run_flow.gd", "layer": "e2e", "domain": "run", "kind": "scene_tree"},
]

static func select(layer: String = "", domain: String = "", skip_slow: bool = false) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for entry_value: Variant in TESTS:
		var entry: Dictionary = entry_value as Dictionary
		if skip_slow and bool(entry.get("slow", false)):
			continue
		if not layer.is_empty() and str(entry.get("layer", "")) != layer:
			continue
		if not domain.is_empty() and str(entry.get("domain", "")) != domain:
			continue
		selected.append(entry)
	return selected

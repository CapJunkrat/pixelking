extends SceneTree

const TEST_PATH := "user://pixelking_run_flow_state_machine_test.save"

var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_expect(manager.create_run(42424242, RunState.MODE_STANDARD, true), "flow test creates a Run")
	_expect(manager.current_run.phase == RunPhase.OPENING_DRAFT, "new Run starts in opening draft")
	_expect_invalid_without_side_effects(manager, "map generation is blocked during opening draft", Callable(manager, "ensure_run_map"))

	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		_expect(manager.submit_opening_draft_choice(str(candidates[0])) == OK, "draft choice commits")
	_expect(manager.current_run.phase == RunPhase.MAP, "completed draft enters map phase")
	_expect(manager.ensure_run_map() == OK, "map generation is legal in map phase")

	var battle_node_id: StringName = _first_battle_node_id(manager)
	_expect(not battle_node_id.is_empty(), "test route exposes a battle")
	_expect(manager.select_map_node(battle_node_id) == OK, "battle node selection commits")
	_expect(manager.current_run.phase == RunPhase.NODE_SELECTED, "selection enters node-selected phase")
	_expect(manager.begin_deployment() == OK, "battle node enters deployment")
	_expect(manager.current_run.phase == RunPhase.DEPLOYMENT, "deployment phase is explicit")
	_expect(manager.confirm_deployment() == OK, "deployment confirmation commits")
	_expect(manager.current_run.phase == RunPhase.BATTLE_READY, "confirmed deployment enters battle-ready phase")
	_expect_invalid_without_side_effects(manager, "battle outcome is blocked before battle start", Callable(manager, "apply_battle_outcome").bind(true))

	_expect(manager.start_current_battle() == OK, "battle start commits")
	_expect(manager.current_run.phase == RunPhase.BATTLE_ACTIVE, "started battle is explicitly active")
	var active_save_data: Dictionary = manager.current_run.to_dictionary()
	_expect(manager.save_active_run() == OK, "active battle phase persists")
	var loader_script: Script = load("res://scripts/autoload/RunManager.gd") as Script
	var loader: AppRunManager = loader_script.new() as AppRunManager
	loader.configure_save_path(TEST_PATH)
	root.add_child(loader)
	await process_frame
	_expect(loader.load_active_run(), "persisted active battle reloads")
	_expect(loader.current_run.phase == RunPhase.BATTLE_READY, "reloaded active battle safely resumes as battle-ready")
	loader.queue_free()
	await process_frame

	_expect(manager.return_to_deployment() == OK, "active battle can return to deployment")
	_expect(manager.current_run.phase == RunPhase.DEPLOYMENT, "battle exit returns to deployment phase")
	_expect(manager.confirm_deployment() == OK, "returned deployment can be reconfirmed")
	_expect(manager.start_current_battle() == OK, "reconfirmed battle restarts")
	_expect(manager.apply_battle_outcome(true) == OK, "active battle accepts victory")
	_expect(manager.current_run.phase == RunPhase.POST_BATTLE_CHOICE, "victory enters post-battle choice")
	_expect(manager.current_run.is_phase_consistent(), "victory phase and payload remain consistent")

	_test_phase_migration_and_restore(manager.current_run, active_save_data)
	manager.abandon_run()
	_cleanup()
	_finish()

func _expect_invalid_without_side_effects(manager: AppRunManager, message: String, command: Callable) -> void:
	var before_run: Dictionary = manager.current_run.to_dictionary()
	var before_rng: Dictionary = manager.rng_service.snapshot_states()
	var result: Variant = command.call()
	_expect(int(result) == ERR_UNAVAILABLE, message)
	_expect(manager.current_run.to_dictionary() == before_run, "%s leaves Run unchanged" % message)
	_expect(manager.rng_service.snapshot_states() == before_rng, "%s leaves RNG unchanged" % message)

func _first_battle_node_id(manager: AppRunManager) -> StringName:
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		var definition: MapNodeDef = Content.map_node(node.node_type_id)
		if definition != null and definition.is_battle:
			return node_id
	return &""

func _test_phase_migration_and_restore(source_run: RunState, active_data: Dictionary) -> void:
	var legacy_data: Dictionary = source_run.to_dictionary()
	legacy_data["run_version"] = RunState.LEGACY_RUN_VERSION
	legacy_data.erase("phase")
	var migrated: RunState = RunState.new()
	_expect(migrated.load_from_dictionary(legacy_data), "v3 Run migrates to explicit phase")
	_expect(migrated.phase == RunPhase.POST_BATTLE_CHOICE, "v3 pending reward infers post-battle phase")
	_expect(migrated.was_migrated_from_legacy, "v3 migration is marked for resave")

	var restored_from_disk: RunState = RunState.new()
	_expect(restored_from_disk.load_from_dictionary(active_data), "v4 active battle save loads")
	_expect(restored_from_disk.phase == RunPhase.BATTLE_READY, "disk load normalizes active battle to ready")
	var cloned_in_memory: RunState = RunState.new()
	_expect(cloned_in_memory.load_from_dictionary(active_data, false), "active battle can be cloned without normalization")
	_expect(cloned_in_memory.phase == RunPhase.BATTLE_ACTIVE, "transaction clone preserves active phase")

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)

func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	print("[PASS] Run flow state machine test" if failures == 0 else "[FAIL] Run flow state machine test")
	quit(0 if failures == 0 else 1)

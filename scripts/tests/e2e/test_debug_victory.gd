extends SceneTree

const TEST_PATH := "user://pixelking_debug_victory_test.save"

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_expect(manager.create_run(42424242, RunState.MODE_STANDARD, true), "debug victory test creates a Run")
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		manager.submit_opening_draft_choice(str(candidates[0]))
	manager.ensure_run_map()
	var battle_node_id: StringName = &""
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		var definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
		if definition.is_battle:
			battle_node_id = node_id
			break
	_expect(not battle_node_id.is_empty(), "debug victory test finds a battle")
	manager.select_map_node(battle_node_id)
	manager.begin_deployment()
	manager.confirm_deployment()
	var game_state: Node = root.get_node("GameState")
	game_state.call("enable_debug_mode")
	_expect(manager.start_current_battle() == OK, "debug victory starts the actual Run battle")
	var battle_scene: PackedScene = load("res://scenes/battle/BattleScene.tscn") as PackedScene
	var battle: Control = battle_scene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	await process_frame
	battle.animation_player.event_delay_seconds = 0.2
	var turn_segment: PanelContainer = battle.get_node("Margin/Layout/TopBar").find_child("TurnSegment", true, false) as PanelContainer
	for _click_index: int in range(5):
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		turn_segment.gui_input.emit(click)
	var result_overlay: ColorRect = battle.get_node("ResultOverlay") as ColorRect
	_expect(not result_overlay.visible, "debug victory waits for the presentation barrier")
	_expect(not manager.map_progress_service.is_current_node_resolved(manager.current_run), "debug Run result waits until presentation completes")
	await battle.presentation_completed
	var flow: Node = battle.get_node("BattleFlow")
	_expect(result_overlay.visible, "five debug clicks display the result overlay")
	var localization: Node = root.get_node("Localization")
	var result_title: Label = flow.get("result_title") as Label
	_expect(result_title.text == str(localization.call("text", "BATTLE_VICTORY")), "five debug clicks award victory")
	_expect(manager.map_progress_service.is_current_node_resolved(manager.current_run), "debug victory resolves the active battle node")
	_expect(str(manager.current_run.pending_choice.get("type", "")) == "battle_reward", "debug victory enters normal victory rewards")
	var processor: BattleCommandProcessor = game_state.get("command_processor") as BattleCommandProcessor
	_expect(processor.status.is_finished() and processor.status.reason == &"debug_victory", "debug victory commits authoritative BattleStatus")
	var run_after_victory: Dictionary = manager.current_run.to_dictionary()
	_expect(not bool(game_state.call("try_move", Vector2i(0, 0), Vector2i(0, 1))), "debug-finished battle rejects later commands")
	flow.call("force_debug_victory")
	await process_frame
	_expect(manager.current_run.to_dictionary() == run_after_victory, "repeated debug victory cannot settle the Run twice")
	battle.queue_free()
	game_state.call("reset_debug_mode")
	manager.abandon_run()
	_cleanup()
	_finish()

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
	print("[PASS] Debug victory test" if failures == 0 else "[FAIL] Debug victory test")
	quit(0 if failures == 0 else 1)

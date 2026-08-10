extends SceneTree

const TEST_PATH := "user://pixelking_path_map_scene_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var run_manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	run_manager.configure_save_path(TEST_PATH)
	run_manager.abandon_run()
	_expect(run_manager.create_run(42424242, RunState.MODE_STANDARD, true), "path map scene test creates a Run")
	for _round_index: int in range(3):
		var candidates: Array = run_manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		run_manager.submit_opening_draft_choice(str(candidates[0]))
	var scene: PackedScene = load("res://scenes/run/PathMapScene.tscn") as PackedScene
	_expect(scene != null, "path map scene loads")
	if scene == null:
		_cleanup()
		_finish()
		return
	var path_map: PathMapScene = scene.instantiate() as PathMapScene
	root.add_child(path_map)
	await process_frame
	_expect(run_manager.current_run.map_state != null, "path map scene generates and persists missing map data")
	_expect(path_map.get_node("SafeArea/Layout/Footer/RosterButton") != null, "route map provides non-battle roster management access")
	var view: PathMapView = path_map.get_node("SafeArea/Layout/MapPanel/MapScroll/MapView") as PathMapView
	var cards: Array[Button] = view.node_buttons()
	_expect(cards.size() == run_manager.current_run.map_state.nodes.size(), "map view renders every public route node")
	var complete_information: bool = true
	for card: Button in cards:
		if card.text.split("\n").size() < 3 or str(card.get_meta("node_type_id", "")).is_empty():
			complete_information = false
			break
	_expect(complete_information, "every map card reveals type, enemy tendency, and reward category")
	var selectable_cards: Array[Button] = []
	for card: Button in cards:
		if not card.disabled:
			selectable_cards.append(card)
	_expect(selectable_cards.size() >= 2 and selectable_cards.size() <= 3, "first layer exposes two to three route choices")
	var selected_card: Button = selectable_cards[0]
	for candidate: Button in selectable_cards:
		var candidate_type_id: StringName = candidate.get_meta("node_type_id", &"")
		var candidate_definition: MapNodeDef = MapNodeDefDatabase.get_def(candidate_type_id)
		if candidate_definition != null and not candidate_definition.is_battle:
			selected_card = candidate
			break
	var selected_id: StringName = selected_card.get_meta("node_id", &"")
	selected_card.pressed.emit()
	await process_frame
	_expect(run_manager.current_run.current_node_id == selected_id, "tapping a map card transactionally locks the route")
	var overlay: ColorRect = path_map.get_node("NodeOverlay") as ColorRect
	_expect(overlay.visible, "selected node opens a full-information confirmation panel")
	_expect(run_manager.available_map_node_ids() == [selected_id], "unresolved selected node is the only resumable map action")
	var selected_node: MapNodeState = run_manager.current_run.map_state.get_node(selected_id)
	var selected_definition: MapNodeDef = MapNodeDefDatabase.get_def(selected_node.node_type_id)
	if not selected_definition.is_battle:
		var action_button: Button = path_map.get_node("NodeOverlay/Center/Panel/Content/ActionButton") as Button
		action_button.pressed.emit()
		await process_frame
		_expect(run_manager.map_progress_service.is_current_node_resolved(run_manager.current_run), "placeholder node action resolves and saves the current node")
		_expect(run_manager.available_map_node_ids() == selected_node.outgoing_node_ids, "placeholder resolution unlocks connected next-layer choices")
	path_map.queue_free()
	run_manager.abandon_run()
	_cleanup()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	print("[PASS] Path map scene test" if not failed else "[FAIL] Path map scene test")
	quit(1 if failed else 0)

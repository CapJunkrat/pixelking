extends SceneTree

const TEST_PATH := "user://pixelking_deployment_scene_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	_prepare_battle_run(manager)
	var scene: PackedScene = load("res://scenes/run/DeploymentScene.tscn") as PackedScene
	_expect(scene != null, "deployment scene loads")
	var deployment_scene: DeploymentScene = scene.instantiate() as DeploymentScene
	root.add_child(deployment_scene)
	await process_frame
	var grid: GridContainer = deployment_scene.get_node("SafeArea/Layout/BoardFrame/BoardCenter/BoardGrid") as GridContainer
	_expect(grid.columns == 5 and grid.get_child_count() == 25, "deployment scene renders the complete 5 x 5 board")
	var visible_player_count: int = 0
	var visible_enemy_count: int = 0
	for child: Node in grid.get_children():
		var square: Button = child as Button
		var position: Vector2i = square.get_meta("board_position", Vector2i(-1, -1))
		var texture: Texture2D = (square.get_node("Piece") as TextureRect).texture
		if texture == null:
			continue
		if manager.current_run.deployment_state.player_at(position) > 0:
			visible_player_count += 1
		else:
			visible_enemy_count += 1
	_expect(visible_player_count == manager.current_run.active_piece_ids.size(), "deployment shows every active player piece")
	_expect(visible_enemy_count == manager.current_run.deployment_state.enemy_placements.size(), "deployment reveals complete enemy setup")
	var king_id: int = manager.current_run.active_piece_ids[0]
	var source: Vector2i = manager.current_run.deployment_state.player_position(king_id)
	var target: Vector2i = _empty_player_square(manager.current_run.deployment_state)
	var source_button: Button = grid.get_node("Square_%d_%d" % [source.x, source.y]) as Button
	source_button.pressed.emit()
	await process_frame
	var target_button: Button = grid.get_node("Square_%d_%d" % [target.x, target.y]) as Button
	target_button.pressed.emit()
	await process_frame
	_expect(manager.current_run.deployment_state.player_position(king_id) == target, "board interaction freely repositions the King")
	_expect(deployment_scene.get_node("SafeArea/Layout/Actions/RosterButton") != null, "deployment provides roster management access")
	_expect(not (deployment_scene.get_node("SafeArea/Layout/Actions/ConfirmButton") as Button).disabled, "valid deployment enables battle confirmation")
	deployment_scene.queue_free()
	manager.abandon_run()
	_cleanup()
	_finish()

func _prepare_battle_run(manager: AppRunManager) -> void:
	manager.create_run(42424242, RunState.MODE_STANDARD, true)
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		manager.submit_opening_draft_choice(str(candidates[0]))
	for instance_id: int in manager.current_run.reserve_piece_ids.duplicate():
		manager.move_roster_piece(instance_id, true)
	manager.ensure_run_map()
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		if MapNodeDefDatabase.get_def(node.node_type_id).is_battle:
			manager.select_map_node(node_id)
			break
	manager.begin_deployment()

func _empty_player_square(deployment: DeploymentState) -> Vector2i:
	for y_position: int in range(2):
		for x_position: int in range(deployment.board_size):
			var position: Vector2i = Vector2i(x_position, y_position)
			if deployment.player_at(position) == 0:
				return position
	return Vector2i(-1, -1)

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
	print("[PASS] Deployment scene test" if not failed else "[FAIL] Deployment scene test")
	quit(1 if failed else 0)

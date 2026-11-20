extends SceneTree

## The pre-battle preview replaces the deployment step: it shows both sides on the
## board with the automatic formation, explains enemy pieces, swaps pieces between the
## battle line and the reserve, and starts the battle in one tap.

const TEST_PATH := "user://pixelking_prebattle_scene_test.save"
const SETTINGS_PATH := "user://pixelking_prebattle_scene_test_settings.cfg"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	var settings: Node = root.get_node("SettingsManager")
	var real_settings_path: String = settings.settings_path
	settings.configure_path(SETTINGS_PATH)
	settings.seen_tips.clear()
	manager.abandon_run()
	_prepare_battle_run(manager)
	_expect(manager.current_run.active_piece_ids.size() == 4, "the three drafted pieces join the battle line on their own")
	var scene: PackedScene = load(AppSceneRoutes.DEPLOYMENT) as PackedScene
	_expect(scene != null, "the pre-battle scene loads")
	var preview: PreBattleScene = scene.instantiate() as PreBattleScene
	root.add_child(preview)
	await process_frame
	await process_frame
	_expect(manager.current_run.phase == RunPhase.DEPLOYMENT, "opening the preview prepares the battle")
	_expect(preview.tip_bubble != null, "the first visit explains arranging once")
	preview._dismiss_tip()
	_expect(preview.tip_bubble == null and settings.has_seen_tip("prebattle_arrange"), "the tip is remembered once dismissed")
	var again: PreBattleScene = (load(AppSceneRoutes.DEPLOYMENT) as PackedScene).instantiate() as PreBattleScene
	root.add_child(again)
	await process_frame
	_expect(again.tip_bubble == null, "the tip never shows again")
	again.queue_free()
	await process_frame
	var board: DeploymentBoardView = preview.get_node("SafeArea/Layout/BoardFrame") as DeploymentBoardView
	var deployment: DeploymentState = manager.current_run.deployment_state
	_expect(board.board_size == 8 and board.piece_count(true) == manager.current_run.active_piece_ids.size(), "the board shows every active piece")
	_expect(board.piece_count(false) == deployment.enemy_placements.size(), "the board shows the whole enemy formation")
	var king_id: int = manager.current_run.active_piece_ids[0]
	_expect(deployment.player_position(king_id) == Vector2i(2, 0), "the King stands in the middle of the back rank of your corner")
	for instance_id: int in manager.current_run.active_piece_ids:
		_expect(DeploymentState.is_player_zone(deployment.player_position(instance_id), 8), "your pieces start in the bottom-left corner")
	for placement: Dictionary in deployment.enemy_placements:
		_expect(DeploymentState.is_enemy_zone(DeploymentState.position_from_value(placement.get("position", {})), 8), "enemies start in the top-right corner")

	var details: Node = preview.get_node("SafeArea/Layout")
	_expect(preview.find_children("*", "ScrollContainer", true, false).size() == 1, "only the details area scrolls, not the page")
	_expect(preview.get_node_or_null("SafeArea/Layout/TitleLabel") == null, "the redundant title and description are gone")
	_expect(preview.find_child("EnemyPieces", true, false) == null, "the row of enemy icons is gone: tap the pieces on the board instead")
	_expect(preview.find_child("LineBadge", true, false) != null and preview.count_label.text == "%d/%d" % [manager.current_run.active_piece_ids.size() - 1, manager.current_run.max_active_pieces()], "the head shows how many pieces are on the board")
	_expect(preview.status_label.visible == false, "no instruction text is shown")
	_expect(details.find_child("ActiveRow", true, false) == null and preview.find_child("ArrangeRow", true, false) == null, "no battle-line row, tip or reset button")
	var pattern: PanelContainer = details.find_child("PiecePattern", true, false) as PanelContainer
	var lineup: Control = details.find_child("Lineup", true, false) as Control
	var strip: HBoxContainer = details.find_child("ItemStrip", true, false) as HBoxContainer
	_expect(pattern.visible and pattern.find_child("DetailsHint", true, false) != null, "the details area invites a tap on a piece until one is chosen")
	_expect(lineup.visible and strip.visible, "the reserve and the item bar are always shown")
	var board_rect: Rect2 = board.get_global_rect()
	var enemy_square: Vector2i = DeploymentState.position_from_value(deployment.enemy_placements[0].get("position", {}))
	board.square_pressed.emit(enemy_square)
	await process_frame
	await process_frame
	_expect(preview.focus_id == str(deployment.enemy_placements[0].get("piece_def_id", "")) and pattern.find_child("DetailsHint", true, false) == null, "tapping an enemy on the board shows its details")
	_expect(lineup.visible and strip.visible, "the reserve and items stay while a piece is explained")
	_expect(board.get_global_rect() == board_rect, "showing details does not move the board")
	_expect(not board.hints.is_empty(), "the chosen enemy's reach is marked on the board")
	board.square_pressed.emit(Vector2i(0, 5))
	await process_frame
	await process_frame
	_expect(preview.focus_id.is_empty() and pattern.find_child("DetailsHint", true, false) != null, "a tap on an empty square goes back to the hint")
	_expect(board.hints.is_empty(), "closing it clears the marks")
	_expect(board.get_global_rect() == board_rect, "closing it does not move the board either")
	board.square_pressed.emit(Vector2i(2, 0))
	await process_frame
	_expect(preview.focus_id == "own:%d" % king_id, "tapping your own piece shows its details too")
	board.square_pressed.emit(Vector2i(2, 0))
	await process_frame
	board.square_pressed.emit(Vector2i(0, 5))
	await process_frame
	manager.current_run.challenger_slots.append(&"holy_water")
	preview._render_items()
	_expect(strip.get_child_count() == 5, "your five item slots are shown before the battle")
	(strip.get_node("Item_holy_water") as Button).pressed.emit()
	await process_frame
	_expect(preview.focus_id == "item:holy_water", "tapping an item explains it")
	board.square_pressed.emit(Vector2i(0, 5))
	await process_frame
	_expect(preview.focus_id.is_empty(), "a tap on the board closes the item explanation")
	manager.current_run.challenger_slots.erase(&"holy_water")

	# Bench a piece from the board and bring it back: the board is the battle line.
	var moved_id: int = manager.current_run.active_piece_ids[1]
	var moved_square: Vector2i = manager.current_run.deployment_state.player_position(moved_id)
	var reserve_row: HBoxContainer = details.find_child("ReserveRow", true, false) as HBoxContainer
	_expect((reserve_row.get_child(0) as Button).disabled, "empty reserve places wait until a piece is picked up")
	board.square_pressed.emit(moved_square)
	await process_frame
	_expect(not (reserve_row.get_child(0) as Button).disabled, "picking up a piece opens the reserve places")
	(reserve_row.get_child(0) as Button).pressed.emit()
	await process_frame
	_expect(moved_id in manager.current_run.reserve_piece_ids and board.piece_count(true) == 3, "tapping a reserve place benches the piece in hand")
	(reserve_row.get_node("Piece_%d" % moved_id) as Button).pressed.emit()
	await process_frame
	_expect(moved_id in manager.current_run.active_piece_ids and manager.current_run.deployment_state.player_position(moved_id).y <= 1, "tapping a reserve piece sends it back in and places it")
	# Swap: hold a board piece and tap a reserve piece; the newcomer takes its square.
	var other_id: int = manager.current_run.active_piece_ids[2]
	board.square_pressed.emit(manager.current_run.deployment_state.player_position(moved_id))
	await process_frame
	(reserve_row.get_child(0) as Button).pressed.emit()
	await process_frame
	var other_square: Vector2i = manager.current_run.deployment_state.player_position(other_id)
	board.square_pressed.emit(other_square)
	await process_frame
	(reserve_row.get_node("Piece_%d" % moved_id) as Button).pressed.emit()
	await process_frame
	_expect(other_id in manager.current_run.reserve_piece_ids and manager.current_run.deployment_state.player_position(moved_id) == other_square, "a reserve piece swaps in onto the square of the piece in hand")
	(reserve_row.get_node("Piece_%d" % other_id) as Button).pressed.emit()
	await process_frame

	# Arrange by hand: move the King one file left; the choice is kept for the Run.
	_expect(preview.get_node_or_null("SafeArea/Layout/ArrangeRow/ArrangeButton") == null, "arranging needs no mode button")
	board.square_pressed.emit(Vector2i(2, 0))
	_expect(board.deploy_rows == DeploymentState.PLAYER_ROWS and board.selected_square == Vector2i(2, 0), "tapping your piece picks it up and lights your corner")
	_expect(board.is_deploy_square(Vector2i(4, 2)) and not board.is_deploy_square(Vector2i(5, 0)), "the lit zone is the bottom-left corner only")
	board.square_pressed.emit(Vector2i(6, 1))
	await process_frame
	_expect(manager.current_run.deployment_state.player_position(king_id) == Vector2i(2, 0), "a square outside the corner does not take the piece")
	board.square_pressed.emit(Vector2i(5, 7))
	_expect(preview.arrange_selected == 0 and board.deploy_rows == 0, "tapping elsewhere puts the piece back down")
	board.square_pressed.emit(Vector2i(2, 0))
	board.square_pressed.emit(Vector2i(3, 0))
	await process_frame
	_expect(manager.current_run.deployment_state.player_position(king_id) == Vector2i(3, 0), "arranging moves the King where the player taps")
	_expect(DeploymentState.position_from_value(manager.current_run.preferred_positions.get(str(king_id), {})) == Vector2i(3, 0), "the hand-placed square is remembered for the Run")
	manager.reset_deployment_formation()
	_expect(manager.current_run.preferred_positions.is_empty(), "the formation can still be reset by the game")

	# Line and reserve both full: pick up a reserve piece, then tap a board piece to trade.
	while manager.current_run.allocate_piece("pawn") != null:
		pass
	manager.deployment_service.synchronize_with_roster(manager.current_run)
	preview._render()
	await process_frame
	_expect(manager.current_run.reserve_piece_ids.size() == RunState.MAX_RESERVE_PIECES, "both the line and the reserve are full")
	var bench_id: int = manager.current_run.reserve_piece_ids[0]
	var line_id: int = manager.current_run.active_piece_ids[1]
	var line_square: Vector2i = manager.current_run.deployment_state.player_position(line_id)
	(reserve_row.get_node("Piece_%d" % bench_id) as Button).pressed.emit()
	await process_frame
	_expect(preview.reserve_held == bench_id and bench_id in manager.current_run.reserve_piece_ids, "with the line full a reserve piece is picked up, not refused")
	board.square_pressed.emit(line_square)
	await process_frame
	_expect(preview.reserve_held == 0 and bench_id in manager.current_run.active_piece_ids and line_id in manager.current_run.reserve_piece_ids, "tapping a board piece trades it for the reserve piece in hand")
	_expect(manager.current_run.deployment_state.player_position(bench_id) == line_square, "the reserve piece takes the traded piece's square")
	board.square_pressed.emit(line_square)
	await process_frame
	(reserve_row.get_node("Piece_%d" % line_id) as Button).pressed.emit()
	await process_frame
	_expect(line_id in manager.current_run.active_piece_ids and manager.current_run.deployment_state.player_position(line_id) == line_square, "holding a board piece and tapping a reserve piece trades them while both sides are full")

	# Stacked pieces: tapping the same spot again picks up the next piece instead of
	# moving the piece in hand onto it.
	preview._put_down()
	var spot: Vector2 = Vector2(INF, INF)
	var stack: Array[Vector2i] = []
	for key: Variant in board._sprites:
		var foot: Vector2 = (board._sprites[key] as Sprite2D).position
		for step: int in range(4, 120, 2):
			var probe: Vector2 = foot + Vector2(0, -step)
			var under: Array[Vector2i] = BoardPainter.pieces_under(probe, board.projection.screen_to_square(probe), board._sprites)
			if under.size() >= 2 and manager.current_run.deployment_state.player_at(under[0]) > 0 and manager.current_run.deployment_state.player_at(under[1]) > 0:
				spot = probe
				stack = under
				break
		if spot.x != INF:
			break
	_expect(spot.x != INF, "two of your pieces stand stacked on screen")
	var before_cycle: Dictionary = manager.current_run.deployment_state.player_positions.duplicate()
	var first_id: int = manager.current_run.deployment_state.player_at(stack[0])
	var second_id: int = manager.current_run.deployment_state.player_at(stack[1])
	var stacked_tap: InputEventMouseButton = InputEventMouseButton.new()
	stacked_tap.button_index = MOUSE_BUTTON_LEFT
	stacked_tap.pressed = true
	stacked_tap.position = spot
	board._gui_input(stacked_tap)
	await process_frame
	_expect(preview.arrange_selected == first_id, "the first tap picks up the piece on the tapped square")
	# The piece in hand floats, so look again from the same spot.
	stacked_tap.position = spot
	board._gui_input(stacked_tap)
	await process_frame
	_expect(preview.arrange_selected == second_id, "tapping the same spot again picks up the stacked piece instead")
	_expect(manager.current_run.deployment_state.player_positions == before_cycle, "stepping through stacked pieces never moves them")
	preview._put_down()

	# Back to the map and in again: the battle stays chosen and can be re-entered.
	_expect(manager.leave_deployment() == OK and manager.current_run.phase == RunPhase.NODE_SELECTED, "leaving the preview returns the run to the map")
	_expect(manager.resume_scene_path() == AppSceneRoutes.PATH_MAP, "after leaving, the game resumes on the map (not the preview)")
	_expect(manager.current_run.current_node_id in manager.available_map_node_ids(), "the chosen battle can be tapped again on the map")
	_expect(manager.begin_deployment() == OK and manager.current_run.phase == RunPhase.DEPLOYMENT, "entering it again prepares the battle again")
	preview._render()
	(preview.get_node("SafeArea/Layout/Actions/FightButton") as Button).pressed.emit()
	await process_frame
	_expect(manager.current_run.phase == RunPhase.BATTLE_ACTIVE, "Fight starts the battle in one tap")
	manager.abandon_run()
	settings.configure_path(real_settings_path)
	settings.load_settings()
	_cleanup()
	_finish()

func _prepare_battle_run(manager: AppRunManager) -> void:
	manager.create_run(42424242, RunState.MODE_STANDARD, true)
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		manager.submit_opening_draft_choice(str(candidates[0]))
	manager.ensure_run_map()
	for node_id: StringName in manager.available_map_node_ids():
		var node: MapNodeState = manager.current_run.map_state.get_node(node_id)
		if MapNodeDefDatabase.get_def(node.node_type_id).is_battle:
			manager.select_map_node(node_id)
			break

## A tap (press and release on the same spot) on the open explanation.
func _tap(preview: PreBattleScene, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.global_position = at
		event.position = at
		preview._on_pattern_input(event)
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak", SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _finish() -> void:
	print("[PASS] Pre-battle scene test" if not failed else "[FAIL] Pre-battle scene test")
	quit(1 if failed else 0)

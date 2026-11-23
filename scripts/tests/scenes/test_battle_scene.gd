extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	var scene := load("res://scenes/battle/BattleScene.tscn") as PackedScene
	if scene == null:
		_fail("Battle scene must load")
		_finish()
		return
	var battle := scene.instantiate()
	root.add_child(battle)
	await process_frame

	_expect(battle.get_node("Margin/Layout/BoardFrame") is BattleBoardView, "battle board is extracted into a static scene component")
	var board_view := battle.get_node("Margin/Layout/BoardFrame") as BattleBoardView
	_expect(board_view.projection.board_size == 8, "battle board follows the standard 8 x 8 board size")
	_expect(board_view.square_count() == 64, "battle board exposes one square per board cell")
	var round_trip := true
	for y: int in range(8):
		for x: int in range(8):
			if board_view.projection.screen_to_square(board_view.square_center(Vector2i(x, y))) != Vector2i(x, y):
				round_trip = false
	_expect(round_trip, "every square centre maps back to its own square on the tilted board")
	_expect(board_view.projection.screen_to_square(Vector2(-50, -50)) == Vector2i(-1, -1), "points off the board select no square")
	_expect(board_view.square_center(Vector2i(0, 0)).y > board_view.square_center(Vector2i(0, 7)).y, "the player's home rank is drawn nearest the viewer")
	_expect(board_view.projection.square_scale(Vector2i(0, 0)) > board_view.projection.square_scale(Vector2i(0, 7)), "nearer squares are drawn larger than far squares")
	_expect(board_view.get_node("PieceLayer").get_child_count() == 32, "battle board shows one standing sprite per piece")
	_expect(battle.get_node("Margin/Layout/TopBar") is BattleHUD, "battle HUD is extracted into a static scene component")
	_expect(battle.get_node("Margin/Layout/TopBar/SettingsButton") != null, "top bar owns the settings button")
	_expect(battle.get_node("SettingsOverlay") is BattleSettingsPanel, "battle settings are extracted into a static scene component")
	_expect(battle.get_node_or_null("Margin/Layout/BackButton") == null, "persistent bottom return button is removed")
	_expect(battle.get_node("Margin/Layout/ChallengerPanel") is ChallengerTray, "challenger tray is extracted into a static scene component")
	_expect(battle.challenger_slots.size() == 5, "persistent and consumable objects share five challenger slots")

	var gear := battle.get_node("Margin/Layout/TopBar/SettingsButton") as Button
	gear.pressed.emit()
	await process_frame
	_expect(battle.settings_overlay.visible, "settings icon opens the battle settings overlay")
	battle.settings_overlay.hide()

	var knight_sprite := board_view.get_node("PieceLayer/Piece_1_0") as Sprite2D
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = knight_sprite.position + Vector2(0, -12)
	board_view._gui_input(tap)
	await process_frame
	_expect(battle.selected_square == Vector2i(1, 0), "clicking the current player's knight selects it")
	_expect(Vector2i(0, 2) in battle.legal_targets, "selected knight exposes its legal move")
	# Stacked pieces: a tap on the knight's head over the pawn's square picks the pawn
	# (the board decides); tapping the same spot again steps to the knight, then back.
	var knight_foot: Vector2 = (board_view.get_node("PieceLayer/Piece_1_0") as Sprite2D).position
	var stacked: Vector2 = Vector2(INF, INF)
	for step: int in range(4, 120):
		var probe: Vector2 = knight_foot + Vector2(0, -step)
		var under: Array[Vector2i] = board_view.pieces_at(probe)
		if board_view.projection.screen_to_square(probe) == Vector2i(1, 1) and under.size() >= 2 and under[0] == Vector2i(1, 1) and Vector2i(1, 0) in under:
			stacked = probe
			break
	_expect(stacked.x != INF, "the knight's figure covers part of the pawn's square behind it")
	var tap_stacked: InputEventMouseButton = InputEventMouseButton.new()
	tap_stacked.button_index = MOUSE_BUTTON_LEFT
	tap_stacked.pressed = true
	tap_stacked.position = stacked
	board_view._gui_input(tap_stacked)
	await process_frame
	_expect(battle.selected_square == Vector2i(1, 1), "the first tap picks the piece on the tapped board square")
	board_view._gui_input(tap_stacked)
	await process_frame
	_expect(battle.selected_square == Vector2i(1, 0), "tapping the same spot again steps to the piece stacked in front")
	board_view._gui_input(tap_stacked)
	await process_frame
	_expect(battle.selected_square == Vector2i(1, 1), "and once more wraps round to the first piece")
	var away: InputEventMouseButton = tap_stacked.duplicate() as InputEventMouseButton
	away.position = knight_foot + Vector2(0, -12)
	board_view._gui_input(away)
	await process_frame
	_expect(battle.selected_square == Vector2i(1, 0), "a tap elsewhere starts afresh from the board square")

	# Tapping an enemy piece shows its reach in its own colours, without selecting it.
	board_view.press_square(Vector2i(1, 7))
	await process_frame
	_expect(board_view.inspected_square == Vector2i(1, 7) and battle.selected_square == Vector2i(-1, -1), "tapping an enemy knight shows its reach and selects nothing")
	_expect(Vector2i(2, 5) in board_view.inspect_moves and board_view.legal_targets.is_empty(), "its moves are listed apart from your own move hints")
	_expect(BoardMarkerLayer.INSPECT_DOT != BoardMarkerLayer.MOVE_DOT and BoardMarkerLayer.INSPECT_THREAT != BoardMarkerLayer.CAPTURE_TINT, "enemy reach is drawn in different colours from your own")
	board_view.press_square(Vector2i(1, 7))
	await process_frame
	_expect(board_view.inspected_square == Vector2i(-1, -1), "tapping it again hides its reach")
	board_view.press_square(Vector2i(1, 7))
	board_view.press_square(Vector2i(1, 0))
	await process_frame
	_expect(board_view.inspected_square == Vector2i(-1, -1) and battle.selected_square == Vector2i(1, 0), "tapping your own piece replaces the enemy reach with your selection")

	battle.animation_player.playback_speed = 0.1
	_expect(board_view.square_at(board_view.square_center(Vector2i(0, 2))) == Vector2i(0, 2), "a legal destination wins the tap even when a piece stands in front of it")
	board_view.press_square(Vector2i(0, 2))
	await process_frame
	_expect(game_state.board.get_piece(Vector2i(0, 2)) != null, "board click dispatches the selected legal move")
	_expect(not battle.board_view.input_enabled, "battle input locks while presentation is active")
	_expect(battle.battle_flow.phase == BattleFlowController.Phase.PRESENTING, "turn flow waits at the presentation barrier")
	await create_timer(0.55).timeout
	_expect(game_state.board.move_history.size() == 1, "enemy AI cannot move before the player presentation completes")
	await battle.presentation_started
	_expect(game_state.board.move_history.size() == 2, "enemy AI dispatches one reply after the player presentation")
	await battle.presentation_completed
	_expect(battle.board_view.input_enabled, "enemy presentation completion returns input to the player")
	_expect(battle.get_node("ResultOverlay") is BattleResultPanel, "battle result panel is extracted into a static scene component")
	_expect(battle.get_node("Margin/Layout/BattleLogPanel") is BattleLogPanel, "battle log consumes the domain event stream")
	_expect(battle.get_node("BattleAnimationLayer") is BattleAnimationPlayer, "battle animation layer is isolated from authoritative state")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_fail(message)

func _fail(message: String) -> void:
	failed = true
	push_error(message)

func _finish() -> void:
	print("[PASS] Battle scene test" if not failed else "[FAIL] Battle scene test")
	quit(1 if failed else 0)

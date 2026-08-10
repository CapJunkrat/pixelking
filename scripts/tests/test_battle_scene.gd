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

	var grid := battle.get_node("Margin/Layout/BoardFrame/BoardCenter/BoardGrid") as GridContainer
	_expect(grid.columns == 5, "battle grid follows the 5x5 board size")
	_expect(grid.get_child_count() == 25, "battle grid creates one control per square")
	var pawn_count := 0
	for x in range(game_state.board.board_size):
		for y in range(game_state.board.board_size):
			var piece: ChessPiece = game_state.board.get_piece(Vector2i(x, y))
			if piece != null and piece.def.is_pawn:
				pawn_count += 1
	_expect(pawn_count == 0, "the temporary battle setup contains no pawns")
	_expect(battle.get_node("Margin/Layout/TopBar/SettingsButton") != null, "top bar owns the settings button")
	_expect(not battle.get_node("Margin/Layout/BackButton").visible, "persistent bottom return button is removed")
	_expect(battle.challenger_slots.size() == 6, "persistent and consumable objects share six challenger slots")

	var gear := battle.get_node("Margin/Layout/TopBar/SettingsButton") as Button
	gear.pressed.emit()
	await process_frame
	_expect(battle.settings_overlay.visible, "settings icon opens the battle settings overlay")
	battle.settings_overlay.hide()

	var persistent := ChallengerItemDef.new()
	var consumable := ChallengerItemDef.new()
	consumable.usage_mode = ChallengerItemDef.UsageMode.CONSUMABLE
	_expect(not persistent.is_consumable() and consumable.is_consumable(), "challenger items encode persistent versus one-use behavior")

	var pawn := battle.get_node("Margin/Layout/BoardFrame/BoardCenter/BoardGrid/Square_1_0") as Button
	pawn.pressed.emit()
	await process_frame
	_expect(battle.selected_square == Vector2i(1, 0), "clicking the current player's knight selects it")
	_expect(Vector2i(0, 2) in battle.legal_targets, "selected knight exposes its legal move")

	var target := battle.get_node("Margin/Layout/BoardFrame/BoardCenter/BoardGrid/Square_0_2") as Button
	target.pressed.emit()
	await process_frame
	_expect(game_state.board.get_piece(Vector2i(0, 2)) != null, "clicking a legal knight target executes the move")
	_expect(game_state.board.turn == GameRules.PieceColor.BLACK, "successful move advances the turn")
	await create_timer(0.7).timeout
	_expect(game_state.board.move_history.size() == 2, "enemy AI automatically chooses and executes a reply")
	_expect(game_state.board.turn == GameRules.PieceColor.WHITE, "enemy reply returns control to the player")
	_expect(battle.get_node("ResultOverlay") != null, "battle flow creates the terminal result overlay")
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

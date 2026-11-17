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
	var grid := battle.get_node("Margin/Layout/BoardFrame/BoardCenter/BoardGrid") as GridContainer
	_expect(grid.columns == 8, "battle grid follows the standard 8 x 8 board size")
	_expect(grid.get_child_count() == 64, "battle grid creates one control per square")
	_expect(battle.get_node("Margin/Layout/TopBar") is BattleHUD, "battle HUD is extracted into a static scene component")
	_expect(battle.get_node("Margin/Layout/TopBar/SettingsButton") != null, "top bar owns the settings button")
	_expect(battle.get_node("SettingsOverlay") is BattleSettingsPanel, "battle settings are extracted into a static scene component")
	_expect(battle.get_node_or_null("Margin/Layout/BackButton") == null, "persistent bottom return button is removed")
	_expect(battle.get_node("Margin/Layout/ChallengerPanel") is ChallengerTray, "challenger tray is extracted into a static scene component")
	_expect(battle.challenger_slots.size() == 6, "persistent and consumable objects share six challenger slots")

	var gear := battle.get_node("Margin/Layout/TopBar/SettingsButton") as Button
	gear.pressed.emit()
	await process_frame
	_expect(battle.settings_overlay.visible, "settings icon opens the battle settings overlay")
	battle.settings_overlay.hide()

	var pawn := battle.get_node("Margin/Layout/BoardFrame/BoardCenter/BoardGrid/Square_1_0") as Button
	pawn.pressed.emit()
	await process_frame
	_expect(battle.selected_square == Vector2i(1, 0), "clicking the current player's knight selects it")
	_expect(Vector2i(0, 2) in battle.legal_targets, "selected knight exposes its legal move")

	battle.animation_player.playback_speed = 0.1
	var target := battle.get_node("Margin/Layout/BoardFrame/BoardCenter/BoardGrid/Square_0_2") as Button
	target.pressed.emit()
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

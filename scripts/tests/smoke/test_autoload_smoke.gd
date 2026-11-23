extends SceneTree

## 验证核心 autoload 在真实项目运行环境下可用。
## 可单独运行，通常由 res://scripts/tests/runner/run_all_tests.gd 调度。

func _init() -> void:
	print("===== Autoload smoke test =====")
	await process_frame

	var game_state: Node = root.get_node("GameState")
	var settings_manager: Node = root.get_node("SettingsManager")
	var audio_manager: Node = root.get_node("AudioManager")
	var run_manager: Node = root.get_node("RunManager")
	var ok: bool = true

	if game_state == null:
		print("[FAIL] GameState autoload was not found")
		ok = false
	elif game_state.get("board") == null:
		print("[FAIL] GameState.board was not initialized")
		ok = false
	else:
		print("[PASS] GameState autoload and initial board are ready")

	if settings_manager == null or audio_manager == null or run_manager == null:
		print("[FAIL] SettingsManager, AudioManager, or RunManager autoload was not found")
		ok = false
	else:
		print("[PASS] Settings, audio, and Run autoloads are ready")
		if run_manager.get("current_run") != null:
			print("[PASS] RunManager safely restored an existing active Run")
		else:
			print("[PASS] RunManager starts without creating an unwanted Run")

	var got_signal: Array[bool] = [false]
	game_state.battle_events_emitted.connect(func(events: Array[BattleEvent]) -> void:
		for event: BattleEvent in events:
			if event.event_type == BattleCommandProcessor.EVENT_PIECE_MOVED:
				got_signal[0] = true)
	var success: bool = game_state.call("try_move", Vector2i(1, 0), Vector2i(0, 2))
	if success and got_signal[0]:
		print("[PASS] GameState.try_move executes a move and publishes piece_moved")
	else:
		print("[FAIL] Move execution or signal emission failed (success=%s, signal=%s)" % [success, got_signal[0]])
		ok = false

	var illegal: bool = game_state.call("try_move", Vector2i(0, 0), Vector2i(0, 5))
	if not illegal:
		print("[PASS] Illegal move was rejected")
	else:
		print("[FAIL] Illegal move was unexpectedly accepted")
		ok = false

	print("===== Result: %s =====" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)

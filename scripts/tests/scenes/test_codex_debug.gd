extends SceneTree

const META_PATH := "user://pixelking_codex_debug_test.save"

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var meta: MetaProgressService = MetaProgressService.new(META_PATH)
	_expect(meta.discovered_piece_ids().is_empty(), "fresh codex starts empty")
	_expect(meta.record_discovered_piece_ids(["pawn", "knight", "missing_piece"]) == OK, "visible pieces persist")
	var discovered: Array[String] = meta.discovered_piece_ids()
	_expect("pawn" in discovered and "knight" in discovered, "known visible pieces unlock")
	_expect("missing_piece" not in discovered, "invalid piece ids are ignored")
	_expect(meta.record_discovered_piece_ids(["rook", "pawn"]) == OK, "codex progress merges")
	discovered = meta.discovered_piece_ids()
	_expect(discovered.size() == 3 and "rook" in discovered, "codex progress is unique and cumulative")
	_expect(meta.record({"best_acts": 4}, {"total_kills": 7}) == OK, "statistics save")
	_expect(meta.stat("best_acts") == 4 and meta.stat("total_kills") == 7, "statistics are readable")
	_expect(meta.record({"best_acts": 2}, {"total_kills": 3}) == OK and meta.stat("best_acts") == 4 and meta.stat("total_kills") == 10, "a best only rises, a total adds up")
	_expect(meta.discovered_piece_ids().size() == 3, "statistics keep codex progress")
	_expect(meta.stat("codex") == 3, "codex pages count as a statistic")
	var fresh: Array[String] = meta.unlock_reached_achievements()
	_expect("act_3" in fresh and "act_5" not in fresh, "reached achievements unlock (%s)" % [fresh])
	_expect(meta.unlock_reached_achievements().is_empty(), "an achievement unlocks only once")
	_expect("act_3" in meta.unlocked_achievement_ids(), "unlocked achievements are saved")
	_expect(meta.record_boss("boss_war_king") == OK and meta.record_boss("boss_war_king") == OK and meta.stat("bosses") == 1, "each Boss counts once")
	# An old save (version 2) with endless mode: its best result becomes best_acts.
	var old_file: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"version": 2, "endless_unlocked": true, "best_endless_acts": 6, "discovered_piece_ids": ["pawn"]}))
	old_file.close()
	_expect(meta.stat("best_acts") == 6 and meta.discovered_piece_ids() == (["pawn"] as Array[String]), "an endless-era save migrates to best_acts")
	old_file = FileAccess.open(META_PATH, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"version": 2, "endless_unlocked": true, "discovered_piece_ids": []}))
	old_file.close()
	_expect(meta.stat("best_acts") == RunState.ACT_COUNT, "a won journey from the old save counts as Act 3 cleared")
	var game_state: Node = root.get_node("GameState")
	game_state.set("debug_mode", false)
	game_state.call("enable_debug_mode")
	_expect(bool(game_state.get("debug_mode")), "debug mode can be enabled for the session")
	game_state.call("reset_debug_mode")
	_expect(not bool(game_state.get("debug_mode")), "debug mode can be reset")
	_cleanup()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)

func _cleanup() -> void:
	if FileAccess.file_exists(META_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))

func _finish() -> void:
	print("[PASS] Codex/debug test" if failures == 0 else "[FAIL] Codex/debug test")
	quit(0 if failures == 0 else 1)

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
	_expect(meta.unlock_endless() == OK, "endless unlock still saves")
	_expect(meta.endless_unlocked(), "endless unlock remains readable")
	_expect(meta.discovered_piece_ids().size() == 3, "endless save preserves codex progress")
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

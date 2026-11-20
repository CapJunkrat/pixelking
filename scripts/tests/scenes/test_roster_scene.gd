extends SceneTree

const TEST_PATH := "user://pixelking_roster_scene_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	manager.create_run(313131, RunState.MODE_STANDARD, true)
	for _round_index: int in range(3):
		var candidates: Array = manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
		manager.submit_opening_draft_choice(str(candidates[0]))
	# Drafted pieces start on the battle line; bench one so the reserve has a card.
	manager.move_roster_piece(manager.current_run.active_piece_ids[1], false)
	var scene: PackedScene = load("res://scenes/run/RosterScene.tscn") as PackedScene
	_expect(scene != null, "roster scene loads")
	var roster_scene: RosterScene = scene.instantiate() as RosterScene
	root.add_child(roster_scene)
	await process_frame
	var line_grid: GridContainer = roster_scene.line_grid
	var reserve_grid: GridContainer = roster_scene.reserve_grid
	_expect(line_grid.get_child_count() == 6, "the battle line shows the King plus five places")
	_expect(reserve_grid.get_child_count() == 5, "the reserve shows five places")
	_expect(roster_scene.item_row.get_child_count() == 5, "the five item slots are shown")
	_expect(roster_scene.detail_scroll.has_node("DragScroll"), "the explanation card scrolls by dragging its text")
	var king_tile: Button = line_grid.get_child(0) as Button
	_expect(int(king_tile.get_meta("instance_id", 0)) == manager.current_run.active_piece_ids[0], "the King is first on the battle line")
	king_tile.pressed.emit()
	await process_frame
	_expect(roster_scene.selected.begins_with("piece:") and not roster_scene.move_button.visible, "the King is explained but cannot be benched")
	_expect(roster_scene.detail_body.find_child("DetailContent", true, false) != null, "roster uses shared complete rule sections, not independent prose")
	var reserve_tile: Button = null
	for child: Node in reserve_grid.get_children():
		if child.has_meta("instance_id"):
			reserve_tile = child as Button
			break
	_expect(reserve_tile != null, "the benched piece has a reserve tile")
	var selected_id: int = int(reserve_tile.get_meta("instance_id", 0))
	reserve_tile.pressed.emit()
	await process_frame
	_expect(selected_id in manager.current_run.reserve_piece_ids, "tapping a tile only explains it")
	_expect(roster_scene.move_button.visible, "a reserve piece can be sent to the battle line")
	roster_scene.move_button.pressed.emit()
	await process_frame
	_expect(selected_id in manager.current_run.active_piece_ids, "sending it moves it to the battle line")
	_expect(selected_id not in manager.current_run.reserve_piece_ids, "and out of the reserve")
	_expect(roster_scene.selected == "piece:%d" % selected_id, "the piece stays chosen after moving")
	# Both rows full: tap a line piece, then a reserve piece, and the two trade places.
	while manager.current_run.allocate_piece("pawn") != null:
		pass
	roster_scene.selected = ""
	roster_scene._render()
	var line_id: int = manager.current_run.active_piece_ids[2]
	var bench_id: int = manager.current_run.reserve_piece_ids[0]
	(line_grid.get_node("Piece_%d" % line_id) as Button).pressed.emit()
	await process_frame
	(reserve_grid.get_node("Piece_%d" % bench_id) as Button).pressed.emit()
	await process_frame
	_expect(bench_id in manager.current_run.active_piece_ids and line_id in manager.current_run.reserve_piece_ids, "tapping a line piece then a reserve piece swaps them while both rows are full")
	_expect(roster_scene.selected.is_empty(), "the swap clears the selection")
	roster_scene.queue_free()
	manager.abandon_run()
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
	print("[PASS] Roster scene test" if not failed else "[FAIL] Roster scene test")
	quit(1 if failed else 0)

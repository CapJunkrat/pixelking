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
	var active_list: VBoxContainer = roster_scene.get_node("SafeArea/Layout/Columns/ActivePanel/Content/ActiveList") as VBoxContainer
	var reserve_list: VBoxContainer = roster_scene.get_node("SafeArea/Layout/Columns/ReservePanel/Content/ReserveList") as VBoxContainer
	_expect(active_list.get_child_count() == 6, "roster scene displays King plus five active slots")
	_expect(reserve_list.get_child_count() == 5, "roster scene displays five reserve slots")
	var king_card: Button = active_list.get_child(0) as Button
	_expect(king_card.disabled and int(king_card.get_meta("instance_id", 0)) > 0, "King card is visible and locked active")
	var reserve_card: Button = null
	for child: Node in reserve_list.get_children():
		var button: Button = child as Button
		if button != null and button.has_meta("instance_id"):
			reserve_card = button
			break
	_expect(reserve_card != null and not reserve_card.disabled, "owned reserve piece is actionable")
	var selected_id: int = int(reserve_card.get_meta("instance_id", 0))
	reserve_card.pressed.emit()
	await process_frame
	_expect(selected_id in manager.current_run.active_piece_ids, "tapping reserve card transactionally activates piece")
	_expect(selected_id not in manager.current_run.reserve_piece_ids, "activated piece leaves reserve")
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

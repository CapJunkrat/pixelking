extends SceneTree

const TEST_PATH := "user://pixelking_opening_draft_scene_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var run_manager: Node = root.get_node("RunManager")
	run_manager.call("configure_save_path", TEST_PATH)
	run_manager.call("abandon_run")
	_expect(run_manager.call("create_run", 11223344, RunState.MODE_STANDARD, true), "scene test creates a draft Run")
	var scene: PackedScene = load("res://scenes/run/OpeningDraftScene.tscn") as PackedScene
	_expect(scene != null, "opening draft scene loads")
	if scene == null:
		_cleanup()
		_finish()
		return
	var draft: Control = scene.instantiate() as Control
	root.add_child(draft)
	await process_frame
	var round_label: Label = draft.get_node("SafeArea/Layout/Header/RoundLabel") as Label
	_expect("1" in round_label.text and "3" in round_label.text, "scene displays round 1 of 3")
	var fan: Control = draft.get_node("SafeArea/Layout/CandidateCards") as Control
	var expected_rotations: Array[float] = [0.0, 0.0, 0.0]
	for index: int in range(3):
		var card: Button = fan.get_node("Slot%d/Candidate%d" % [index, index]) as Button
		var portrait: TextureRect = card.get_node("Content/Portrait") as TextureRect
		var select_button: Button = fan.get_node("Slot%d/Select%d" % [index, index]) as Button
		_expect(card.visible and not card.disabled, "candidate card %d is previewable" % index)
		_expect(select_button.visible and not select_button.disabled, "candidate card %d has a separate Select action" % index)
		_expect(portrait.texture != null, "candidate card %d has a piece portrait" % index)
		_expect(is_equal_approx(card.rotation_degrees, expected_rotations[index]), "candidate card %d follows the focused fan layout" % index)
	_expect((fan.get_node("Slot1/Candidate1") as Button).size.x > (fan.get_node("Slot0/Candidate0") as Button).size.x, "previewed candidate is visually emphasized over the side cards")
	var original_reserve_count: int = (run_manager.get("current_run") as RunState).reserve_piece_ids.size()
	var left_card: Button = fan.get_node("Slot0/Candidate0") as Button
	left_card.pressed.emit()
	await create_timer(0.25).timeout
	_expect((run_manager.get("current_run") as RunState).reserve_piece_ids.size() == original_reserve_count, "clicking a card previews it without choosing it")
	_expect(left_card.size.x > (fan.get_node("Slot1/Candidate1") as Button).size.x, "previewed card grows while the other cards move aside")
	_expect((left_card.get_node("Content/Text/MovementLabel") as Label).visible, "previewed card displays movement information")
	_expect((left_card.get_node("Content/Text/AttackLabel") as Label).visible, "previewed card displays attack information")

	for round_index: int in range(3):
		var first_select: Button = draft.get_node("SafeArea/Layout/CandidateCards/Slot0/Select0") as Button
		first_select.pressed.emit()
		await process_frame
	_expect(draft.get_node_or_null("CompletionOverlay") == null, "draft completion overlay is removed")
	_expect(run_manager.call("resume_scene_path").ends_with("PathMapScene.tscn"), "completed draft routes directly to the map")
	var current_run: RunState = run_manager.get("current_run") as RunState
	_expect(current_run != null and current_run.reserve_piece_ids.size() == 3, "scene selections persist three reserve pieces")
	draft.queue_free()
	run_manager.call("abandon_run")
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
	print("[PASS] Opening draft scene test" if not failed else "[FAIL] Opening draft scene test")
	quit(1 if failed else 0)

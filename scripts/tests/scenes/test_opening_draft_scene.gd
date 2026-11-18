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
	var expected_rotations: Array[float] = [-6.0, 0.0, 6.0]
	for index: int in range(3):
		var pivot: Node2D = fan.get_node("CardPivot%d" % index) as Node2D
		var card: Button = pivot.get_node("Candidate%d" % index) as Button
		var portrait: TextureRect = card.get_node("Content/Portrait") as TextureRect
		_expect(card.visible and not card.disabled, "candidate card %d is previewable" % index)
		_expect(portrait.texture != null, "candidate card %d has a piece portrait" % index)
		_expect(is_equal_approx(pivot.rotation_degrees, expected_rotations[index]), "candidate card %d follows the rotating fan" % index)
	var select_button: Button = fan.get_node("SelectButton") as Button
	_expect(select_button.visible and not select_button.disabled, "only one Select action sits below the centered card")
	var original_reserve_count: int = (run_manager.get("current_run") as RunState).reserve_piece_ids.size()
	var left_pivot: Node2D = fan.get_node("CardPivot0") as Node2D
	var left_card: Button = left_pivot.get_node("Candidate0") as Button
	left_card.pressed.emit()
	await draft.fan_transition_completed
	_expect((run_manager.get("current_run") as RunState).reserve_piece_ids.size() == original_reserve_count, "clicking a card previews it without choosing it")
	_expect(is_zero_approx(left_pivot.rotation_degrees) and left_pivot.scale.is_equal_approx(Vector2.ONE), "clicked card moves upright to the center at the original card size")
	_expect((fan.get_node("CardPivot1") as Node2D).scale.x < left_pivot.scale.x, "other candidates move aside and shrink")
	draft.call("_start_candidate_info", 0)
	await draft.candidate_info_opened
	var info_layer: CanvasLayer = draft.get_node("InfoLayer") as CanvasLayer
	var info_popup: PanelContainer = info_layer.get_node("CandidateInfoPopup") as PanelContainer
	var diagram: GridContainer = info_popup.get_node("Content/DiagramCenter/Diagram") as GridContainer
	_expect(info_popup.visible, "holding a card opens the floating piece information")
	_expect(info_layer.layer > 10, "floating information renders above every draft card")
	_expect(diagram.get_child_count() == 25, "floating information prioritizes a 5 x 5 movement diagram")
	_expect(not (info_popup.get_node("Content/MovementLabel") as Label).text.is_empty(), "floating information gives a concise movement summary")
	_expect(not (info_popup.get_node("Content/AttackLabel") as Label).text.is_empty(), "floating information gives a concise attack summary")
	draft.call("_stop_candidate_info")

	for round_index: int in range(3):
		var first_card: Button = draft.get_node("SafeArea/Layout/CandidateCards/CardPivot0/Candidate0") as Button
		if draft.previewed_candidate_index != 0:
			first_card.pressed.emit()
			await draft.fan_transition_completed
		select_button = draft.get_node("SafeArea/Layout/CandidateCards/SelectButton") as Button
		select_button.pressed.emit()
		await process_frame
	_expect(draft.get_node_or_null("CompletionOverlay") == null, "draft completion overlay is removed")
	_expect(run_manager.call("resume_scene_path").ends_with("PathMapScene.tscn"), "completed draft routes directly to the map")
	var current_run: RunState = run_manager.get("current_run") as RunState
	_expect(current_run != null and current_run.active_piece_ids.size() == 4, "scene selections persist three pieces on the battle line")
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

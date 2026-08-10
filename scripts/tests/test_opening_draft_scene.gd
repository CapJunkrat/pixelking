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
	for index: int in range(3):
		var card: Button = draft.get_node("SafeArea/Layout/CandidateCards/Candidate%d" % index) as Button
		var portrait: TextureRect = card.get_node("Content/Portrait") as TextureRect
		_expect(card.visible and not card.disabled, "candidate card %d is actionable" % index)
		_expect(portrait.texture != null, "candidate card %d has a piece portrait" % index)

	for round_index: int in range(3):
		var first_card: Button = draft.get_node("SafeArea/Layout/CandidateCards/Candidate0") as Button
		first_card.pressed.emit()
		await process_frame
	var completion: ColorRect = draft.get_node("CompletionOverlay") as ColorRect
	_expect(completion.visible, "completion overlay appears after three picks")
	_expect(draft.get_node("CompletionOverlay/Center/Panel/Content/RosterButton") != null, "completed draft provides roster management access")
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

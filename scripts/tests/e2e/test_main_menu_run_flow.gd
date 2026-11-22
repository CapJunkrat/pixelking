extends SceneTree

const TEST_PATH := "user://pixelking_main_menu_run_flow_test.save"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var run_manager: Node = root.get_node("RunManager")
	run_manager.call("configure_save_path", TEST_PATH)
	run_manager.call("abandon_run")
	var menu_scene: PackedScene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu: Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	var continue_button: Button = menu.get_node("SafeArea/Layout/MenuPanel/MenuButtons/ContinueButton") as Button
	var new_button: Button = menu.get_node("SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton") as Button
	_expect(continue_button.disabled, "Continue is disabled without an active Run")
	_expect(run_manager.call("create_run", 556677, RunState.MODE_STANDARD, true), "menu test creates active Run")
	await process_frame
	_expect(not continue_button.disabled, "Continue enables when an active Run exists")
	var original_run: RunState = run_manager.get("current_run") as RunState
	new_button.pressed.emit()
	await process_frame
	var overwrite: ColorRect = menu.get_node("OverwriteConfirmation") as ColorRect
	var cancel_button: Button = overwrite.get_node("Center/Panel/Content/Actions/CancelButton") as Button
	var confirm_button: Button = overwrite.get_node("Center/Panel/Content/Actions/ConfirmButton") as Button
	_expect(overwrite.visible, "New Journey opens the themed overwrite confirmation")
	_expect(cancel_button.has_focus(), "overwrite confirmation gives safe cancel the initial focus")
	var localization: Node = root.get_node("Localization")
	_expect(confirm_button.text == str(localization.call("text", "MENU_OVERWRITE_CONFIRM")), "overwrite confirmation uses localized themed actions")
	cancel_button.pressed.emit()
	_expect(not overwrite.visible, "cancel closes the themed overwrite confirmation")
	_expect(run_manager.get("current_run") == original_run, "canceling overwrite preserves the active Run")
	# Confirming the overwrite asks for the difficulty before anything is replaced.
	new_button.pressed.emit()
	await process_frame
	confirm_button.pressed.emit()
	await process_frame
	var picker: ColorRect = menu.get_node("DifficultyPicker") as ColorRect
	var picker_content: Node = picker.get_node("Center/Panel/Content")
	var easy_button: Button = picker_content.get_node("Actions/EasyButton") as Button
	var medium_button: Button = picker_content.get_node("Actions/MediumButton") as Button
	var back_button: Button = picker_content.get_node("BackButton") as Button
	_expect(picker.visible and not overwrite.visible, "confirming the overwrite asks for the difficulty")
	_expect(easy_button.text == str(localization.call("text", "DIFFICULTY_EASY")) and medium_button.text == str(localization.call("text", "DIFFICULTY_MEDIUM")), "the difficulty choices are localized")
	_expect(easy_button.has_focus(), "Easy has the initial focus")
	back_button.pressed.emit()
	_expect(not picker.visible and run_manager.get("current_run") == original_run, "backing out of the difficulty keeps the active Run")
	run_manager.call("abandon_run")
	await process_frame
	new_button.pressed.emit()
	await process_frame
	_expect(picker.visible and run_manager.get("current_run") == null, "New Journey first asks for the difficulty")
	medium_button.pressed.emit()
	await process_frame
	var random_run: RunState = run_manager.get("current_run") as RunState
	_expect(random_run != null and random_run.run_seed != 0, "choosing a difficulty creates a random-seed Run")
	_expect(random_run != null and random_run.ai_difficulty == EnemyMoveSelector.DIFFICULTY_MEDIUM, "the journey keeps the chosen difficulty")
	var reloaded: RunState = RunState.new()
	_expect(random_run != null and reloaded.load_from_dictionary(random_run.to_dictionary(), false) and reloaded.ai_difficulty == EnemyMoveSelector.DIFFICULTY_MEDIUM, "the difficulty survives a save")
	var legacy: Dictionary = random_run.to_dictionary() if random_run != null else {}
	legacy.erase("ai_difficulty")
	_expect(reloaded.load_from_dictionary(legacy, false) and reloaded.ai_difficulty == EnemyMoveSelector.DIFFICULTY_EASY, "older saves load as Easy")
	_expect(menu.get_node_or_null("RunSetupOverlay") == null, "player-facing seed setup is removed")
	_expect(menu.get_node_or_null("SafeArea/Layout/Version") == null, "pre-alpha version label is removed")
	menu.queue_free()
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
	print("[PASS] Main menu Run flow test" if not failed else "[FAIL] Main menu Run flow test")
	quit(1 if failed else 0)

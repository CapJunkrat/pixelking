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
	var overwrite: ConfirmationDialog = menu.get_node("OverwriteConfirmation") as ConfirmationDialog
	_expect(overwrite.visible, "New Journey asks before replacing an active Run")
	overwrite.canceled.emit()
	_expect(run_manager.get("current_run") == original_run, "canceling overwrite preserves the active Run")
	run_manager.call("abandon_run")
	await process_frame
	new_button.pressed.emit()
	await process_frame
	var setup: ColorRect = menu.get_node("RunSetupOverlay") as ColorRect
	_expect(setup.visible, "New Journey opens seed setup when no Run exists")
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

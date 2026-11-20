extends SceneTreeTestCase

## Every screen fits the 360-wide phone layout in both languages, with the longest text
## it shows (an act-cleared title, a run summary, event outcomes...).

const TEST_PATH := "user://pixelking_phone_width_test.save"
const WIDTH := 360.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(360, 640)
	var run_manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	run_manager.configure_save_path(TEST_PATH)
	var localization: Node = root.get_node("Localization")
	for locale: String in ["en", "zh_CN"]:
		localization.call("set_locale", locale, false)
		run_manager.abandon_run()
		expect(run_manager.create_run(777001, RunState.MODE_STANDARD, true), "%s: run created" % locale)
		await _check_scene("res://scenes/run/OpeningDraftScene.tscn", locale)
		for _round: int in range(3):
			var candidates: Array = run_manager.current_run.pending_choice.get("candidate_piece_def_ids", []) as Array
			run_manager.submit_opening_draft_choice(str(candidates[0]))
		await _check_scene("res://scenes/run/PathMapScene.tscn", locale)
		await _check_scene("res://scenes/run/RosterScene.tscn", locale)
		await _check_scene("res://scenes/ui/MainMenu.tscn", locale)
		await _check_achievements(locale)
		# The act-cleared reward page with its title, then the run summary.
		var run: RunState = run_manager.current_run
		var saved_choice: Dictionary = run.pending_choice.duplicate(true)
		run.pending_choice = {
			"type": "battle_reward",
			"title_key": "ACT_CLEARED_TITLE",
			"title_args": [3],
			"description": "Choose one option.",
			"options": [
				{"id": "gold", "label": "Take 40 gold and a very long description of the reward that goes on", "payload": {"kind": "gold", "amount": 40}},
			],
		}
		await _check_scene("res://scenes/run/RunInteractionScene.tscn", locale + " act cleared")
		run.pending_choice = {
			"type": "run_summary",
			"title_key": "SUMMARY_TITLE",
			"description_key": "SUMMARY_TEXT",
			"description_args": [5, 4, 12, 40, 330],
			"options": [],
		}
		await _check_scene("res://scenes/run/RunInteractionScene.tscn", locale + " summary")
		run.pending_choice = saved_choice
		# Pre-battle and the battle itself, with the run's act and layer in the top bar.
		run_manager.abandon_run()
		expect(RunTestFixture.create_drafted_run(run_manager) == OK, "%s: drafted run for battle" % locale)
		expect(RunTestFixture.prepare_confirmed_battle(run_manager, true) == OK, "%s: battle deployment ready" % locale)
		await _check_scene("res://scenes/run/PreBattleScene.tscn", locale)
		expect(run_manager.start_current_battle() == OK, "%s: battle starts" % locale)
		await _check_scene("res://scenes/battle/BattleScene.tscn", locale)
		await _check_long_boss_name(locale)
	run_manager.abandon_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	finish_test("Phone width layout test")

## The achievements page, and the main menu's buttons all on screen.
func _check_achievements(locale: String) -> void:
	var menu: Control = (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	for _frame: int in range(4):
		await process_frame
	var last_button: Control = menu.get_node("SafeArea/Layout/MenuPanel/MenuButtons").get_child(-1) as Control
	expect(last_button.get_global_rect().end.y <= 640.0, "%s: every main menu button fits on screen (bottom %.0f)" % [locale, last_button.get_global_rect().end.y])
	menu.call("_open_achievements")
	for _frame: int in range(4):
		await process_frame
	var overlay: Control = menu.get_node("AchievementOverlay") as Control
	expect(overlay.visible and overlay.find_children("Ach_*", "", true, false).size() == AchievementCatalog.ENTRIES.size(), "%s: achievements page opens" % locale)
	var overflow: Array[String] = LayoutOverflow.find(overlay, WIDTH)
	expect(overflow.is_empty(), "achievements page (%s) fits 360 wide%s" % [locale, "" if overflow.is_empty() else ": " + ", ".join(overflow.slice(0, 4))])
	menu.queue_free()
	await process_frame

## The longest boss name in the battle top bar still leaves the bar on screen (the name
## ends in "…" instead).
func _check_long_boss_name(locale: String) -> void:
	var battle: Control = (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate() as Control
	root.add_child(battle)
	for _frame: int in range(2):
		await process_frame
	var localization: Node = root.get_node("Localization")
	var hud: BattleHUD = battle.get_node("Margin/Layout/TopBar") as BattleHUD
	hud.enemy_label.text = str(localization.call("text", "BOSS_SHADOW_KING")).to_upper() + " THE ENDLESS"
	for _frame: int in range(4):
		await process_frame
	var overflow: Array[String] = LayoutOverflow.find(battle, WIDTH)
	expect(overflow.is_empty(), "battle top bar with a long boss name (%s) fits 360 wide%s" % [locale, "" if overflow.is_empty() else ": " + ", ".join(overflow.slice(0, 4))])
	expect(hud.settings_button.get_global_rect().end.x <= WIDTH, "%s: the settings gear stays on screen" % locale)
	battle.queue_free()
	await process_frame

func _check_scene(path: String, label: String) -> void:
	var packed: PackedScene = load(path) as PackedScene
	var instance: Control = packed.instantiate() as Control
	root.add_child(instance)
	for _frame: int in range(4):
		await process_frame
	var overflow: Array[String] = LayoutOverflow.find(instance, WIDTH)
	expect(overflow.is_empty(), "%s (%s) fits 360 wide%s" % [path.get_file(), label, "" if overflow.is_empty() else ": " + ", ".join(overflow.slice(0, 4))])
	instance.queue_free()
	await process_frame

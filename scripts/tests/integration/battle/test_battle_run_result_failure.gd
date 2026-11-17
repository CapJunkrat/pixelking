class_name TestBattleRunResultFailure
extends SceneTreeTestCase

const TEST_PATH = "user://pixelking_battle_result_failure.save"
const META_PATH = "user://pixelking_battle_result_failure_meta.save"
const FAILING_PATH = "user://pixelking_missing_battle_result_dir/active.save"

var run_saved_count: int = 0
var active_changed_count: int = 0
var phase_changed_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sandbox: TestSaveSandbox = TestSaveSandbox.new().add(TEST_PATH).add(META_PATH).add(FAILING_PATH)
	sandbox.cleanup()
	sandbox.cleanup_parent_directory(FAILING_PATH)
	var manager: AppRunManager = AppRunManager.new()
	root.add_child(manager)
	await process_frame
	manager.configure_save_path(TEST_PATH)
	manager.meta_progress_service.save_path = META_PATH
	expect(RunTestFixture.create_drafted_run(manager) == OK, "result failure fixture creates drafted Run")
	expect(RunTestFixture.prepare_confirmed_battle(manager) == OK, "result failure fixture confirms battle")
	expect(manager.start_current_battle() == OK, "result failure fixture enters active battle")
	var before_run: Dictionary = manager.current_run.to_dictionary()
	var before_rng: Dictionary = manager.rng_service.snapshot_states()
	manager.run_saved.connect(_on_run_saved)
	manager.active_run_changed.connect(_on_active_changed)
	manager.run_phase_changed.connect(_on_phase_changed)
	manager.save_service = ActiveRunSaveService.new(FAILING_PATH)

	var coordinator: BattleRunResultCoordinator = BattleRunResultCoordinator.new()
	var failed_result: BattleRunResult = coordinator.integrate(manager, true)
	expect(not failed_result.success and failed_result.error != OK, "battle result exposes Run persistence failure")
	expect(manager.current_run.to_dictionary() == before_run, "failed victory leaves authoritative Run unchanged")
	expect(manager.rng_service.snapshot_states() == before_rng, "failed victory leaves deterministic RNG unchanged")
	expect(not manager.map_progress_service.is_current_node_resolved(manager.current_run), "failed victory does not resolve map node")
	expect(run_saved_count == 0 and active_changed_count == 0 and phase_changed_count == 0, "failed victory publishes no Run success signals")

	var panel_scene: PackedScene = load("res://scenes/battle/BattleResultPanel.tscn") as PackedScene
	var panel: BattleResultPanel = panel_scene.instantiate() as BattleResultPanel
	root.add_child(panel)
	var presenter: BattleResultPresenter = BattleResultPresenter.new()
	presenter.bind(panel, root.get_node("Localization"))
	presenter.present(true, false, failed_result)
	expect(panel.visible and "Run save error:" in panel.detail_label.text, "result panel displays persistence failure")

	var repeated_failure: BattleRunResult = coordinator.integrate(manager, true)
	expect(not repeated_failure.success and manager.current_run.to_dictionary() == before_run, "repeated failed settlement remains side-effect free")
	manager.save_service = ActiveRunSaveService.new(TEST_PATH)
	var success: BattleRunResult = coordinator.integrate(manager, true)
	expect(success.success and manager.map_progress_service.is_current_node_resolved(manager.current_run), "restored persistence commits victory once")
	var committed: Dictionary = manager.current_run.to_dictionary()
	var duplicate: BattleRunResult = coordinator.integrate(manager, true)
	expect(not duplicate.success and manager.current_run.to_dictionary() == committed, "duplicate settlement is rejected without mutation")
	expect(run_saved_count == 1 and active_changed_count == 1 and phase_changed_count == 1, "only successful settlement publishes Run signals")

	panel.queue_free()
	manager.abandon_run()
	manager.queue_free()
	sandbox.cleanup()
	sandbox.cleanup_parent_directory(FAILING_PATH)
	finish_test("Battle Run result failure test")

func _on_run_saved() -> void:
	run_saved_count += 1

func _on_active_changed(_run_state: RunState) -> void:
	active_changed_count += 1

func _on_phase_changed(_previous: StringName, _current: StringName) -> void:
	phase_changed_count += 1

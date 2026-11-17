class_name TestSceneRoutes
extends SceneTreeTestCase

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var routes: Array[String] = [
		AppSceneRoutes.MAIN_MENU,
		AppSceneRoutes.OPENING_DRAFT,
		AppSceneRoutes.PATH_MAP,
		AppSceneRoutes.DEPLOYMENT,
		AppSceneRoutes.BATTLE,
		AppSceneRoutes.RUN_INTERACTION,
		AppSceneRoutes.ROSTER,
	]
	var unique_routes: Dictionary = {}
	for route: String in routes:
		unique_routes[route] = true
		expect(route.begins_with("res://scenes/") and ResourceLoader.exists(route), "registered scene route exists: %s" % route)
	expect(unique_routes.size() == routes.size(), "scene route registry contains no duplicates")
	expect(AppSceneRoutes.navigate(null, AppSceneRoutes.MAIN_MENU) == ERR_INVALID_PARAMETER, "navigation rejects a missing SceneTree")
	expect(AppSceneRoutes.navigate(self, "") == ERR_INVALID_PARAMETER, "navigation rejects an empty scene path")

	var manager: AppRunManager = AppRunManager.new()
	expect(manager.resume_scene_path() == AppSceneRoutes.MAIN_MENU, "empty Run resumes at registered main menu")
	manager.current_run = RunState.new()
	var expected_by_phase: Dictionary = {
		RunPhase.OPENING_DRAFT: AppSceneRoutes.OPENING_DRAFT,
		RunPhase.MAP: AppSceneRoutes.PATH_MAP,
		RunPhase.NODE_SELECTED: AppSceneRoutes.PATH_MAP,
		RunPhase.DEPLOYMENT: AppSceneRoutes.DEPLOYMENT,
		RunPhase.BATTLE_READY: AppSceneRoutes.DEPLOYMENT,
		RunPhase.BATTLE_ACTIVE: AppSceneRoutes.DEPLOYMENT,
		RunPhase.NODE_INTERACTION: AppSceneRoutes.RUN_INTERACTION,
		RunPhase.POST_BATTLE_CHOICE: AppSceneRoutes.RUN_INTERACTION,
		RunPhase.SACRIFICE: AppSceneRoutes.RUN_INTERACTION,
		RunPhase.RUN_SUMMARY: AppSceneRoutes.RUN_INTERACTION,
	}
	for phase_value: Variant in expected_by_phase:
		manager.current_run.phase = StringName(phase_value)
		expect(manager.resume_scene_path() == str(expected_by_phase[phase_value]), "Run phase %s resumes through registered route" % phase_value)
	manager.free()
	finish_test("Scene route contract test")

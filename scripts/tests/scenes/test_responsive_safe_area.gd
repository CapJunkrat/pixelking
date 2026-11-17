class_name TestResponsiveSafeArea
extends SceneTreeTestCase

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	expect(int(ProjectSettings.get_setting("display/window/size/viewport_width")) == 360, "mobile layout keeps 360 logical width")
	expect(int(ProjectSettings.get_setting("display/window/size/viewport_height")) == 640, "mobile layout keeps 640 logical height")
	expect(str(ProjectSettings.get_setting("display/window/stretch/mode")) == "canvas_items", "mobile layout uses Canvas Items stretch")
	expect(str(ProjectSettings.get_setting("display/window/stretch/aspect")) == "keep_width", "mobile layout preserves width without non-uniform stretch")

	var portrait: Vector4i = ResponsiveSafeArea.calculate_safe_margins(
		Vector2i(1080, 2400), Rect2i(0, 96, 1080, 2208), Vector2(360, 800)
	)
	expect(portrait == Vector4i(0, 32, 0, 32), "portrait system bars convert to logical safe margins")
	var cutout: Vector4i = ResponsiveSafeArea.calculate_safe_margins(
		Vector2i(1440, 3200), Rect2i(80, 120, 1280, 2960), Vector2(360, 800)
	)
	expect(cutout == Vector4i(20, 30, 20, 30), "asymmetric cutout converts independently on both axes")
	expect(ResponsiveSafeArea.calculate_safe_margins(Vector2i.ZERO, Rect2i(), Vector2(360, 640)) == Vector4i.ZERO, "invalid display metrics never create margins")

	var scene_nodes: Dictionary = {
		AppSceneRoutes.MAIN_MENU: "SafeArea",
		AppSceneRoutes.OPENING_DRAFT: "SafeArea",
		AppSceneRoutes.PATH_MAP: "SafeArea",
		AppSceneRoutes.DEPLOYMENT: "SafeArea",
		AppSceneRoutes.ROSTER: "SafeArea",
		AppSceneRoutes.RUN_INTERACTION: "SafeArea",
		AppSceneRoutes.BATTLE: "Margin",
	}
	for scene_path_value: Variant in scene_nodes:
		var scene_path: String = str(scene_path_value)
		var packed: PackedScene = load(scene_path) as PackedScene
		var instance: Node = packed.instantiate()
		var safe_node_path: String = str(scene_nodes[scene_path_value])
		var safe_area: ResponsiveSafeArea = instance.get_node_or_null(safe_node_path) as ResponsiveSafeArea
		expect(safe_area != null, "%s attaches ResponsiveSafeArea" % scene_path.get_file())
		if safe_area != null:
			var authored_offsets: Vector4 = Vector4(safe_area.offset_left, safe_area.offset_top, safe_area.offset_right, safe_area.offset_bottom)
			safe_area.call("_set_safe_margins", 1, 2, 3, 4)
			expect(authored_offsets == Vector4(safe_area.offset_left, safe_area.offset_top, safe_area.offset_right, safe_area.offset_bottom), "%s keeps authored visual offsets" % scene_path.get_file())
			expect(
				safe_area.get_theme_constant("margin_left") == 1
				and safe_area.get_theme_constant("margin_top") == 2
				and safe_area.get_theme_constant("margin_right") == 3
				and safe_area.get_theme_constant("margin_bottom") == 4,
				"%s applies non-negative inset margins" % scene_path.get_file()
			)
		instance.free()
	finish_test("Responsive safe area contract test")

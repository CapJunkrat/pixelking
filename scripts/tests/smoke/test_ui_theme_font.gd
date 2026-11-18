extends SceneTree

const EXPECTED_FONT_PATH := "res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf"

func _init() -> void:
	await process_frame
	var packed_scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu := packed_scene.instantiate()
	root.add_child(menu)
	await process_frame

	var paths := [
		"SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton",
		"SafeArea/Layout/MenuPanel/MenuButtons/ContinueButton",
		"SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton",
		"SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton/Content/Group/Label",
		"SafeArea/Layout/MenuPanel/MenuButtons/ContinueButton/Content/Group/Label",
		"SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton/Content/Group/Label",
		"SettingsOverlay/SettingsPanel/SettingsContent/Title",
		"SettingsOverlay/SettingsPanel/SettingsContent/LanguageOption",
		"SettingsOverlay/SettingsPanel/SettingsContent/BackButton",
	]
	var ok := true
	for path in paths:
		var control := menu.get_node(path) as Control
		var resolved_font := control.get_theme_font("font")
		var resolved_path := resolved_font.resource_path
		if resolved_path != EXPECTED_FONT_PATH:
			push_error("%s resolved %s instead of %s" % [path, resolved_path, EXPECTED_FONT_PATH])
			ok = false

	var menu_panel := menu.get_node("SafeArea/Layout/MenuPanel") as Control
	if not is_equal_approx(menu_panel.size.x, 280.0):
		push_error("Menu panel width must be 280px, got %s" % menu_panel.size.x)
		ok = false
	for button_name in ["NewGameButton", "ContinueButton", "SettingsButton"]:
		var button := menu.get_node("SafeArea/Layout/MenuPanel/MenuButtons/" + button_name) as Button
		var icon := button.get_node("Content/Group/Icon") as TextureRect
		var label := button.get_node("Content/Group/Label") as Label
		var visual_gap := label.position.x - (icon.position.x + icon.size.x)
		if not is_equal_approx(button.size.y, 48.0):
			push_error("%s height must be 48px, got %s" % [button_name, button.size.y])
			ok = false
		if not is_equal_approx(visual_gap, 8.0):
			push_error("%s icon-label gap must be 8px, got %s" % [button_name, visual_gap])
			ok = false

	var language_option := menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/LanguageOption") as OptionButton
	var popup: PopupMenu = language_option.get_popup()
	var popup_font: Font = popup.get_theme_font("font")
	if popup_font.resource_path != EXPECTED_FONT_PATH:
		push_error("Language popup resolved %s instead of %s" % [popup_font.resource_path, EXPECTED_FONT_PATH])
		ok = false

	print("[PASS] UI theme font test" if ok else "[FAIL] UI theme font test")
	quit(0 if ok else 1)

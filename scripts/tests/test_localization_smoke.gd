extends SceneTree

func _init() -> void:
	await process_frame
	var localization := root.get_node("Localization")
	var ok := true
	if localization.current_locale != "en":
		push_error("Default locale must be English")
		ok = false
	if localization.text("MENU_NEW_GAME") != "New Journey":
		push_error("English menu translation is unavailable")
		ok = false
	if localization.text(String(GameRules.color_key(GameRules.PieceColor.WHITE))) != "White":
		push_error("White color localization is unavailable")
		ok = false
	if localization.text(String(GameRules.color_key(GameRules.PieceColor.BLACK))) != "Black":
		push_error("Black color localization is unavailable")
		ok = false
	if localization.text(String(PieceDefDatabase.get_def("king").display_name_key)) != "King":
		push_error("Piece display-name localization is unavailable")
		ok = false
	if localization.title_texture() == null:
		push_error("English title texture is unavailable")
		ok = false
	if not localization.set_locale("en"):
		push_error("Enabled locale could not be selected")
		ok = false
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://settings.cfg") != OK or str(config.get_value("general", "locale", "")) != "en":
		push_error("Selected locale was not persisted")
		ok = false
	if localization.set_locale("zh_CN"):
		push_error("Incomplete Chinese locale must remain disabled")
		ok = false
	print("[PASS] Localization smoke test" if ok else "[FAIL] Localization smoke test")
	quit(0 if ok else 1)

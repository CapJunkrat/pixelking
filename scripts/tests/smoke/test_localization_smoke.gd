extends SceneTree

func _init() -> void:
	await process_frame
	var localization := root.get_node("Localization")
	var ok := true
	# Without a saved choice the game follows the device language.
	var device_default: String = "zh_CN" if OS.get_locale_language() == "zh" else "en"
	var saved: ConfigFile = ConfigFile.new()
	var has_saved: bool = saved.load("user://settings.cfg") == OK and saved.has_section_key("general", "locale")
	if not has_saved and localization.current_locale != device_default:
		push_error("Default locale must follow the device")
		ok = false
	localization.set_locale("en", false)
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
	for piece_id: StringName in [&"assassin", &"royal_guard", &"catapult", &"bowman", &"portal_mage", &"unicorn_cavalry", &"centaur", &"manticore", &"gryphon", &"gorgon"]:
		var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
		if definition == null or localization.text(String(definition.display_name_key)) == String(definition.display_name_key):
			push_error("New piece localization is unavailable: %s" % piece_id)
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
	# Simplified Chinese: every English text has a translation, and content texts
	# (events, generated labels) are translated through templates.
	var english: Dictionary = localization.LOCALES["en"]["strings"]
	var missing: Array[String] = []
	for key: String in english:
		if not LocalizationZh.STRINGS.has(key):
			missing.append(key)
	if not missing.is_empty():
		push_error("Chinese is missing: %s" % ", ".join(missing))
		ok = false
	if not localization.set_locale("zh_CN", false):
		push_error("Chinese locale could not be selected")
		ok = false
	var checks: Dictionary = {
		localization.text("MENU_NEW_GAME"): "新的旅程",
		localization.content("Wishing Well"): "许愿井",
		localization.content("Recruit Knight"): "招募骑士",
		localization.content("Holy Water — 30 Gold"): "圣水 — 30 金币",
		localization.content("Your Pawn leaves; a Bishop takes its place."): "你的兵离开了，主教取而代之。",
		localization.content("+15 Gold earned. Choose one extra reward. Offers are saved and cannot be rerolled."): "获得 15 金币。选择一份额外奖励。选项已保存，无法重新刷新。",
		localization.content("Inside the crate: Royal Bomb."): "箱子里是：皇家炸弹。",
	}
	for got: String in checks:
		if got != str(checks[got]):
			push_error("Chinese text mismatch: got '%s', expected '%s'" % [got, checks[got]])
			ok = false
	localization.set_locale("en", false)
	if localization.content("Wishing Well") != "Wishing Well":
		push_error("English content must stay English")
		ok = false
	print("[PASS] Localization smoke test" if ok else "[FAIL] Localization smoke test")
	quit(0 if ok else 1)

extends Control

@onready var title_logo: TextureRect = $SafeArea/Layout/Header/TitleLogo
@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var battle_placeholder: ColorRect = $BattlePlaceholder
@onready var new_game_button: Button = $SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton
@onready var language_option: OptionButton = $SettingsOverlay/SettingsPanel/SettingsContent/LanguageOption

func _ready() -> void:
	$SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton.pressed.connect(_on_new_game_pressed)
	$SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton.pressed.connect(_on_settings_pressed)
	$SafeArea/Layout/MenuPanel/MenuButtons/QuitButton.pressed.connect(_on_quit_pressed)
	_setup_menu_button_visuals()
	$SettingsOverlay/SettingsPanel/SettingsContent/BackButton.pressed.connect(_close_settings)
	$BattlePlaceholder/BattleContent/BackButton.pressed.connect(_close_battle_placeholder)
	language_option.item_selected.connect(_on_language_selected)
	Localization.locale_changed.connect(_apply_locale)
	_populate_languages()
	_apply_locale(Localization.current_locale)
	new_game_button.grab_focus()
	_play_intro()
	_play_title_float()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_overlay.visible:
			_close_settings()
		elif battle_placeholder.visible:
			_close_battle_placeholder()

func _populate_languages() -> void:
	language_option.clear()
	var selected_index := 0
	for locale_variant in Localization.locale_codes():
		var locale := str(locale_variant)
		var info := Localization.locale_info(locale)
		var index := language_option.item_count
		language_option.add_item(info.get("label", locale))
		language_option.set_item_metadata(index, locale)
		language_option.set_item_disabled(index, not info.get("enabled", false))
		if locale == Localization.current_locale:
			selected_index = index
	language_option.select(selected_index)

func _apply_locale(_locale: String) -> void:
	title_logo.texture = Localization.title_texture()
	$SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton/Content/Group/Label.text = Localization.text("MENU_NEW_GAME")
	$SafeArea/Layout/MenuPanel/MenuButtons/ContinueButton/Content/Group/Label.text = Localization.text("MENU_CONTINUE")
	$SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton/Content/Group/Label.text = Localization.text("MENU_SETTINGS")
	$SafeArea/Layout/MenuPanel/MenuButtons/QuitButton/Content/Group/Label.text = Localization.text("MENU_QUIT")
	$SettingsOverlay/SettingsPanel/SettingsContent/Title.text = Localization.text("SETTINGS_TITLE")
	$SettingsOverlay/SettingsPanel/SettingsContent/LanguageLabel.text = Localization.text("SETTINGS_LANGUAGE")
	$SettingsOverlay/SettingsPanel/SettingsContent/MusicLabel.text = Localization.text("SETTINGS_MUSIC")
	$SettingsOverlay/SettingsPanel/SettingsContent/SoundLabel.text = Localization.text("SETTINGS_SOUND")
	$SettingsOverlay/SettingsPanel/SettingsContent/BackButton.text = Localization.text("COMMON_BACK")
	$BattlePlaceholder/BattleContent/Title.text = Localization.text("JOURNEY_TITLE")
	$BattlePlaceholder/BattleContent/Description.text = Localization.text("JOURNEY_DESCRIPTION")
	$BattlePlaceholder/BattleContent/BackButton.text = Localization.text("JOURNEY_BACK")

func _setup_menu_button_visuals() -> void:
	for child in $SafeArea/Layout/MenuPanel/MenuButtons.get_children():
		var button := child as Button
		if button == null:
			continue
		button.mouse_entered.connect(_refresh_menu_button.bind(button))
		button.mouse_exited.connect(_refresh_menu_button.bind(button))
		button.focus_entered.connect(_refresh_menu_button.bind(button))
		button.focus_exited.connect(_refresh_menu_button.bind(button))
		button.button_down.connect(_refresh_menu_button.bind(button))
		button.button_up.connect(_refresh_menu_button.bind(button))
		_refresh_menu_button(button)

func _refresh_menu_button(button: Button) -> void:
	var label := button.get_node("Content/Group/Label") as Label
	var icon := button.get_node("Content/Group/Icon") as TextureRect
	if button.disabled:
		label.add_theme_color_override("font_color", Color(0.48, 0.48, 0.5, 1.0))
		icon.modulate = Color(0.48, 0.48, 0.5, 1.0)
		return
	var highlighted := button.is_hovered() or button.has_focus() or button.button_pressed
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.85, 0.4, 1.0) if highlighted else Color(0.94, 0.9, 0.78, 1.0)
	)
	icon.modulate = Color(1.15, 1.08, 0.88, 1.0) if highlighted else Color.WHITE

func _on_language_selected(index: int) -> void:
	var locale := str(language_option.get_item_metadata(index))
	Localization.set_locale(locale)

func _play_intro() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.45)

func _play_title_float() -> void:
	var start_y := title_logo.position.y
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_logo, "position:y", start_y - 3.0, 1.5)
	tween.tween_property(title_logo, "position:y", start_y, 1.5)

func _on_new_game_pressed() -> void:
	battle_placeholder.visible = true
	$BattlePlaceholder/BattleContent/BackButton.grab_focus()

func _close_battle_placeholder() -> void:
	battle_placeholder.visible = false
	new_game_button.grab_focus()

func _on_settings_pressed() -> void:
	settings_overlay.visible = true
	$SettingsOverlay/SettingsPanel/SettingsContent/LanguageOption.grab_focus()

func _close_settings() -> void:
	settings_overlay.visible = false
	$SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()

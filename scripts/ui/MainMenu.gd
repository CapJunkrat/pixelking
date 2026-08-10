extends Control

@onready var title_logo: TextureRect = $SafeArea/Layout/Header/TitleLogo
@onready var settings_overlay: ColorRect = $SettingsOverlay
@onready var battle_placeholder: ColorRect = $BattlePlaceholder
@onready var new_game_button: Button = $SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton
@onready var continue_button: Button = $SafeArea/Layout/MenuPanel/MenuButtons/ContinueButton
@onready var language_option: OptionButton = $SettingsOverlay/SettingsPanel/SettingsContent/LanguageOption
@onready var piece_skin_option: OptionButton = $SettingsOverlay/SettingsPanel/SettingsContent/PieceSkinOption
@onready var white_skin_preview: HBoxContainer = $SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/WhitePieces
@onready var black_skin_preview: HBoxContainer = $SettingsOverlay/SettingsPanel/SettingsContent/SkinPreview/BlackPieces
@onready var music_slider: HSlider = $SettingsOverlay/SettingsPanel/SettingsContent/MusicSlider
@onready var sound_slider: HSlider = $SettingsOverlay/SettingsPanel/SettingsContent/SoundSlider
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")
@onready var settings_manager: AppSettingsManager = get_node("/root/SettingsManager") as AppSettingsManager
@onready var audio_manager: AppAudioManager = get_node("/root/AudioManager") as AppAudioManager
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager

const PIECE_TYPES: Array[StringName] = [&"king", &"queen", &"rook", &"bishop", &"knight", &"pawn"]
const RUN_SETUP_SCENE: PackedScene = preload("res://scenes/run/RunSetupOverlay.tscn")
const INTRO_BUTTON_DELAY := 0.15

var _intro_tween: Tween
var _intro_playing: bool = false
var _run_setup_overlay: RunSetupOverlay
var _overwrite_confirmation: ConfirmationDialog
var _allow_overwrite_for_setup: bool = false

func _ready() -> void:
	$SafeArea/Layout/MenuPanel/MenuButtons/NewGameButton.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	$SafeArea/Layout/MenuPanel/MenuButtons/SettingsButton.pressed.connect(_on_settings_pressed)
	$SafeArea/Layout/MenuPanel/MenuButtons/QuitButton.pressed.connect(_on_quit_pressed)
	_setup_menu_button_visuals()
	$SettingsOverlay/SettingsPanel/SettingsContent/BackButton.pressed.connect(_close_settings)
	$BattlePlaceholder/BattleContent/BackButton.pressed.connect(_close_battle_placeholder)
	language_option.item_selected.connect(_on_language_selected)
	piece_skin_option.item_selected.connect(_on_piece_skin_selected)
	piece_skin_manager.skin_changed.connect(_on_piece_skin_changed)
	Localization.locale_changed.connect(_apply_locale)
	_populate_languages()
	_apply_locale(Localization.current_locale)
	_populate_piece_skins()
	_build_skin_preview()
	_setup_audio_controls()
	_setup_run_controls()
	_refresh_run_buttons()
	_play_intro()

func _unhandled_input(event: InputEvent) -> void:
	if _intro_playing and event.is_pressed():
		_finish_intro(true)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if settings_overlay.visible:
			_close_settings()
		elif battle_placeholder.visible:
			_close_battle_placeholder()

func _populate_languages() -> void:
	language_option.clear()
	var selected_index := 0
	for locale_variant: Variant in Localization.locale_codes():
		var locale: String = str(locale_variant)
		var info: Dictionary = Localization.locale_info(locale)
		var index: int = language_option.item_count
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
	$SettingsOverlay/SettingsPanel/SettingsContent/PieceSkinLabel.text = Localization.text("SETTINGS_PIECE_SKIN")
	$SettingsOverlay/SettingsPanel/SettingsContent/PreviewLabel.text = Localization.text("SETTINGS_SKIN_PREVIEW")
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
	var locale: String = str(language_option.get_item_metadata(index))
	Localization.set_locale(locale)

func _setup_audio_controls() -> void:
	for slider: HSlider in [music_slider, sound_slider]:
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
	music_slider.set_value_no_signal(audio_manager.music_volume())
	sound_slider.set_value_no_signal(audio_manager.sfx_volume())
	music_slider.value_changed.connect(_on_music_volume_changed)
	sound_slider.value_changed.connect(_on_sfx_volume_changed)
	settings_manager.music_volume_changed.connect(_sync_music_slider)
	settings_manager.sfx_volume_changed.connect(_sync_sfx_slider)

func _on_music_volume_changed(value: float) -> void:
	audio_manager.set_music_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	audio_manager.set_sfx_volume(value)

func _sync_music_slider(value: float) -> void:
	music_slider.set_value_no_signal(value)

func _sync_sfx_slider(value: float) -> void:
	sound_slider.set_value_no_signal(value)

func _setup_run_controls() -> void:
	_run_setup_overlay = RUN_SETUP_SCENE.instantiate() as RunSetupOverlay
	add_child(_run_setup_overlay)
	_run_setup_overlay.seed_confirmed.connect(_on_seed_confirmed)
	_run_setup_overlay.cancelled.connect(_focus_new_game_button)
	_overwrite_confirmation = ConfirmationDialog.new()
	_overwrite_confirmation.name = "OverwriteConfirmation"
	_overwrite_confirmation.title = Localization.text("MENU_OVERWRITE_TITLE")
	_overwrite_confirmation.dialog_text = Localization.text("MENU_OVERWRITE_MESSAGE")
	_overwrite_confirmation.confirmed.connect(_show_run_setup.bind(true))
	_overwrite_confirmation.canceled.connect(_focus_new_game_button)
	add_child(_overwrite_confirmation)
	run_manager.active_run_changed.connect(_on_active_run_changed)

func _focus_new_game_button() -> void:
	if new_game_button.focus_mode != Control.FOCUS_NONE:
		new_game_button.grab_focus()

func _refresh_run_buttons() -> void:
	continue_button.disabled = not run_manager.can_continue()
	_refresh_menu_button(continue_button)

func _on_active_run_changed(_run_state: RunState) -> void:
	_refresh_run_buttons()

func _show_run_setup(allow_overwrite: bool = false) -> void:
	_allow_overwrite_for_setup = allow_overwrite
	_run_setup_overlay.show_setup()

func _on_seed_confirmed(run_seed: int) -> void:
	var created: bool = run_manager.create_run(run_seed, RunState.MODE_STANDARD, _allow_overwrite_for_setup)
	if not created:
		_run_setup_overlay.show_error(Localization.text("SAVE_ERROR"))
		return
	get_tree().change_scene_to_file(run_manager.resume_scene_path())

func _play_intro() -> void:
	modulate.a = 1.0
	_intro_playing = true
	title_logo.modulate.a = 0.0

	var version_label := $SafeArea/Layout/Version as Label
	version_label.modulate.a = 0.0

	var buttons: Array[Button] = []
	for child in $SafeArea/Layout/MenuPanel/MenuButtons.get_children():
		var button := child as Button
		if button == null:
			continue
		buttons.append(button)
		button.modulate.a = 0.0
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE

	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(title_logo, "modulate:a", 1.0, 0.70).set_delay(0.10)

	for index in buttons.size():
		var button := buttons[index]
		var delay := 0.55 + index * INTRO_BUTTON_DELAY
		_intro_tween.tween_property(button, "modulate:a", 1.0, 0.60).set_delay(delay)

	_intro_tween.tween_property(version_label, "modulate:a", 1.0, 0.40).set_delay(1.35)
	_intro_tween.chain().tween_callback(_finish_intro)

func _finish_intro(skip_tween: bool = false) -> void:
	if not _intro_playing:
		return
	_intro_playing = false
	if skip_tween and is_instance_valid(_intro_tween):
		_intro_tween.kill()
	_intro_tween = null

	title_logo.modulate.a = 1.0
	var version_label := $SafeArea/Layout/Version as Label
	version_label.modulate.a = 1.0

	for child in $SafeArea/Layout/MenuPanel/MenuButtons.get_children():
		var button := child as Button
		if button == null:
			continue
		button.modulate.a = 1.0
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_ALL

	new_game_button.grab_focus()
	_play_title_float()

func _populate_piece_skins() -> void:
	piece_skin_option.clear()
	var selected_index := 0
	for skin in piece_skin_manager.available_skins():
		var index := piece_skin_option.item_count
		piece_skin_option.add_item(skin.display_name)
		piece_skin_option.set_item_metadata(index, skin.skin_id)
		if skin.skin_id == piece_skin_manager.current_skin_id:
			selected_index = index
	piece_skin_option.select(selected_index)

func _build_skin_preview() -> void:
	for row in [white_skin_preview, black_skin_preview]:
		for child in row.get_children():
			child.queue_free()
	for piece_type in PIECE_TYPES:
		white_skin_preview.add_child(_make_preview_piece(&"white", piece_type))
		black_skin_preview.add_child(_make_preview_piece(&"black", piece_type))

func _make_preview_piece(color: StringName, piece_type: StringName) -> TextureRect:
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(38, 38)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture = piece_skin_manager.piece_texture(color, piece_type)
	preview.tooltip_text = "%s %s" % [String(color).capitalize(), String(piece_type).capitalize()]
	return preview

func _on_piece_skin_selected(index: int) -> void:
	piece_skin_manager.set_skin(StringName(piece_skin_option.get_item_metadata(index)))

func _on_piece_skin_changed(_skin_id: StringName) -> void:
	_build_skin_preview()

func _play_title_float() -> void:
	var start_y := title_logo.position.y
	var tween := create_tween().set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title_logo, "position:y", start_y - 3.0, 1.5)
	tween.tween_property(title_logo, "position:y", start_y, 1.5)

func _on_new_game_pressed() -> void:
	if run_manager.can_continue():
		_overwrite_confirmation.popup_centered()
		return
	_show_run_setup(false)

func _on_continue_pressed() -> void:
	var error: Error = run_manager.ensure_opening_draft_pending()
	if error != OK:
		_run_setup_overlay.show_error(Localization.text("SAVE_ERROR"))
		return
	get_tree().change_scene_to_file(run_manager.resume_scene_path())

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

class_name BattleSettingsPanel
extends ColorRect

@onready var music_slider: HSlider = $Center/Panel/Margin/Content/MusicVolume
@onready var sfx_slider: HSlider = $Center/Panel/Margin/Content/SFXVolume
@onready var leave_confirmation: ConfirmationDialog = $LeaveConfirmation
@onready var settings_manager: AppSettingsManager = get_node("/root/SettingsManager") as AppSettingsManager
@onready var audio_manager: AppAudioManager = get_node("/root/AudioManager") as AppAudioManager

func _ready() -> void:
	$Center/Panel/Margin/Content/ResumeButton.pressed.connect(close)
	$Center/Panel/Margin/Content/MainMenuButton.pressed.connect(_request_main_menu)
	leave_confirmation.confirmed.connect(_return_to_menu)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	settings_manager.music_volume_changed.connect(_sync_music)
	settings_manager.sfx_volume_changed.connect(_sync_sfx)
	music_slider.set_value_no_signal(audio_manager.music_volume())
	sfx_slider.set_value_no_signal(audio_manager.sfx_volume())
	_apply_locale()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	show()
	$Center/Panel/Margin/Content/ResumeButton.grab_focus()

func close() -> void:
	hide()

func is_open() -> bool:
	return visible

func _on_music_changed(value: float) -> void:
	audio_manager.set_music_volume(value)

func _on_sfx_changed(value: float) -> void:
	audio_manager.set_sfx_volume(value)

func _sync_music(value: float) -> void:
	music_slider.set_value_no_signal(value)

func _sync_sfx(value: float) -> void:
	sfx_slider.set_value_no_signal(value)

func _request_main_menu() -> void:
	leave_confirmation.popup_centered()

func _return_to_menu() -> void:
	var run_manager: AppRunManager = get_node_or_null("/root/RunManager") as AppRunManager
	if run_manager != null and run_manager.current_run != null:
		var return_error: Error = run_manager.return_to_deployment()
		if return_error != OK:
			return
	get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)

func _apply_locale() -> void:
	$Center/Panel/Margin/Content/Title.text = _text("SETTINGS_TITLE")
	$Center/Panel/Margin/Content/MusicLabel.text = _text("SETTINGS_MUSIC")
	$Center/Panel/Margin/Content/SfxLabel.text = _text("SETTINGS_SOUND")
	$Center/Panel/Margin/Content/ResumeButton.text = _text("BATTLE_SETTINGS_RESUME")
	$Center/Panel/Margin/Content/MainMenuButton.text = _text("BATTLE_SETTINGS_MAIN_MENU")
	leave_confirmation.title = _text("BATTLE_SETTINGS_MAIN_MENU")
	leave_confirmation.dialog_text = _text("BATTLE_SETTINGS_CONFIRM")

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

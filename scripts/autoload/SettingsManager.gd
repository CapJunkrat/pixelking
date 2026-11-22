class_name AppSettingsManager
extends Node

signal music_volume_changed(value: float)
signal sfx_volume_changed(value: float)
signal locale_setting_changed(locale: String)
signal short_battle_animations_changed(enabled: bool)

const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MUSIC_VOLUME := 0.75
const DEFAULT_SFX_VOLUME := 0.85
const DEFAULT_LOCALE := "en"

var settings_path: String = DEFAULT_SETTINGS_PATH
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var locale: String = DEFAULT_LOCALE
## When on, battle animations play at a faster pace.
var short_battle_animations: bool = false
## One-time tips the player has already seen, by id.
var seen_tips: Array[String] = []

func _ready() -> void:
	load_settings()

func configure_path(path: String) -> void:
	settings_path = path

func load_settings() -> void:
	# Until the player picks a language, follow the device: Chinese devices (any script
	# or region) start in Chinese, every other device in English. This must hold on the
	# very first launch too, before any settings file exists.
	var device_locale: String = locale_for_language(device_language())
	locale = device_locale
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) != OK:
		_apply_audio_buses()
		return
	music_volume = clampf(float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0)
	var saved_locale: String = str(config.get_value("general", "locale", device_locale))
	locale = saved_locale if not saved_locale.is_empty() else device_locale
	short_battle_animations = bool(config.get_value("battle", "short_animations", false))
	seen_tips.clear()
	for tip: Variant in config.get_value("tips", "seen", []) as Array:
		seen_tips.append(str(tip))
	_apply_audio_buses()

## The device's language code ("zh", "en", ...); tests can pin it with
## `device_language_override`.
var device_language_override: String = ""

func device_language() -> String:
	return device_language_override if not device_language_override.is_empty() else OS.get_locale_language()

static func locale_for_language(language: String) -> String:
	return "zh_CN" if language.to_lower().begins_with("zh") else DEFAULT_LOCALE

func set_music_volume(value: float, persist: bool = true) -> void:
	var normalized: float = clampf(value, 0.0, 1.0)
	music_volume = normalized
	_apply_bus_volume(&"Music", normalized)
	if persist:
		_save_value("audio", "music_volume", normalized)
	music_volume_changed.emit(normalized)

func set_sfx_volume(value: float, persist: bool = true) -> void:
	var normalized: float = clampf(value, 0.0, 1.0)
	sfx_volume = normalized
	_apply_bus_volume(&"SFX", normalized)
	if persist:
		_save_value("audio", "sfx_volume", normalized)
	sfx_volume_changed.emit(normalized)

func set_locale(locale_code: String, persist: bool = true) -> void:
	if locale_code.is_empty():
		return
	locale = locale_code
	if persist:
		_save_value("general", "locale", locale_code)
	locale_setting_changed.emit(locale_code)

func set_short_battle_animations(enabled: bool, persist: bool = true) -> void:
	short_battle_animations = enabled
	if persist:
		_save_value("battle", "short_animations", enabled)
	short_battle_animations_changed.emit(enabled)

func has_seen_tip(tip_id: String) -> bool:
	return tip_id in seen_tips

func mark_tip_seen(tip_id: String, persist: bool = true) -> void:
	if tip_id in seen_tips:
		return
	seen_tips.append(tip_id)
	if persist:
		_save_value("tips", "seen", seen_tips.duplicate())

func _apply_audio_buses() -> void:
	_apply_bus_volume(&"Music", music_volume)
	_apply_bus_volume(&"SFX", sfx_volume)

func _apply_bus_volume(bus_name: StringName, value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("Audio bus not found: %s" % bus_name)
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(bus_index, value <= 0.0)

func _save_value(section: String, key: String, value: Variant) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(settings_path)
	config.set_value(section, key, value)
	var error: Error = config.save(settings_path)
	if error != OK:
		push_warning("Unable to save setting %s/%s: %s" % [section, key, error])

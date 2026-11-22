extends SceneTree

const TEST_SETTINGS_PATH := "user://pixelking_settings_test.cfg"

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	var initial: ConfigFile = ConfigFile.new()
	initial.set_value("unrelated", "preserved", 42)
	initial.save(TEST_SETTINGS_PATH)

	var manager_script: Script = load("res://scripts/autoload/SettingsManager.gd") as Script
	var writer: Node = manager_script.new() as Node
	writer.call("configure_path", TEST_SETTINGS_PATH)
	root.add_child(writer)
	await process_frame
	writer.call("set_music_volume", 0.35)
	writer.call("set_sfx_volume", 0.0)
	writer.call("set_locale", "en")
	_expect(is_equal_approx(float(writer.get("music_volume")), 0.35), "music volume updates in memory")
	_expect(is_equal_approx(float(writer.get("sfx_volume")), 0.0), "SFX volume updates in memory")
	writer.queue_free()
	await process_frame

	var reader: Node = manager_script.new() as Node
	reader.call("configure_path", TEST_SETTINGS_PATH)
	root.add_child(reader)
	await process_frame
	_expect(is_equal_approx(float(reader.get("music_volume")), 0.35), "music volume survives reload")
	_expect(is_equal_approx(float(reader.get("sfx_volume")), 0.0), "SFX volume survives reload")
	_expect(str(reader.get("locale")) == "en", "locale survives reload")

	var saved: ConfigFile = ConfigFile.new()
	_expect(saved.load(TEST_SETTINGS_PATH) == OK, "settings file can be reloaded")
	_expect(int(saved.get_value("unrelated", "preserved", 0)) == 42, "saving preserves unrelated settings")
	reader.queue_free()

	# A saved choice beats the device language.
	var chinese_device_with_choice: Node = manager_script.new() as Node
	chinese_device_with_choice.call("configure_path", TEST_SETTINGS_PATH)
	chinese_device_with_choice.set("device_language_override", "zh")
	chinese_device_with_choice.call("load_settings")
	_expect(str(chinese_device_with_choice.get("locale")) == "en", "a saved language is kept on a Chinese device")
	chinese_device_with_choice.free()

	# First launch: no settings file yet, so the device language decides.
	_cleanup()
	for case: Array in [["zh", "zh_CN"], ["ZH", "zh_CN"], ["en", "en"], ["ja", "en"], ["fr", "en"]]:
		var fresh: Node = manager_script.new() as Node
		fresh.call("configure_path", TEST_SETTINGS_PATH)
		fresh.set("device_language_override", case[0])
		fresh.call("load_settings")
		_expect(str(fresh.get("locale")) == case[1], "first launch on a '%s' device starts in %s" % [case[0], case[1]])
		fresh.free()
	_expect(not FileAccess.file_exists(TEST_SETTINGS_PATH), "the device default is not written as a choice")
	_cleanup()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

func _finish() -> void:
	print("[PASS] Settings persistence test" if not failed else "[FAIL] Settings persistence test")
	quit(1 if failed else 0)

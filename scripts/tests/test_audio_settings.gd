extends SceneTree

var failed: bool = false
var original_music: float = 0.75
var original_sfx: float = 0.85

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var settings_manager: Node = root.get_node("SettingsManager")
	var audio_manager: Node = root.get_node("AudioManager")
	var music_player: AudioStreamPlayer = audio_manager.get("music_player") as AudioStreamPlayer
	_expect(music_player != null and music_player.stream != null and music_player.playing, "placeholder music is loaded and playing")
	original_music = float(settings_manager.get("music_volume"))
	original_sfx = float(settings_manager.get("sfx_volume"))
	audio_manager.call("set_music_volume", 0.40)
	audio_manager.call("set_sfx_volume", 0.30)
	_expect(_bus_matches(&"Music", 0.40), "Music bus follows the persisted music setting")
	_expect(_bus_matches(&"SFX", 0.30), "SFX bus follows the persisted SFX setting")

	var menu_scene: PackedScene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu: Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	var menu_music: HSlider = menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/MusicSlider") as HSlider
	var menu_sfx: HSlider = menu.get_node("SettingsOverlay/SettingsPanel/SettingsContent/SoundSlider") as HSlider
	_expect(is_equal_approx(float(menu_music.value), 0.40), "main-menu music slider loads the shared value")
	_expect(is_equal_approx(float(menu_sfx.value), 0.30), "main-menu SFX slider loads the shared value")

	var game_state: Node = root.get_node("GameState")
	game_state.call("start_new_game")
	var battle_scene: PackedScene = load("res://scenes/battle/BattleScene.tscn") as PackedScene
	var battle: Control = battle_scene.instantiate() as Control
	root.add_child(battle)
	await process_frame
	var battle_music: HSlider = _find_slider(battle, "MusicVolume")
	var battle_sfx: HSlider = _find_slider(battle, "SFXVolume")
	_expect(battle_music != null and is_equal_approx(float(battle_music.value), 0.40), "battle music slider loads the shared value")
	_expect(battle_sfx != null and is_equal_approx(float(battle_sfx.value), 0.30), "battle SFX slider loads the shared value")

	settings_manager.call("set_music_volume", 0.55)
	await process_frame
	_expect(is_equal_approx(float(menu_music.value), 0.55), "main-menu music slider stays synchronized")
	_expect(is_equal_approx(float(battle_music.value), 0.55), "battle music slider stays synchronized")

	battle_sfx.value = 0.20
	await process_frame
	_expect(is_equal_approx(float(settings_manager.get("sfx_volume")), 0.20), "battle SFX slider updates shared settings")
	_expect(is_equal_approx(float(menu_sfx.value), 0.20), "main-menu SFX slider receives battle changes")

	audio_manager.call("set_sfx_volume", 0.0)
	var sfx_bus: int = AudioServer.get_bus_index(&"SFX")
	_expect(sfx_bus >= 0 and AudioServer.is_bus_mute(sfx_bus), "zero SFX volume mutes the bus")

	audio_manager.call("set_music_volume", original_music)
	audio_manager.call("set_sfx_volume", original_sfx)
	menu.queue_free()
	battle.queue_free()
	await process_frame
	_finish()

func _find_slider(node: Node, slider_name: String) -> HSlider:
	if node.name == slider_name and node is HSlider:
		return node as HSlider
	for child: Node in node.get_children():
		var found: HSlider = _find_slider(child, slider_name)
		if found != null:
			return found
	return null

func _bus_matches(bus_name: StringName, expected: float) -> bool:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return false
	return is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), expected)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func _finish() -> void:
	print("[PASS] Audio settings test" if not failed else "[FAIL] Audio settings test")
	quit(1 if failed else 0)

class_name AppAudioManager
extends Node

const PLACEHOLDER_MUSIC_PATH := "res://assets/audio/placeholder_chiptune.wav"

var music_player: AudioStreamPlayer
@onready var settings_manager: AppSettingsManager = get_node("/root/SettingsManager") as AppSettingsManager

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "PlaceholderMusic"
	music_player.bus = &"Music"
	music_player.finished.connect(_restart_music)
	add_child(music_player)
	_start_placeholder_music()

func set_music_volume(value: float) -> void:
	settings_manager.set_music_volume(value)

func set_sfx_volume(value: float) -> void:
	settings_manager.set_sfx_volume(value)

func music_volume() -> float:
	return settings_manager.music_volume

func sfx_volume() -> float:
	return settings_manager.sfx_volume

func _start_placeholder_music() -> void:
	var stream: AudioStream = load(PLACEHOLDER_MUSIC_PATH) as AudioStream
	if stream == null:
		push_warning("Placeholder music could not be loaded: %s" % PLACEHOLDER_MUSIC_PATH)
		return
	if stream is AudioStreamWAV:
		var wave: AudioStreamWAV = stream.duplicate() as AudioStreamWAV
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_begin = 0
		wave.loop_end = int(wave.get_length() * float(wave.mix_rate))
		stream = wave
	music_player.stream = stream
	music_player.play()

func _restart_music() -> void:
	if music_player.stream != null:
		music_player.play()

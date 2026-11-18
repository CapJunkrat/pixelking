class_name AppAudioManager
extends Node

## Background music. Each screen has a track; moving to a screen with another track
## crossfades to it. All tracks are seamless loops (CC0, see assets/audio/music/CREDITS.md).

const TRACKS := {
	&"explore": "res://assets/audio/music/bards_tale_loop.wav",
	&"battle": "res://assets/audio/music/minstrel_dance_loop.wav",
	&"rest": "res://assets/audio/music/old_tower_inn_loop.wav",
}
## Screens (scene file paths) and their track; any other screen plays `explore`.
const SCENE_TRACKS := {
	"res://scenes/battle/BattleScene.tscn": &"battle",
	"res://scenes/run/RunInteractionScene.tscn": &"rest",
}
const DEFAULT_TRACK := &"explore"
const FADE_SECONDS := 0.8
const SILENT_DB := -40.0

var music_player: AudioStreamPlayer
var current_track: StringName = &""
var _fade: Tween = null
var _last_scene: Node = null
var _streams: Dictionary = {}
@onready var settings_manager: AppSettingsManager = get_node("/root/SettingsManager") as AppSettingsManager

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.bus = &"Music"
	add_child(music_player)
	play_track(DEFAULT_TRACK, true)

## Follows scene changes (change_scene_to_* swaps current_scene between frames).
func _process(_delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == _last_scene:
		return
	_last_scene = scene
	if scene != null:
		play_track(track_for_scene(scene.scene_file_path))

static func track_for_scene(scene_path: String) -> StringName:
	return SCENE_TRACKS.get(scene_path, DEFAULT_TRACK)

## Switches to `track` (no-op when it already plays), fading the old one out.
func play_track(track: StringName, immediate: bool = false) -> void:
	if track == current_track and music_player.playing:
		return
	var stream: AudioStream = _stream(track)
	if stream == null:
		return
	current_track = track
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if immediate or not music_player.playing:
		_start(stream)
		return
	_fade = create_tween()
	_fade.tween_property(music_player, "volume_db", SILENT_DB, FADE_SECONDS * 0.5)
	_fade.tween_callback(_start.bind(stream))

func _start(stream: AudioStream) -> void:
	music_player.stream = stream
	music_player.volume_db = SILENT_DB if music_player.playing else 0.0
	music_player.play()
	if music_player.volume_db < 0.0:
		_fade = create_tween()
		_fade.tween_property(music_player, "volume_db", 0.0, FADE_SECONDS * 0.5)

func _stream(track: StringName) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	var path: String = str(TRACKS.get(track, ""))
	var stream: AudioStream = load(path) as AudioStream if not path.is_empty() else null
	if stream == null:
		push_warning("Music could not be loaded: %s" % path)
		return null
	if stream is AudioStreamWAV:
		var wave: AudioStreamWAV = stream as AudioStreamWAV
		if wave.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wave = wave.duplicate() as AudioStreamWAV
			wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wave.loop_begin = 0
			wave.loop_end = int(wave.get_length() * float(wave.mix_rate))
		stream = wave
	_streams[track] = stream
	return stream

func set_music_volume(value: float) -> void:
	settings_manager.set_music_volume(value)

func set_sfx_volume(value: float) -> void:
	settings_manager.set_sfx_volume(value)

func music_volume() -> float:
	return settings_manager.music_volume

func sfx_volume() -> float:
	return settings_manager.sfx_volume

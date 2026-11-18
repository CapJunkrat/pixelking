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
## Sound effects (CC0 by Kenney, see assets/audio/sfx/CREDITS.md): name -> variant
## count; a random variant plays each time, slightly re-pitched so repeats differ.
const SFX_DIR := "res://assets/audio/sfx/"
const SFX := {
	&"move": 5, &"capture": 4, &"explode": 2, &"rock": 2, &"shell": 1, &"check": 1,
	&"shot": 2, &"coins": 2, &"page": 1, &"item": 1, &"select": 1, &"click": 1,
	&"error": 1, &"confirm": 1, &"victory": 1, &"defeat": 1,
}
## Jingles keep their pitch; everything else varies a little.
const SFX_STEADY: Array[StringName] = [&"victory", &"defeat", &"check"]
const SFX_VOICES := 8
const FADE_SECONDS := 0.8
const SILENT_DB := -40.0

var music_player: AudioStreamPlayer
var current_track: StringName = &""
var _fade: Tween = null
var _last_scene: Node = null
var _streams: Dictionary = {}
var _sfx_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
@onready var settings_manager: AppSettingsManager = get_node("/root/SettingsManager") as AppSettingsManager

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.bus = &"Music"
	add_child(music_player)
	for index: int in range(SFX_VOICES):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "Sfx%d" % index
		voice.bus = &"SFX"
		add_child(voice)
		_sfx_players.append(voice)
	get_tree().node_added.connect(_on_node_added)
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

## Plays sound effect `name` (a key of SFX) on the next free voice.
func play_sfx(name: StringName, volume_db: float = 0.0) -> void:
	var count: int = int(SFX.get(name, 0))
	if count <= 0 or _sfx_players.is_empty():
		return
	var path: String = "%s%s_%d.ogg" % [SFX_DIR, String(name), randi() % count]
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path)
	var stream: AudioStream = _sfx_cache[path] as AudioStream
	if stream == null:
		return
	var voice: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 if name in SFX_STEADY else randf_range(0.93, 1.07)
	voice.play()

## Plays `name` after `seconds` (to land on an animation's hit).
func play_sfx_later(name: StringName, seconds: float, volume_db: float = 0.0) -> void:
	if seconds <= 0.0:
		play_sfx(name, volume_db)
		return
	get_tree().create_timer(seconds).timeout.connect(play_sfx.bind(name, volume_db))

## Every button in the game clicks when pressed (unless it opts out with the
## "silent" meta, e.g. when it plays its own sound).
func _on_node_added(node: Node) -> void:
	var button: BaseButton = node as BaseButton
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed.bind(button))

func _on_button_pressed(button: BaseButton) -> void:
	if is_instance_valid(button) and not button.has_meta("silent"):
		play_sfx(&"click", -6.0)

func set_music_volume(value: float) -> void:
	settings_manager.set_music_volume(value)

func set_sfx_volume(value: float) -> void:
	settings_manager.set_sfx_volume(value)

func music_volume() -> float:
	return settings_manager.music_volume

func sfx_volume() -> float:
	return settings_manager.sfx_volume

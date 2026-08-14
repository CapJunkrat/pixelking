extends Node

signal skin_changed(skin_id: StringName)

const SKIN_DIRECTORY := "res://assets/chess/piece_skins"
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SKIN_ID: StringName = &"modern_parchment"
const CURRENT_STYLE_VERSION := 2

var current_skin_id: StringName = DEFAULT_SKIN_ID
var _skins: Dictionary = {}

func _ready() -> void:
	_discover_skins()
	_load_selection()

func available_skins() -> Array[PieceSkin]:
	var result: Array[PieceSkin] = []
	for skin in _skins.values():
		result.append(skin as PieceSkin)
	result.sort_custom(func(a: PieceSkin, b: PieceSkin) -> bool: return a.display_name < b.display_name)
	return result

func current_skin() -> PieceSkin:
	return _skins.get(current_skin_id) as PieceSkin

func set_skin(skin_id: StringName) -> bool:
	if not _skins.has(skin_id):
		return false
	if current_skin_id == skin_id:
		return true
	current_skin_id = skin_id
	_save_selection()
	skin_changed.emit(current_skin_id)
	return true

func piece_texture(color: StringName, piece_type: StringName) -> Texture2D:
	var skin: PieceSkin = current_skin()
	if skin == null:
		return null
	if skin.has_texture(color, piece_type):
		return skin.texture(color, piece_type)
	var fallback_type: StringName = _fallback_piece_type(piece_type)
	return skin.texture(color, fallback_type) if skin.has_texture(color, fallback_type) else null

func _fallback_piece_type(piece_type: StringName) -> StringName:
	match piece_type:
		&"lancer":
			return &"knight"
		&"archmage":
			return &"queen"
		_:
			return piece_type

func _discover_skins() -> void:
	_skins.clear()
	for file_name in DirAccess.get_files_at(SKIN_DIRECTORY):
		if not file_name.ends_with(".tres"):
			continue
		var resource := load(SKIN_DIRECTORY.path_join(file_name)) as PieceSkin
		if resource == null or resource.skin_id.is_empty():
			continue
		_skins[resource.skin_id] = resource
	if not _skins.has(current_skin_id) and not _skins.is_empty():
		current_skin_id = (_skins.keys()[0] as StringName)

func _load_selection() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	if int(config.get_value("appearance", "style_version", 0)) < CURRENT_STYLE_VERSION:
		current_skin_id = DEFAULT_SKIN_ID
		_save_selection()
		return
	var saved_id := StringName(config.get_value("appearance", "piece_skin", current_skin_id))
	if _skins.has(saved_id):
		current_skin_id = saved_id

func _save_selection() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("appearance", "piece_skin", String(current_skin_id))
	config.set_value("appearance", "style_version", CURRENT_STYLE_VERSION)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Unable to save piece skin setting: %s" % error)

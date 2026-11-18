extends Node

signal skin_changed(skin_id: StringName)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_SKIN_ID: StringName = &"carved_figurine"
## Bumped when the default art changes so existing players switch to it once.
const CURRENT_STYLE_VERSION := 3
const CARVED_FIGURINE_SKIN: PieceSkin = preload("res://assets/chess/piece_skins/carved_figurine.tres")
const MODERN_PARCHMENT_SKIN: PieceSkin = preload("res://assets/chess/piece_skins/modern_parchment.tres")
const ROYAL_FORGE_SKIN: PieceSkin = preload("res://assets/chess/piece_skins/royal_forge.tres")
const BUILT_IN_SKINS: Array[PieceSkin] = [CARVED_FIGURINE_SKIN, MODERN_PARCHMENT_SKIN, ROYAL_FORGE_SKIN]

var current_skin_id: StringName = DEFAULT_SKIN_ID
var _skins: Dictionary = {}

func _ready() -> void:
	_discover_skins()
	_load_selection()

func available_skins() -> Array[PieceSkin]:
	var result: Array[PieceSkin] = []
	for skin: Variant in   _skins.values():
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
	# Forms of one piece (squire levels, tide states) share that piece's picture.
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece_type))
	if definition != null:
		piece_type = StringName(definition.art_key())
	if skin.has_texture(color, piece_type):
		return skin.texture(color, piece_type)
	var fallback_type: StringName = _fallback_piece_type(piece_type)
	if skin.has_texture(color, fallback_type):
		return skin.texture(color, fallback_type)
	# Pieces drawn only for the default style still show up under older styles.
	var default_skin: PieceSkin = _skins.get(DEFAULT_SKIN_ID) as PieceSkin
	if default_skin != null and default_skin != skin and default_skin.has_texture(color, piece_type):
		return default_skin.texture(color, piece_type)
	return null

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
	for resource: PieceSkin in BUILT_IN_SKINS:
		if resource == null or resource.skin_id.is_empty():
			push_error("Invalid built-in piece skin resource")
			continue
		_skins[resource.skin_id] = resource
	if not _skins.has(DEFAULT_SKIN_ID):
		push_error("Default piece skin is unavailable: %s" % DEFAULT_SKIN_ID)
	if not _skins.has(current_skin_id) and _skins.has(DEFAULT_SKIN_ID):
		current_skin_id = DEFAULT_SKIN_ID
	elif not _skins.has(current_skin_id) and not _skins.is_empty():
		current_skin_id = _skins.keys()[0] as StringName

func _load_selection() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	if int(config.get_value("appearance", "style_version", 0)) < CURRENT_STYLE_VERSION:
		current_skin_id = DEFAULT_SKIN_ID
		_save_selection()
		return
	var saved_id: StringName = StringName(config.get_value("appearance", "piece_skin", current_skin_id))
	if _skins.has(saved_id):
		current_skin_id = saved_id

func _save_selection() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("appearance", "piece_skin", String(current_skin_id))
	config.set_value("appearance", "style_version", CURRENT_STYLE_VERSION)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Unable to save piece skin setting: %s" % error)

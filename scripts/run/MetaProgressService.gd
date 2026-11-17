class_name MetaProgressService
extends RefCounted

const DEFAULT_PATH := "user://pixelking_meta.save"
const SAVE_VERSION := 2

var save_path: String = DEFAULT_PATH

func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path

func endless_unlocked() -> bool:
	return bool(_load_data().get("endless_unlocked", false))

func unlock_endless() -> Error:
	var data: Dictionary = _load_data()
	data["endless_unlocked"] = true
	return _save_data(data)

func discovered_piece_ids() -> Array[String]:
	var result: Array[String] = []
	var stored: Variant = _load_data().get("discovered_piece_ids", [])
	if stored is Array:
		for value: Variant in stored as Array:
			var piece_id: String = str(value)
			if PieceDefDatabase.has_def(piece_id) and piece_id not in result:
				result.append(piece_id)
	result.sort()
	return result

func is_piece_discovered(piece_id: String) -> bool:
	return piece_id in discovered_piece_ids()

func record_discovered_piece_ids(piece_ids: Array[String]) -> Error:
	var data: Dictionary = _load_data()
	var discovered: Array[String] = discovered_piece_ids()
	var changed: bool = false
	for piece_id: String in piece_ids:
		if PieceDefDatabase.has_def(piece_id) and piece_id not in discovered:
			discovered.append(piece_id)
			changed = true
	if not changed:
		return OK
	discovered.sort()
	data["discovered_piece_ids"] = discovered
	return _save_data(data)

func _load_data() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {"version": SAVE_VERSION, "endless_unlocked": false, "discovered_piece_ids": []}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {"version": SAVE_VERSION, "endless_unlocked": false, "discovered_piece_ids": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"version": SAVE_VERSION, "endless_unlocked": false, "discovered_piece_ids": []}
	var data: Dictionary = (parsed as Dictionary).duplicate(true)
	data["version"] = SAVE_VERSION
	if not data.has("discovered_piece_ids"):
		data["discovered_piece_ids"] = []
	return data

func _save_data(data: Dictionary) -> Error:
	data["version"] = SAVE_VERSION
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	return OK

class_name MetaProgressService
extends RefCounted

const DEFAULT_PATH := "user://pixelking_meta.save"

var save_path: String = DEFAULT_PATH

func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path

func endless_unlocked() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data is Dictionary and bool((data as Dictionary).get("endless_unlocked", false))

func unlock_endless() -> Error:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "endless_unlocked": true}))
	file.flush()
	return OK

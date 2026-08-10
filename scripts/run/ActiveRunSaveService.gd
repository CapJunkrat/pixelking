class_name ActiveRunSaveService
extends RefCounted

const FORMAT_ID := "pixelking_active_run"
const SAVE_MAGIC := "PKRUN001"
const SAVE_FORMAT_VERSION := 1
const DEFAULT_SAVE_PATH := "user://active_run.save"

var save_path: String = DEFAULT_SAVE_PATH
var last_error: Error = OK
var last_error_message: String = ""

func _init(path: String = DEFAULT_SAVE_PATH) -> void:
	save_path = path
	_recover_backup_if_needed()

func exists() -> bool:
	_recover_backup_if_needed()
	return FileAccess.file_exists(save_path)

func save(run_state: RunState) -> Error:
	if run_state == null or not run_state.is_valid():
		return _set_error(ERR_INVALID_DATA, "RunState is invalid and was not saved")
	var envelope: Dictionary = {
		"format_id": FORMAT_ID,
		"save_format_version": SAVE_FORMAT_VERSION,
		"run_state": run_state.to_dictionary(),
	}
	var temporary_path: String = save_path + ".tmp"
	var backup_path: String = save_path + ".bak"
	_remove_if_exists(temporary_path)
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _set_error(FileAccess.get_open_error(), "Unable to open temporary active Run save")
	file.store_buffer(SAVE_MAGIC.to_ascii_buffer())
	file.store_var(envelope, false)
	file.flush()
	file.close()
	if not FileAccess.file_exists(temporary_path):
		return _set_error(ERR_FILE_CANT_WRITE, "Temporary active Run save was not written")

	_remove_if_exists(backup_path)
	if FileAccess.file_exists(save_path):
		var backup_error: Error = DirAccess.rename_absolute(_absolute(save_path), _absolute(backup_path))
		if backup_error != OK:
			_remove_if_exists(temporary_path)
			return _set_error(backup_error, "Unable to create active Run backup")
	var replace_error: Error = DirAccess.rename_absolute(_absolute(temporary_path), _absolute(save_path))
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(_absolute(backup_path), _absolute(save_path))
		_remove_if_exists(temporary_path)
		return _set_error(replace_error, "Unable to replace active Run save")
	_remove_if_exists(backup_path)
	return _set_error(OK, "")

func load_run() -> RunState:
	_recover_backup_if_needed()
	if not FileAccess.file_exists(save_path):
		_set_error(ERR_FILE_NOT_FOUND, "No active Run save exists")
		return null
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_set_error(FileAccess.get_open_error(), "Unable to open active Run save")
		return null
	var magic_size: int = SAVE_MAGIC.length()
	if file.get_length() <= magic_size:
		file.close()
		_set_error(ERR_FILE_CORRUPT, "Active Run save is truncated")
		return null
	var magic: String = file.get_buffer(magic_size).get_string_from_ascii()
	if magic != SAVE_MAGIC:
		file.close()
		_set_error(ERR_FILE_CORRUPT, "Active Run save header is invalid")
		return null
	var raw_value: Variant = file.get_var(false)
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF:
		_set_error(read_error, "Active Run save could not be read")
		return null
	if not raw_value is Dictionary:
		_set_error(ERR_FILE_CORRUPT, "Active Run save envelope is corrupt")
		return null
	var envelope: Dictionary = raw_value as Dictionary
	if str(envelope.get("format_id", "")) != FORMAT_ID:
		_set_error(ERR_FILE_UNRECOGNIZED, "Active Run save format is unrecognized")
		return null
	if int(envelope.get("save_format_version", -1)) != SAVE_FORMAT_VERSION:
		_set_error(ERR_FILE_UNRECOGNIZED, "Active Run save format version is unsupported")
		return null
	var state_value: Variant = envelope.get("run_state", null)
	if not state_value is Dictionary:
		_set_error(ERR_FILE_CORRUPT, "Active Run payload is missing")
		return null
	var run_state: RunState = RunState.new()
	if not run_state.load_from_dictionary(state_value as Dictionary):
		_set_error(ERR_INVALID_DATA, "Active Run payload failed validation")
		return null
	_set_error(OK, "")
	return run_state

func delete() -> Error:
	var first_error: Error = OK
	for path: String in [save_path, save_path + ".tmp", save_path + ".bak"]:
		if FileAccess.file_exists(path):
			var remove_error: Error = DirAccess.remove_absolute(_absolute(path))
			if first_error == OK and remove_error != OK:
				first_error = remove_error
	return _set_error(first_error, "Unable to delete active Run save" if first_error != OK else "")

func _recover_backup_if_needed() -> void:
	var backup_path: String = save_path + ".bak"
	if not FileAccess.file_exists(save_path) and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(_absolute(backup_path), _absolute(save_path))

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute(path))

func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func _set_error(error: Error, message: String) -> Error:
	last_error = error
	last_error_message = message
	return error

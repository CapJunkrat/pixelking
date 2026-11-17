class_name TestSaveSandbox
extends RefCounted

var base_paths: Array[String] = []

func add(base_path: String) -> TestSaveSandbox:
	if base_path not in base_paths:
		base_paths.append(base_path)
	return self

func cleanup() -> void:
	for base_path: String in base_paths:
		for suffix: String in ["", ".tmp", ".bak"]:
			var path: String = base_path + suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func cleanup_parent_directory(base_path: String) -> void:
	var directory: String = base_path.get_base_dir()
	if directory.begins_with("user://") and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(directory)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))

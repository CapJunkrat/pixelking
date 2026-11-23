class_name TestManifestIntegrity
extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest_paths: Array[String] = []
	var layers: Dictionary = {}
	var unique_paths: Dictionary = {}
	var missing_paths: Array[String] = []
	var invalid_kind_paths: Array[String] = []
	for entry: Dictionary in TestManifest.TESTS:
		var path: String = str(entry.get("path", ""))
		manifest_paths.append(path)
		layers[str(entry.get("layer", ""))] = true
		unique_paths[path] = true
		if not FileAccess.file_exists(path):
			missing_paths.append(path)
		if str(entry.get("kind", "")) not in ["scene_tree", "node_methods"]:
			invalid_kind_paths.append(path)
	_expect(missing_paths.is_empty(), "all manifest paths exist: %s" % [missing_paths])
	_expect(invalid_kind_paths.is_empty(), "all manifest kinds are supported: %s" % [invalid_kind_paths])
	_expect(unique_paths.size() == manifest_paths.size(), "manifest contains no duplicate paths")
	for required_layer: String in ["unit", "integration", "scene", "smoke", "e2e"]:
		_expect(layers.has(required_layer), "manifest includes %s layer" % required_layer)
	var discovered_paths: Array[String] = []
	_collect_tests("res://scripts/tests", discovered_paths)
	manifest_paths.sort()
	discovered_paths.sort()
	_expect(manifest_paths == discovered_paths, "every test_*.gd file is explicitly registered once")
	print("[PASS] Test manifest integrity" if not failed else "[FAIL] Test manifest integrity")
	quit(1 if failed else 0)

func _collect_tests(directory_path: String, output: Array[String]) -> void:
	for file_name: String in DirAccess.get_files_at(directory_path):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			output.append(directory_path.path_join(file_name))
	for child_directory: String in DirAccess.get_directories_at(directory_path):
		_collect_tests(directory_path.path_join(child_directory), output)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

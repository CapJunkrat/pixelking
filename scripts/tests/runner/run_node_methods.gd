class_name NodeMethodTestRunner
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_path: String = _argument_value("--test-file=")
	if test_path.is_empty():
		push_error("run_node_methods requires --test-file=res://...")
		quit(2)
		return
	var script: Script = load(test_path) as Script
	if script == null:
		push_error("Cannot load Node test suite: %s" % test_path)
		quit(2)
		return
	var suite: Node = script.new() as Node
	if suite == null:
		push_error("Node test suite cannot be instantiated: %s" % test_path)
		quit(2)
		return
	root.add_child(suite)
	var methods: Array[StringName] = []
	for method_value: Variant in suite.get_method_list():
		var method: Dictionary = method_value as Dictionary
		var method_name: StringName = StringName(str(method.get("name", "")))
		if String(method_name).begins_with("test_"):
			methods.append(method_name)
	methods.sort()
	if methods.is_empty():
		push_error("Node test suite contains no test_* methods: %s" % test_path)
		quit(2)
		return
	for method_name: StringName in methods:
		print("[RUN] %s::%s" % [test_path, method_name])
		suite.call(method_name)
		print("[PASS] %s::%s" % [test_path, method_name])
	suite.queue_free()
	print("[PASS] Node suite: %d methods" % methods.size())
	quit(0)

func _argument_value(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

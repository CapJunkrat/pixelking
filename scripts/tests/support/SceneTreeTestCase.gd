class_name SceneTreeTestCase
extends SceneTree

var failed: bool = false

func expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

func finish_test(label: String) -> void:
	print("[PASS] %s" % label if not failed else "[FAIL] %s" % label)
	quit(1 if failed else 0)

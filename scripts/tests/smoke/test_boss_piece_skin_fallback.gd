extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var manager: Node = root.get_node("PieceSkinManager")
	for color: StringName in [&"white", &"black"]:
		var own_lancer: Texture2D = manager.call("piece_texture", color, &"lancer") as Texture2D
		_expect(own_lancer != null and own_lancer != manager.call("piece_texture", color, &"knight"), "%s Lancer has its own art in the default skin" % color)
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("[PASS] Boss piece skin fallback test" if failures == 0 else "[FAIL] Boss piece skin fallback test")
	quit(0 if failures == 0 else 1)

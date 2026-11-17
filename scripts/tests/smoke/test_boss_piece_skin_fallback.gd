extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var manager: Node = root.get_node("PieceSkinManager")
	var default_skin: StringName = manager.get("current_skin_id")
	for color: StringName in [&"white", &"black"]:
		var own_lancer: Texture2D = manager.call("piece_texture", color, &"lancer") as Texture2D
		_expect(own_lancer != null and own_lancer != manager.call("piece_texture", color, &"knight"), "%s Lancer has its own art in the default skin" % color)
	# Older skins have no Lancer or Archmage art and fall back. Switched without saving.
	manager.set("current_skin_id", &"modern_parchment")
	for color: StringName in [&"white", &"black"]:
		var lancer: Texture2D = manager.call("piece_texture", color, &"lancer") as Texture2D
		var archmage: Texture2D = manager.call("piece_texture", color, &"archmage") as Texture2D
		var knight: Texture2D = manager.call("piece_texture", color, &"knight") as Texture2D
		var queen: Texture2D = manager.call("piece_texture", color, &"queen") as Texture2D
		_expect(lancer != null and lancer == knight, "%s Lancer falls back to the Knight in skins without Lancer art" % color)
		_expect(archmage != null and archmage == queen, "%s Archmage falls back to the Queen in skins without Archmage art" % color)
	manager.set("current_skin_id", default_skin)
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

extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var items: Array[ChallengerItemDef] = []
	for id: StringName in RunContentDatabase.relic_ids():
		var definition: ChallengerItemDef = ChallengerItemDatabase.get_def(id)
		_expect(definition != null and definition.icon != null, "%s has an item icon texture" % id)
		items.append(definition)
	var scene: PackedScene = load("res://scenes/battle/ChallengerTray.tscn") as PackedScene
	var tray: ChallengerTray = scene.instantiate() as ChallengerTray
	root.add_child(tray)
	await process_frame
	tray.refresh(items, [false, false, false, false])
	var slots: Array[Button] = tray.slots()
	for index: int in range(items.size()):
		_expect(slots[index].icon == items[index].icon and slots[index].text.is_empty(), "slot %d displays its texture instead of placeholder text" % index)
		_expect("\n" in slots[index].tooltip_text and slots[index].tooltip_text.length() > 20, "slot %d tooltip contains item name, function, and usage" % index)
	var bomb: ChallengerItemDef = ChallengerItemDatabase.get_def(&"royal_bomb")
	_expect(bomb != null and bomb.icon != null and bomb.is_consumable(), "Royal Bomb is a real one-use item with an icon")
	tray.refresh([bomb], [true])
	_expect(not tray.slots()[0].disabled and "One use" in tray.slots()[0].tooltip_text, "usable consumable is enabled and explains how to target it")
	tray.queue_free()
	_finish()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("[PASS] Challenger item icon test" if failures == 0 else "[FAIL] Challenger item icon test")
	quit(0 if failures == 0 else 1)

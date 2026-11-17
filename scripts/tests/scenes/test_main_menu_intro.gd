extends SceneTree

func _init() -> void:
	await process_frame
	var ok := true
	var packed_scene := load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu := packed_scene.instantiate()
	root.add_child(menu)
	await process_frame

	var menu_buttons := menu.get_node("SafeArea/Layout/MenuPanel/MenuButtons") as VBoxContainer
	var new_game_button := menu_buttons.get_node("NewGameButton") as Button
	var initial_positions: Dictionary = {}
	for child in menu_buttons.get_children():
		var button := child as Button
		if button != null:
			initial_positions[button] = button.position

	if menu.modulate.a < 0.99:
		push_error("Main menu background must remain visible during intro")
		ok = false
	if new_game_button.modulate.a > 0.1:
		push_error("Menu buttons must begin hidden for the staggered intro")
		ok = false

	menu.call("_finish_intro", true)
	await process_frame
	if new_game_button.modulate.a < 0.99:
		push_error("Skipping the intro must reveal every menu button")
		ok = false
	if not new_game_button.has_focus():
		push_error("New Journey must receive focus after the intro")
		ok = false

	var previous_bottom := -INF
	for child in menu_buttons.get_children():
		var button := child as Button
		if button == null:
			continue
		if button.position != initial_positions[button]:
			push_error("Intro must not move menu buttons")
			ok = false
		if button.position.y < previous_bottom:
			push_error("Menu buttons overlap after the intro")
			ok = false
		if button.modulate.a < 0.99:
			push_error("Every menu button must be visible after the intro")
			ok = false
		previous_bottom = button.position.y + button.size.y

	print("[PASS] Main menu intro test" if ok else "[FAIL] Main menu intro test")
	quit(0 if ok else 1)

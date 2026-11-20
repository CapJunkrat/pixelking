extends SceneTreeTestCase

## Real production constructors, every piece / locale / phone width. No real save.
var records: Array[Dictionary] = []
var cases: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 1000
	var info: Control = (load("res://scripts/battle/PieceInfoPanel.gd") as GDScript).new() as Control
	root.add_child(info)
	expect(info.has_method("show_definition"), "shared readable detail supports definitions outside battle")
	if not info.has_method("show_definition"):
		info.queue_free()
		finish_test("Piece introduction scenes test")
		return
	var loc: Node = root.get_node("Localization")
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	var saved: RunState = manager.current_run
	manager.current_run = RunState.new()
	manager.current_run.gold = 999
	var menu: Control = (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate() as Control
	root.add_child(menu)
	var interaction: Control = (load("res://scenes/run/RunInteractionScene.tscn") as PackedScene).instantiate() as Control
	root.add_child(interaction)
	var piece_count: int = PieceDefDatabase.all_ids().size()
	for width: int in [320, 360, 414]:
		root.content_scale_size = Vector2i(width, 740)
		root.size = Vector2i(width, 740)
		for locale: String in ["en", "zh_CN"]:
			loc.set_locale(locale, false)
			for id: String in PieceDefDatabase.all_ids():
				var definition: PieceDef = PieceDefDatabase.get_def(id)
				for kind: String in ["battle_reward", "shop"]:
					manager.current_run.pending_choice = {"type": kind, "options": [{"id": "inspect", "label": "Recruit " + id, "payload": {"kind": "piece", "piece_def_id": id, "price": 20 if kind == "shop" else 0}}]}
					interaction._render()
					await _settle()
					var card: Control = interaction.choices.get_child(-1) as Control
					var before: Dictionary = manager.current_run.to_dictionary().duplicate(true)
					var button: Button = card.find_child("DetailsButton", true, false) as Button
					expect(button != null and button.is_visible_in_tree(), "%s %s %s %d: visible independent details" % [kind, id, locale, width])
					if button != null:
						var primary: Button = card.find_child("ActionButton", true, false) as Button
						expect(not primary.is_ancestor_of(button) and not button.is_ancestor_of(primary) and not card is BaseButton, "details and recruit/buy are physically independent siblings")
						if id in ["stone_giant", "flame_phoenix", "shield_king"]:
							await _tap(button)
						else:
							button.pressed.emit()
						var panel: Node = interaction.find_child("PieceDetails", true, false)
						expect(panel != null and panel.is_open(), "details opens without choosing")
						expect(manager.current_run.to_dictionary() == before, "details never submits / recruits / buys / changes selection")
						if panel != null:
							panel.close()
					_check_card(card, width, "%s %s %s" % [kind, id, locale])
				var host: GridContainer = GridContainer.new()
				host.columns = 2
				host.position = Vector2(12, 0)
				host.size = Vector2(width - 24, 0)
				root.add_child(host)
				var codex: Control = menu._make_codex_card(id, true)
				host.add_child(codex)
				host.add_child(menu._make_codex_card(id, true))
				await _settle()
				_check_card(codex, width, "Codex %s %s" % [id, locale])
				var codex_detail: Button = codex.find_child("DetailsButton", true, false) as Button
				expect(codex_detail != null, "Codex compact summary links to complete shared detail")
				if codex_detail != null:
					codex_detail.pressed.emit()
					var codex_panel: Node = menu.find_child("PieceDetails", true, false)
					expect(codex_panel != null and codex_panel.is_open(), "Codex details opens the same complete component")
					if codex_panel != null:
						codex_panel.close()
				host.queue_free()
				info.call("show_definition", definition)
				await _settle()
				var scroll: ScrollContainer = info.find_child("DetailScroll", true, false) as ScrollContainer
				expect(scroll != null and info.is_open(), "%s %s %d: shared scrollable detail" % [id, locale, width])
				if scroll != null:
					var text: String = _all_text(info)
					var facts: Dictionary = PiecePresentation.describe(definition)
					expect(str(facts.movement) in text and str(facts.capture) in text, "detail retains complete separated movement and attack")
					for ability_entry: Dictionary in facts.traits:
						expect(str(ability_entry.rule) in text, "detail retains the entire passive rule separately from movement")
					var last: Control = scroll.get_child(0).get_child(-1) as Control
					scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
					await _settle()
					expect(last.get_global_rect().end.y <= scroll.get_global_rect().end.y + 2, "last exception is reachable by scrolling")
					var inside: InputEventMouseButton = InputEventMouseButton.new()
					inside.button_index = MOUSE_BUTTON_LEFT
					inside.pressed = true
					inside.position = info.get_node("Card").position + Vector2(20, 100)
					info._gui_input(inside)
					expect(info.is_open(), "internal taps never dismiss shared detail")
					expect(LayoutOverflow.find(info, width).is_empty(), "detail fits viewport horizontally")
				info.close()
				cases += 1
				records.append({"id": id, "locale": locale, "width": width, "surfaces": ["reward", "shop", "codex", "detail"]})
	expect(cases == piece_count * 6, "all piece / locale / width combinations exercised")
	var report_dir: String = OS.get_environment("TMPDIR")
	if report_dir.is_empty():
		report_dir = OS.get_cache_dir()
	var report: FileAccess = FileAccess.open(report_dir.path_join("pk-ui-layout-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"piece_count": piece_count, "cases": cases, "records": records}, "\t"))
	print("COVERAGE pieces=%d locales=2 widths=320,360,414 cases=%d" % [piece_count, cases])
	interaction.queue_free()
	menu.queue_free()
	info.queue_free()
	manager.current_run = saved
	await process_frame
	finish_test("Piece introduction scenes test")

func _tap(button: Button) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		Input.parse_input_event(event)
		await process_frame

func _settle() -> void:
	for frame: int in range(3):
		await process_frame

func _check_card(card: Control, width: int, context: String) -> void:
	var bounds: Rect2 = card.get_global_rect()
	var errors: Array[String] = []
	for item: Node in card.find_children("*", "Control", true, false):
		var control: Control = item as Control
		if control is Label or control is Button:
			var rect: Rect2 = control.get_global_rect()
			if rect.position.x < bounds.position.x - 1 or rect.end.x > bounds.end.x + 1 or rect.position.y < bounds.position.y - 1 or rect.end.y > bounds.end.y + 1:
				errors.append(str(control.name) + "=" + str(rect))
			if control is Label:
				expect(control.get_theme_font_size("font_size") >= 11, context + " readable labels")
	expect(bounds.position.x >= -1 and bounds.end.x <= width + 1, context + " card fits viewport " + str(bounds))
	expect(errors.is_empty(), context + " all labels/actions within owning card, including vertical bottom: " + str(errors))

func _all_text(node: Node) -> String:
	var text: String = ""
	for label: Node in node.find_children("*", "Label", true, false):
		text += label.text + "\n"
	return text

extends SceneTreeTestCase

## The codex shows every piece on a card of one fixed size with its rarity and a few
## one-word traits; tapping a card (not dragging it) opens the same one-page details
## card used in battle. Every piece's details fit on one 360 x 640 screen.

const SCREEN := Vector2(360, 640)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(SCREEN)
	var game_state: Node = root.get_node("GameState")
	game_state.set("debug_mode", true)
	var localization: Node = root.get_node("Localization")
	for locale: String in ["en", "zh_CN"]:
		localization.call("set_locale", locale, false)
		var menu: Control = (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate() as Control
		root.add_child(menu)
		await _frames(3)
		menu.call("_open_codex")
		await _frames(4)
		var cards: Array[Node] = menu.find_children("Codex_*", "PanelContainer", true, false)
		expect(cards.size() == AchievementCatalog.codex_piece_ids().size(), "%s: a card for every codex piece (%d)" % [locale, cards.size()])
		var heights: Dictionary = {}
		var tagged: int = 0
		for card: Node in cards:
			heights[roundi((card as Control).size.y)] = true
			var tags: Node = card.find_child("Tags", true, false)
			if tags != null and tags.get_child_count() > 0:
				tagged += 1
		expect(heights.size() == 1, "%s: every codex card has the same height %s" % [locale, heights.keys()])
		expect(tagged >= 15, "%s: pieces with traits show them as tags (%d)" % [locale, tagged])
		var giant: Control = menu.find_child("Codex_stone_giant", true, false) as Control
		var tag_texts: Array[String] = []
		for chip: Node in giant.find_child("Tags", true, false).get_children():
			tag_texts.append(str((chip.get_child(0) as Label).text))
		expect(tag_texts.size() >= 2 and tag_texts.all(func(t: String) -> bool: return t.length() <= 14), "%s: Stone Giant tags are short words %s" % [locale, tag_texts])

		# A drag that scrolls does not open anything; a tap does.
		var details: Control = menu.get("codex_details") as Control
		var center: Vector2 = giant.get_global_rect().get_center()
		_click(giant, center, true)
		_click(giant, center + Vector2(0, 40), false)
		expect(not bool(details.call("is_open")), "%s: dragging a card does not open its details" % locale)
		_click(giant, center, true)
		_click(giant, center, false)
		await _frames(2)
		expect(bool(details.call("is_open")), "%s: tapping a card opens its details" % locale)

		# Every piece's details fit on one screen.
		var too_tall: Array[String] = []
		for piece_id: String in AchievementCatalog.codex_piece_ids():
			details.call("show_definition", PieceDefDatabase.get_def(piece_id))
			await _frames(2)
			var card_rect: Rect2 = (details.find_child("Card", true, false) as Control).get_global_rect()
			if card_rect.size.y > SCREEN.y - 40.0 or card_rect.position.x < 0.0 or card_rect.end.x > SCREEN.x:
				too_tall.append("%s %.0fx%.0f" % [piece_id, card_rect.size.x, card_rect.size.y])
		expect(too_tall.is_empty(), "%s: every piece's details fit on one screen %s" % [locale, too_tall])
		details.call("close")
		menu.queue_free()
		await _frames(2)
	localization.call("set_locale", "en", false)
	game_state.set("debug_mode", false)
	finish_test("Codex cards test")

func _click(target: Control, point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.global_position = point
	event.position = point - target.get_global_rect().position
	target.gui_input.emit(event)

func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame

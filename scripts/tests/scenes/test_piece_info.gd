extends SceneTree

## Long-pressing a piece in battle opens a card with how it moves and captures, its
## traits and its current state; a quick tap still just selects it; any tap closes it.

var failed: bool = false
var _loc: Node = null

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_state: Node = root.get_node("GameState")
	_loc = root.get_node("Localization")
	game_state.start_new_game()
	var battle: Node = (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame
	var board_view: Node = battle.board_view
	var info: Node = battle.piece_info
	_expect(info != null and not info.is_open(), "the info card starts closed")

	# A quick tap selects as before and opens nothing.
	var knight: Sprite2D = board_view.get_node("PieceLayer/Piece_1_0") as Sprite2D
	_press(board_view, knight.position + Vector2(0, -12), true)
	board_view.advance_hold(0.1)
	_press(board_view, knight.position + Vector2(0, -12), false)
	board_view.advance_hold(1.0)
	_expect(battle.selected_square == Vector2i(1, 0) and not info.is_open(), "a quick tap selects the knight without opening the card")

	# Holding still opens the card for that piece.
	knight = board_view.get_node("PieceLayer/Piece_1_0") as Sprite2D
	_press(board_view, knight.position + Vector2(0, -12), true)
	board_view.advance_hold(0.5)
	await process_frame
	_expect(info.is_open() and info.shown_square == Vector2i(1, 0), "holding a piece opens its card")
	var text: String = _all_text(info)
	_expect(_loc.text("DRAFT_MOVE_KNIGHT") in text and _loc.text("DRAFT_ATTACK_KNIGHT") in text, "the card explains how it moves and captures")
	_expect(info.find_children("*", "GridContainer", true, false).size() == 1, "the card draws the move grid")
	var close_tap: InputEventMouseButton = InputEventMouseButton.new()
	close_tap.button_index = MOUSE_BUTTON_LEFT
	close_tap.pressed = true
	info._gui_input(close_tap)
	_expect(not info.is_open(), "any tap closes the card")

	# A finger that slides away is not a long press.
	knight = board_view.get_node("PieceLayer/Piece_1_0") as Sprite2D
	_press(board_view, knight.position + Vector2(0, -12), true)
	var drift: InputEventMouseMotion = InputEventMouseMotion.new()
	drift.position = knight.position + Vector2(40, -12)
	board_view._gui_input(drift)
	board_view.advance_hold(1.0)
	_expect(not info.is_open(), "sliding the finger away cancels the long press")

	# Enemy pieces can be inspected too, and their live state is listed.
	var enemy_square: Vector2i = Vector2i(1, 7)
	var enemy: ChessPiece = game_state.board.get_piece(enemy_square)
	enemy.shield_until_serial = game_state.board.turn_serial + 3
	enemy.frozen_until_serial = game_state.board.turn_serial + 2
	_expect(info.show_piece(game_state.board, enemy_square, game_state.player_color), "an enemy piece opens a card")
	text = _all_text(info)
	_expect(_loc.text("PIECE_INFO_ENEMY") in text, "the card says whose piece it is")
	_expect(_loc.text("PIECE_INFO_SHIELDED") % 2 in text and _loc.text("PIECE_INFO_FROZEN") % 1 in text, "the card lists shield and freeze with turns left")
	_expect(not info.show_piece(game_state.board, Vector2i(4, 4), game_state.player_color), "an empty square opens nothing")

	battle.queue_free()
	print("[PASS] Piece info test" if not failed else "[FAIL] Piece info test")
	quit(1 if failed else 0)

func _press(view: Node, point: Vector2, down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = point
	view._gui_input(event)

func _all_text(node: Node) -> String:
	var parts: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false):
		parts.append((label as Label).text)
	return "\n".join(parts)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

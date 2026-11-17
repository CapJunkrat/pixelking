extends SceneTree

var failed: bool = false
var observed_order: Array[String] = []
var observed_board_was_mutated: bool = false
var game_state: Node
var event_bus: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game_state = root.get_node("GameState")
	event_bus = root.get_node("EventBus")
	game_state.call("start_new_game")
	event_bus.move_made.connect(_on_move_made)
	event_bus.turn_changed.connect(_on_turn_changed)
	event_bus.check_declared.connect(_on_check_declared)
	event_bus.checkmate.connect(_on_checkmate)
	event_bus.stalemate.connect(_on_stalemate)

	var success: bool = bool(game_state.call("try_move", Vector2i(1, 0), Vector2i(0, 2)))
	_expect(success, "characterized legal move succeeds")
	_expect(observed_board_was_mutated, "board mutation and turn switch happen before move event")
	_expect(observed_order.size() >= 2, "legal move emits move and turn events")
	if observed_order.size() >= 2:
		_expect(observed_order[0] == "move" and observed_order[1] == "turn", "legacy event order is move then turn")

	var event_count: int = observed_order.size()
	var illegal: bool = bool(game_state.call("try_move", Vector2i(0, 0), Vector2i(0, 4)))
	_expect(not illegal, "characterized illegal move is rejected")
	_expect(observed_order.size() == event_count, "illegal move emits no legacy events")
	_disconnect_signals()
	print("[PASS] Battle execution characterization test" if not failed else "[FAIL] Battle execution characterization test")
	quit(1 if failed else 0)

func _on_move_made(_from: Vector2i, to: Vector2i, _result: Dictionary) -> void:
	observed_order.append("move")
	var board: BoardState = game_state.get("board") as BoardState
	observed_board_was_mutated = board != null and board.get_piece(to) != null and board.turn == GameRules.PieceColor.BLACK

func _on_turn_changed(_new_turn: int) -> void:
	observed_order.append("turn")

func _on_check_declared(_color: int) -> void:
	observed_order.append("check")

func _on_checkmate(_color: int) -> void:
	observed_order.append("checkmate")

func _on_stalemate(_color: int) -> void:
	observed_order.append("stalemate")

func _disconnect_signals() -> void:
	if event_bus.move_made.is_connected(_on_move_made):
		event_bus.move_made.disconnect(_on_move_made)
	if event_bus.turn_changed.is_connected(_on_turn_changed):
		event_bus.turn_changed.disconnect(_on_turn_changed)
	if event_bus.check_declared.is_connected(_on_check_declared):
		event_bus.check_declared.disconnect(_on_check_declared)
	if event_bus.checkmate.is_connected(_on_checkmate):
		event_bus.checkmate.disconnect(_on_checkmate)
	if event_bus.stalemate.is_connected(_on_stalemate):
		event_bus.stalemate.disconnect(_on_stalemate)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var reference_board: BoardState = BoardState.new()
	reference_board.remove_all_pawns()
	var first: BattleCommandResult = _execute_reference_move(reference_board.clone())
	var second: BattleCommandResult = _execute_reference_move(reference_board.clone())
	_expect(first.success and second.success, "identical reference commands execute")
	var first_serialized: Array[Dictionary] = _serialize(first.events)
	var second_serialized: Array[Dictionary] = _serialize(second.events)
	_expect(first_serialized == second_serialized, "same board and input produce identical BattleEvent sequences")
	_expect(first.events.size() >= 3, "move command produces a structured event sequence")
	if first.events.size() >= 3:
		_expect(first.events[0].event_type == &"action_started", "event sequence starts with action intent")
		_expect(first.events[1].event_type == &"piece_moved", "piece movement is an explicit domain event")
		_expect(first.events[2].event_type == &"turn_changed", "turn change follows movement")
		_expect(first.events[0].sequence < first.events[1].sequence, "BattleEvent sequence numbers are monotonic")

	var event: BattleEvent = first.events[1]
	var external_payload: Dictionary = event.payload
	external_payload["to"] = Vector2i(4, 4)
	_expect(event.payload.get("to") == Vector2i(0, 2), "BattleEvent payload cannot be mutated by consumers")

	var game_state: Node = root.get_node("GameState")
	game_state.call("start_new_game")
	var emitted: Array[BattleEvent] = []
	var receiver: Callable = func(events: Array[BattleEvent]) -> void: emitted.assign(events)
	game_state.battle_events_emitted.connect(receiver)
	game_state.call("try_move", Vector2i(1, 0), Vector2i(0, 2))
	_expect(not emitted.is_empty(), "GameState publishes the battle-local event stream")
	game_state.battle_events_emitted.disconnect(receiver)
	print("[PASS] Battle event stream test" if not failed else "[FAIL] Battle event stream test")
	quit(1 if failed else 0)

func _execute_reference_move(board: BoardState) -> BattleCommandResult:
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	return processor.execute(MoveAction.new(Vector2i(1, 0), Vector2i(0, 2), GameRules.PieceColor.WHITE))

func _serialize(events: Array[BattleEvent]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for event: BattleEvent in events:
		serialized.append(event.to_dictionary())
	return serialized

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

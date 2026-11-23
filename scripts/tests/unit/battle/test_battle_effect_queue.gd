extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_stable_order()
	_test_chain_and_loop_guard()
	_test_processor_settles_before_terminal_check()
	print("[PASS] Battle effect queue test" if not failed else "[FAIL] Battle effect queue test")
	quit(1 if failed else 0)

func _test_stable_order() -> void:
	var queue: BattleEffectQueue = BattleEffectQueue.new()
	queue.enqueue(BattleEffect.new(&"white_late", &"noop", GameRules.PieceColor.WHITE, 5, Vector2i(4, 4), 9))
	queue.enqueue(BattleEffect.new(&"black_current", &"noop", GameRules.PieceColor.BLACK, 99, Vector2i(4, 4), 9))
	queue.enqueue(BattleEffect.new(&"white_position_b", &"noop", GameRules.PieceColor.WHITE, 1, Vector2i(2, 1), 2))
	queue.enqueue(BattleEffect.new(&"white_position_a_high_id", &"noop", GameRules.PieceColor.WHITE, 1, Vector2i(1, 1), 8))
	queue.enqueue(BattleEffect.new(&"white_position_a_low_id", &"noop", GameRules.PieceColor.WHITE, 1, Vector2i(1, 1), 3))
	var settlement: Dictionary = queue.settle(GameRules.PieceColor.BLACK)
	var ids: Array[StringName] = []
	for effect_value: Variant in settlement.get("applied", []):
		var effect: BattleEffect = effect_value as BattleEffect
		ids.append(effect.effect_id)
	_expect(ids == [&"black_current", &"white_position_a_low_id", &"white_position_a_high_id", &"white_position_b", &"white_late"], "effect queue sorts current side then priority, board position, and instance ID")

func _test_chain_and_loop_guard() -> void:
	var chain_queue: BattleEffectQueue = BattleEffectQueue.new()
	chain_queue.enqueue(BattleEffect.new(&"root", &"noop", GameRules.PieceColor.WHITE))
	var chain_handler: Callable = func(effect: BattleEffect) -> Array[BattleEffect]:
		var generated: Array[BattleEffect] = []
		if effect.effect_id == &"root":
			generated.append(BattleEffect.new(&"child", &"noop", GameRules.PieceColor.WHITE))
		return generated
	var chain_result: Dictionary = chain_queue.settle(GameRules.PieceColor.WHITE, chain_handler)
	_expect(bool(chain_result.get("success", false)) and (chain_result.get("applied", []) as Array).size() == 2, "effect queue settles generated death-chain style effects")

	var loop_queue: BattleEffectQueue = BattleEffectQueue.new()
	loop_queue.enqueue(BattleEffect.new(&"loop", &"noop", GameRules.PieceColor.WHITE, 0, Vector2i.ZERO, 7))
	var loop_handler: Callable = func(_effect: BattleEffect) -> Array[BattleEffect]:
		var generated: Array[BattleEffect] = []
		generated.append(BattleEffect.new(&"loop", &"noop", GameRules.PieceColor.WHITE, 0, Vector2i.ZERO, 7))
		return generated
	var loop_result: Dictionary = loop_queue.settle(GameRules.PieceColor.WHITE, loop_handler)
	_expect(not bool(loop_result.get("success", true)) and str(loop_result.get("error", "")) == "source_repeat_exceeded", "effect queue aborts infinite same-source chains")

func _test_processor_settles_before_terminal_check() -> void:
	var board: BoardState = BoardState.new(5, false)
	board.clear_for_setup()
	board.place_piece_for_setup(Vector2i(0, 0), ChessPiece.new(Content.piece("king"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(4, 4), ChessPiece.new(Content.piece("king"), GameRules.PieceColor.BLACK))
	board.place_piece_for_setup(Vector2i(1, 0), ChessPiece.new(Content.piece("rook"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(3, 4), ChessPiece.new(Content.piece("rook"), GameRules.PieceColor.BLACK))
	board.finalize_setup(GameRules.PieceColor.WHITE)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	processor.queue_effect(BattleEffect.new(&"remove_moved_rook", &"remove_piece", GameRules.PieceColor.WHITE, 0, Vector2i(1, 1), 1, {"position": Vector2i(1, 1)}))
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(1, 0), Vector2i(1, 1), GameRules.PieceColor.WHITE))
	var effect_index: int = _event_index(result.events, BattleCommandProcessor.EVENT_EFFECT_APPLIED)
	var terminal_index: int = _event_index(result.events, BattleCommandProcessor.EVENT_BATTLE_ENDED)
	_expect(result.success and board.get_piece(Vector2i(1, 1)) == null, "processor applies queued effects after movement")
	_expect(effect_index >= 0 and terminal_index > effect_index, "terminal evaluation happens after the complete effect settlement")

func _event_index(events: Array[BattleEvent], event_type: StringName) -> int:
	for index: int in range(events.size()):
		if events[index].event_type == event_type:
			return index
	return -1

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var board: BoardState = BoardState.new()
	board.remove_all_pawns()
	var first_item: ChallengerItemDef = _consumable(&"first_item")
	var second_item: ChallengerItemDef = _consumable(&"second_item")
	var items: Array[ChallengerItemDef] = [first_item, second_item]
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board, items, GameRules.PieceColor.WHITE)
	_expect(processor.can_use_item(0, GameRules.PieceColor.WHITE), "consumable is available in the pre-move player item window")
	var item_result: BattleCommandResult = processor.execute(UseItemAction.new(0, GameRules.PieceColor.WHITE))
	_expect(item_result.success and items.size() == 1, "using a consumable removes it from the shared six-slot inventory")
	_expect(board.turn == GameRules.PieceColor.WHITE and board.move_history.is_empty(), "item use does not consume the normal chess move")
	_expect(_has_event(item_result.events, BattleCommandProcessor.EVENT_ITEM_USED), "item use emits a domain event")
	_expect(_has_event(item_result.events, BattleCommandProcessor.EVENT_EFFECT_APPLIED), "item effect uses the unified effect queue")
	var repeated: BattleCommandResult = processor.execute(UseItemAction.new(0, GameRules.PieceColor.WHITE))
	_expect(not repeated.success and repeated.error == &"item_unavailable", "only one consumable can be used per player turn")

	var player_move: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(1, 0), Vector2i(0, 2), GameRules.PieceColor.WHITE))
	_expect(player_move.success, "player can still move after using an item")
	var selector: EnemyMoveSelector = EnemyMoveSelector.new()
	var enemy_move: Dictionary = selector.choose_move(board, GameRules.PieceColor.BLACK)
	var enemy_result: BattleCommandResult = processor.execute(MoveAction.new(enemy_move["from"], enemy_move["to"], GameRules.PieceColor.BLACK))
	_expect(enemy_result.success and board.turn == GameRules.PieceColor.WHITE, "enemy response starts the next player turn")
	_expect(processor.can_use_item(0, GameRules.PieceColor.WHITE), "item allowance resets on the next player turn")

	var game_state: Node = root.get_node("GameState")
	game_state.call("start_new_game")
	var runtime_items: Array[ChallengerItemDef] = game_state.get("challenger_items")
	runtime_items.append(_consumable(&"runtime_item"))
	_expect(bool(game_state.call("can_use_challenger_item", 0)), "GameState exposes the current item window eligibility")
	_expect(bool(game_state.call("try_use_item", 0)) and runtime_items.is_empty(), "GameState routes item intents through the command processor")

	var tray_scene: PackedScene = load("res://scenes/battle/ChallengerTray.tscn") as PackedScene
	var tray: ChallengerTray = tray_scene.instantiate() as ChallengerTray
	root.add_child(tray)
	await process_frame
	var requested_slot: Array[int] = [-1]
	tray.item_requested.connect(func(index: int) -> void: requested_slot[0] = index)
	tray.refresh(items, [true])
	tray.challenger_slots[0].pressed.emit()
	_expect(requested_slot[0] == 0, "challenger tray emits item intent instead of applying effects")
	tray.queue_free()
	print("[PASS] Battle item window test" if not failed else "[FAIL] Battle item window test")
	quit(1 if failed else 0)

func _consumable(item_id: StringName) -> ChallengerItemDef:
	var item: ChallengerItemDef = ChallengerItemDef.new()
	item.id = item_id
	item.display_name_key = item_id
	item.usage_mode = ChallengerItemDef.UsageMode.CONSUMABLE
	item.effect_type = &"noop"
	return item

func _has_event(events: Array[BattleEvent], event_type: StringName) -> bool:
	for event: BattleEvent in events:
		if event.event_type == event_type:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

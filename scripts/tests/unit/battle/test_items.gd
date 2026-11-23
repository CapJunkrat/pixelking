extends SceneTree

## Relics change every battle; consumables are used once before a move.

const W := GameRules.PieceColor.WHITE
const B := GameRules.PieceColor.BLACK

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for id: StringName in Content.relic_ids():
		_expect(Content.challenger_item(id).effect_type != &"noop", "%s does something" % id)

	# Holy Water: the chosen piece cannot be captured on the enemy's next turn.
	var board: BoardState = _board()
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board, [_item(&"holy_water")] as Array[ChallengerItemDef])
	_expect(not processor.execute(UseItemAction.new(0, W, Vector2i(5, 5))).success, "Holy Water cannot target an enemy")
	_expect(processor.execute(UseItemAction.new(0, W, Vector2i(3, 3))).success, "Holy Water blesses one of your pieces")
	processor.execute(MoveAction.new(Vector2i(0, 0), Vector2i(0, 1), W))
	_expect(Vector2i(3, 3) not in board.get_executable_moves(Vector2i(3, 5)), "the blessed piece cannot be captured next turn")

	# Freeze Charm: the chosen enemy cannot move on its next turn.
	board = _board()
	processor = BattleCommandProcessor.new(board, [_item(&"freeze_charm")] as Array[ChallengerItemDef])
	_expect(processor.execute(UseItemAction.new(0, W, Vector2i(3, 5))).success, "Freeze Charm targets an enemy piece")
	processor.execute(MoveAction.new(Vector2i(0, 0), Vector2i(0, 1), W))
	_expect(board.get_executable_moves(Vector2i(3, 5)).is_empty(), "the frozen enemy cannot move on its turn")

	# Second Wind: the next move is followed by a bonus action.
	board = _board()
	processor = BattleCommandProcessor.new(board, [_item(&"second_wind")] as Array[ChallengerItemDef])
	_expect(processor.execute(UseItemAction.new(0, W)).success, "Second Wind needs no target")
	_expect(processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(5, 4), W)).success, "the knight moves")
	_expect(board.turn == W and board.bonus_instance_id != 0, "Second Wind grants a bonus action")

	# Glass Feather and Iron Crown take effect when a battle starts.
	board = _board()
	processor = BattleCommandProcessor.new(board, [_item(&"glass_feather"), _item(&"iron_crown")] as Array[ChallengerItemDef])
	processor.apply_battle_start_relics()
	_expect(board.get_piece(Vector2i(0, 0)).is_shielded(board.turn_serial), "Iron Crown shields the back rank")
	_expect(processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(5, 4), W)).success, "the knight moves")
	_expect(board.turn == W, "Glass Feather turns the first move into two actions")

	# War Banner and Lucky Coin change the Run.
	var run: RunState = RunState.new()
	run.initialize_new(3)
	_expect(run.max_active_pieces() == 5, "the battle line holds five pieces")
	run.challenger_slots.append(&"war_banner")
	_expect(run.max_active_pieces() == 6, "the War Banner adds a sixth")
	print("[PASS] Item test" if not failed else "[FAIL] Item test")
	quit(1 if failed else 0)

func _board() -> BoardState:
	var board: BoardState = BoardState.new(8, false)
	board.clear_for_setup()
	board.place_piece_for_setup(Vector2i(0, 0), ChessPiece.new(Content.piece("king"), W))
	board.place_piece_for_setup(Vector2i(7, 7), ChessPiece.new(Content.piece("king"), B))
	board.place_piece_for_setup(Vector2i(3, 3), ChessPiece.new(Content.piece("knight"), W))
	board.place_piece_for_setup(Vector2i(3, 5), ChessPiece.new(Content.piece("rook"), B))
	board.finalize_setup(W)
	return board

func _item(id: StringName) -> ChallengerItemDef:
	return Content.challenger_item(id)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

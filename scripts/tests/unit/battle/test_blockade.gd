extends SceneTree

## Blockade rules: a side locked down for good (a Gorgon's stare) loses, a timed freeze,
## a coming hatch or an item that would free a piece only costs or keeps the turn, and
## a bonus action is never swallowed by a stalemate judged too early.

const W := GameRules.PieceColor.WHITE
const B := GameRules.PieceColor.BLACK
## The 0.3.0 phone record: Act 5, Glass Feather, Gorgon a3-e7 turns the whole enemy
## army (Phoenix e8, Courier f7, shielded King f8) to stone. It used to end in a draw.
const PHONE_CODE := "PK1:eJylks1q7DAMRvd+CsFd35K/adKAIdxtN911GTS2kphJpMH2NO3bVzO0dNNF6d0YdIzlT8d+eizNiy3u6rsCEpG3ZftQNVVdFA2gy/YALJ4sS9xwHY+Y80pA7D5JysgeozdH0dV24GSVaJ8hXyInW5go7pSsCZm2ZHeM2oOZIswrpjROhHnRar2409voJDCEKDy6KDtrICfsxz2wN8+A0S0bzjQcqz50vSu/iFNy6F0HaUEv+3gKPA9eYdm7A0TkmeJAWrfXY7PEWXjAug9V7+oKaDuSBgvRD17hfe8qSFmYxjkg54EUPvSuMf8g7WHKGvQSg7acWm1RlzCtuNF4XoQ4vA7UXWkFtxTTrSjMJi+UrlPUf6mFP11bN2bDeLIlLJgWewOJ8Wyu5qzeRDHgqtv6DEFuLn/rYGm+0/CzqZMqaj6VUfuh7D9MaJqPT/EO+8jTQg=="

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_phone_record_keeps_the_bonus_action()
	_test_ending_the_turn_on_a_full_lock_wins()
	_test_second_step_that_frees_the_enemy_plays_on()
	_test_enemy_blockade_beats_the_player()
	_test_timed_freeze_skips_a_turn()
	_test_coming_hatch_skips_a_turn()
	_test_item_that_frees_a_piece_keeps_the_turn()
	_test_nobody_can_act_is_a_draw()
	_test_both_sides_skipping_is_a_draw()
	_test_moves_that_only_endanger_the_king_stay_a_stalemate()
	_test_ai_takes_the_blockade()
	_finish()

# --- the phone record ----------------------------------------------------------

func _phone_processor() -> BattleCommandProcessor:
	var record: BattleRecord = BattleRecord.decode(PHONE_CODE)
	var built: Dictionary = record.build()
	return built.get("processor") as BattleCommandProcessor

func _test_phone_record_keeps_the_bonus_action() -> void:
	var processor: BattleCommandProcessor = _phone_processor()
	var result: BattleCommandResult = processor.execute(MoveAction.new(_sq("a3"), _sq("e7"), W))
	_expect(result.success, "phone record: a3-e7 is accepted")
	_expect(not processor.status.is_finished(), "phone record: no draw after the first action")
	_expect(_has_event(result.events, BattleCommandProcessor.EVENT_EXTRA_MOVE_GRANTED), "phone record: the bonus action is granted")
	_expect(processor.board.turn == W and processor.board.bonus_instance_id == processor.board.get_piece(_sq("e7")).instance_id, "phone record: the same Gorgon holds the second action")

func _test_ending_the_turn_on_a_full_lock_wins() -> void:
	var processor: BattleCommandProcessor = _phone_processor()
	processor.execute(MoveAction.new(_sq("a3"), _sq("e7"), W))
	var result: BattleCommandResult = processor.execute(EndTurnAction.new(W))
	_expect(result.success, "phone record: ending the turn on e7 is accepted")
	_expect(processor.status.is_finished() and processor.status.winner == W and not processor.status.draw, "phone record: the locked-down enemy loses")
	_expect(processor.status.reason == &"blockade", "phone record: the win is a blockade")

func _test_second_step_that_frees_the_enemy_plays_on() -> void:
	var processor: BattleCommandProcessor = _phone_processor()
	processor.execute(MoveAction.new(_sq("a3"), _sq("e7"), W))
	var result: BattleCommandResult = processor.execute(MoveAction.new(_sq("e7"), _sq("d6"), W))
	_expect(result.success, "phone record: e7-d6 is a legal second action")
	_expect(not processor.status.is_finished(), "phone record: the battle goes on after e7-d6")
	_expect(processor.board.turn == B and processor.board.has_any_executable_move(B), "phone record: the enemy is free to move again")

# --- built positions -------------------------------------------------------------

## 5x5: shielded White King a1 and Rook b1, Black Gorgon c3 and King e5; Black to move.
func _gorgon_board() -> BoardState:
	var board: BoardState = _empty_board()
	_put(board, Vector2i(0, 0), "king", W).shield_until_serial = 100
	_put(board, Vector2i(1, 0), "rook", W)
	_put(board, Vector2i(2, 2), "gorgon", B)
	_put(board, Vector2i(4, 4), "king", B)
	board.finalize_setup(B)
	return board

func _test_enemy_blockade_beats_the_player() -> void:
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(_gorgon_board())
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(1, 1), B))
	_expect(result.success and processor.status.is_finished(), "a Gorgon that locks down the player's whole army ends the battle")
	_expect(processor.status.winner == B and processor.status.reason == &"blockade", "the blockaded player loses, the King's shield notwithstanding")

func _test_timed_freeze_skips_a_turn() -> void:
	var board: BoardState = _empty_board()
	var king: ChessPiece = _put(board, Vector2i(0, 0), "king", W)
	var rook: ChessPiece = _put(board, Vector2i(1, 0), "rook", W)
	_put(board, Vector2i(4, 4), "king", B)
	_put(board, Vector2i(4, 3), "rook", B)
	board.finalize_setup(B)
	king.frozen_until_serial = 3
	rook.frozen_until_serial = 3
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(4, 3), Vector2i(3, 3), B))
	_expect(not processor.status.is_finished(), "a timed freeze never ends the battle")
	_expect(_has_event(result.events, BattleCommandProcessor.EVENT_TURN_SKIPPED), "the frozen side's turn is skipped")
	_expect(board.turn == B, "the turn comes straight back to the side that can move")
	processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(3, 2), B))
	_expect(not processor.status.is_finished() and board.turn == W and board.has_any_executable_move(W), "once the freeze runs out the player moves again")

func _test_coming_hatch_skips_a_turn() -> void:
	var board: BoardState = _gorgon_board()
	var egg: ChessPiece = _put(board, Vector2i(4, 0), "ember_egg", W)
	egg.hatch_piece = ChessPiece.new(PieceDefDatabase.get_def("ember_bird"), W)
	egg.hatch_serial = 3
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(1, 1), B))
	_expect(not processor.status.is_finished(), "an egg that will hatch keeps the blockade from being final")
	_expect(_has_event(result.events, BattleCommandProcessor.EVENT_TURN_SKIPPED), "the player waits for the hatch")

func _test_item_that_frees_a_piece_keeps_the_turn() -> void:
	var items: Array[ChallengerItemDef] = [ChallengerItemDatabase.get_def(&"royal_bomb")]
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(_gorgon_board(), items, W)
	processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(1, 1), B))
	_expect(not processor.status.is_finished(), "a usable item that removes the Gorgon is a way out")
	_expect(processor.board.turn == W and processor.can_end_turn(W), "the player keeps the turn and may also end it")
	var used: BattleCommandResult = processor.execute(UseItemAction.new(0, W, Vector2i(1, 1)))
	_expect(used.success and processor.board.has_any_executable_move(W), "using the item frees the player's pieces")

func _test_nobody_can_act_is_a_draw() -> void:
	var board: BoardState = _empty_board()
	_put(board, Vector2i(0, 0), "king", W)
	_put(board, Vector2i(4, 0), "rook", W)
	_put(board, Vector2i(0, 4), "rook", B)
	_put(board, Vector2i(4, 4), "king", B)
	board.finalize_setup(W)
	board.set_rocks([
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(1, 4), Vector2i(3, 4), Vector2i(3, 3), Vector2i(4, 3),
	])
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	processor.evaluate_terminal_state()
	_expect(processor.status.is_finished() and processor.status.draw, "when neither side can ever act the battle is drawn")

func _test_both_sides_skipping_is_a_draw() -> void:
	var board: BoardState = _empty_board()
	for entry: Array in [[Vector2i(0, 0), "king", W], [Vector2i(1, 0), "rook", W], [Vector2i(4, 4), "king", B], [Vector2i(3, 4), "rook", B]]:
		_put(board, entry[0], entry[1], entry[2]).frozen_until_serial = 5
	board.finalize_setup(W)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var result: BattleCommandResult = processor.evaluate_terminal_state()
	_expect(result != null and _has_event(result.events, BattleCommandProcessor.EVENT_TURN_SKIPPED), "the first frozen side skips")
	_expect(processor.status.is_finished() and processor.status.draw, "a skip right after the other side's skip draws the battle")

func _test_moves_that_only_endanger_the_king_stay_a_stalemate() -> void:
	# Classic stalemate: the lone King's every step walks into the Rooks.
	var board: BoardState = _empty_board()
	_put(board, Vector2i(0, 0), "king", W)
	_put(board, Vector2i(1, 4), "rook", B)
	_put(board, Vector2i(4, 1), "rook", B)
	_put(board, Vector2i(4, 4), "king", B)
	_put(board, Vector2i(2, 4), "pawn", W).frozen_until_serial = 100
	board.finalize_setup(W)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	processor.evaluate_terminal_state()
	_expect(processor.status.is_finished() and processor.status.draw and processor.status.reason == &"stalemate", "a King with only unsafe steps is still stalemated")

func _test_ai_takes_the_blockade() -> void:
	var selector: EnemyMoveSelector = EnemyMoveSelector.new()
	for difficulty: String in [EnemyMoveSelector.DIFFICULTY_MEDIUM, EnemyMoveSelector.DIFFICULTY_HARD]:
		selector.difficulty = difficulty
		selector.hard_budget_ms = 400
		var move: Dictionary = selector.choose_move(_gorgon_board(), B)
		_expect(not move.is_empty() and move["to"] == Vector2i(1, 1), "%s AI plays the blockading move" % difficulty)

# --- helpers -----------------------------------------------------------------------

func _empty_board() -> BoardState:
	var board: BoardState = BoardState.new(5, false)
	board.clear_for_setup()
	return board

func _put(board: BoardState, square: Vector2i, def_id: String, color: int) -> ChessPiece:
	var piece: ChessPiece = ChessPiece.new(PieceDefDatabase.get_def(def_id), color)
	board.place_piece_for_setup(square, piece)
	return piece

func _sq(name: String) -> Vector2i:
	return BattleRecord.parse_square(name)

func _has_event(events: Array[BattleEvent], event_type: StringName) -> bool:
	for event: BattleEvent in events:
		if event.event_type == event_type:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)

func _finish() -> void:
	quit(1 if failed else 0)

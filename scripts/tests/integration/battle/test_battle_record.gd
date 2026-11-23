extends SceneTreeTestCase

## A run battle is written down as it is played; its battle code decodes back to the same
## line-up and moves, and replaying it reaches the very same board, step by step.

const TEST_PATH := "user://pixelking_battle_record_test.save"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: AppRunManager = root.get_node("RunManager") as AppRunManager
	manager.configure_save_path(TEST_PATH)
	manager.abandon_run()
	expect(RunTestFixture.create_drafted_run(manager) == OK, "fixture drafts a run")
	expect(RunTestFixture.prepare_confirmed_battle(manager, true) == OK, "fixture confirms a battle")
	manager.current_run.challenger_slots = [&"royal_bomb", &"war_banner"]
	var game_state: Node = root.get_node("GameState")
	expect(manager.start_current_battle() == OK, "run battle starts")
	var record: BattleRecord = game_state.get("battle_record") as BattleRecord
	expect(record != null, "a run battle is recorded from the start")
	if record == null:
		finish_test("Battle record test")
		return
	expect(record.pieces.size() > 2 and record.item_ids == ["royal_bomb", "war_banner"], "the record holds the line-up and the items")

	# Both sides play the AI's choice; the player throws the bomb on the second turn.
	var selector: EnemyMoveSelector = EnemyMoveSelector.new()
	var used_item: bool = false
	for turn: int in range(40):
		var board: BoardState = game_state.get("board") as BoardState
		if bool(game_state.call("is_battle_finished")):
			break
		if turn == 2 and board.turn == GameRules.PieceColor.WHITE and not used_item:
			var target: Vector2i = _enemy_square(board)
			used_item = bool(game_state.call("try_use_item", 0, target))
			game_state.call("evaluate_battle_terminal_state")
			continue
		var action: MoveAction = selector.choose_action(board, board.turn)
		if action == null:
			game_state.call("evaluate_battle_terminal_state")
			break
		if not bool(game_state.call("try_move", action.from, action.to, action.promotion_id)):
			break
		game_state.call("evaluate_battle_terminal_state")
	expect(used_item, "an item use is recorded too")
	expect(record.actions.size() >= 5, "every step was recorded (%d): %s" % [record.actions.size(), record.actions])

	var live_board: BoardState = game_state.get("board") as BoardState
	var code: String = str(game_state.call("battle_code", ["d5:hidden"] as Array[String]))
	expect(code.begins_with(BattleRecord.PREFIX), "the battle code has its prefix")
	expect(code.length() < 4000, "the battle code stays short enough to paste (%d chars)" % code.length())
	var decoded: BattleRecord = BattleRecord.decode(code)
	expect(decoded != null, "the battle code decodes")
	if decoded != null:
		expect(decoded.pieces.size() == record.pieces.size() and decoded.actions == record.actions, "decoded line-up and moves match")
		expect(str(decoded.context.get("view", "")) == "d5:hidden", "the screen check travels with the code")
		expect(str(decoded.context.get("hash", "")) == BattleRecord.board_hash(live_board), "the code carries the board fingerprint at copy time")
		var report: Dictionary = decoded.replay()
		expect(str(report["error"]).is_empty(), "the replay sets up the battle")
		expect(int(report["first_mismatch"]) == -1, "every replayed step matches the game (first mismatch %d)" % int(report["first_mismatch"]))
		var processor: BattleCommandProcessor = report.get("processor") as BattleCommandProcessor
		expect(processor != null and BattleRecord.snapshot_lines(processor.board) == BattleRecord.snapshot_lines(live_board), "the replay ends on the same board")
		expect(BattleRecord.board_ascii(live_board).contains("a"), "the board prints as text")
	# A changed move is caught at the step it happens.
	if decoded != null and decoded.actions.size() > 3:
		decoded.actions[1] = decoded.actions[1].split(" #")[0] + " #ffff"
		expect(int(decoded.replay()["first_mismatch"]) == 1, "a wrong fingerprint points at its step")
	_check_born_pieces(game_state)
	game_state.call("start_new_game")
	expect(game_state.get("battle_record") == null, "leaving the battle drops its record")
	manager.abandon_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	finish_test("Battle record test")

## Eggs and promotions take fresh instance ids from a global counter, which is never
## the same on the phone and in a replay; the replay must still match step by step.
func _check_born_pieces(game_state: Node) -> void:
	var text: String = "PK1\nv=t\nboard=8 color=W turns=0\nrocks=c4 f5\nitems=\nW king@e1:i1 queen@d1:i2 rook@a1:i3 knight@g1:i4 gargoyle@c2:i6 bowman@f2:i7\nB king@e8:i20 queen@d8:i21 rook@h8:i22 ember_bird@c7:i23 stone_giant@f7:i24 powder_keg@d7:i25 lancer@g7:i26\nmoves\n"
	expect(bool(game_state.call("start_recorded_battle", BattleRecord.decode(text))), "a battle starts from a written line-up")
	var selector: EnemyMoveSelector = EnemyMoveSelector.new()
	for _step: int in range(60):
		var board: BoardState = game_state.get("board") as BoardState
		if bool(game_state.call("is_battle_finished")):
			break
		var action: MoveAction = selector.choose_action(board, board.turn)
		if action == null or not bool(game_state.call("try_move", action.from, action.to, action.promotion_id)):
			break
		game_state.call("evaluate_battle_terminal_state")
	var code: String = str(game_state.call("battle_code", [] as Array[String]))
	expect(BattleRecord.decode_text(code).contains("ember_bird"), "the code holds the line-up")
	for _burn: int in range(500):
		ChessPiece.new(Content.piece("pawn"), GameRules.PieceColor.WHITE)
	var report: Dictionary = BattleRecord.decode(code).replay()
	expect(int(report["first_mismatch"]) == -1, "a battle with an egg laid replays exactly after other ids were used (first mismatch %d of %d)" % [int(report["first_mismatch"]), (report["steps"] as Array).size()])

func _enemy_square(board: BoardState) -> Vector2i:
	for y: int in range(board.board_size):
		for x: int in range(board.board_size):
			var piece: ChessPiece = board.get_piece(Vector2i(x, y))
			if piece != null and piece.color == GameRules.PieceColor.BLACK and not piece.def.is_king:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

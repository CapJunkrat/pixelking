class_name TestNewPieceRules
extends SceneTreeTestCase

## Rules of the pieces added in docs §27: movement, on-capture abilities, growth,
## bonus actions and the King fusions.

const W := GameRules.PieceColor.WHITE
const B := GameRules.PieceColor.BLACK

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_vanguard()
	_test_sentry()
	_test_powder_keg()
	_test_martyr()
	_test_lantern_bearer()
	_test_squire_growth()
	_test_tide_knight()
	_test_antelope()
	_test_echo()
	_test_stand_in()
	_test_ranged_capture()
	_test_monk()
	_test_shells()
	_test_chameleon()
	_test_crystal_mage()
	_test_revival()
	_test_revive_limits()
	_test_squire_levels()
	_test_courier()
	_test_blast_catapult()
	_test_kings()
	_test_run_growth()
	_test_king_execution()
	_test_opening_king_shield()
	finish_test("New piece rules test")

func _test_vanguard() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"vanguard", W], Vector2i(4, 4): [&"pawn", B], Vector2i(3, 4): [&"pawn", B]})
	var moves: Array[Vector2i] = _moves(board, Vector2i(3, 3))
	expect(Vector2i(4, 4) in moves and Vector2i(2, 3) in moves, "Vanguard captures diagonally forward and steps sideways")
	expect(Vector2i(3, 4) not in moves and Vector2i(3, 2) not in moves, "Vanguard cannot capture ahead or step back")
	var black: BoardState = _board({Vector2i(3, 5): [&"vanguard", B]})
	expect(Vector2i(3, 3) in _moves(black, Vector2i(3, 5)), "Black Vanguard advances down the board")
	var promote: BoardState = _board({Vector2i(3, 6): [&"vanguard", W]})
	promote.make_move(Vector2i(3, 6), Vector2i(3, 7))
	expect(promote.get_piece(Vector2i(3, 7)).def.id == "lancer", "Vanguard becomes a Lancer on the far rank")

func _test_sentry() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"sentry", W], Vector2i(3, 5): [&"pawn", B], Vector2i(4, 4): [&"pawn", B]})
	var moves: Array[Vector2i] = _moves(board, Vector2i(3, 3))
	expect(moves.size() == 2 and Vector2i(3, 5) in moves and Vector2i(4, 4) in moves, "Sentry only moves by capturing")

func _test_powder_keg() -> void:
	var board: BoardState = _board({Vector2i(3, 4): [&"rook", B], Vector2i(3, 3): [&"powder_keg", W], Vector2i(4, 3): [&"knight", W], Vector2i(2, 2): [&"bishop", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]}, B)
	var result: Dictionary = board.make_move(Vector2i(3, 4), Vector2i(3, 3))
	expect(board.get_piece(Vector2i(3, 3)) == null, "the Rook that captured the Powder Keg is blown up")
	expect(board.get_piece(Vector2i(4, 3)) == null and board.get_piece(Vector2i(2, 2)) == null, "the explosion hits both sides")
	expect((result["removed"] as Array).size() == 4, "keg, capturer and two neighbours are removed")

func _test_martyr() -> void:
	var board: BoardState = _board({Vector2i(3, 4): [&"rook", B], Vector2i(3, 3): [&"martyr", W], Vector2i(4, 3): [&"knight", W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]}, B)
	board.make_move(Vector2i(3, 4), Vector2i(3, 3))
	board.make_move(Vector2i(0, 0), Vector2i(0, 1))
	expect(Vector2i(4, 3) not in _moves(board, Vector2i(3, 3)), "a shielded ally cannot be captured on the next enemy turn")
	board.make_move(Vector2i(3, 3), Vector2i(3, 2))
	board.make_move(Vector2i(0, 1), Vector2i(0, 0))
	board.make_move(Vector2i(3, 2), Vector2i(3, 3))
	board.make_move(Vector2i(0, 0), Vector2i(0, 1))
	expect(Vector2i(4, 3) in _moves(board, Vector2i(3, 3)), "the shield fades after that turn")

func _test_lantern_bearer() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"rook", W], Vector2i(3, 4): [&"gorgon", B], Vector2i(2, 2): [&"lantern_bearer", W]})
	expect(not board.is_piece_immobilized(Vector2i(3, 3)), "a Lantern Bearer neighbour prevents freezing")

func _test_squire_growth() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"squire", W], Vector2i(4, 4): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	var squire: ChessPiece = board.get_piece(Vector2i(3, 3))
	var result: Dictionary = board.make_move(Vector2i(3, 3), Vector2i(4, 4))
	expect(squire.def.id == "squire_lv2" and str(result["evolved_into"]) == "squire_lv2", "the first capture makes the Squire level 2")
	expect(board.growth.has(str(squire.instance_id)) and int(board.growth[str(squire.instance_id)]["capture_count"]) == 1, "the battle records the Squire's growth")
	squire.capture_count = 5
	board.set_piece(Vector2i(6, 5), _piece(&"pawn", B))
	board.turn = W
	board.make_move(Vector2i(4, 4), Vector2i(6, 5))
	expect(squire.def.id == "squire_lv4", "reaching 6 captures goes straight to level 4")
	expect(root.get_node("PieceSkinManager").call("piece_texture", &"white", &"squire_lv4") != null, "every Squire level uses the Squire picture")

func _test_tide_knight() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"tide_knight", W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	board.make_move(Vector2i(3, 3), Vector2i(4, 5))
	var knight: ChessPiece = board.get_piece(Vector2i(4, 5))
	expect(knight.def.id == "tide_knight_ebb", "moving turns high tide into low tide")
	expect(Vector2i(5, 7) not in _moves(board, Vector2i(4, 5), W) and Vector2i(6, 3) in _moves(board, Vector2i(4, 5), W), "low tide moves up to 2 diagonally instead of leaping")
	expect(knight.def.run_form_id() == "tide_knight", "the Run keeps the high-tide form")

func _test_antelope() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"antelope", W], Vector2i(4, 4): [&"pawn", W]})
	var moves: Array[Vector2i] = _moves(board, Vector2i(3, 3))
	expect(Vector2i(6, 4) in moves and Vector2i(5, 5) in moves and Vector2i(4, 5) not in moves, "Antelope leaps 3+1 and 2+2 over pieces")
	for square: Vector2i in moves:
		expect((square.x + square.y) % 2 == 0, "Antelope lands on its own colour (%s)" % square)

func _test_echo() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"echo", W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B], Vector2i(6, 0): [&"knight", W]})
	expect(_moves(board, Vector2i(3, 3)).size() == 8, "Echo steps like a King before its side has moved")
	board.make_move(Vector2i(6, 0), Vector2i(5, 2))
	board.make_move(Vector2i(7, 7), Vector2i(7, 6))
	var moves: Array[Vector2i] = _moves(board, Vector2i(3, 3))
	expect(Vector2i(4, 5) in moves and Vector2i(4, 4) not in moves, "Echo copies the Knight that moved last")

func _test_stand_in() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"stand_in", W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	expect(Vector2i(0, 0) in _moves(board, Vector2i(3, 3)), "Stand-in may swap with its King")
	var result: Dictionary = board.make_move(Vector2i(3, 3), Vector2i(0, 0))
	expect(bool(result["swapped_with_king"]) and board.king_pos[W] == Vector2i(3, 3) and board.get_piece(Vector2i(0, 0)).def.id == "stand_in", "the swap trades places")
	board.make_move(Vector2i(7, 7), Vector2i(7, 6))
	expect(Vector2i(3, 3) not in _moves(board, Vector2i(0, 0)), "the swap works once per battle")

func _test_ranged_capture() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"falconer", W], Vector2i(3, 4): [&"pawn", W], Vector2i(3, 5): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	var result: Dictionary = board.make_move(Vector2i(3, 3), Vector2i(3, 5))
	expect(bool(result["captured"]) and bool(result["ranged"]), "Falconer captures over a piece from a distance")
	expect(board.get_piece(Vector2i(3, 3)).def.id == "falconer" and board.get_piece(Vector2i(3, 5)) == null, "Falconer stays on its square")
	var ranger: BoardState = _board({Vector2i(0, 3): [&"ranger", W]})
	expect(Vector2i(0, 7) not in _moves(ranger, Vector2i(0, 3)) and Vector2i(1, 4) in _moves(ranger, Vector2i(0, 3)), "Ranger only steps one square")

func _test_monk() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"sun_moon_monk", W]})
	var moves: Array[Vector2i] = _moves(board, Vector2i(3, 3))
	expect(Vector2i(5, 5) in moves and Vector2i(6, 6) in moves and Vector2i(4, 3) not in moves and Vector2i(7, 7) not in moves, "Monk teleports to same-coloured squares within 3")

func _test_shells() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"rook", B], Vector2i(3, 1): [&"knight", W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]}, B)
	var shelled: ChessPiece = board.get_piece(Vector2i(3, 1))
	shelled.shell_left = 1
	var result: Dictionary = board.make_move(Vector2i(3, 3), Vector2i(3, 1))
	expect(not bool(result["captured"]) and board.get_piece(Vector2i(3, 1)) == shelled and board.get_piece(Vector2i(3, 3)).def.id == "rook", "a shell breaks and the attacker bounces back")
	board.make_move(Vector2i(0, 0), Vector2i(0, 1))
	result = board.make_move(Vector2i(3, 3), Vector2i(3, 1))
	expect(bool(result["captured"]), "the second capture destroys the shelled piece")
	var giant: BoardState = _board({Vector2i(3, 3): [&"stone_giant", W]})
	expect(giant.get_piece(Vector2i(3, 3)).shell_left == 2, "the Stone Giant needs three captures")

func _test_chameleon() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"chameleon", W], Vector2i(4, 4): [&"knight", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	board.make_move(Vector2i(3, 3), Vector2i(4, 4))
	var chameleon: ChessPiece = board.get_piece(Vector2i(4, 4))
	expect(chameleon.learned_def_ids == (["knight"] as Array[String]), "Chameleon learns the captured Knight")
	expect(Vector2i(5, 6) in _moves(board, Vector2i(4, 4), W), "Chameleon leaps like a Knight")
	chameleon.learned_def_ids = ["knight", "bishop"] as Array[String]
	board.set_piece(Vector2i(5, 5), _piece(&"rook", B))
	board.turn = W
	board.make_move(Vector2i(4, 4), Vector2i(5, 5))
	expect(chameleon.learned_def_ids == (["bishop", "rook"] as Array[String]), "a third learned move pushes out the oldest")

func _test_crystal_mage() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"crystal_mage", W], Vector2i(3, 5): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	var mage: ChessPiece = board.get_piece(Vector2i(3, 3))
	var walks: Array[Vector2i] = _moves(board, Vector2i(3, 3), W)
	expect(Vector2i(7, 7) not in walks and Vector2i(6, 6) in walks and Vector2i(0, 6) in walks, "the Crystal Mage walks diagonal rays like a Bishop")
	expect(Vector2i(3, 4) not in walks and Vector2i(5, 3) not in walks and Vector2i(1, 3) not in walks, "the Crystal Mage no longer walks along files and ranks")
	expect(Vector2i(3, 5) in walks, "the Crystal Mage still shoots 2-3 squares along any line")
	var close: BoardState = _board({Vector2i(3, 3): [&"crystal_mage", W], Vector2i(3, 4): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	close.make_move(Vector2i(3, 3), Vector2i(3, 4))
	expect(close.get_piece(Vector2i(3, 4)) != null and close.get_piece(Vector2i(3, 4)).def.id == "crystal_mage", "the Crystal Mage still captures an enemy next to it")
	mage.capture_count = 2
	expect(mage.def.is_ranged(), "the Crystal Mage is a ranged piece")
	board.make_move(Vector2i(3, 3), Vector2i(3, 5))
	expect(board.get_piece(Vector2i(3, 3)) == mage and board.get_piece(Vector2i(3, 5)) == null, "the Crystal Mage shoots from where it stands")
	expect(mage.def.id == "archmage", "the third capture in the Run turns the Crystal Mage into an Archmage")
	expect(Vector2i(3, 7) in _moves(board, Vector2i(3, 3), W) and Vector2i(6, 6) in _moves(board, Vector2i(3, 3), W) and Vector2i(4, 5) not in _moves(board, Vector2i(3, 3), W), "the Archmage moves like a Queen, without Knight leaps")

func _test_revival() -> void:
	var board: BoardState = _board({Vector2i(2, 0): [&"ember_bird", W], Vector2i(7, 1): [&"pawn", W], Vector2i(2, 4): [&"rook", B], Vector2i(4, 0): [&"king", W], Vector2i(7, 7): [&"king", B]}, B)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	processor.execute(MoveAction.new(Vector2i(2, 4), Vector2i(2, 0), B))
	expect(board.get_piece(Vector2i(2, 0)).def.id == "rook", "Ember Bird is captured")
	processor.execute(MoveAction.new(Vector2i(4, 0), Vector2i(4, 1), W))
	processor.execute(MoveAction.new(Vector2i(7, 7), Vector2i(7, 6), B))
	var bird_back: bool = false
	for x: int in range(8):
		var piece: ChessPiece = board.get_piece(Vector2i(x, 0))
		bird_back = bird_back or (piece != null and piece.def.id == "ember_bird")
	expect(not bird_back, "Ember Bird is still gone on its owner's second turn")
	processor.execute(MoveAction.new(Vector2i(4, 1), Vector2i(4, 0), W))
	var revived: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(7, 6), Vector2i(7, 7), B))
	expect(_has(revived.events, BattleCommandProcessor.EVENT_PIECE_REVIVED), "Ember Bird revives after missing two of its owner's turns")
	expect(board.get_piece(Vector2i(0, 0)) != null and board.get_piece(Vector2i(0, 0)).def.id == "ember_bird", "it hatches where its egg lay, in its owner's bottom-left corner")
	_test_eggs()
	expect(board.get_piece(Vector2i(0, 0)) != null and board.get_piece(Vector2i(0, 0)).def.id == "ember_bird", "its start square is taken, so it revives in the bottom-left corner")

func _test_revive_limits() -> void:
	var phoenix: ChessPiece = ChessPiece.new(PieceDefDatabase.get_def("flame_phoenix"), W)
	var bird: ChessPiece = ChessPiece.new(PieceDefDatabase.get_def("ember_bird"), W)
	expect(phoenix.def.revive_after_turns == 2 and bird.def.revive_after_turns == 2, "Phoenix and Ember Bird eggs both hatch after 2 turns")
	expect(phoenix.revives_left < 0 and bird.revives_left == 1, "the Phoenix lays an egg every time, the Ember Bird only once")
	var board: BoardState = _board({Vector2i(3, 3): [&"flame_phoenix", W], Vector2i(4, 0): [&"king", W], Vector2i(7, 7): [&"king", B], Vector2i(3, 6): [&"rook", B]}, B)
	var reborn: ChessPiece = board.get_piece(Vector2i(3, 3))
	for round_index: int in range(2):
		var result: Dictionary = board.make_move(Vector2i(3, 6), reborn_square(board, reborn))
		expect((result.get("eggs_laid", []) as Array).size() == 1, "the Phoenix leaves an egg on fall %d" % (round_index + 1))
		# Put the Phoenix back on the board in front of the rook for the next fall.
		board.set_piece(Vector2i(3, 6), null)
		for x: int in range(8):
			for y: int in range(8):
				var piece: ChessPiece = board.get_piece(Vector2i(x, y))
				if piece != null and piece.def.is_egg:
					board.set_piece(Vector2i(x, y), null)
		board.set_piece(Vector2i(3, 3), reborn)
		var rook: ChessPiece = ChessPiece.new(PieceDefDatabase.get_def("rook"), B)
		board.set_piece(Vector2i(3, 6), rook)
		board.turn = B
	expect(reborn.revives_left < 0, "the Phoenix never runs out of eggs")

func reborn_square(board: BoardState, piece: ChessPiece) -> Vector2i:
	for x: int in range(8):
		for y: int in range(8):
			if board.get_piece(Vector2i(x, y)) == piece:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _test_squire_levels() -> void:
	var board: BoardState = _board({Vector2i(3, 3): [&"squire_lv2", W], Vector2i(4, 5): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	var squire: ChessPiece = board.get_piece(Vector2i(3, 3))
	squire.capture_count = 1
	board.make_move(Vector2i(3, 3), Vector2i(4, 5))
	expect(squire.def.id == "squire_lv3", "a Squire grows a level with every capture")
	expect(PieceDefDatabase.get_def("squire").evolve_at_captures == 1 and PieceDefDatabase.get_def("squire_lv2").evolve_at_captures == 2 and PieceDefDatabase.get_def("squire_lv3").evolve_at_captures == 3, "Squire levels need 1, 2 and 3 captures in all")

func _test_courier() -> void:
	var board: BoardState = _board({Vector2i(2, 2): [&"swift_courier", W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B], Vector2i(6, 6): [&"pawn", B]})
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(4, 4), W))
	expect(board.turn == W and board.bonus_instance_id != 0, "Swift Courier acts twice every turn")
	expect(not processor.execute(MoveAction.new(Vector2i(0, 0), Vector2i(0, 1), W)).success, "the second action belongs to the Courier")
	var ended: BattleCommandResult = processor.execute(EndTurnAction.new(W))
	expect(ended.success and board.turn == B and board.bonus_instance_id == 0, "the player may end the turn instead")

func _test_blast_catapult() -> void:
	var board: BoardState = _board({Vector2i(3, 1): [&"blast_catapult", W], Vector2i(3, 5): [&"pawn", B], Vector2i(4, 5): [&"knight", B], Vector2i(2, 6): [&"rook", W], Vector2i(4, 6): [&"king", B], Vector2i(0, 0): [&"king", W]})
	var result: Dictionary = board.make_move(Vector2i(3, 1), Vector2i(3, 5))
	expect(bool(result["ranged"]) and board.get_piece(Vector2i(3, 1)).def.id == "blast_catapult", "Blast Catapult fires from its square")
	expect(board.get_piece(Vector2i(4, 5)) == null and board.get_piece(Vector2i(2, 6)) != null and board.has_king(B), "the blast destroys enemies around the target but spares allies and Kings")

func _test_kings() -> void:
	var war: BoardState = _board({Vector2i(3, 3): [&"war_king", W], Vector2i(7, 7): [&"king", B]})
	var moves: Array[Vector2i] = _moves(war, Vector2i(3, 3))
	expect(Vector2i(3, 5) in moves and Vector2i(5, 5) in moves, "War King moves 2 along all eight rays")
	var shadow: BoardState = _board({Vector2i(3, 3): [&"shadow_king", W], Vector2i(7, 7): [&"king", B], Vector2i(6, 0): [&"rook", B]})
	moves = _moves(shadow, Vector2i(3, 3))
	expect(Vector2i(5, 5) in moves and Vector2i(6, 3) not in moves and Vector2i(3, 0) not in moves, "Shadow King blinks to safe squares within 3")
	shadow.make_move(Vector2i(3, 3), Vector2i(5, 5))
	shadow.make_move(Vector2i(7, 7), Vector2i(7, 6))
	expect(Vector2i(2, 2) in _moves(shadow, Vector2i(5, 5)), "the safe Shadow step remains available on later turns")
	# Shield King: the checking Rook covers both horizontal escape squares;
	# the pawns block the extended vertical/diagonal rays, so this remains mate.
	# The checking Rook is destroyed instead.
	var board: BoardState = _board({Vector2i(0, 0): [&"shield_king", W], Vector2i(0, 1): [&"pawn", W], Vector2i(1, 1): [&"pawn", W], Vector2i(7, 7): [&"king", B], Vector2i(5, 6): [&"pawn", B], Vector2i(7, 4): [&"rook", B]}, B)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var mate: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(7, 4), Vector2i(7, 0), B))
	expect(_has(mate.events, BattleCommandProcessor.EVENT_LAST_STAND) and not processor.status.is_finished(), "the Shield King survives its first checkmate")
	expect(board.get_piece(Vector2i(7, 0)) == null, "the checking Rook is destroyed")
	expect(PieceDefDatabase.get_def("war_king").has_movement_rule(&"castling") == false, "fused Kings cannot castle")

func _test_run_growth() -> void:
	var state: PieceInstanceState = PieceInstanceState.new(7, &"squire", false)
	state.absorb_growth({"def_id": "squire_lv2", "capture_count": 2, "learned": []})
	var saved: Dictionary = state.to_dictionary()
	var loaded: PieceInstanceState = PieceInstanceState.new()
	expect(loaded.load_from_dictionary(saved) and loaded.piece_def_id == &"squire_lv2" and loaded.capture_count == 2, "Squire growth survives a save")
	var chameleon: PieceInstanceState = PieceInstanceState.new(8, &"chameleon", false)
	chameleon.absorb_growth({"def_id": "chameleon", "capture_count": 1, "learned": ["knight"]})
	var piece: ChessPiece = chameleon.to_chess_piece(W)
	expect(piece.learned_def_ids == (["knight"] as Array[String]) and piece.capture_count == 1, "learned moves come back in the next battle")

func _test_king_execution() -> void:
	# White takes Black's last piece: the lone Black King falls at once.
	var board: BoardState = _board({Vector2i(0, 0): [&"king", W], Vector2i(3, 3): [&"rook", W], Vector2i(3, 6): [&"knight", B], Vector2i(7, 7): [&"king", B]})
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(3, 6), W))
	expect(_has(result.events, BattleCommandProcessor.EVENT_KING_EXECUTION), "taking the last piece triggers the King's execution")
	expect(processor.status.is_finished() and board.king_pos[W] == Vector2i(0, 0) and board.get_piece(Vector2i(7, 7)) == null and not board.has_king(B), "the lone King falls in place, the winning King stays on its own square, and the battle is over")
	# And the other way round: losing your last piece loses the battle at once.
	var losing: BoardState = _board({Vector2i(0, 0): [&"king", W], Vector2i(3, 3): [&"knight", W], Vector2i(3, 6): [&"rook", B], Vector2i(7, 7): [&"king", B]}, B)
	var enemy: BattleCommandProcessor = BattleCommandProcessor.new(losing)
	enemy.execute(MoveAction.new(Vector2i(3, 6), Vector2i(3, 3), B))
	expect(enemy.status.is_finished() and not losing.has_king(W), "the enemy King strikes down a lone player King")

func _test_opening_king_shield() -> void:
	var board: BoardState = _board({Vector2i(4, 0): [&"king", W], Vector2i(4, 7): [&"king", B], Vector2i(4, 3): [&"rook", W], Vector2i(0, 7): [&"rook", B]})
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	processor.shield_kings_for_opening()
	expect(Vector2i(4, 7) not in board.get_executable_moves(Vector2i(4, 3)), "a King cannot be captured in the opening turns")
	board.turn_serial = BattleCommandProcessor.OPENING_KING_SHIELD_SERIAL
	expect(Vector2i(4, 7) in board.get_executable_moves(Vector2i(4, 3)), "the opening shield wears off after two turns each")

# --- helpers ------------------------------------------------------------------

func _board(pieces: Dictionary, turn: int = W) -> BoardState:
	var board: BoardState = BoardState.new(8, false)
	board.clear_for_setup()
	for square: Vector2i in pieces:
		var spec: Array = pieces[square]
		var piece: ChessPiece = _piece(spec[0], spec[1])
		if piece.def.is_king:
			board.place_piece_for_setup(square, piece)
		else:
			board.set_piece(square, piece)
			piece.origin = square
	board.turn = turn
	return board

func _moves(board: BoardState, square: Vector2i, color: int = -1) -> Array[Vector2i]:
	var piece: ChessPiece = board.get_piece(square)
	if piece == null:
		return []
	return board.get_executable_moves_for_color(square, piece.color if color < 0 else color)

func _piece(piece_id: StringName, color: int) -> ChessPiece:
	return ChessPiece.new(PieceDefDatabase.get_def(piece_id), color)

func _has(events: Array[BattleEvent], event_type: StringName) -> bool:
	for event: BattleEvent in events:
		if event.event_type == event_type:
			return true
	return false

func _test_eggs() -> void:
	# The egg goes to the free square nearest the owner's bottom-left corner.
	var crowded: BoardState = _board({Vector2i(3, 3): [&"ember_bird", W], Vector2i(0, 0): [&"rook", W], Vector2i(1, 0): [&"pawn", W], Vector2i(3, 6): [&"rook", B], Vector2i(4, 0): [&"king", W], Vector2i(7, 7): [&"king", B]}, B)
	var result: Dictionary = crowded.make_move(Vector2i(3, 6), Vector2i(3, 3))
	var egg: ChessPiece = crowded.get_piece(Vector2i(0, 1))
	expect(egg != null and egg.def.id == "ember_egg" and egg.color == W, "a captured Ember Bird lays an egg on the free square nearest a1")
	expect((result.get("eggs_laid", []) as Array).size() == 1, "the move result reports the egg")
	expect(crowded.egg_turns_left(egg) == 2, "the egg hatches in 2 of its owner's turns")
	expect(egg.def.is_egg and MoveGenerator.generate_pseudo_legal(crowded, Vector2i(0, 1)).is_empty(), "an egg cannot move")
	# A Black egg goes to Black's own bottom-left corner (h8).
	var black: BoardState = _board({Vector2i(3, 3): [&"ember_bird", B], Vector2i(3, 0): [&"rook", W], Vector2i(4, 0): [&"king", W], Vector2i(4, 7): [&"king", B]})
	black.make_move(Vector2i(3, 0), Vector2i(3, 3))
	expect(black.get_piece(Vector2i(7, 7)) != null and black.get_piece(Vector2i(7, 7)).def.id == "ember_egg", "a Black egg lies in h8")
	# Breaking an Ember Egg ends the bird for good.
	var fragile: BoardState = _board({Vector2i(3, 3): [&"ember_bird", W], Vector2i(3, 6): [&"rook", B], Vector2i(0, 6): [&"rook", B], Vector2i(4, 0): [&"king", W], Vector2i(7, 7): [&"king", B], Vector2i(5, 1): [&"pawn", W]}, B)
	fragile.make_move(Vector2i(3, 6), Vector2i(3, 3))
	fragile.make_move(Vector2i(5, 1), Vector2i(5, 2))
	fragile.make_move(Vector2i(0, 6), Vector2i(0, 0))
	expect(fragile.get_piece(Vector2i(0, 0)).def.id == "rook", "the Ember Egg breaks when attacked")
	var ember_left: bool = false
	for x: int in range(8):
		for y: int in range(8):
			var piece: ChessPiece = fragile.get_piece(Vector2i(x, y))
			ember_left = ember_left or (piece != null and (piece.def.id == "ember_bird" or piece.def.id == "ember_egg"))
	expect(not ember_left, "with its egg broken the Ember Bird is gone for good")
	# A Phoenix Egg is never broken; each blow adds 2 turns.
	var hard: BoardState = _board({Vector2i(3, 3): [&"flame_phoenix", W], Vector2i(3, 6): [&"rook", B], Vector2i(0, 6): [&"rook", B], Vector2i(4, 0): [&"king", W], Vector2i(7, 7): [&"king", B], Vector2i(5, 1): [&"pawn", W]}, B)
	hard.make_move(Vector2i(3, 6), Vector2i(3, 3))
	var phoenix_egg: ChessPiece = hard.get_piece(Vector2i(0, 0))
	expect(phoenix_egg != null and phoenix_egg.def.id == "phoenix_egg", "a captured Flame Phoenix lays a Phoenix Egg")
	var before: int = hard.egg_turns_left(phoenix_egg)
	hard.make_move(Vector2i(5, 1), Vector2i(5, 2))
	var blow: Dictionary = hard.make_move(Vector2i(0, 6), Vector2i(0, 0))
	expect(hard.get_piece(Vector2i(0, 0)) == phoenix_egg and hard.get_piece(Vector2i(0, 6)).def.id == "rook", "the Phoenix Egg survives and the attacker bounces back")
	expect(hard.egg_turns_left(phoenix_egg) == before + 2 - 1, "each blow adds 2 turns to the hatching")
	expect(not bool(blow["captured"]), "hitting a Phoenix Egg is not a capture")
	# Eggs do not keep a side in the battle.
	var lone: BoardState = _board({Vector2i(0, 0): [&"ember_egg", B], Vector2i(4, 7): [&"king", B], Vector2i(4, 0): [&"king", W], Vector2i(3, 1): [&"pawn", W]})
	expect(lone.has_only_king(B) and not lone.has_non_king_piece(B), "a King with only an egg left is alone")

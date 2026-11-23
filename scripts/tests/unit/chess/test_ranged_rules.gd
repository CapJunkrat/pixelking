class_name TestRangedRules
extends SceneTreeTestCase

## Shared ranged rules: shoot without moving, engaged by an adjacent enemy, the King's
## bodyguard, Gargoyle immunity, the Ranger's boomerang and heavy shots breaking rocks.

const W := GameRules.PieceColor.WHITE
const B := GameRules.PieceColor.BLACK

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_shoot_and_stay()
	_test_engaged()
	_test_bodyguard()
	_test_gargoyle()
	_test_boomerang()
	_test_rocks()
	_test_presentation_event()
	_test_ai_takes_the_shot()
	_test_new_ranges()
	finish_test("Ranged rules test")

func _test_shoot_and_stay() -> void:
	var board: BoardState = _board({Vector2i(3, 1): [&"bowman", W], Vector2i(3, 4): [&"knight", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	var moves: Array[Vector2i] = _moves(board, Vector2i(3, 1))
	expect(Vector2i(3, 4) in moves and Vector2i(3, 3) not in moves, "a ranged piece targets enemies but cannot walk down its line")
	expect(MoveGenerator.action_kind(board, Vector2i(3, 1), Vector2i(3, 4)) == RangedAttackRule.ACTION, "the shot is a ranged action")
	var far: BoardState = _board({Vector2i(3, 1): [&"bowman", W], Vector2i(3, 5): [&"knight", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	expect(Vector2i(3, 5) not in _moves(far, Vector2i(3, 1)), "the Bowman shoots at most 3 squares")
	var result: MoveOutcome = BattleTestFixture.play(board, Vector2i(3, 1), Vector2i(3, 4))
	expect(result.captured and result.ranged and result.landing == Vector2i(3, 1), "the bowman shoots and stays put")
	expect(board.get_piece(Vector2i(3, 1)).def.id == "bowman" and board.get_piece(Vector2i(3, 4)) == null, "the target is gone")
	var melee: BoardState = _board({Vector2i(3, 3): [&"bowman", W], Vector2i(4, 4): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	result = BattleTestFixture.play(melee, Vector2i(3, 3), Vector2i(4, 4))
	expect(result.captured and not result.ranged and melee.get_piece(Vector2i(4, 4)).def.id == "bowman", "an adjacent enemy is taken in melee, moving in")

func _test_engaged() -> void:
	var board: BoardState = _board({Vector2i(3, 1): [&"bowman", W], Vector2i(4, 2): [&"pawn", B], Vector2i(3, 4): [&"rook", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	var moves: Array[Vector2i] = _moves(board, Vector2i(3, 1))
	expect(Vector2i(3, 4) not in moves, "an enemy on a diagonal next to the shooter stops it from shooting")
	expect(Vector2i(4, 2) in moves, "the engaged shooter can still capture the adjacent enemy")
	expect(Vector2i(3, 4) not in MoveGenerator.get_attack_squares(board, Vector2i(3, 1)), "an engaged shooter threatens nothing at range")
	board.set_piece(Vector2i(4, 2), null)
	expect(Vector2i(3, 4) in _moves(board, Vector2i(3, 1)), "once free it can shoot again")

func _test_bodyguard() -> void:
	var board: BoardState = _board({Vector2i(4, 3): [&"bowman", W], Vector2i(4, 6): [&"king", B], Vector2i(0, 0): [&"king", W]})
	expect(Vector2i(4, 6) in _moves(board, Vector2i(4, 3)) and board.is_in_check(B), "a lone King can be shot (and is in check)")
	board.set_piece(Vector2i(5, 7), _piece(&"pawn", B))
	expect(board.is_king_guarded(Vector2i(4, 6)), "an ally next to the King guards it")
	expect(Vector2i(4, 6) not in _moves(board, Vector2i(4, 3)) and not board.is_in_check(B), "a guarded King cannot be shot and is not in check from range")
	board.set_piece(Vector2i(4, 5), _piece(&"rook", W))
	board.set_piece(Vector2i(4, 3), null)
	expect(board.is_in_check(B), "melee threats ignore the bodyguard")

func _test_gargoyle() -> void:
	var board: BoardState = _board({Vector2i(3, 1): [&"bowman", W], Vector2i(3, 5): [&"gargoyle", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	expect(Vector2i(3, 5) not in _moves(board, Vector2i(3, 1)), "the Gargoyle cannot be shot")
	var gargoyle: ChessPiece = board.get_piece(Vector2i(3, 5))
	expect(gargoyle.shell_left == 0 and gargoyle.def.rarity == PieceDef.Rarity.EPIC, "the Gargoyle has no shell and is Epic")
	board.turn = B
	var moves: Array[Vector2i] = _moves(board, Vector2i(3, 5))
	expect(Vector2i(3, 2) in moves and Vector2i(3, 1) in moves and Vector2i(7, 5) in moves and Vector2i(4, 4) not in moves, "the Gargoyle moves and captures like a Rook")
	var result: MoveOutcome = BattleTestFixture.play(board, Vector2i(3, 5), Vector2i(3, 1))
	expect(result.captured and board.get_piece(Vector2i(3, 1)).def.id == "gargoyle", "the Gargoyle captures in melee and moves in")
	var blast: BoardState = _board({Vector2i(3, 1): [&"blast_catapult", W], Vector2i(3, 5): [&"pawn", B], Vector2i(4, 5): [&"gargoyle", B], Vector2i(2, 5): [&"knight", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	BattleTestFixture.play(blast, Vector2i(3, 1), Vector2i(3, 5))
	expect(blast.get_piece(Vector2i(4, 5)) != null and blast.get_piece(Vector2i(2, 5)) == null, "the blast splash spares the Gargoyle")

func _test_boomerang() -> void:
	var board: BoardState = _board({Vector2i(1, 1): [&"ranger", W], Vector2i(1, 3): [&"pawn", B], Vector2i(1, 4): [&"pawn", W], Vector2i(1, 5): [&"knight", B], Vector2i(1, 6): [&"rook", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	var moves: Array[Vector2i] = _moves(board, Vector2i(1, 1))
	expect(Vector2i(1, 3) in moves and Vector2i(1, 5) in moves and Vector2i(1, 6) not in moves, "the boomerang reaches enemies 2-4 squares away, over pieces")
	var result: MoveOutcome = BattleTestFixture.play(board, Vector2i(1, 1), Vector2i(1, 3))
	expect(board.get_piece(Vector2i(1, 3)) == null and board.get_piece(Vector2i(1, 5)) == null, "the boomerang hits every enemy on the line")
	expect(board.get_piece(Vector2i(1, 4)) != null and board.get_piece(Vector2i(1, 6)) != null, "it passes allies and stops after 4 squares")
	expect(board.get_piece(Vector2i(1, 1)).def.id == "ranger" and result.captured, "the Ranger stays put")
	var rock: BoardState = _board({Vector2i(1, 1): [&"ranger", W], Vector2i(1, 3): [&"pawn", B], Vector2i(1, 5): [&"knight", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	rock.set_rocks([Vector2i(1, 4)])
	expect(Vector2i(1, 5) not in _moves(rock, Vector2i(1, 1)), "a rock turns the boomerang back")
	BattleTestFixture.play(rock, Vector2i(1, 1), Vector2i(1, 3))
	expect(rock.get_piece(Vector2i(1, 3)) == null and rock.get_piece(Vector2i(1, 5)) != null and rock.is_rock(Vector2i(1, 4)), "only the enemies before the rock are hit, and the rock stays")
	var guarded: BoardState = _board({Vector2i(4, 1): [&"ranger", W], Vector2i(4, 3): [&"king", B], Vector2i(3, 3): [&"pawn", B], Vector2i(4, 4): [&"knight", B], Vector2i(0, 0): [&"king", W]})
	BattleTestFixture.play(guarded, Vector2i(4, 1), Vector2i(4, 4))
	expect(guarded.has_king(B) and guarded.get_piece(Vector2i(4, 4)) == null, "the boomerang passes a guarded King and hits the enemy behind it")
	var ranger: PieceDef = Content.piece("ranger")
	expect(ranger.rarity == PieceDef.Rarity.EPIC, "the Ranger is Epic")

func _test_rocks() -> void:
	var light: BoardState = _board({Vector2i(3, 1): [&"bowman", W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	light.set_rocks([Vector2i(3, 4)])
	expect(Vector2i(3, 4) not in _moves(light, Vector2i(3, 1)), "light shooters cannot target rocks")
	for id: StringName in [&"falconer", &"ranger"]:
		var other: BoardState = _board({Vector2i(3, 1): [id, W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
		other.set_rocks([Vector2i(3, 3)])
		expect(Vector2i(3, 3) not in _moves(other, Vector2i(3, 1)), "%s cannot break rocks" % id)
	# The Catapult lobs over rocks instead of breaking them.
	var lobber: BoardState = _board({Vector2i(3, 1): [&"catapult", W], Vector2i(3, 4): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	lobber.set_rocks([Vector2i(3, 3)])
	var lob_moves: Array[Vector2i] = _moves(lobber, Vector2i(3, 1))
	expect(Vector2i(3, 3) not in lob_moves, "the catapult cannot target or break a rock")
	expect(Vector2i(3, 4) in lob_moves, "the catapult shoots over a rock")
	var lob_result: MoveOutcome = BattleTestFixture.play(lobber, Vector2i(3, 1), Vector2i(3, 4))
	expect(bool(lob_result.success) and lobber.get_piece(Vector2i(3, 4)) == null and lobber.is_rock(Vector2i(3, 3)), "the shot lands beyond the rock and the rock stays")
	for id: StringName in [&"blast_catapult", &"sky_archer"]:
		var heavy: BoardState = _board({Vector2i(3, 1): [id, W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
		heavy.set_rocks([Vector2i(3, 3)])
		var clone: BoardState = heavy.clone()
		expect(Vector2i(3, 3) in _moves(heavy, Vector2i(3, 1)), "%s can target a rock" % id)
		var result: MoveOutcome = BattleTestFixture.play(heavy, Vector2i(3, 1), Vector2i(3, 3))
		expect(result.success and result.rock_broken == Vector2i(3, 3), "%s breaks the rock" % id)
		expect(not heavy.is_rock(Vector2i(3, 3)) and heavy.get_piece(Vector2i(3, 1)).def.id == String(id), "the rock is gone and the shooter stays")
		expect(clone.is_rock(Vector2i(3, 3)), "a board copy keeps its own rocks")
	var blast: BoardState = _board({Vector2i(3, 1): [&"blast_catapult", W], Vector2i(3, 5): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	blast.set_rocks([Vector2i(4, 5)])
	BattleTestFixture.play(blast, Vector2i(3, 1), Vector2i(3, 5))
	expect(blast.is_rock(Vector2i(4, 5)), "the blast splash leaves neighbouring rocks alone")

func _test_presentation_event() -> void:
	var board: BoardState = _board({Vector2i(3, 1): [&"blast_catapult", W], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	board.set_rocks([Vector2i(3, 4)])
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(3, 1), Vector2i(3, 4), W))
	var found: bool = false
	for event: BattleEvent in result.events:
		found = found or (event.event_type == BattleCommandProcessor.EVENT_ROCK_BROKEN and event.payload.get("position") == Vector2i(3, 4))
	expect(result.success and found, "breaking a rock emits a rock_broken event")

func _test_ai_takes_the_shot() -> void:
	var board: BoardState = _board({Vector2i(3, 6): [&"bowman", B], Vector2i(3, 3): [&"rook", W], Vector2i(0, 0): [&"king", W], Vector2i(1, 0): [&"pawn", W], Vector2i(7, 7): [&"king", B]}, B)
	var move: Dictionary = EnemyMoveSelector.new().choose_move(board, B)
	expect(move.get("from") == Vector2i(3, 6) and move.get("to") == Vector2i(3, 3), "the enemy AI shoots a free Rook")
	var multi: BoardState = _board({Vector2i(1, 6): [&"ranger", B], Vector2i(1, 4): [&"knight", W], Vector2i(1, 3): [&"bishop", W], Vector2i(6, 1): [&"pawn", W], Vector2i(0, 0): [&"king", W], Vector2i(1, 0): [&"pawn", W], Vector2i(7, 7): [&"king", B]}, B)
	var score: int = int(EnemyMoveSelector.new()._score_move(multi, Vector2i(1, 6), Vector2i(1, 4), B, true)["score"])
	expect(score >= 5000, "a boomerang that takes two pieces scores both (%d)" % score)

func _test_new_ranges() -> void:
	var catapult: BoardState = _board({Vector2i(3, 1): [&"catapult", W], Vector2i(3, 2): [&"pawn", B], Vector2i(3, 5): [&"knight", B], Vector2i(2, 2): [&"pawn", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	var moves: Array[Vector2i] = _moves(catapult, Vector2i(3, 1))
	expect(Vector2i(3, 2) not in moves and Vector2i(2, 2) not in moves, "the Catapult cannot capture next to it")
	expect(Vector2i(4, 1) in moves, "the Catapult still steps one square")
	var lob: BoardState = _board({Vector2i(3, 1): [&"catapult", W], Vector2i(3, 5): [&"knight", B], Vector2i(3, 6): [&"rook", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	expect(Vector2i(3, 5) in _moves(lob, Vector2i(3, 1)) and Vector2i(3, 6) not in _moves(lob, Vector2i(3, 1)), "the Catapult lobs 2-4 squares up or down")
	var ranger: BoardState = _board({Vector2i(1, 1): [&"ranger", W], Vector2i(3, 3): [&"pawn", B], Vector2i(1, 3): [&"pawn", B], Vector2i(0, 7): [&"king", W], Vector2i(7, 7): [&"king", B]})
	moves = _moves(ranger, Vector2i(1, 1))
	expect(Vector2i(1, 3) in moves and Vector2i(3, 3) not in moves, "the Ranger throws only up, down or sideways")
	var sky: BoardState = _board({Vector2i(1, 1): [&"sky_archer", W], Vector2i(1, 7): [&"knight", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	sky.set_rocks([Vector2i(1, 3)])
	sky.set_piece(Vector2i(1, 4), _piece(&"pawn", W))
	moves = _moves(sky, Vector2i(1, 1))
	expect(Vector2i(1, 7) in moves, "the Sky Archer shoots 6 squares, over rocks and pieces")
	expect(Vector2i(1, 3) in moves, "the Sky Archer can still break a rock")
	var mage: BoardState = _board({Vector2i(3, 3): [&"archmage", W], Vector2i(4, 4): [&"pawn", B], Vector2i(3, 6): [&"knight", B], Vector2i(3, 5): [&"pawn", W], Vector2i(0, 3): [&"rook", B], Vector2i(4, 5): [&"bishop", B], Vector2i(0, 0): [&"king", W], Vector2i(7, 7): [&"king", B]})
	mage.set_rocks([Vector2i(1, 3)])
	moves = _moves(mage, Vector2i(3, 3))
	expect(Vector2i(4, 4) in moves, "the Archmage beams an enemy next to it")
	expect(Vector2i(3, 6) not in moves, "pieces block the beam")
	expect(Vector2i(0, 3) not in moves and Vector2i(2, 3) in moves, "rocks block the beam; it still walks up to them")
	expect(Vector2i(4, 5) not in moves, "the Archmage no longer leaps like a Knight")
	var beam: MoveOutcome = BattleTestFixture.play(mage, Vector2i(3, 3), Vector2i(4, 4))
	expect(beam.captured and beam.ranged and mage.get_piece(Vector2i(3, 3)).def.id == "archmage" and mage.get_piece(Vector2i(4, 4)) == null, "the beam kills and the Archmage stays put")

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

func _moves(board: BoardState, square: Vector2i) -> Array[Vector2i]:
	var piece: ChessPiece = board.get_piece(square)
	if piece == null:
		return []
	return board.get_executable_moves_for_color(square, piece.color)

func _piece(piece_id: StringName, color: int) -> ChessPiece:
	return ChessPiece.new(Content.piece(piece_id), color)

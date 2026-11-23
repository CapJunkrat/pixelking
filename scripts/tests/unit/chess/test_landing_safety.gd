class_name TestLandingSafety
extends SceneTreeTestCase

## BoardState.evaluate_landing: the danger and protection marks on a selected piece's
## destinations come from playing the enemy replies with the real rules.

const W := GameRules.PieceColor.WHITE
const B := GameRules.PieceColor.BLACK

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_melee_threats()
	_test_ranged_attacker()
	_test_immunity_and_shells()
	_test_bodyguard_and_shield()
	_test_guarded_safe_square()
	_test_boomerang()
	finish_test("Landing safety test")

func _test_melee_threats() -> void:
	var lone: BoardState = _board({Vector2i(1, 0): [&"knight", W], Vector2i(2, 7): [&"rook", B]})
	var safety: Dictionary = lone.evaluate_landing(Vector2i(1, 0), Vector2i(2, 2))
	expect(bool(safety["lethal"]) and not bool(safety["protected"]), "a square a rook can take on, with no defender, is a plain danger")
	var guarded: BoardState = _board({Vector2i(1, 0): [&"knight", W], Vector2i(2, 7): [&"rook", B], Vector2i(0, 2): [&"rook", W]})
	safety = guarded.evaluate_landing(Vector2i(1, 0), Vector2i(2, 2))
	expect(bool(safety["lethal"]) and bool(safety["protected"]), "a defender that can retake on the landing square makes it an exchange")

func _test_ranged_attacker() -> void:
	# A shooter does not step onto the square: retaking there answers nothing.
	var shot: BoardState = _board({Vector2i(1, 0): [&"knight", W], Vector2i(2, 5): [&"bowman", B], Vector2i(0, 2): [&"rook", W]})
	var safety: Dictionary = shot.evaluate_landing(Vector2i(1, 0), Vector2i(2, 2))
	expect(bool(safety["lethal"]), "a bowman two squares off can shoot the landing piece")
	expect(not bool(safety["protected"]), "guarding the landing square does not answer a shot from a distance")
	var answered: BoardState = _board({Vector2i(1, 0): [&"knight", W], Vector2i(2, 5): [&"bowman", B], Vector2i(0, 5): [&"rook", W]})
	safety = answered.evaluate_landing(Vector2i(1, 0), Vector2i(2, 2))
	expect(bool(safety["lethal"]) and bool(safety["protected"]), "a piece that can take the shooter where it stands protects the move")

func _test_immunity_and_shells() -> void:
	var gargoyle: BoardState = _board({Vector2i(0, 1): [&"gargoyle", W], Vector2i(2, 4): [&"bowman", B]})
	var safety: Dictionary = gargoyle.evaluate_landing(Vector2i(0, 1), Vector2i(2, 1))
	expect(not bool(safety["lethal"]) and not bool(safety["shell"]), "a Gargoyle in a bowman's line is not threatened: arrows cannot hurt it")
	var rook: BoardState = _board({Vector2i(0, 1): [&"rook", W], Vector2i(2, 4): [&"bowman", B]})
	expect(bool(rook.evaluate_landing(Vector2i(0, 1), Vector2i(2, 1))["lethal"]), "the same square is deadly for a piece without the immunity")
	var giant: BoardState = _board({Vector2i(0, 1): [&"stone_giant", W], Vector2i(2, 7): [&"rook", B]})
	safety = giant.evaluate_landing(Vector2i(0, 1), Vector2i(2, 1))
	expect(bool(safety["shell"]) and not bool(safety["lethal"]), "a Stone Giant with its shell only loses a layer there")
	var bare: BoardState = _board({Vector2i(0, 1): [&"stone_giant", W], Vector2i(2, 7): [&"rook", B]})
	bare.get_piece(Vector2i(0, 1)).shell_left = 0
	expect(bool(bare.evaluate_landing(Vector2i(0, 1), Vector2i(2, 1))["lethal"]), "with its shell gone the Stone Giant can be taken")

func _test_bodyguard_and_shield() -> void:
	var guarded_king: BoardState = _board({Vector2i(3, 0): [&"pawn", W], Vector2i(4, 4): [&"bowman", B]}, Vector2i(4, 0))
	expect(not bool(guarded_king.evaluate_landing(Vector2i(4, 0), Vector2i(4, 1))["lethal"]), "a King next to its own piece cannot be shot")
	var open_king: BoardState = _board({Vector2i(4, 4): [&"bowman", B]}, Vector2i(4, 0))
	expect(bool(open_king.evaluate_landing(Vector2i(4, 0), Vector2i(4, 1))["lethal"]), "a King alone in a bowman's line can be shot")
	var shielded: BoardState = _board({Vector2i(1, 0): [&"knight", W], Vector2i(2, 7): [&"rook", B]})
	shielded.get_piece(Vector2i(1, 0)).shield_until_serial = 99
	expect(not bool(shielded.evaluate_landing(Vector2i(1, 0), Vector2i(2, 2))["lethal"]), "a shielded piece cannot be attacked at all")

func _test_guarded_safe_square() -> void:
	var guarded: BoardState = _board({Vector2i(1, 0): [&"knight", W], Vector2i(0, 2): [&"rook", W]})
	var safety: Dictionary = guarded.evaluate_landing(Vector2i(1, 0), Vector2i(2, 2))
	expect(not bool(safety["lethal"]) and bool(safety["protected"]), "a safe square another piece covers is marked protected")
	var open: BoardState = _board({Vector2i(1, 0): [&"knight", W]})
	safety = open.evaluate_landing(Vector2i(1, 0), Vector2i(2, 2))
	expect(not bool(safety["lethal"]) and not bool(safety["protected"]), "a safe square nobody covers carries no mark")

func _test_boomerang() -> void:
	var board: BoardState = _board({Vector2i(1, 0): [&"knight", W], Vector2i(2, 4): [&"pawn", W], Vector2i(2, 6): [&"ranger", B]})
	expect(bool(board.evaluate_landing(Vector2i(1, 0), Vector2i(2, 2))["lethal"]), "a boomerang thrown down the line reaches the piece behind another")

## Kings on (7, 0) / (7, 7) unless `white_king` moves White's.
func _board(pieces: Dictionary, white_king: Vector2i = Vector2i(7, 0)) -> BoardState:
	var board: BoardState = BoardState.new(8, false)
	board.clear_for_setup()
	board.place_piece_for_setup(white_king, _piece(&"king", W))
	board.place_piece_for_setup(Vector2i(7, 7), _piece(&"king", B))
	for square: Vector2i in pieces:
		var spec: Array = pieces[square]
		var piece: ChessPiece = _piece(spec[0], spec[1])
		board.set_piece(square, piece)
		piece.origin = square
	board.turn = W
	return board

func _piece(piece_id: StringName, color: int) -> ChessPiece:
	return ChessPiece.new(Content.piece(piece_id), color)

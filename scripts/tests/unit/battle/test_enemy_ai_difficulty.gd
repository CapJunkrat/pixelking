extends SceneTreeTestCase

const W := GameRules.PieceColor.WHITE
const B := GameRules.PieceColor.BLACK

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_difficulty_values()
	_test_medium_sees_discovered_attacks()
	_test_medium_never_opens_its_king()
	_test_medium_counts_recaptures()
	_test_shadow_king_threats()
	_test_medium_is_fast_enough()
	finish_test("Enemy AI difficulty")

func _test_difficulty_values() -> void:
	expect(EnemyMoveSelector.new().difficulty == EnemyMoveSelector.DIFFICULTY_EASY, "the AI defaults to Easy")
	expect(EnemyMoveSelector.is_valid_difficulty("easy") and EnemyMoveSelector.is_valid_difficulty("medium") and not EnemyMoveSelector.is_valid_difficulty("hard"), "only Easy and Medium exist")

## The Bishop can grab a pawn, but moving it uncovers the Queen to a White Rook. Easy
## only checks the piece it moves; Medium sees the Rook's reply.
func _test_medium_sees_discovered_attacks() -> void:
	var board := _board({Vector2i(0, 4): ["rook", W], Vector2i(4, 5): ["pawn", W], Vector2i(0, 0): ["king", W], Vector2i(3, 4): ["bishop", B], Vector2i(6, 4): ["queen", B], Vector2i(7, 7): ["king", B]})
	var grab := {"from": Vector2i(3, 4), "to": Vector2i(4, 5)}
	expect(_same(_choose(board, "easy"), grab), "Easy grabs the pawn and uncovers its Queen")
	var medium := _choose(board, "medium")
	expect(not medium.is_empty() and not _same(medium, grab), "Medium keeps the Queen covered")

## Taking the Queen with the Rook opens the diagonal from a White Bishop onto the
## Black King.
func _test_medium_never_opens_its_king() -> void:
	var board := _board({Vector2i(3, 3): ["bishop", W], Vector2i(6, 1): ["queen", W], Vector2i(0, 0): ["king", W], Vector2i(6, 6): ["rook", B], Vector2i(7, 7): ["king", B], Vector2i(0, 7): ["pawn", B]})
	var bait := {"from": Vector2i(6, 6), "to": Vector2i(6, 1)}
	var easy := _choose(board, "easy")
	expect(_same(easy, bait), "Easy takes the Queen even though it opens its King (%s)" % easy)
	var medium := _choose(board, "medium")
	expect(not medium.is_empty() and not _same(medium, bait), "Medium never leaves its King to be taken")
	var after := board.clone()
	after._apply_move(medium["from"], medium["to"], "queen", true)
	expect(EnemyMoveSelector.new().worst_reply_loss(after, B) < EnemyMoveSelector.KING_LOSS, "Medium's move keeps its King safe")

## A guarded pawn taken by a Rook is answered by a recapture: the reply only counts as
## the difference.
func _test_medium_counts_recaptures() -> void:
	var board := _board({Vector2i(3, 3): ["rook", W], Vector2i(0, 0): ["king", W], Vector2i(3, 6): ["knight", B], Vector2i(2, 7): ["rook", B], Vector2i(7, 7): ["king", B]})
	var selector := EnemyMoveSelector.new()
	# White Rook on d4 can take the Knight on d7, then the Black Rook on c8 cannot
	# reach d7, so the loss is the whole Knight.
	expect(selector.worst_reply_loss(board, B) == 3000, "an unguarded Knight is a full loss (%d)" % selector.worst_reply_loss(board, B))
	board.set_piece(Vector2i(3, 7), board.get_piece(Vector2i(2, 7)))
	board.set_piece(Vector2i(2, 7), null)
	# Now the Black Rook on d8 takes back on d7: the Rook (5) is worth more than the
	# Knight (3), so White gains nothing by taking.
	expect(selector.worst_reply_loss(board, B) == 0, "a guarded Knight is not lost (%d)" % selector.worst_reply_loss(board, B))

## A Shadow King strikes and returns home, so guarding the target does not help.
func _test_shadow_king_threats() -> void:
	# The Rook on f6 is two squares diagonally from the Shadow King (which a Rook cannot
	# answer), and the Knight on h7 guards it.
	var board := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(0, 0): ["pawn", W], Vector2i(5, 5): ["rook", B], Vector2i(7, 6): ["knight", B], Vector2i(7, 7): ["king", B]})
	var selector := EnemyMoveSelector.new()
	expect(selector.worst_reply_loss(board, B) == 5000, "a guarded Rook in the Shadow King's reach is still lost (%d)" % selector.worst_reply_loss(board, B))
	var medium := _choose(board, "medium")
	expect(not medium.is_empty(), "Medium finds a move against the Shadow King")
	if medium.is_empty():
		return
	var after := board.clone()
	after._apply_move(medium["from"], medium["to"], "queen", true)
	expect(selector.worst_reply_loss(after, B) == 0, "Medium takes its pieces out of the Shadow King's reach (%s -> %s)" % [medium["from"], medium["to"]])

## A full board is the slowest case: Medium must still answer quickly.
func _test_medium_is_fast_enough() -> void:
	var board := BoardState.new(8, true)
	board.turn = B
	var selector := EnemyMoveSelector.new()
	selector.difficulty = EnemyMoveSelector.DIFFICULTY_MEDIUM
	var started := Time.get_ticks_msec()
	var move := selector.choose_move(board, B)
	var elapsed := Time.get_ticks_msec() - started
	print("  medium move on a full board took %d ms" % elapsed)
	expect(not move.is_empty() and elapsed < 1500, "Medium chooses a move on a full board in time (%d ms)" % elapsed)

func _choose(board: BoardState, difficulty: String) -> Dictionary:
	var selector := EnemyMoveSelector.new()
	selector.difficulty = difficulty
	return selector.choose_move(board.clone(), B)

func _same(move: Dictionary, expected: Dictionary) -> bool:
	return not move.is_empty() and move.get("from") == expected["from"] and move.get("to") == expected["to"]

func _board(specs: Dictionary, color: int = B) -> BoardState:
	var board := BoardState.new(8, false)
	for square: Vector2i in specs:
		var spec: Array = specs[square]
		board.place_piece_for_setup(square, ChessPiece.new(PieceDefDatabase.get_def(spec[0]), spec[1]))
	board.turn = color
	return board

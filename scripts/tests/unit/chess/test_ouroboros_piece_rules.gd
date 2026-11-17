class_name TestOuroborosPieceRules
extends SceneTreeTestCase

const NEW_IDS: Array[StringName] = [
	&"assassin", &"royal_guard", &"catapult", &"bowman", &"portal_mage",
	&"unicorn_cavalry", &"centaur", &"manticore", &"gryphon", &"gorgon",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for piece_id: StringName in NEW_IDS:
		expect(PieceDefDatabase.get_def(piece_id) != null, "catalog resolves %s" % piece_id)
	_test_royal_guard()
	_test_catapult()
	_test_bowman()
	_test_portal_mage()
	_test_hybrid_leapers()
	_test_bent_rays()
	_test_gorgon()
	_test_assassin_bonus_action()
	finish_test("Ouroboros piece rules test")

func _test_royal_guard() -> void:
	var board: BoardState = _piece_board(&"royal_guard")
	expect(Vector2i(4, 3) in MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3)), "Royal Guard moves to adjacent empty square")
	expect(Vector2i(6, 3) not in MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3)), "Royal Guard cannot relocate along a Queen ray")
	board.set_piece(Vector2i(6, 3), _piece(&"pawn", GameRules.PieceColor.BLACK))
	expect(Vector2i(6, 3) in MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3)), "Royal Guard captures first distant enemy on Queen ray")
	expect(Vector2i(5, 3) in MoveGenerator.get_attack_squares(board, Vector2i(3, 3)), "Royal Guard threatens empty Queen-ray squares")

func _test_catapult() -> void:
	var board: BoardState = _piece_board(&"catapult")
	board.set_piece(Vector2i(3, 4), _piece(&"pawn", GameRules.PieceColor.WHITE))
	var moves: Array[Vector2i] = MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3))
	expect(Vector2i(3, 5) in moves, "Catapult jumps over vertical blockers")
	board.set_piece(Vector2i(4, 3), _piece(&"pawn", GameRules.PieceColor.WHITE))
	moves = MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3))
	expect(Vector2i(5, 3) not in moves, "Catapult horizontal movement remains blocked")

func _test_bowman() -> void:
	var board: BoardState = _piece_board(&"bowman")
	var moves: Array[Vector2i] = MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3))
	expect(Vector2i(4, 3) not in moves and Vector2i(5, 3) in moves, "Bowman requires at least two squares")
	board.set_piece(Vector2i(4, 3), _piece(&"pawn", GameRules.PieceColor.WHITE))
	expect(Vector2i(5, 3) not in MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3)), "adjacent blocker stops Bowman distant ray")

func _test_portal_mage() -> void:
	var board: BoardState = _piece_board(&"portal_mage")
	expect(Vector2i(6, 1) in MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3)), "Portal Mage teleports to any empty square")
	board.set_piece(Vector2i(6, 1), _piece(&"pawn", GameRules.PieceColor.BLACK))
	board.set_piece(Vector2i(4, 4), _piece(&"pawn", GameRules.PieceColor.BLACK))
	var moves: Array[Vector2i] = MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3))
	expect(Vector2i(6, 1) not in moves and Vector2i(4, 4) in moves, "Portal Mage captures adjacent enemies only")
	expect(Vector2i(6, 1) not in MoveGenerator.get_attack_squares(board, Vector2i(3, 3)), "Portal teleport is not an attack")

func _test_hybrid_leapers() -> void:
	var unicorn: BoardState = _piece_board(&"unicorn_cavalry")
	var unicorn_moves: Array[Vector2i] = MoveGenerator.generate_pseudo_legal(unicorn, Vector2i(3, 3))
	expect(Vector2i(3, 6) in unicorn_moves and Vector2i(5, 4) in unicorn_moves, "Unicorn Cavalry combines Rook and Knight")
	var centaur: BoardState = _piece_board(&"centaur")
	var centaur_moves: Array[Vector2i] = MoveGenerator.generate_pseudo_legal(centaur, Vector2i(3, 3))
	expect(Vector2i(6, 6) in centaur_moves and Vector2i(5, 4) in centaur_moves, "Centaur combines Bishop and Knight")

func _test_bent_rays() -> void:
	var manticore: BoardState = _piece_board(&"manticore")
	expect(Vector2i(5, 4) in MoveGenerator.generate_pseudo_legal(manticore, Vector2i(3, 3)), "Manticore turns from cardinal step into diagonal ray")
	manticore.set_piece(Vector2i(4, 3), _piece(&"pawn", GameRules.PieceColor.WHITE))
	expect(Vector2i(5, 4) not in MoveGenerator.generate_pseudo_legal(manticore, Vector2i(3, 3)), "occupied Manticore corner blocks that branch")
	var gryphon: BoardState = _piece_board(&"gryphon")
	expect(Vector2i(6, 4) in MoveGenerator.generate_pseudo_legal(gryphon, Vector2i(3, 3)), "Gryphon turns from diagonal step into cardinal ray")
	gryphon.set_piece(Vector2i(4, 4), _piece(&"pawn", GameRules.PieceColor.BLACK))
	expect(Vector2i(6, 4) not in MoveGenerator.generate_pseudo_legal(gryphon, Vector2i(3, 3)), "occupied Gryphon corner blocks that branch")

func _test_gorgon() -> void:
	var board: BoardState = _piece_board(&"gorgon")
	board.set_piece(Vector2i(3, 5), _piece(&"pawn", GameRules.PieceColor.BLACK))
	expect(Vector2i(3, 4) in MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3)) and Vector2i(3, 5) not in MoveGenerator.generate_pseudo_legal(board, Vector2i(3, 3)), "Gorgon moves on Queen rays but cannot capture")
	expect(MoveGenerator.get_attack_squares(board, Vector2i(3, 3)).is_empty(), "Gorgon creates no attack squares")
	board.set_piece(Vector2i(4, 3), _piece(&"rook", GameRules.PieceColor.WHITE))
	board.set_piece(Vector2i(2, 3), _piece(&"rook", GameRules.PieceColor.BLACK))
	expect(MoveGenerator.generate_pseudo_legal(board, Vector2i(4, 3)).is_empty() and MoveGenerator.generate_pseudo_legal(board, Vector2i(2, 3)).is_empty(), "Gorgon freezes adjacent allies and enemies")
	board.set_piece(Vector2i(4, 4), _piece(&"gorgon", GameRules.PieceColor.BLACK))
	expect(not MoveGenerator.generate_pseudo_legal(board, Vector2i(4, 4)).is_empty(), "Gorgons are immune to Gorgon freezing")

func _test_assassin_bonus_action() -> void:
	var board: BoardState = BoardState.new(5, false)
	board.clear_for_setup()
	board.place_piece_for_setup(Vector2i(0, 0), _piece(&"king", GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(4, 4), _piece(&"king", GameRules.PieceColor.BLACK))
	board.place_piece_for_setup(Vector2i(2, 2), _piece(&"assassin", GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(2, 3), _piece(&"pawn", GameRules.PieceColor.BLACK))
	board.place_piece_for_setup(Vector2i(3, 3), _piece(&"rook", GameRules.PieceColor.BLACK))
	board.finalize_setup(GameRules.PieceColor.WHITE)
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var first: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(2, 3), GameRules.PieceColor.WHITE))
	expect(first.success and board.turn == GameRules.PieceColor.WHITE and bool(first.legacy_result.get("extra_move_granted", false)), "Assassin capture retains action authority")
	expect(_has_event(first.events, BattleCommandProcessor.EVENT_EXTRA_MOVE_GRANTED) and board.turn_serial == 0, "Assassin emits bonus event without advancing side-turn serial")
	var second: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(2, 3), Vector2i(3, 3), GameRules.PieceColor.WHITE))
	expect(second.success and board.turn == GameRules.PieceColor.WHITE, "Assassin bonus captures can chain")
	var final_move: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(3, 2), GameRules.PieceColor.WHITE))
	expect(final_move.success and board.turn == GameRules.PieceColor.BLACK and board.turn_serial == 1, "Assassin non-capture ends the side turn")

	var terminal_board: BoardState = BoardState.new(5, false)
	terminal_board.clear_for_setup()
	terminal_board.place_piece_for_setup(Vector2i(0, 0), _piece(&"king", GameRules.PieceColor.WHITE))
	terminal_board.place_piece_for_setup(Vector2i(2, 3), _piece(&"king", GameRules.PieceColor.BLACK))
	terminal_board.place_piece_for_setup(Vector2i(2, 2), _piece(&"assassin", GameRules.PieceColor.WHITE))
	terminal_board.finalize_setup(GameRules.PieceColor.WHITE)
	var terminal_processor: BattleCommandProcessor = BattleCommandProcessor.new(terminal_board)
	var terminal_capture: BattleCommandResult = terminal_processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(2, 3), GameRules.PieceColor.WHITE))
	expect(terminal_processor.status.is_finished() and not bool(terminal_capture.legacy_result.get("extra_move_granted", false)), "terminal King capture suppresses Assassin bonus action")

func _piece_board(piece_id: StringName) -> BoardState:
	var board: BoardState = BoardState.new(8, false)
	board.clear_for_setup()
	board.set_piece(Vector2i(3, 3), _piece(piece_id, GameRules.PieceColor.WHITE))
	return board

func _piece(piece_id: StringName, color: int) -> ChessPiece:
	return ChessPiece.new(PieceDefDatabase.get_def(piece_id), color)

func _has_event(events: Array[BattleEvent], event_type: StringName) -> bool:
	for event: BattleEvent in events:
		if event.event_type == event_type:
			return true
	return false

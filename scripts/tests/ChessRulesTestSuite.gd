extends RefCounted
class_name ChessRulesTestSuite

var pass_count := 0
var fail_count := 0
var log_lines: Array[String] = []

func _log(line: String) -> void:
	log_lines.append(line)

func _assert(condition: bool, label: String) -> void:
	if condition:
		pass_count += 1
		_log("[PASS] " + label)
	else:
		fail_count += 1
		_log("[FAIL] " + label)

func run_all() -> Dictionary:
	pass_count = 0
	fail_count = 0
	log_lines.clear()
	_log("===== PixelKing rule tests =====")

	test_default_and_dynamic_board_sizes()
	test_color_uses_localization_keys()
	test_simulation_clone_preserves_identity()
	test_inherited_king_movement_can_be_extended()
	test_royal_tag_does_not_define_the_king()
	test_black_pawn_double_step_uses_dynamic_board_size()
	test_basic_standard_moves()
	test_make_move_rejects_illegal_move()
	test_has_any_legal_move_uses_explicit_color()
	test_castling_success_on_small_board()
	test_castling_requires_clear_path_and_same_color()
	test_castling_requires_unmoved_king_and_rook()
	test_castling_rejects_current_check()
	test_castling_rejects_attacked_path()
	test_castling_rejects_attacked_destination()
	test_en_passant_is_capture()
	test_promotion_validation()
	test_pin_prevents_illegal_move()
	test_lone_king_terminal_conditions()

	_log("\n===== Result: %d passed / %d failed =====" % [pass_count, fail_count])
	return {"pass_count": pass_count, "fail_count": fail_count, "log_lines": log_lines}

func _empty_board(size: int = 5) -> BoardState:
	return BoardState.new(size, false)

func _piece(id: String, color: int) -> ChessPiece:
	return ChessPiece.new(PieceDefDatabase.get_def(id), color)

func _place_kings(board: BoardState, white_pos: Vector2i, black_pos: Vector2i) -> void:
	board.set_piece(white_pos, _piece("king", GameRules.PieceColor.WHITE))
	board.set_piece(black_pos, _piece("king", GameRules.PieceColor.BLACK))
	board.king_pos[GameRules.PieceColor.WHITE] = white_pos
	board.king_pos[GameRules.PieceColor.BLACK] = black_pos

func _castle_board() -> BoardState:
	var board := _empty_board()
	_place_kings(board, Vector2i(2, 0), Vector2i(0, 4))
	board.set_piece(Vector2i(4, 0), _piece("rook", GameRules.PieceColor.WHITE))
	return board

func test_default_and_dynamic_board_sizes() -> void:
	_log("\n-- test_default_and_dynamic_board_sizes --")
	var default_board := BoardState.new()
	_assert(default_board.board_size == 5, "test_default_and_dynamic_board_sizes assertion 1")
	_assert(default_board.grid.size() == 5 and default_board.grid[0].size() == 5, "test_default_and_dynamic_board_sizes assertion 2")
	_assert(default_board.get_piece(Vector2i(2, 0)).def.id == "king", "test_default_and_dynamic_board_sizes assertion 3")
	_assert(default_board.get_piece(Vector2i(4, 0)).def.id == "rook", "test_default_and_dynamic_board_sizes assertion 4")
	var board6 := BoardState.new(6)
	var board7 := BoardState.new(7)
	_assert(board6.board_size == 6 and board6.in_bounds(Vector2i(5, 5)), "test_default_and_dynamic_board_sizes assertion 5")
	_assert(board7.board_size == 7 and board7.in_bounds(Vector2i(6, 6)), "test_default_and_dynamic_board_sizes assertion 6")

func test_color_uses_localization_keys() -> void:
	_log("\n-- test_color_uses_localization_keys --")
	_assert(GameRules.color_key(GameRules.PieceColor.WHITE) == &"COLOR_WHITE", "white color returns a localization key")
	_assert(GameRules.color_key(GameRules.PieceColor.BLACK) == &"COLOR_BLACK", "black color returns a localization key")

func test_simulation_clone_preserves_identity() -> void:
	_log("\n-- test_simulation_clone_preserves_identity --")
	var original := _piece("rook", GameRules.PieceColor.WHITE)
	original.has_moved = true
	var simulation_copy := original.clone_for_simulation()
	var board := _empty_board()
	board.set_piece(Vector2i(0, 0), original)
	var board_copy := board.clone()
	var next_real_piece := _piece("pawn", GameRules.PieceColor.WHITE)
	_assert(simulation_copy != original, "simulation clone is an independent object")
	_assert(simulation_copy.instance_id == original.instance_id, "simulation clone preserves logical identity")
	_assert(simulation_copy.has_moved == original.has_moved, "simulation clone copies mutable state")
	_assert(board_copy.get_piece(Vector2i(0, 0)).instance_id == original.instance_id, "board clone preserves piece identity")
	_assert(next_real_piece.instance_id == original.instance_id + 1, "simulation clones do not consume a real instance ID")

func test_inherited_king_movement_can_be_extended() -> void:
	_log("\n-- test_inherited_king_movement_can_be_extended --")
	var king_definition := PieceDefDatabase.get_def("king")
	var inherited_profile := MovementProfile.new()
	inherited_profile.parent = king_definition.movement_profile
	var rook_slide := SlideMovementRule.new()
	rook_slide.directions = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]
	rook_slide.max_distance = 5
	inherited_profile.rules.append(rook_slide)

	var definition := PieceDef.new()
	definition.id = "royal_tower"
	definition.movement_profile = inherited_profile
	var board := _empty_board()
	board.set_piece(Vector2i(2, 2), ChessPiece.new(definition, GameRules.PieceColor.WHITE))
	var moves := MoveGenerator.generate_pseudo_legal(board, Vector2i(2, 2))
	_assert(Vector2i(3, 3) in moves, "child profile inherits the king diagonal step")
	_assert(Vector2i(2, 0) in moves and Vector2i(4, 2) in moves, "child profile extends king movement with rook slides")
	_assert(Vector2i(4, 4) not in moves, "inherited king diagonal remains range one")
	_assert(moves.size() == 12, "inherited and added movement rules are deduplicated")
	_assert(not definition.has_movement_rule(&"castling"), "inheriting king movement does not inherit castling")

	var extra_jump := JumpMovementRule.new()
	extra_jump.offsets = [Vector2i(2, 2)]
	king_definition.movement_profile.rules.append(extra_jump)
	var updated_moves := MoveGenerator.generate_pseudo_legal(board, Vector2i(2, 2))
	_assert(Vector2i(4, 4) in updated_moves, "changes to the parent king profile propagate to inheritors")
	king_definition.movement_profile.rules.erase(extra_jump)

func test_royal_tag_does_not_define_the_king() -> void:
	_log("\n-- test_royal_tag_does_not_define_the_king --")
	var king_definition := PieceDefDatabase.get_def("king")
	var royal_guard_definition := PieceDef.new()
	royal_guard_definition.id = "royal_guard"
	royal_guard_definition.is_royal = true
	royal_guard_definition.is_king = false
	royal_guard_definition.movement_profile = MovementProfile.new()
	royal_guard_definition.movement_profile.parent = king_definition.movement_profile

	_assert(king_definition.is_royal and king_definition.is_king, "standard king is both Royal and the loss-condition king")
	_assert(royal_guard_definition.is_royal, "Royal guard keeps the Royal category tag")
	_assert(not royal_guard_definition.is_king, "Royal guard is not the loss-condition king")
	_assert(not royal_guard_definition.has_movement_rule(&"castling"), "Royal guard does not inherit the king special action")

	var board := _empty_board()
	_place_kings(board, Vector2i(0, 0), Vector2i(4, 4))
	board.set_piece(Vector2i(1, 1), ChessPiece.new(royal_guard_definition, GameRules.PieceColor.WHITE))
	var result := board.make_move(Vector2i(1, 1), Vector2i(1, 2))
	_assert(result["success"], "Royal non-king piece can move normally")
	_assert(board.king_pos[GameRules.PieceColor.WHITE] == Vector2i(0, 0), "moving a Royal non-king does not change tracked king position")

func test_black_pawn_double_step_uses_dynamic_board_size() -> void:
	_log("\n-- test_black_pawn_double_step_uses_dynamic_board_size --")
	var board := _empty_board()
	board.set_piece(Vector2i(2, 3), _piece("pawn", GameRules.PieceColor.BLACK))
	var moves := MoveGenerator.generate_pseudo_legal(board, Vector2i(2, 3))
	_assert(Vector2i(2, 2) in moves, "black pawn can move one square on 5x5 board")
	_assert(Vector2i(2, 1) in moves, "black pawn double step derives its start rank from board size")

func test_basic_standard_moves() -> void:
	_log("\n-- test_basic_standard_moves --")
	var board := BoardState.new(8)
	var moves := board.get_legal_moves(Vector2i(4, 1))
	_assert(Vector2i(4, 2) in moves and Vector2i(4, 3) in moves, "test_basic_standard_moves assertion 1")
	var result := board.make_move(Vector2i(4, 1), Vector2i(4, 3))
	_assert(result["success"] and board.turn == GameRules.PieceColor.BLACK, "test_basic_standard_moves assertion 2")

func test_make_move_rejects_illegal_move() -> void:
	_log("\n-- test_make_move_rejects_illegal_move --")
	var board := BoardState.new(8)
	var original_piece := board.get_piece(Vector2i(0, 1))
	var result := board.make_move(Vector2i(0, 1), Vector2i(0, 5))
	_assert(not result["success"] and result["error"] == "illegal_move", "test_make_move_rejects_illegal_move assertion 1")
	_assert(board.get_piece(Vector2i(0, 1)) == original_piece and board.get_piece(Vector2i(0, 5)) == null, "test_make_move_rejects_illegal_move assertion 2")
	_assert(board.turn == GameRules.PieceColor.WHITE, "test_make_move_rejects_illegal_move assertion 3")

func test_has_any_legal_move_uses_explicit_color() -> void:
	_log("\n-- test_has_any_legal_move_uses_explicit_color --")
	var board := _empty_board()
	_place_kings(board, Vector2i(0, 0), Vector2i(4, 4))
	board.turn = GameRules.PieceColor.WHITE
	_assert(board.get_legal_moves(Vector2i(4, 4)).is_empty(), "test_has_any_legal_move_uses_explicit_color assertion 1")
	_assert(not board.get_legal_moves_for_color(Vector2i(4, 4), GameRules.PieceColor.BLACK).is_empty(), "test_has_any_legal_move_uses_explicit_color assertion 2")
	_assert(board.has_any_legal_move(GameRules.PieceColor.BLACK), "test_has_any_legal_move_uses_explicit_color assertion 3")

func test_castling_success_on_small_board() -> void:
	_log("\n-- test_castling_success_on_small_board --")
	var board := _castle_board()
	_assert(Vector2i(4, 0) in board.get_legal_moves(Vector2i(2, 0)), "test_castling_success_on_small_board assertion 1")
	var result := board.make_move(Vector2i(2, 0), Vector2i(4, 0))
	_assert(result["success"] and result["castled"], "test_castling_success_on_small_board assertion 2")
	_assert(board.get_piece(Vector2i(4, 0)).def.id == "king", "test_castling_success_on_small_board assertion 3")
	_assert(board.get_piece(Vector2i(2, 0)).def.id == "rook", "test_castling_success_on_small_board assertion 4")

func test_castling_requires_clear_path_and_same_color() -> void:
	_log("\n-- test_castling_requires_clear_path_and_same_color --")
	var blocked := _castle_board()
	blocked.set_piece(Vector2i(3, 0), _piece("bishop", GameRules.PieceColor.WHITE))
	_assert(Vector2i(4, 0) not in blocked.get_legal_moves(Vector2i(2, 0)), "test_castling_requires_clear_path_and_same_color assertion 1")
	var enemy_rook := _castle_board()
	enemy_rook.set_piece(Vector2i(4, 0), _piece("rook", GameRules.PieceColor.BLACK))
	_assert(Vector2i(4, 0) not in enemy_rook.get_legal_moves(Vector2i(2, 0)), "test_castling_requires_clear_path_and_same_color assertion 2")

func test_castling_requires_unmoved_king_and_rook() -> void:
	_log("\n-- test_castling_requires_unmoved_king_and_rook --")
	var moved_king := _castle_board()
	moved_king.get_piece(Vector2i(2, 0)).has_moved = true
	_assert(Vector2i(4, 0) not in moved_king.get_legal_moves(Vector2i(2, 0)), "test_castling_requires_unmoved_king_and_rook assertion 1")
	var moved_rook := _castle_board()
	moved_rook.get_piece(Vector2i(4, 0)).has_moved = true
	_assert(Vector2i(4, 0) not in moved_rook.get_legal_moves(Vector2i(2, 0)), "test_castling_requires_unmoved_king_and_rook assertion 2")

func test_castling_rejects_current_check() -> void:
	_log("\n-- test_castling_rejects_current_check --")
	var board := _castle_board()
	board.set_piece(Vector2i(2, 4), _piece("rook", GameRules.PieceColor.BLACK))
	_assert(board.is_in_check(GameRules.PieceColor.WHITE), "test_castling_rejects_current_check assertion 1")
	_assert(Vector2i(4, 0) not in board.get_legal_moves(Vector2i(2, 0)), "test_castling_rejects_current_check assertion 2")

func test_castling_rejects_attacked_path() -> void:
	_log("\n-- test_castling_rejects_attacked_path --")
	var board := _castle_board()
	board.set_piece(Vector2i(3, 4), _piece("rook", GameRules.PieceColor.BLACK))
	_assert(Vector2i(4, 0) not in board.get_legal_moves(Vector2i(2, 0)), "test_castling_rejects_attacked_path assertion 1")

func test_castling_rejects_attacked_destination() -> void:
	_log("\n-- test_castling_rejects_attacked_destination --")
	var board := _castle_board()
	board.set_piece(Vector2i(4, 4), _piece("rook", GameRules.PieceColor.BLACK))
	_assert(Vector2i(4, 0) not in board.get_legal_moves(Vector2i(2, 0)), "test_castling_rejects_attacked_destination assertion 1")

func test_en_passant_is_capture() -> void:
	_log("\n-- test_en_passant_is_capture --")
	var board := BoardState.new(8)
	board.make_move(Vector2i(4, 1), Vector2i(4, 3))
	board.make_move(Vector2i(0, 6), Vector2i(0, 5))
	board.make_move(Vector2i(4, 3), Vector2i(4, 4))
	board.make_move(Vector2i(3, 6), Vector2i(3, 4))
	var result := board.make_move(Vector2i(4, 4), Vector2i(3, 5))
	_assert(result["success"] and result["en_passant_capture"], "test_en_passant_is_capture assertion 1")
	_assert(result["captured"] and board.last_move_was_capture, "test_en_passant_is_capture assertion 2")

func test_promotion_validation() -> void:
	_log("\n-- test_promotion_validation --")
	var invalid_board := _empty_board()
	_place_kings(invalid_board, Vector2i(2, 0), Vector2i(4, 4))
	invalid_board.set_piece(Vector2i(0, 3), _piece("pawn", GameRules.PieceColor.WHITE))
	var invalid := invalid_board.make_move(Vector2i(0, 3), Vector2i(0, 4), "king")
	_assert(not invalid["success"] and invalid["error"] == "invalid_promotion", "test_promotion_validation assertion 1")
	_assert(invalid_board.get_piece(Vector2i(0, 3)).def.id == "pawn", "test_promotion_validation assertion 2")

	var valid_board := _empty_board()
	_place_kings(valid_board, Vector2i(2, 0), Vector2i(4, 4))
	valid_board.set_piece(Vector2i(0, 3), _piece("pawn", GameRules.PieceColor.WHITE))
	var valid := valid_board.make_move(Vector2i(0, 3), Vector2i(0, 4), "knight")
	_assert(valid["success"] and valid["promoted"], "test_promotion_validation assertion 3")
	_assert(valid_board.get_piece(Vector2i(0, 4)).def.id == "knight", "test_promotion_validation assertion 4")

func test_pin_prevents_illegal_move() -> void:
	_log("\n-- test_pin_prevents_illegal_move --")
	var board := _empty_board(8)
	_place_kings(board, Vector2i(4, 0), Vector2i(0, 7))
	board.set_piece(Vector2i(4, 3), _piece("knight", GameRules.PieceColor.WHITE))
	board.set_piece(Vector2i(4, 7), _piece("rook", GameRules.PieceColor.BLACK))
	_assert(board.get_legal_moves(Vector2i(4, 3)).is_empty(), "test_pin_prevents_illegal_move assertion 1")

func test_lone_king_terminal_conditions() -> void:
	_log("\n-- test_lone_king_terminal_conditions --")
	var board := _empty_board()
	_place_kings(board, Vector2i(0, 0), Vector2i(4, 4))
	board.set_piece(Vector2i(3, 4), _piece("rook", GameRules.PieceColor.BLACK))

	board.turn = GameRules.PieceColor.BLACK
	_assert(board.get_lone_king_loser() == GameRules.PieceColor.WHITE, "active equipped side defeats the waiting lone king")

	board.turn = GameRules.PieceColor.WHITE
	_assert(board.get_lone_king_loser() == -1, "lone king receives its response turn before losing")

	board.set_piece(Vector2i(3, 4), null)
	_assert(board.has_only_king(GameRules.PieceColor.WHITE), "white has only its king")
	_assert(board.has_only_king(GameRules.PieceColor.BLACK), "black has only its king")
	_assert(board.get_lone_king_loser() == -1, "two lone kings do not defeat either side")

	board.set_piece(Vector2i(1, 0), _piece("knight", GameRules.PieceColor.WHITE))
	board.set_piece(Vector2i(3, 4), _piece("rook", GameRules.PieceColor.BLACK))
	board.turn = GameRules.PieceColor.BLACK
	_assert(board.get_lone_king_loser() == -1, "no lone-king loss while both sides retain non-king pieces")

extends SceneTreeTestCase

const W := GameRules.PieceColor.WHITE
const B := GameRules.PieceColor.BLACK

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_ray_kings()
	_test_war_actions()
	_test_shadow_strike()
	_test_shadow_safety()
	_test_shadow_previews()
	_test_shadow_enemy_turn_hatch_safety()
	_test_protection_and_death_regressions()
	_test_last_stand_regressions()
	_test_variant_replays()
	_test_shadow_command_payload()
	finish_test("Variant Kings rules")

func _test_ray_kings() -> void:
	for id: String in ["war_king", "shield_king"]:
		for color: int in [W, B]:
			var board := _board({Vector2i(3, 3): [id, color]})
			var moves := board.get_executable_moves_for_color(Vector2i(3, 3), color)
			# Two squares straight, one diagonally.
			for direction: Vector2i in BoardState.NEIGHBORS:
				var reach: int = 1 if direction.x != 0 and direction.y != 0 else 2
				expect(Vector2i(3, 3) + direction * reach in moves, "%s reaches %d along %s" % [id, reach, direction])
				expect(Vector2i(3, 3) + direction * (reach + 1) not in moves, "%s stops after %d along %s" % [id, reach, direction])
				var target := Vector2i(3, 3) + direction * reach
				board.set_piece(target, _piece("pawn", GameRules.opposite(color)))
				expect(target in board.get_executable_moves_for_color(Vector2i(3, 3), color), "%s captures at its full reach" % id)
				if reach == 2:
					board.set_piece(Vector2i(3, 3) + direction, _piece("pawn", color))
					expect(target not in board.get_executable_moves_for_color(Vector2i(3, 3), color), "%s cannot cross pieces" % id)
					board.set_piece(Vector2i(3, 3) + direction, null)
					board.set_rocks([Vector2i(3, 3) + direction])
					expect(target not in board.get_executable_moves_for_color(Vector2i(3, 3), color), "%s cannot cross rocks" % id)
					board.set_rocks([])
				board.set_piece(target, null)
			expect(moves.size() == 12, "%s reaches 12 squares (%d)" % [id, moves.size()])
			expect(Vector2i(5, 4) not in moves, "%s has no knight offset" % id)

func _test_war_actions() -> void:
	for color: int in [W, B]:
		for captures: Array in [[false, false], [false, true], [true, false], [true, true]]:
			var enemy := GameRules.opposite(color)
			var board := _board({Vector2i(2, 2): ["war_king", color], Vector2i(0, 0): ["pawn", color], Vector2i(7, 7): ["king", enemy], Vector2i(6, 6): ["pawn", enemy]}, color)
			if captures[0]:
				board.set_piece(Vector2i(3, 3), _piece("pawn", enemy))
			if captures[1]:
				board.set_piece(Vector2i(4, 4), _piece("pawn", enemy))
			var processor := BattleCommandProcessor.new(board)
			processor.pending_bonus_color = color
			var first := processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(3, 3), color))
			expect(first.success and board.turn == color and board.actions_this_turn == 1, "War first action grants same-piece bonus %s" % str(captures))
			expect(not processor.execute(MoveAction.new(Vector2i(0, 0), Vector2i(0, 1), color)).success, "War bonus cannot transfer")
			var second := processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(4, 4), color))
			expect(second.success and board.turn == enemy and board.bonus_instance_id == 0, "War/relic cap is two actions %s" % str(captures))
			processor.execute(MoveAction.new(Vector2i(7, 7), Vector2i(7, 6), enemy))
			var next := processor.execute(MoveAction.new(Vector2i(4, 4), Vector2i(3, 3), color))
			expect(next.success and board.turn == color and processor.can_end_turn(color), "War always repeats bonus on later turn")
			expect(processor.execute(EndTurnAction.new(color)).success and board.turn == enemy, "War may forfeit second action")
	var shell := _board({Vector2i(2, 2): ["war_king", W], Vector2i(0, 0): ["pawn", W], Vector2i(3, 3): ["stone_giant", B], Vector2i(7, 7): ["king", B]})
	var processor := BattleCommandProcessor.new(shell)
	var hit := processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(3, 3), W))
	expect(hit.success and not hit.move_outcome.captured and shell.turn == W and shell.bonus_instance_id == shell.get_piece(Vector2i(2, 2)).instance_id, "War shell-only hit spends action but keeps permanent bonus")
	var second_shell := processor.execute(MoveAction.new(Vector2i(2, 2), Vector2i(3, 3), W))
	expect(second_shell.success and shell.turn == B and shell.get_piece(Vector2i(3, 3)).shell_left == 0, "War second shell-only action exhausts two-action budget")
	var stopped := _board({Vector2i(3, 3): ["war_king", W], Vector2i(0, 0): ["pawn", W], Vector2i(5, 3): ["gorgon", B], Vector2i(7, 7): ["king", B]})
	processor = BattleCommandProcessor.new(stopped)
	var no_followup := processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(4, 3), W))
	expect(no_followup.success and stopped.turn == B and stopped.bonus_instance_id == 0, "War without executable followup automatically passes turn")
	var ending := _board({Vector2i(3, 3): ["war_king", W], Vector2i(0, 0): ["pawn", W], Vector2i(3, 5): ["king", B], Vector2i(7, 5): ["rook", B]})
	processor = BattleCommandProcessor.new(ending)
	var ended := processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(3, 5), W))
	expect(ended.success and processor.status.is_finished() and ending.bonus_instance_id == 0, "War King capture ends battle without granting another action")

func _test_shadow_strike() -> void:
	for color: int in [W, B]:
		var enemy := GameRules.opposite(color)
		var board := _board({Vector2i(3, 3): ["shadow_king", color], Vector2i(3, 6): ["pawn", enemy], Vector2i(4, 4): ["pawn", color]}, color)
		board.set_rocks([Vector2i(3, 4)])
		var moves := board.get_executable_moves(Vector2i(3, 3))
		expect(Vector2i(3, 6) in moves and Vector2i(6, 6) in moves, "Shadow strikes and steps through rocks and allies")
		expect(Vector2i(6, 3) in moves and Vector2i(0, 0) in moves and Vector2i(5, 1) in moves, "Shadow reaches 3 squares along ranks, files and diagonals")
		expect(Vector2i(5, 4) not in moves and Vector2i(6, 5) not in moves and Vector2i(4, 5) not in moves, "Shadow never reaches off its eight lines")
		expect(Vector2i(7, 3) not in moves and Vector2i(7, 7) not in moves, "Shadow reaches no further than 3 squares")
		expect(Vector2i(4, 4) not in moves and Vector2i(3, 4) not in moves, "Shadow cannot target allies or rocks")
		var attacker := board.get_piece(Vector2i(3, 3))
		var result := BattleTestFixture.play(board, Vector2i(3, 3), Vector2i(3, 6))
		expect(result.success and result.captured and result.action_kind == "shadow_strike" and not result.ranged, "Shadow strike is melee, not remote shot")
		expect(board.get_piece(Vector2i(3, 3)) == attacker and board.get_piece(Vector2i(3, 6)) == null and result.landing == Vector2i(3, 3), "Shadow kills target and returns origin")
		board.turn = color
		var step := BattleTestFixture.play(board, Vector2i(3, 3), Vector2i(6, 6))
		expect(step.success and step.action_kind == "shadow_step" and board.get_piece(Vector2i(6, 6)) == attacker, "Shadow repeat step stops at empty target")
		expect(attacker.used_abilities.is_empty(), "Permanent Shadow actions do not spend once abilities")

func _test_shadow_safety() -> void:
	# Defended target is irrelevant after the living attacker has returned.
	var safe := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["pawn", B], Vector2i(7, 5): ["rook", B], Vector2i(7, 7): ["king", B]})
	expect(Vector2i(3, 5) in safe.get_executable_moves(Vector2i(3, 3)), "Shadow safe return may strike a defended target")
	# Removing a blocker opens a real attack on the origin.
	var exposed := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["pawn", B], Vector2i(3, 7): ["rook", B], Vector2i(7, 7): ["king", B]})
	expect(Vector2i(3, 5) not in exposed.get_executable_moves(Vector2i(3, 3)), "Shadow rejects strike exposing returned origin")
	expect(not BattleTestFixture.play(exposed.clone(), Vector2i(3, 3), Vector2i(3, 5)).success, "Unsafe Shadow command is rejected by authority")
	var removed := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["rook", B], Vector2i(7, 7): ["king", B]})
	expect(Vector2i(3, 5) in removed.get_executable_moves(Vector2i(3, 3)), "Killed checking target no longer threatens origin")
	var landing := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(6, 0): ["rook", B], Vector2i(7, 7): ["king", B], Vector2i(2, 0): ["rook", W]})
	expect(Vector2i(6, 3) not in landing.get_executable_moves(Vector2i(3, 3)), "Shadow empty step checks new square, not protected exchange")
	expect(Vector2i(4, 3) in landing.get_executable_moves(Vector2i(3, 3)), "Shadow still has safe empty steps")
	# A shell preserves the blocker, whereas its final death would expose origin.
	exposed.get_piece(Vector2i(3, 5)).shell_left = 1
	expect(Vector2i(3, 5) in exposed.get_executable_moves(Vector2i(3, 3)), "Shadow shell-only simulation preserves blocker")
	var shell := BattleTestFixture.play(exposed, Vector2i(3, 3), Vector2i(3, 5))
	expect(shell.success and not shell.captured and shell.landing == Vector2i(3, 3) and exposed.get_piece(Vector2i(3, 5)).shell_left == 0 and exposed.turn == B, "Shadow shell spends action and returns origin")
	# One-square targets must not bypass mandatory safety through the old King rule.
	var adjacent := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 4): ["pawn", B], Vector2i(3, 7): ["rook", B]})
	expect(Vector2i(3, 4) not in adjacent.get_executable_moves(Vector2i(3, 3)), "Adjacent Shadow strike has the same safety contract")
	var terminal := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["king", B], Vector2i(3, 7): ["rook", B], Vector2i(4, 5): ["pawn", B]})
	expect(Vector2i(3, 5) in terminal.get_executable_moves(Vector2i(3, 3)), "Shadow may kill guarded enemy King without invented terminal reply")
	var killed := BattleTestFixture.play(terminal, Vector2i(3, 3), Vector2i(3, 5))
	expect(killed.success and killed.king_captured and terminal.has_king(W) and not terminal.has_king(B), "Shadow enemy King capture is actual terminal capture")
	var mutual := _board({Vector2i(2, 2): ["shadow_king", W], Vector2i(5, 5): ["shadow_king", B]})
	for color: int in [W, B]:
		var origin: Vector2i = mutual.king_pos[color]
		var target: Vector2i = mutual.king_pos[GameRules.opposite(color)]
		expect(target in mutual.get_executable_moves_for_color(origin, color), "Mutual Shadow King capture terminates safely")
		expect(mutual.is_square_attacked(target, color), "Mutual Shadow attack map is bounded geometry")
		expect(Vector2i(2, 5) not in mutual.get_executable_moves_for_color(origin, color), "Mutual Shadow unsafe nonterminal step is rejected")
		var shielded_king := mutual.get_piece(origin)
		shielded_king.shell_left = 1
		expect(Vector2i(2, 5) in mutual.get_executable_moves_for_color(origin, color), "Geometric enemy Shadow strike breaking only a shell is not a lethal reply")
		shielded_king.shell_left = 0
	var normal := _board({Vector2i(2, 2): ["king", W], Vector2i(3, 3): ["king", B]})
	expect(normal.is_in_check(W) and normal.is_in_check(B), "Ordinary opposing King attack maps remain bounded")

func _test_shadow_previews() -> void:
	var board := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["ember_bird", B], Vector2i(7, 7): ["king", B]})
	var before := BattleRecord.snapshot_lines(board)
	var next_id := ChessPiece._next_instance_id
	for repeat: int in range(3):
		var moves := board.get_executable_moves(Vector2i(3, 3))
		expect(Vector2i(3, 5) in moves, "Shadow may strike a reviving target")
		var safety := board.evaluate_landing(Vector2i(3, 3), Vector2i(3, 5))
		expect(not safety.lethal and safety.landing == Vector2i(3, 3), "Shadow preview uses actual returned origin")
	expect(BattleRecord.snapshot_lines(board) == before, "Shadow previews are immutable including egg/turn state")
	var original := board.get_piece(Vector2i(3, 3))
	expect(original.used_abilities.is_empty() and not original.has_moved and board.growth.is_empty() and board.bonus_instance_id == 0 and board.get_piece(Vector2i(3, 5)).revives_left == 1, "Shadow previews preserve ability/moved/bonus/growth/revival state omitted by replay fingerprint")
	expect(ChessPiece._next_instance_id == next_id, "Shadow previews never allocate real IDs for simulated eggs")
	var terminal := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["king", B], Vector2i(3, 7): ["rook", B]})
	expect(not terminal.evaluate_landing(Vector2i(3, 3), Vector2i(3, 5)).lethal, "Terminal Shadow preview cannot invent a postgame rook reply")
	var promotion := _board({Vector2i(2, 0): ["shadow_king", W], Vector2i(2, 2): ["rook", B], Vector2i(1, 1): ["pawn", B]})
	next_id = ChessPiece._next_instance_id
	promotion.get_executable_moves(Vector2i(2, 0))
	expect(ChessPiece._next_instance_id == next_id, "Shadow threat previews never allocate real IDs for reply promotions")
	var corner := _board({Vector2i(7, 7): ["shadow_king", W], Vector2i(7, 5): ["ember_bird", B], Vector2i(0, 0): ["king", B]})
	var strike := BattleTestFixture.play(corner, Vector2i(7, 7), Vector2i(7, 5))
	var egg_square: Vector2i = strike.eggs_laid[0].get("position", Vector2i(-1, -1)) if not strike.eggs_laid.is_empty() else Vector2i(-1, -1)
	var egg := corner.get_piece(egg_square)
	expect(strike.success and egg != null and egg.def.is_egg and egg_square != Vector2i(7, 7), "Shadow return never silently overwrites a freshly laid egg at origin")

func _test_protection_and_death_regressions() -> void:
	var empty := _board({Vector2i(3, 3): ["shadow_king", W]})
	expect(empty.get_executable_moves(Vector2i(3, 3)).size() == 24, "Shadow center reaches all 24 squares of its eight 3-square lines")
	var shield := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["pawn", B]})
	shield.get_piece(Vector2i(3, 5)).shield_until_serial = 5
	expect(Vector2i(3, 5) not in shield.get_executable_moves(Vector2i(3, 3)), "Shadow still respects ordinary shields")
	shield.get_piece(Vector2i(3, 3)).frozen_until_serial = 5
	expect(shield.get_executable_moves(Vector2i(3, 3)).is_empty(), "Frozen Shadow cannot act")
	var immune := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 6): ["gargoyle", B], Vector2i(4, 3): ["pawn", B]})
	expect(RangedAttackRule.is_engaged(immune, Vector2i(3, 3), W), "Regression fixture actually has ranged engagement")
	expect(Vector2i(3, 6) in immune.get_executable_moves(Vector2i(3, 3)), "Shadow ignores ranged immunity and engagement restrictions")
	var gorgon := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(4, 4): ["gorgon", B]})
	expect(gorgon.get_executable_moves(Vector2i(3, 3)).is_empty(), "Gorgon still immobilizes Shadow")
	# Real royal explosion immunity is unchanged; the other explosion victims die.
	var blast := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["powder_keg", B], Vector2i(4, 5): ["pawn", W]})
	var killed := BattleTestFixture.play(blast, Vector2i(3, 3), Vector2i(3, 5))
	expect(killed.success and blast.get_piece(Vector2i(4, 5)) == null and blast.get_piece(Vector2i(3, 3)) != null, "Shadow strike resolves actual target death effects before royal return")
	# A nonroyal test instance proves the executor never resurrects a dead striker.
	var mortal := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(3, 5): ["powder_keg", B]})
	var attacker := mortal.get_piece(Vector2i(3, 3))
	attacker.def = attacker.def.duplicate()
	attacker.def.is_king = false
	mortal.king_pos.clear()
	expect(Vector2i(3, 5) not in mortal.get_executable_moves(Vector2i(3, 3)), "Mandatory safety rejects a lethal on-death effect")
	var death := mortal.simulate_move(Vector2i(3, 3), Vector2i(3, 5))
	expect(death.success and death.removed_instance(attacker.instance_id) and mortal.get_piece(Vector2i(3, 3)) == null and mortal.get_piece(Vector2i(3, 5)) == null, "Dead Shadow striker does not return or resurrect")
	# Last-stand and attack graphs are geometric; actual ordinary strikes still apply shells.
	var ordinary := _board({Vector2i(3, 3): ["sun_moon_monk", W]})
	expect(Vector2i(5, 4) not in ordinary.get_executable_moves(Vector2i(3, 3)) and Vector2i(6, 4) in ordinary.get_executable_moves(Vector2i(3, 3)), "Other teleport piece retains full same-color radius, not Shadow rays")

func _test_last_stand_regressions() -> void:
	var board := _board({Vector2i(0, 0): ["shield_king", W], Vector2i(0, 1): ["pawn", W], Vector2i(1, 1): ["pawn", W], Vector2i(7, 0): ["rook", B], Vector2i(7, 7): ["king", B], Vector2i(5, 6): ["pawn", B]})
	board.get_piece(Vector2i(7, 0)).shell_left = 2
	board.get_piece(Vector2i(7, 0)).shield_until_serial = 20
	expect(board.is_checkmate(W), "Expanded Shield range still genuinely mated in blocker fixture")
	var processor := BattleCommandProcessor.new(board)
	var events: Array[BattleEvent] = []
	processor._try_last_stand(events, 1)
	expect(events.size() == 1 and board.get_piece(Vector2i(7, 0)) == null and board.get_piece(Vector2i(5, 6)) != null, "Shield first mate removes only checkers bypassing shell/shield")
	board.set_piece(Vector2i(7, 0), _piece("rook", B))
	events.clear()
	processor._try_last_stand(events, 2)
	expect(events.is_empty() and board.get_piece(Vector2i(7, 0)) != null and board.is_checkmate(W), "Shield second mate cannot trigger last stand")
	var check := _board({Vector2i(3, 3): ["shield_king", W], Vector2i(3, 7): ["rook", B], Vector2i(7, 7): ["king", B]})
	processor = BattleCommandProcessor.new(check)
	events.clear()
	processor._try_last_stand(events, 3)
	expect(check.is_in_check(W) and not check.is_checkmate(W) and events.is_empty() and not check.get_piece(Vector2i(3, 3)).has_used(&"last_stand"), "Ordinary check does not spend Shield last stand")
	var royal := _board({Vector2i(0, 0): ["shield_king", W], Vector2i(0, 1): ["pawn", W], Vector2i(1, 1): ["pawn", W], Vector2i(2, 0): ["war_king", B], Vector2i(2, 1): ["knight", B]})
	royal.get_piece(Vector2i(2, 0)).shield_until_serial = 20
	processor = BattleCommandProcessor.new(royal)
	events.clear()
	expect(royal.is_checkmate(W), "King/knight fixture is genuinely mate after Shield range extension")
	processor._try_last_stand(events, 4)
	expect(events.size() == 1 and royal.has_king(B) and royal.get_piece(Vector2i(2, 1)) == null, "Shield removes checking non-King but never enemy King")

func _test_variant_replays() -> void:
	var war := _board({Vector2i(2, 2): ["war_king", W], Vector2i(0, 0): ["pawn", W], Vector2i(7, 7): ["king", B], Vector2i(7, 5): ["rook", B]})
	_check_replay("War", war, ["W c3-d4", "W d4-e5", "B h8-h7", "W e5-d4", "W end"])
	var shadow := _board({Vector2i(2, 2): ["shadow_king", W], Vector2i(0, 0): ["rook", W], Vector2i(7, 7): ["king", B], Vector2i(7, 5): ["rook", B], Vector2i(2, 5): ["pawn", B], Vector2i(5, 2): ["pawn", B]})
	_check_replay("Shadow", shadow, ["W c3xc6", "B h8-g8", "W c3xf3", "B g8-h8", "W c3-e5"])
	var shield := _board({Vector2i(0, 0): ["shield_king", W], Vector2i(0, 1): ["pawn", W], Vector2i(1, 1): ["pawn", W], Vector2i(4, 2): ["knight", W], Vector2i(7, 7): ["king", B], Vector2i(5, 6): ["pawn", B], Vector2i(7, 4): ["rook", B]})
	_check_replay("Shield", shield, ["W e3-f5", "B h8-g8", "W f5-e3", "B g8-h8", "W e3-f5", "B h5-h1"])

func _check_replay(label: String, setup: BoardState, lines: Array) -> void:
	var record := BattleRecord.from_setup(setup, [], W, 0)
	var built := record.build()
	var processor: BattleCommandProcessor = built.processor
	var snapshots: Array = []
	for line: String in lines:
		expect(record._apply(line, processor), "%s records real action %s" % [label, line])
		record.add_line(line, processor.board)
		snapshots.append(BattleRecord.snapshot_lines(processor.board))
	var decoded := BattleRecord.decode(record.encode(processor.board))
	var replay := decoded.replay()
	expect(replay.first_mismatch == -1 and replay.error.is_empty(), "%s replay verifies every action hash" % label)
	for prefix: int in range(1, lines.size() + 1):
		var intermediate := decoded.replay(prefix)
		expect(BattleRecord.snapshot_lines(intermediate.processor.board) == snapshots[prefix - 1], "%s immutable prefix snapshot %d matches" % [label, prefix])
	if label == "Shield":
		expect(processor.board.get_piece(Vector2i(0, 0)).has_used(&"last_stand") and processor.board.get_piece(Vector2i(7, 0)) == null, "Shield replay actually triggered first-checkmate last stand")
	if label == "Shadow":
		expect(processor.board.king_pos[W] == Vector2i(4, 4), "Shadow replay contains repeated return strikes then relocated empty step")

func _test_shadow_command_payload() -> void:
	var board := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(0, 0): ["pawn", W], Vector2i(3, 5): ["pawn", B], Vector2i(7, 5): ["rook", B], Vector2i(7, 7): ["king", B]})
	var processor := BattleCommandProcessor.new(board)
	var result := processor.execute(MoveAction.new(Vector2i(3, 3), Vector2i(3, 5), W))
	expect(result.success and board.turn == B and board.bonus_instance_id == 0, "Shadow strike consumes one normal action without permanent bonus")
	var moved: Dictionary = {}
	for event: BattleEvent in result.events:
		if event.event_type == BattleCommandProcessor.EVENT_PIECE_MOVED:
			moved = event.payload
	expect(moved.get("from") == Vector2i(3, 3) and moved.get("to") == Vector2i(3, 3) and moved.get("target") == Vector2i(3, 5) and moved.get("action_kind") == "shadow_strike" and not moved.get("ranged"), "Shadow event preserves origin/final/target for strike animation")
	print("SHADOW_STRIKE_MOVED_EVENT=", moved)
	var terminal := _board({Vector2i(3, 3): ["shadow_king", W], Vector2i(0, 0): ["pawn", W], Vector2i(3, 5): ["king", B], Vector2i(3, 7): ["rook", B], Vector2i(4, 5): ["pawn", B]})
	var chosen := EnemyMoveSelector.new().choose_action(terminal, W)
	expect(chosen != null and chosen.from == Vector2i(3, 3) and chosen.to == Vector2i(3, 5), "AI consumes authoritative Shadow capture candidates")
	processor = BattleCommandProcessor.new(terminal)
	var end := processor.execute(chosen)
	expect(end.success and processor.status.is_finished() and terminal.get_piece(Vector2i(3, 3)) != null, "Processor ends real enemy-King strike with Shadow returned")
	var mutual := _board({Vector2i(2, 2): ["shadow_king", W], Vector2i(5, 5): ["shadow_king", B], Vector2i(0, 1): ["pawn", W], Vector2i(1, 0): ["rook", W], Vector2i(6, 7): ["rook", B], Vector2i(7, 6): ["pawn", B]})
	var before := BattleRecord.snapshot_lines(mutual)
	var start := Time.get_ticks_usec()
	for iteration: int in range(20):
		for color: int in [W, B]:
			var from: Vector2i = mutual.king_pos[color]
			var moves := mutual.get_executable_moves_for_color(from, color)
			expect(not moves.is_empty(), "Repeated mutual Shadow query remains executable")
			MoveGenerator.get_attack_squares(mutual, from)
	print("SHADOW_MUTUAL_40_QUERIES_USEC=", Time.get_ticks_usec() - start)
	expect(BattleRecord.snapshot_lines(mutual) == before, "Repeated mutual Shadow queries do not mutate real state")

func _piece(id: String, color: int) -> ChessPiece:
	return ChessPiece.new(PieceDefDatabase.get_def(id), color)

func _board(specs: Dictionary, color: int = W) -> BoardState:
	var board := BoardState.new(8, false)
	for square: Vector2i in specs:
		var spec: Array = specs[square]
		board.place_piece_for_setup(square, _piece(spec[0], spec[1]))
	board.turn = color
	return board

func _test_shadow_enemy_turn_hatch_safety() -> void:
	# Reviewer fixture: the empty step lands on e5; the strike returns to e5.
	for strike: bool in [false, true]:
		var label := "return strike" if strike else "empty step"
		var origin := Vector2i(4, 4) if strike else Vector2i(3, 3)
		var target := Vector2i(4, 2) if strike else Vector2i(4, 4)
		var egg_square := Vector2i(7, 7)
		var board := _board({origin: ["shadow_king", W], Vector2i(0, 0): ["pawn", W], Vector2i(0, 7): ["king", B], Vector2i(0, 6): ["rook", B]})
		var egg := _piece("ember_egg", B)
		var bird := _piece("ember_bird", B)
		egg.hatch_piece = bird
		egg.hatch_serial = board.turn_serial + 1
		board.place_piece_for_setup(egg_square, egg)
		if strike:
			board.place_piece_for_setup(target, _piece("pawn", B))
		var before := BattleRecord.snapshot_lines(board)
		var next_id := ChessPiece._next_instance_id
		for repeat: int in range(3):
			expect(not board.is_shadow_action_safe(origin, target), "Shadow %s rejects enemy turn-start hatch capture" % label)
			expect(target not in board.get_executable_moves(origin), "Shadow %s excludes hatch-lethal candidate" % label)
		expect(BattleRecord.snapshot_lines(board) == before, "Shadow %s hatch preview preserves source board and turn" % label)
		expect(board.get_piece(egg_square) == egg and egg.hatch_piece == bird and egg.hatch_serial == board.turn_serial + 1 and not bird.has_moved and bird.revives_left == 1, "Shadow %s hatch preview preserves original egg and nested bird" % label)
		expect(not board.get_piece(origin).has_moved and board.growth.is_empty() and board.bonus_instance_id == 0 and ChessPiece._next_instance_id == next_id, "Shadow %s hatch preview preserves mover, growth, bonus and real IDs" % label)
		# A later hatch must not become an invented immediate threat.
		var delayed := board.clone()
		delayed.get_piece(egg_square).hatch_serial += 2
		expect(delayed.is_shadow_action_safe(origin, target) and target in delayed.get_executable_moves(origin), "Shadow %s remains safe before egg is due" % label)
		# Bypass only candidate validation to replay the forbidden action's actual
		# result, then use processor turn-start and terminal rules for the reply.
		var after := board.clone()
		var action := after.simulate_move(origin, target)
		expect(action.success and action.landing == Vector2i(4, 4), "Shadow %s fixture settles at real threatened landing" % label)
		var processor := BattleCommandProcessor.new(after)
		var events: Array[BattleEvent] = []
		processor._hand_over_turn(events, 1)
		expect(after.get_piece(egg_square).get_id() == "ember_bird" and not processor.status.is_finished(), "Shadow %s fixture hatches at enemy turn start without ending battle" % label)
		var reply := processor.execute(MoveAction.new(egg_square, Vector2i(4, 4), B))
		expect(reply.success and reply.move_outcome.king_captured and processor.status.is_finished(), "Shadow %s hatched bird really captures King and ends battle" % label)
		if strike:
			var terminal := board.clone()
			terminal.set_piece(Vector2i(0, 7), null)
			terminal.king_pos.erase(B)
			terminal.set_piece(target, null)
			expect(terminal.place_piece_for_setup(target, _piece("king", B)), "Shadow terminal hatch fixture places real enemy King")
			expect(terminal.is_shadow_action_safe(origin, target), "Shadow terminal King strike does not invent a hatch reply")
			var ending := BattleCommandProcessor.new(terminal)
			var killed := ending.execute(MoveAction.new(origin, target, W))
			expect(killed.success and killed.move_outcome.king_captured and ending.status.is_finished() and terminal.has_king(W), "Shadow King strike really ends battle despite due enemy egg")
			expect(not ending.execute(MoveAction.new(egg_square, origin, B)).success, "Shadow terminal strike has no postgame hatch capture")

extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("GameState").start_new_game()
	var battle: Node = (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame
	var view: BattleBoardView = battle.board_view
	var from: Vector2i = Vector2i(2, 2)
	var target: Vector2i = Vector2i(2, 5)
	var board: BoardState = BoardState.new(8, false)
	board.clear_for_setup()
	board.place_piece_for_setup(from, ChessPiece.new(Content.piece("shadow_king"), GameRules.PieceColor.WHITE))
	board.place_piece_for_setup(Vector2i(7, 7), ChessPiece.new(Content.piece("king"), GameRules.PieceColor.BLACK))
	board.place_piece_for_setup(Vector2i(6, 6), ChessPiece.new(Content.piece("knight"), GameRules.PieceColor.BLACK))
	view.refresh(board)
	var before: String = "\n".join(BattleRecord.snapshot_lines(board))
	view.present_events([
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": from, "to": from, "target": target, "piece_def_id": "shadow_king", "color": GameRules.PieceColor.WHITE, "action_kind": "shadow_strike"}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_CAPTURED, 2, 1, {"position": target, "piece_def_id": "pawn", "color": GameRules.PieceColor.BLACK}),
	] as Array[BattleEvent], 8.0)
	var director: StrikeDirector = view.get_node("StrikeDirector") as StrikeDirector
	_expect(director.is_playing() and director._a.is_equal_approx(director._dest), "shadow strike targets the victim but final position is its origin")
	var fading: StrikeDirector.Pose = director._compute_pose(1.23)
	_expect(fading.alpha < 0.4, "shadow strike fades out near the victim before returning, rather than sliding home")
	var returned: StrikeDirector.Pose = director._compute_pose(1.42)
	_expect(Vector2(returned.x, returned.z).distance_to(Vector2(director._a.x, director._a.z)) < 0.01 and returned.alpha > 0.5, "shadow strike reappears at its origin before presentation completes")
	var guard: int = 0
	while view.is_presenting() and guard < 800:
		await process_frame
		guard += 1
	_expect(not view.is_presenting() and view.standing_sprites().has(from) and not view.standing_sprites().has(target), "shadow strike cleans up with the attacker visible only at its real origin")
	_expect(before == "\n".join(BattleRecord.snapshot_lines(board)), "shadow presentation never mutates the authoritative board")
	battle.queue_free()
	print("[PASS] Variant King presentation" if not failed else "[FAIL] Variant King presentation")
	quit(1 if failed else 0)

func _expect(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
	else:
		print("[PASS] ", description)

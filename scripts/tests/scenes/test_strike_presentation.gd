extends SceneTree

## Every standard piece capturing every standard piece must play a strike animation
## that finishes, cleans up after itself and never touches authoritative state.

const PIECES: Array[String] = ["pawn", "knight", "bishop", "rook", "queen", "king"]

var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var slash: int = PieceDef.StrikeType.SLASH
	var blunt: int = PieceDef.StrikeType.BLUNT
	var pierce: int = PieceDef.StrikeType.PIERCE
	var crush: int = PieceDef.StrikeType.CRUSH
	var light: int = PieceDef.WeightClass.LIGHT
	var medium: int = PieceDef.WeightClass.MEDIUM
	var heavy: int = PieceDef.WeightClass.HEAVY
	_expect(StrikeDirector.reaction_for(slash, medium, light) == &"slash_shatter", "a slash shatters a light piece")
	_expect(StrikeDirector.reaction_for(slash, medium, medium) == &"slash_split", "a slash splits a medium piece along the cut")
	_expect(StrikeDirector.reaction_for(blunt, heavy, light) == &"blunt_fly", "a blunt hit sends a light piece flying")
	_expect(StrikeDirector.reaction_for(blunt, heavy, medium) == &"low_fly", "a heavier blunt attacker knocks a medium piece low and far")
	_expect(StrikeDirector.reaction_for(blunt, light, medium) == &"quick_tip", "a lighter blunt attacker topples a medium piece quickly")
	_expect(StrikeDirector.reaction_for(blunt, heavy, heavy) == &"blunt_crack", "an equal blunt hit cracks a heavy piece across the middle")
	_expect(StrikeDirector.reaction_for(blunt, light, heavy) == &"underdog", "a light blunt attacker needs two hits to topple a heavy piece")
	_expect(StrikeDirector.reaction_for(pierce, heavy, light) == &"pierce_knock", "a pierce carries a light piece away")
	_expect(StrikeDirector.reaction_for(pierce, heavy, heavy) == &"hole_heavy", "a pierce leaves a hole in a heavy piece")
	_expect(StrikeDirector.reaction_for(crush, medium, light) == &"crush_flat", "a crush flattens a light piece")
	_expect(StrikeDirector.reaction_for(crush, medium, medium) == &"crush_collapse", "a crush collapses a medium piece from the top")
	_expect(StrikeDirector.reaction_for(crush, medium, heavy) == &"crush_sink", "a crush sinks a heavy piece into the board")
	_expect(not StrikeDirector.can_play(&"gorgon", PieceDef.StrikeType.NONE), "special pieces keep the simple move presentation")

	var game_state := root.get_node("GameState")
	game_state.start_new_game()
	var battle := (load("res://scenes/battle/BattleScene.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	await process_frame
	var view := battle.get_node("Margin/Layout/BoardFrame") as BattleBoardView
	var layer := view.get_node("PieceLayer") as Node2D
	var authoritative: String = game_state.board.to_ascii()

	for attacker: String in PIECES:
		for victim: String in PIECES:
			var from := Vector2i(2, 2)
			var to := Vector2i(3, 4) if attacker == "knight" else Vector2i(3, 3)
			var events: Array[BattleEvent] = [
				BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": from, "to": to, "piece_def_id": attacker, "color": GameRules.PieceColor.WHITE}),
				BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_CAPTURED, 2, 1, {"position": to, "piece_def_id": victim, "color": GameRules.PieceColor.BLACK}),
			]
			view.present_events(events, 8.0)
			var started: bool = view.is_presenting() and layer.get_child_count() > 32
			var frames: int = 0
			while view.is_presenting() and frames < 600:
				frames += 1
				await process_frame
			await process_frame
			var clean: bool = not view.is_presenting() and layer.get_child_count() == 32
			_expect(started and clean, "%s capturing %s plays a strike and leaves only the standing pieces" % [attacker, victim])

	# En passant: the victim stands beside the pawn, not on the destination square.
	view.present_events([
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": Vector2i(2, 4), "to": Vector2i(3, 5), "piece_def_id": "pawn", "color": GameRules.PieceColor.WHITE}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_CAPTURED, 2, 1, {"position": Vector2i(3, 4), "piece_def_id": "pawn", "color": GameRules.PieceColor.BLACK}),
	] as Array[BattleEvent], 8.0)
	_expect(view.get_node("StrikeDirector").is_playing(), "en passant plays the pawn strike on the neighbouring square")
	await _settle(view)

	# Castling swaps the king with its partner, so two pieces travel.
	view.present_events([
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": Vector2i(4, 0), "to": Vector2i(7, 0), "piece_def_id": "king", "color": GameRules.PieceColor.WHITE}),
		BattleEvent.new(BattleCommandProcessor.EVENT_CASTLED, 2, 1, {"from": Vector2i(4, 0), "to": Vector2i(7, 0)}),
	] as Array[BattleEvent], 8.0)
	_expect(layer.get_child_count() == 34, "castling moves both the king and its partner")
	await _settle(view)
	_expect(layer.get_child_count() == 32, "castling presentation cleans up both travelling pieces")

	# Promotion and check play on the settled board and must not block the turn.
	view.present_events([
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": Vector2i(2, 2), "to": Vector2i(2, 3), "piece_def_id": "pawn", "color": GameRules.PieceColor.WHITE}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PROMOTED, 2, 1, {"position": Vector2i(0, 1), "piece_def_id": "queen", "color": GameRules.PieceColor.WHITE}),
		BattleEvent.new(BattleCommandProcessor.EVENT_CHECK_DECLARED, 3, 1, {"color": GameRules.PieceColor.BLACK, "checkmate": false}),
	] as Array[BattleEvent], 8.0)
	await _settle(view)
	_expect(not view.is_presenting() and layer.get_child_count() == 32, "promotion and check effects do not hold up the presentation")

	var settings := root.get_node("SettingsManager") as AppSettingsManager
	settings.set_short_battle_animations(true, false)
	var toggle := battle.get_node("SettingsOverlay/Center/Panel/Margin/Content/ShortAnimations") as CheckButton
	_expect(toggle != null, "battle settings offer a short animation switch")
	var strike_events: Array[BattleEvent] = [
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": Vector2i(2, 2), "to": Vector2i(3, 3), "piece_def_id": "king", "color": GameRules.PieceColor.WHITE}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_CAPTURED, 2, 1, {"position": Vector2i(3, 3), "piece_def_id": "pawn", "color": GameRules.PieceColor.BLACK}),
	]
	view.present_events(strike_events, 1.0)
	var short_frames: int = await _settle(view)
	settings.set_short_battle_animations(false, false)
	view.present_events(strike_events, 1.0)
	var full_frames: int = await _settle(view)
	_expect(short_frames < full_frames, "short battle animations finish sooner than full ones")

	view.present_events([
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_MOVED, 1, 1, {"from": Vector2i(2, 2), "to": Vector2i(3, 3), "piece_def_id": "queen", "color": GameRules.PieceColor.WHITE}),
		BattleEvent.new(BattleCommandProcessor.EVENT_PIECE_CAPTURED, 2, 1, {"position": Vector2i(3, 3), "piece_def_id": "rook", "color": GameRules.PieceColor.BLACK}),
	] as Array[BattleEvent], 1.0)
	await process_frame
	_expect(view.is_presenting(), "a strike is in progress before it is skipped")
	view.skip_presentations()
	await process_frame
	_expect(not view.is_presenting() and layer.get_child_count() == 32, "skipping a strike removes it at once")
	_expect(layer.transform == Transform2D.IDENTITY, "skipping a strike restores the board camera")
	_expect(game_state.board.to_ascii() == authoritative, "strike animations never mutate authoritative battle state")
	_finish()

func _settle(view: BattleBoardView) -> int:
	var frames: int = 0
	while view.is_presenting() and frames < 900:
		frames += 1
		await process_frame
	await process_frame
	return frames

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		_fail(message)

func _fail(message: String) -> void:
	failed = true
	push_error(message)

func _finish() -> void:
	print("[PASS] Strike presentation test" if not failed else "[FAIL] Strike presentation test")
	quit(1 if failed else 0)

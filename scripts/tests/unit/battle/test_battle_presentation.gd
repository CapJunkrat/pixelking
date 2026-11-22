extends SceneTree

var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var board: BoardState = BoardState.new()
	board.remove_all_pawns()
	var processor: BattleCommandProcessor = BattleCommandProcessor.new(board)
	var result: BattleCommandResult = processor.execute(MoveAction.new(Vector2i(1, 0), Vector2i(0, 2), GameRules.PieceColor.WHITE))
	var authoritative_state: String = board.to_ascii()

	var animator: BattleAnimationPlayer = BattleAnimationPlayer.new()
	animator.playback_speed = 8.0
	animator.event_delay_seconds = 0.0
	root.add_child(animator)
	animator.enqueue_events(result.events)
	await process_frame
	_expect(animator.presented_events.size() == result.events.size(), "animation player consumes every BattleEvent in order")
	_expect(board.to_ascii() == authoritative_state, "animation playback never mutates authoritative battle state")

	var log_scene: PackedScene = load("res://scenes/battle/BattleLogPanel.tscn") as PackedScene
	var log_panel: BattleLogPanel = log_scene.instantiate() as BattleLogPanel
	root.add_child(log_panel)
	await process_frame
	log_panel.consume(result.events)
	_expect(not log_panel.lines.is_empty(), "battle log derives readable lines from BattleEvents")
	_expect("knight" in log_panel.log_label.text.to_lower(), "battle log describes the moved piece")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("portal_mage")) == &"teleport", "teleport rules select the portal presentation")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("manticore")) == &"bent_ray", "bent-ray rules select a turning presentation")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("ember_bird")) == &"lob", "jumping slide rules select a lob presentation")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("gorgon")) == &"petrify", "immobilizing traits select a petrify presentation")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("assassin"), true) == &"chained_capture", "capture-action traits select a chained strike presentation")
	var strike_expectations: Dictionary = {
		"pawn": [PieceDef.StrikeType.BLUNT, PieceDef.WeightClass.LIGHT],
		"knight": [PieceDef.StrikeType.CRUSH, PieceDef.WeightClass.MEDIUM],
		"bishop": [PieceDef.StrikeType.SLASH, PieceDef.WeightClass.MEDIUM],
		"rook": [PieceDef.StrikeType.BLUNT, PieceDef.WeightClass.HEAVY],
		"queen": [PieceDef.StrikeType.PIERCE, PieceDef.WeightClass.HEAVY],
		"king": [PieceDef.StrikeType.CRUSH, PieceDef.WeightClass.HEAVY],
		"assassin": [PieceDef.StrikeType.SLASH, PieceDef.WeightClass.LIGHT],
		"bowman": [PieceDef.StrikeType.PIERCE, PieceDef.WeightClass.LIGHT],
		"catapult": [PieceDef.StrikeType.CRUSH, PieceDef.WeightClass.HEAVY],
		"lancer": [PieceDef.StrikeType.PIERCE, PieceDef.WeightClass.MEDIUM],
		"portal_mage": [PieceDef.StrikeType.VOID, PieceDef.WeightClass.MEDIUM],
		"royal_guard": [PieceDef.StrikeType.BLUNT, PieceDef.WeightClass.HEAVY],
		"centaur": [PieceDef.StrikeType.SLASH, PieceDef.WeightClass.MEDIUM],
		"unicorn_cavalry": [PieceDef.StrikeType.PIERCE, PieceDef.WeightClass.HEAVY],
		"gryphon": [PieceDef.StrikeType.GRAB, PieceDef.WeightClass.MEDIUM],
		"manticore": [PieceDef.StrikeType.VENOM, PieceDef.WeightClass.HEAVY],
		"archmage": [PieceDef.StrikeType.ARCANE, PieceDef.WeightClass.MEDIUM],
	}
	for piece_id: String in strike_expectations:
		var strike_def: PieceDef = PieceDefDatabase.get_def(piece_id)
		_expect(strike_def.strike_type == strike_expectations[piece_id][0] and strike_def.weight_class == strike_expectations[piece_id][1], "%s carries its strike type and weight class" % piece_id)
	_expect(PieceDefDatabase.get_def("gorgon").strike_type == PieceDef.StrikeType.VENOM, "the gorgon bites adjacent enemies with a venom strike")
	var portal_pattern: Dictionary = PieceRulePreview.pattern("portal_mage", 5)
	_expect(portal_pattern.get(Vector2i(2, 2)) == "move" and portal_pattern.get(Vector2i(1, 0)) == "both", "rule preview derives teleport and adjacent attacks from live MovementRules")
	var gorgon_pattern: Dictionary = PieceRulePreview.pattern("gorgon", 5)
	_expect(gorgon_pattern.get(Vector2i(1, 1)) == "both" and gorgon_pattern.get(Vector2i(2, 2)) == "move" and gorgon_pattern.get(Vector2i(0, 1)) == "attack" and not gorgon_pattern.has(Vector2i(0, 2)), "rule preview shows Gorgon's bite next to it and non-capturing diagonals beyond")
	animator.queue_free()
	log_panel.queue_free()
	print("[PASS] Battle presentation test" if not failed else "[FAIL] Battle presentation test")
	quit(1 if failed else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] ", message)
	else:
		failed = true
		push_error(message)

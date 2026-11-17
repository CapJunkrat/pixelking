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
	_expect("knight" in log_panel.log_label.text, "battle log describes the moved piece")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("portal_mage")) == &"teleport", "teleport rules select the portal presentation")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("manticore")) == &"bent_ray", "bent-ray rules select a turning presentation")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("catapult")) == &"lob", "jumping slide rules select a lob presentation")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("gorgon")) == &"petrify", "immobilizing traits select a petrify presentation")
	_expect(BattleBoardView.presentation_kind_for(PieceDefDatabase.get_def("assassin"), true) == &"chained_capture", "capture-action traits select a chained strike presentation")
	var portal_pattern: Dictionary = PieceRulePreview.pattern("portal_mage", 5)
	_expect(portal_pattern.get(Vector2i(2, 2)) == "move" and portal_pattern.get(Vector2i(1, 0)) == "both", "rule preview derives teleport and adjacent attacks from live MovementRules")
	var gorgon_pattern: Dictionary = PieceRulePreview.pattern("gorgon", 5)
	_expect("attack" not in gorgon_pattern.values() and "both" not in gorgon_pattern.values(), "rule preview shows Gorgon's non-capturing rays")
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

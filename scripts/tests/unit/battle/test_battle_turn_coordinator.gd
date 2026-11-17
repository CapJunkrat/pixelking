class_name TestBattleTurnCoordinator
extends SceneTreeTestCase

class FakeGameState:
	extends Node
	var board: BoardState = BattleTestFixture.standard_board()
	var player_color: int = GameRules.PieceColor.WHITE
	var finished: bool = false
	var move_attempts: int = 0
	var terminal_evaluations: int = 0

	func is_battle_finished() -> bool:
		return finished

	func evaluate_battle_terminal_state() -> bool:
		terminal_evaluations += 1
		return finished

	func try_move(_from: Vector2i, _to: Vector2i, _promotion_id: StringName = &"") -> bool:
		move_attempts += 1
		return true

var settings_open: bool = false
var clear_count: int = 0
var input_states: Array[bool] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_state: FakeGameState = FakeGameState.new()
	root.add_child(game_state)
	var coordinator: BattleTurnCoordinator = BattleTurnCoordinator.new()
	root.add_child(coordinator)
	coordinator.enemy_delay_seconds = 0.02
	coordinator.configure(game_state, Callable(self, "_settings_open"), Callable(self, "_clear_selection"))
	coordinator.input_enabled_changed.connect(_capture_input)
	coordinator.start()
	expect(coordinator.state == BattleTurnCoordinator.State.PLAYER_TURN, "player turn starts with player input authority")
	expect(input_states == [true], "player turn enables input once")

	game_state.board.turn = GameRules.PieceColor.BLACK
	var empty_events: Array[BattleEvent] = []
	coordinator.begin_presentation(empty_events)
	coordinator.begin_presentation(empty_events)
	expect(coordinator.state == BattleTurnCoordinator.State.PRESENTING and input_states.back() == false, "consecutive event batches keep input locked")
	settings_open = true
	coordinator.complete_presentation()
	coordinator.complete_presentation()
	await create_timer(0.03).timeout
	expect(game_state.move_attempts == 0, "open settings postpone every scheduled enemy action")
	settings_open = false
	await create_timer(0.04).timeout
	expect(game_state.move_attempts == 1, "closing settings resumes exactly one enemy action")
	expect(clear_count == 1, "enemy action clears selection exactly once")

	var cancelled_state: FakeGameState = FakeGameState.new()
	cancelled_state.board.turn = GameRules.PieceColor.BLACK
	root.add_child(cancelled_state)
	var cancelled: BattleTurnCoordinator = BattleTurnCoordinator.new()
	root.add_child(cancelled)
	cancelled.enemy_delay_seconds = 0.02
	cancelled.configure(cancelled_state, Callable(), Callable())
	cancelled.start()
	cancelled.finish()
	await create_timer(0.03).timeout
	expect(cancelled_state.move_attempts == 0, "finish invalidates a pending enemy timer")

	var terminal_state: FakeGameState = FakeGameState.new()
	terminal_state.finished = true
	root.add_child(terminal_state)
	var terminal: BattleTurnCoordinator = BattleTurnCoordinator.new()
	root.add_child(terminal)
	terminal.configure(terminal_state, Callable(), Callable())
	terminal.start()
	expect(terminal.is_finished(), "terminal battle never unlocks input or schedules AI")

	coordinator.queue_free()
	cancelled.queue_free()
	terminal.queue_free()
	game_state.queue_free()
	cancelled_state.queue_free()
	terminal_state.queue_free()
	finish_test("BattleTurnCoordinator test")

func _settings_open() -> bool:
	return settings_open

func _clear_selection() -> void:
	clear_count += 1

func _capture_input(enabled: bool) -> void:
	input_states.append(enabled)

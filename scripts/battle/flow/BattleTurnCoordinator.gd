class_name BattleTurnCoordinator
extends Node

enum State { BOOTING, PRESENTING, PLAYER_TURN, ENEMY_TURN, FINISHED }

signal input_enabled_changed(enabled: bool)

var state: State = State.BOOTING
var enemy_selector: EnemyMoveSelector = EnemyMoveSelector.new()
var enemy_delay_seconds: float = 0.45
var game_state: Node = null
var settings_open_query: Callable = Callable()
var clear_selection_command: Callable = Callable()
var _enemy_generation: int = 0
## The Hard search running on a worker thread, if any.
var _search: EnemySearch = null
var _search_task: int = -1
var _search_result: Dictionary = {}

func configure(p_game_state: Node, p_settings_open_query: Callable, p_clear_selection_command: Callable) -> void:
	game_state = p_game_state
	settings_open_query = p_settings_open_query
	clear_selection_command = p_clear_selection_command

func start() -> void:
	_advance()

func begin_presentation(_events: Array[BattleEvent]) -> void:
	if state == State.FINISHED:
		return
	state = State.PRESENTING
	_enemy_generation += 1
	input_enabled_changed.emit(false)

func complete_presentation() -> void:
	if state == State.FINISHED:
		return
	_advance()

func finish() -> void:
	state = State.FINISHED
	_enemy_generation += 1
	_cancel_search()
	input_enabled_changed.emit(false)

func _exit_tree() -> void:
	_cancel_search()

## Stops a running Hard search and waits for its thread, so nothing outlives the battle.
func _cancel_search() -> void:
	if _search != null:
		_search.cancelled = true
	if _search_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_search_task)
		_search_task = -1
	_search = null

func is_finished() -> bool:
	return state == State.FINISHED

func _advance() -> void:
	var board: BoardState = game_state.get("board") as BoardState if game_state != null else null
	if board == null or bool(game_state.call("is_battle_finished")):
		finish()
		return
	if bool(game_state.call("evaluate_battle_terminal_state")):
		return
	if board.turn == int(game_state.get("player_color")):
		state = State.PLAYER_TURN
		input_enabled_changed.emit(true)
		return
	state = State.ENEMY_TURN
	input_enabled_changed.emit(false)
	_enemy_generation += 1
	_play_enemy_turn(_enemy_generation)

func _play_enemy_turn(generation: int) -> void:
	await get_tree().create_timer(enemy_delay_seconds).timeout
	var board: BoardState = game_state.get("board") as BoardState if game_state != null else null
	if state != State.ENEMY_TURN or generation != _enemy_generation or board == null:
		return
	if settings_open_query.is_valid() and bool(settings_open_query.call()):
		_enemy_generation += 1
		_play_enemy_turn(_enemy_generation)
		return
	enemy_selector.difficulty = str(game_state.get("ai_difficulty")) if game_state.get("ai_difficulty") != null else EnemyMoveSelector.DIFFICULTY_EASY
	var action: MoveAction = null
	if enemy_selector.difficulty == EnemyMoveSelector.DIFFICULTY_HARD and not OS.has_feature("web"):
		action = await _search_in_background(board, generation)
		if state != State.ENEMY_TURN or generation != _enemy_generation:
			return
		# The settings may have opened while the enemy was thinking: wait for them.
		while settings_open_query.is_valid() and bool(settings_open_query.call()):
			await get_tree().process_frame
			if state != State.ENEMY_TURN or generation != _enemy_generation:
				return
	else:
		action = enemy_selector.choose_action(board, board.turn)
	if action == null:
		game_state.call("evaluate_battle_terminal_state")
		return
	if clear_selection_command.is_valid():
		clear_selection_command.call()
	if not bool(game_state.call("try_move", action.from, action.to, action.promotion_id)):
		_advance()

## Runs the Hard search on a worker thread so the screen keeps moving while the enemy
## thinks (up to EnemySearch's time budget). The moves the enemy may make are worked
## out here, on the main thread; the thread only reads its own copy of the board.
func _search_in_background(board: BoardState, generation: int) -> MoveAction:
	var color: int = board.turn
	var moves: Array = EnemySearch.root_moves(board, color)
	if moves.is_empty():
		return null
	var copy: BoardState = board.clone()
	var search: EnemySearch = EnemySearch.new()
	search.time_budget_ms = enemy_selector.hard_budget_ms
	_search = search
	_search_result = {}
	_search_task = WorkerThreadPool.add_task(func() -> void: _search_result = search.search(copy, color, moves))
	while not WorkerThreadPool.is_task_completed(_search_task):
		await get_tree().process_frame
		if generation != _enemy_generation:
			_cancel_search()
			return null
	WorkerThreadPool.wait_for_task_completion(_search_task)
	_search_task = -1
	_search = null
	if _search_result.is_empty():
		return null
	return MoveAction.new(_search_result["from"], _search_result["to"], color)

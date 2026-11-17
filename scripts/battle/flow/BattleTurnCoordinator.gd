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
	input_enabled_changed.emit(false)

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
	var action: MoveAction = enemy_selector.choose_action(board, board.turn)
	if action == null:
		game_state.call("evaluate_battle_terminal_state")
		return
	if clear_selection_command.is_valid():
		clear_selection_command.call()
	if not bool(game_state.call("try_move", action.from, action.to, action.promotion_id)):
		_advance()

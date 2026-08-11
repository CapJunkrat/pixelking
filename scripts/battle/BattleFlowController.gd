extends Node
class_name BattleFlowController

enum Phase { PLAYER_TURN, ENEMY_TURN, FINISHED }

var phase := Phase.PLAYER_TURN
var enemy_selector := EnemyMoveSelector.new()
var enemy_pending := false
var result_panel: BattleResultPanel
var result_overlay: ColorRect
var result_title: Label
var result_detail: Label
var retry_button: Button
var exit_button: Button
var battle: Control

func _ready() -> void:
	battle = get_parent() as Control
	call_deferred("_finish_ready")

func _finish_ready() -> void:
	_bind_result_panel()
	GameState.battle_events_emitted.connect(_on_battle_events_emitted)
	call_deferred("_advance_flow")

func _exit_tree() -> void:
	if GameState.battle_events_emitted.is_connected(_on_battle_events_emitted):
		GameState.battle_events_emitted.disconnect(_on_battle_events_emitted)

func _on_battle_events_emitted(events: Array[BattleEvent]) -> void:
	for event: BattleEvent in events:
		if event.event_type != BattleCommandProcessor.EVENT_BATTLE_ENDED:
			continue
		var data: Dictionary = event.payload
		var draw: bool = bool(data.get("draw", false))
		var winner: int = int(data.get("winner", -1))
		_show_result.call_deferred(winner == GameState.player_color, draw)
		return
	call_deferred("_advance_flow")

func _advance_flow() -> void:
	var board := GameState.board
	if board == null or phase == Phase.FINISHED:
		return
	if board.is_checkmate(board.turn):
		_show_result(board.turn != GameState.player_color, false)
		return
	if board.has_only_king(GameRules.PieceColor.WHITE) and board.has_only_king(GameRules.PieceColor.BLACK):
		_show_result(false, true)
		return
	var lone_king_loser: int = board.get_lone_king_loser()
	if lone_king_loser >= 0:
		_show_result(lone_king_loser != GameState.player_color, false)
		return
	if board.is_stalemate(board.turn):
		_show_result(false, true)
		return
	phase = Phase.PLAYER_TURN if board.turn == GameState.player_color else Phase.ENEMY_TURN
	if phase == Phase.ENEMY_TURN and not enemy_pending:
		enemy_pending = true
		_play_enemy_turn.call_deferred()

func _play_enemy_turn() -> void:
	await get_tree().create_timer(0.45).timeout
	if phase != Phase.ENEMY_TURN or GameState.board == null:
		enemy_pending = false
		return
	if bool(battle.call("is_settings_open")):
		enemy_pending = false
		_advance_flow.call_deferred()
		return
	var move := enemy_selector.choose_move(GameState.board, GameState.board.turn)
	enemy_pending = false
	if move.is_empty():
		_advance_flow()
		return
	GameState.try_move(move["from"], move["to"])
	battle.call("clear_board_selection")
	battle.call("_refresh_board")
func _bind_result_panel() -> void:
	result_panel = battle.get_node("ResultOverlay") as BattleResultPanel
	result_overlay = result_panel
	result_title = result_panel.title_label
	result_detail = result_panel.detail_label
	retry_button = result_panel.retry_button
	exit_button = result_panel.exit_button
	retry_button.text = Localization.text("BATTLE_RETRY")
	exit_button.text = Localization.text("BATTLE_RESULT_MAIN_MENU")
	result_panel.retry_requested.connect(_restart)
	result_panel.exit_requested.connect(_return_after_result)

func _show_result(player_won: bool, draw: bool) -> void:
	phase = Phase.FINISHED
	if draw:
		result_title.text = Localization.text("BATTLE_DRAW")
		result_detail.text = Localization.text("BATTLE_DRAW_DETAIL")
	elif player_won:
		result_title.text = Localization.text("BATTLE_VICTORY")
		result_detail.text = Localization.text("BATTLE_VICTORY_DETAIL")
	else:
		result_title.text = Localization.text("BATTLE_DEFEAT")
		result_detail.text = Localization.text("BATTLE_DEFEAT_DETAIL")
	_integrate_run_result(player_won and not draw)
	result_panel.present(result_title.text, result_detail.text)

func _integrate_run_result(player_won: bool) -> void:
	var manager: AppRunManager = get_node_or_null("/root/RunManager") as AppRunManager
	if manager == null or manager.current_run == null:
		retry_button.show()
		exit_button.text = Localization.text("BATTLE_RESULT_MAIN_MENU")
		return
	var current: MapNodeState = manager.current_map_node()
	var definition: MapNodeDef = MapNodeDefDatabase.get_def(current.node_type_id) if current != null else null
	if definition == null or not definition.is_battle:
		retry_button.show()
		exit_button.text = Localization.text("BATTLE_RESULT_MAIN_MENU")
		return
	if player_won:
		var error: Error = manager.resolve_current_battle_node({"outcome": "prototype_victory"})
		if error == OK:
			retry_button.hide()
			exit_button.text = Localization.text("BATTLE_RESULT_MAP")
	else:
		exit_button.text = Localization.text("BATTLE_RESULT_DEPLOYMENT")

func _return_after_result() -> void:
	GameState.start_new_game()
	var manager: AppRunManager = get_node_or_null("/root/RunManager") as AppRunManager
	if manager != null and manager.current_run != null:
		get_tree().change_scene_to_file(manager.resume_scene_path())
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _restart() -> void:
	var manager: AppRunManager = get_node_or_null("/root/RunManager") as AppRunManager
	if manager != null and manager.current_run != null and manager.current_run.deployment_state != null:
		GameState.start_run_battle(manager.current_run)
	else:
		GameState.start_new_game()
	get_tree().reload_current_scene()

func _return_to_menu() -> void:
	GameState.start_new_game()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

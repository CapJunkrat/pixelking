class_name BattleFlowController
extends Node

## Thin scene coordinator. Turn scheduling, Run integration, and result rendering
## are delegated to focused collaborators under scripts/battle/flow.
enum Phase { PLAYER_TURN, ENEMY_TURN, PRESENTING, FINISHED }

var phase: Phase = Phase.PLAYER_TURN
var result_panel: BattleResultPanel = null
var result_overlay: ColorRect = null
var result_title: Label = null
var result_detail: Label = null
var retry_button: Button = null
var exit_button: Button = null
var battle: Node = null
var game_state: Node = null
var turn_coordinator: BattleTurnCoordinator = null
var run_result_coordinator: BattleRunResultCoordinator = BattleRunResultCoordinator.new()
var result_presenter: BattleResultPresenter = BattleResultPresenter.new()
var _pending_terminal: Dictionary = {}
var _result_presented: bool = false

func _ready() -> void:
	battle = get_parent()
	game_state = get_node("/root/GameState")
	call_deferred("_finish_ready")

func _finish_ready() -> void:
	_bind_result_panel()
	turn_coordinator = BattleTurnCoordinator.new()
	add_child(turn_coordinator)
	turn_coordinator.configure(game_state, Callable(battle, "is_settings_open"), Callable(battle, "clear_board_selection"))
	turn_coordinator.input_enabled_changed.connect(Callable(battle, "set_battle_input_enabled"))
	battle.connect("presentation_started", turn_coordinator.begin_presentation)
	battle.connect("presentation_completed", _on_presentation_completed)
	game_state.connect("battle_events_emitted", _on_battle_events_emitted)
	turn_coordinator.start()
	_sync_phase()

func _exit_tree() -> void:
	if game_state != null and game_state.is_connected("battle_events_emitted", _on_battle_events_emitted):
		game_state.disconnect("battle_events_emitted", _on_battle_events_emitted)

func _on_battle_events_emitted(events: Array[BattleEvent]) -> void:
	for event: BattleEvent in events:
		if event.event_type != BattleCommandProcessor.EVENT_BATTLE_ENDED:
			continue
		var data: Dictionary = event.payload
		_pending_terminal = {
			"player_won": int(data.get("winner", -1)) == int(game_state.get("player_color")),
			"draw": bool(data.get("draw", false)),
		}
		phase = Phase.FINISHED
		turn_coordinator.finish()
		return
	phase = Phase.PRESENTING

func _on_presentation_completed() -> void:
	if not _pending_terminal.is_empty():
		_show_result(bool(_pending_terminal.get("player_won", false)), bool(_pending_terminal.get("draw", false)))
		_pending_terminal.clear()
		return
	turn_coordinator.complete_presentation()
	_sync_phase()

func force_debug_victory() -> void:
	if not bool(game_state.get("debug_mode")) or phase == Phase.FINISHED:
		return
	game_state.call("force_debug_victory")

func _show_result(player_won: bool, draw: bool) -> void:
	if _result_presented:
		return
	_result_presented = true
	phase = Phase.FINISHED
	turn_coordinator.finish()
	var manager: AppRunManager = get_node_or_null("/root/RunManager") as AppRunManager
	var run_result: BattleRunResult = run_result_coordinator.integrate(manager, player_won and not draw)
	result_presenter.present(player_won, draw, run_result)

func _bind_result_panel() -> void:
	result_panel = battle.get_node("ResultOverlay") as BattleResultPanel
	result_overlay = result_panel
	result_presenter.bind(result_panel, get_node("/root/Localization"))
	result_title = result_presenter.title_label
	result_detail = result_presenter.detail_label
	retry_button = result_presenter.retry_button
	exit_button = result_presenter.exit_button
	result_panel.retry_requested.connect(_restart)
	result_panel.exit_requested.connect(_return_after_result)

func _sync_phase() -> void:
	if turn_coordinator == null:
		return
	match turn_coordinator.state:
		BattleTurnCoordinator.State.PLAYER_TURN:
			phase = Phase.PLAYER_TURN
		BattleTurnCoordinator.State.ENEMY_TURN:
			phase = Phase.ENEMY_TURN
		BattleTurnCoordinator.State.FINISHED:
			phase = Phase.FINISHED
		_:
			phase = Phase.PRESENTING

func _return_after_result() -> void:
	game_state.call("start_new_game")
	var manager: AppRunManager = get_node_or_null("/root/RunManager") as AppRunManager
	if manager != null and manager.current_run != null:
		get_tree().change_scene_to_file(manager.resume_scene_path())
	else:
		get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)

func _restart() -> void:
	var manager: AppRunManager = get_node_or_null("/root/RunManager") as AppRunManager
	if manager != null and manager.current_run != null and manager.current_run.deployment_state != null:
		game_state.call("start_run_battle", manager.current_run)
	else:
		game_state.call("start_new_game")
	get_tree().reload_current_scene()

func _return_to_menu() -> void:
	game_state.call("start_new_game")
	get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)

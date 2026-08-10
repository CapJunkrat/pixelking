extends Node
class_name BattleFlowController

enum Phase { PLAYER_TURN, ENEMY_TURN, FINISHED }

var phase := Phase.PLAYER_TURN
var enemy_selector := EnemyMoveSelector.new()
var enemy_pending := false
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
	_build_result_overlay()
	EventBus.move_made.connect(_on_move_made)
	call_deferred("_advance_flow")

func _exit_tree() -> void:
	if EventBus.move_made.is_connected(_on_move_made):
		EventBus.move_made.disconnect(_on_move_made)

func _on_move_made(_from: Vector2i, _to: Vector2i, _result: Dictionary) -> void:
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

func _build_result_overlay() -> void:
	result_overlay = ColorRect.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.color = Color(0.01, 0.025, 0.06, 0.88)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.hide()
	battle.add_child(result_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(292, 236)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b1625")
	style.border_color = Color("#f0d8a2")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 28)
	result_title.add_theme_color_override("font_color", Color("#f0d8a2"))
	content.add_child(result_title)
	result_detail = Label.new()
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(result_detail)
	retry_button = Button.new()
	retry_button.name = "RetryButton"
	retry_button.text = Localization.text("BATTLE_RETRY")
	retry_button.custom_minimum_size = Vector2(0, 44)
	retry_button.pressed.connect(_restart)
	content.add_child(retry_button)
	exit_button = Button.new()
	exit_button.name = "ExitButton"
	exit_button.text = Localization.text("BATTLE_RESULT_MAIN_MENU")
	exit_button.custom_minimum_size = Vector2(0, 44)
	exit_button.pressed.connect(_return_after_result)
	content.add_child(exit_button)

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
	result_overlay.show()

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

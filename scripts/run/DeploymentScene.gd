class_name DeploymentScene
extends Control

@onready var board_view: DeploymentBoardView = $SafeArea/Layout/BoardFrame as DeploymentBoardView
@onready var active_tray: HBoxContainer = $SafeArea/Layout/ActiveTray
@onready var status_label: Label = $SafeArea/Layout/StatusLabel
@onready var confirm_button: Button = $SafeArea/Layout/Actions/ConfirmButton
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var selected_instance_id: int = 0
var _dropped_square: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	$SafeArea/Layout/Actions/RosterButton.pressed.connect(_open_roster)
	$SafeArea/Layout/Actions/MapButton.pressed.connect(_return_to_map)
	confirm_button.pressed.connect(_confirm_deployment)
	board_view.square_pressed.connect(_on_square_pressed)
	_apply_locale()
	if run_manager.current_run == null:
		status_label.text = _text("DEPLOY_NO_ACTIVE_RUN")
		confirm_button.disabled = true
		return
	var error: Error = run_manager.begin_deployment()
	if error != OK:
		status_label.text = _text("DEPLOY_INVALID_NODE")
		confirm_button.disabled = true
		return
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_map()

func _render() -> void:
	_render_board()
	_render_tray()
	var current: MapNodeState = run_manager.current_map_node()
	var definition: MapNodeDef = MapNodeDefDatabase.get_def(current.node_type_id) if current != null else null
	$SafeArea/Layout/Header/EncounterLabel.text = _text("DEPLOY_ENCOUNTER") % _text(String(definition.display_name_key)) if definition != null else ""
	status_label.text = _text("DEPLOY_SELECTED") % _piece_name(selected_instance_id) if selected_instance_id > 0 else _text("DEPLOY_INSTRUCTION")
	confirm_button.disabled = run_manager.current_run.deployment_state == null or not run_manager.current_run.deployment_state.is_valid(run_manager.current_run)

func _render_board() -> void:
	var deployment: DeploymentState = run_manager.current_run.deployment_state
	var pieces: Dictionary = {}
	var selected_square: Vector2i = Vector2i(-1, -1)
	for y_position: int in range(deployment.board_size):
		for x_position: int in range(deployment.board_size):
			var board_position: Vector2i = Vector2i(x_position, y_position)
			var texture: Texture2D = _texture_at(board_position)
			if texture == null:
				continue
			var player_id: int = deployment.player_at(board_position)
			pieces[board_position] = {"texture": texture, "player": player_id > 0}
			if player_id > 0 and player_id == selected_instance_id:
				selected_square = board_position
	board_view.show_position(deployment.board_size, pieces, selected_square, _dropped_square)
	_dropped_square = Vector2i(-1, -1)

func _render_tray() -> void:
	for child: Node in active_tray.get_children():
		active_tray.remove_child(child)
		child.queue_free()
	for instance_id: int in run_manager.current_run.active_piece_ids:
		var piece: PieceInstanceState = run_manager.current_run.get_piece_state(instance_id)
		var button: Button = Button.new()
		button.name = "Piece_%d" % instance_id
		button.custom_minimum_size = Vector2(46, 46)
		button.set_meta("instance_id", instance_id)
		button.icon = piece_skin_manager.call("piece_texture", &"white", piece.piece_def_id) as Texture2D
		button.expand_icon = true
		button.tooltip_text = _piece_name(instance_id)
		button.toggle_mode = true
		button.button_pressed = instance_id == selected_instance_id
		button.pressed.connect(_select_piece.bind(instance_id))
		active_tray.add_child(button)

func _on_square_pressed(board_position: Vector2i) -> void:
	var deployment: DeploymentState = run_manager.current_run.deployment_state
	var player_id: int = deployment.player_at(board_position)
	if player_id > 0:
		if selected_instance_id <= 0 or selected_instance_id == player_id:
			_select_piece(player_id)
			return
		var swap_error: Error = run_manager.move_deployed_piece(selected_instance_id, board_position)
		if swap_error != OK:
			status_label.text = _text("DEPLOY_PLAYER_ROWS_ONLY")
			return
		selected_instance_id = 0
		_dropped_square = board_position
		_render()
		return
	if selected_instance_id <= 0:
		status_label.text = _text("DEPLOY_SELECT_FIRST")
		return
	var error: Error = run_manager.move_deployed_piece(selected_instance_id, board_position)
	if error != OK:
		status_label.text = _text("DEPLOY_PLAYER_ROWS_ONLY")
		return
	selected_instance_id = 0
	_dropped_square = board_position
	_render()

func _select_piece(instance_id: int) -> void:
	selected_instance_id = instance_id
	_render()

func _texture_at(board_position: Vector2i) -> Texture2D:
	var deployment: DeploymentState = run_manager.current_run.deployment_state
	var player_id: int = deployment.player_at(board_position)
	if player_id > 0:
		var piece: PieceInstanceState = run_manager.current_run.get_piece_state(player_id)
		return piece_skin_manager.call("piece_texture", &"white", piece.piece_def_id) as Texture2D
	for placement: Dictionary in deployment.enemy_placements:
		if DeploymentState.position_from_value(placement.get("position", {})) == board_position:
			return piece_skin_manager.call("piece_texture", &"black", StringName(str(placement.get("piece_def_id", "")))) as Texture2D
	return null

func _piece_name(instance_id: int) -> String:
	var piece: PieceInstanceState = run_manager.current_run.get_piece_state(instance_id) if run_manager.current_run != null else null
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id)) if piece != null else null
	return _text(String(definition.display_name_key)) if definition != null else "?"

func _confirm_deployment() -> void:
	var error: Error = run_manager.confirm_deployment()
	if error != OK:
		status_label.text = _text("DEPLOY_CONFIRM_ERROR")
		return
	if run_manager.start_current_battle() != OK:
		status_label.text = _text("DEPLOY_CONFIRM_ERROR")
		return
	get_tree().change_scene_to_file(AppSceneRoutes.BATTLE)

func _open_roster() -> void:
	get_tree().change_scene_to_file(AppSceneRoutes.ROSTER)

func _return_to_map() -> void:
	get_tree().change_scene_to_file(AppSceneRoutes.PATH_MAP)

func _apply_locale() -> void:
	$SafeArea/Layout/Header/Title.text = _text("DEPLOY_TITLE")
	$SafeArea/Layout/Header/Subtitle.text = _text("DEPLOY_SUBTITLE")
	$SafeArea/Layout/Actions/RosterButton.text = _text("ROSTER_MANAGE")
	$SafeArea/Layout/Actions/MapButton.text = _text("DEPLOY_MAP")
	confirm_button.text = _text("DEPLOY_CONFIRM")

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

class_name DeploymentScene
extends Control

const CELL_SIZE := 58.0
const PLAYER_LIGHT := Color("#d9c58f")
const PLAYER_DARK := Color("#a99062")
const BOARD_LIGHT := Color("#8ba0a5")
const BOARD_DARK := Color("#526b72")

@onready var board_grid: GridContainer = $SafeArea/Layout/BoardFrame/BoardCenter/BoardGrid
@onready var active_tray: HBoxContainer = $SafeArea/Layout/ActiveTray
@onready var status_label: Label = $SafeArea/Layout/StatusLabel
@onready var confirm_button: Button = $SafeArea/Layout/Actions/ConfirmButton
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var selected_instance_id: int = 0

func _ready() -> void:
	$SafeArea/Layout/Actions/RosterButton.pressed.connect(_open_roster)
	$SafeArea/Layout/Actions/MapButton.pressed.connect(_return_to_map)
	confirm_button.pressed.connect(_confirm_deployment)
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
	for child: Node in board_grid.get_children():
		board_grid.remove_child(child)
		child.queue_free()
	var deployment: DeploymentState = run_manager.current_run.deployment_state
	board_grid.columns = deployment.board_size
	for display_y: int in range(deployment.board_size):
		var board_y: int = deployment.board_size - 1 - display_y
		for x_position: int in range(deployment.board_size):
			var board_position: Vector2i = Vector2i(x_position, board_y)
			var button: Button = Button.new()
			button.name = "Square_%d_%d" % [x_position, board_y]
			button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			button.set_meta("board_position", board_position)
			button.add_theme_stylebox_override("normal", _square_style(board_position, false))
			button.add_theme_stylebox_override("hover", _square_style(board_position, true))
			button.add_theme_stylebox_override("focus", _square_style(board_position, true))
			button.pressed.connect(_on_square_pressed.bind(board_position))
			var portrait: TextureRect = TextureRect.new()
			portrait.name = "Piece"
			portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.texture = _texture_at(board_position)
			button.add_child(portrait)
			board_grid.add_child(button)

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
		_select_piece(player_id)
		return
	if selected_instance_id <= 0:
		status_label.text = _text("DEPLOY_SELECT_FIRST")
		return
	var error: Error = run_manager.move_deployed_piece(selected_instance_id, board_position)
	if error != OK:
		status_label.text = _text("DEPLOY_PLAYER_ROWS_ONLY")
		return
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

func _square_style(board_position: Vector2i, highlighted: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var is_player_row: bool = board_position.y <= 1
	var fill: Color = PLAYER_LIGHT if (board_position.x + board_position.y) % 2 == 0 else PLAYER_DARK
	if not is_player_row:
		fill = BOARD_LIGHT if (board_position.x + board_position.y) % 2 == 0 else BOARD_DARK
	style.bg_color = fill.lightened(0.12) if highlighted else fill
	style.border_color = Color("#f1d56f") if run_manager.current_run != null and run_manager.current_run.deployment_state != null and run_manager.current_run.deployment_state.player_at(board_position) == selected_instance_id and selected_instance_id > 0 else Color("#1b2b32")
	style.set_border_width_all(3 if style.border_color == Color("#f1d56f") else 1)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _piece_name(instance_id: int) -> String:
	var piece: PieceInstanceState = run_manager.current_run.get_piece_state(instance_id) if run_manager.current_run != null else null
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id)) if piece != null else null
	return _text(String(definition.display_name_key)) if definition != null else "?"

func _confirm_deployment() -> void:
	var error: Error = run_manager.confirm_deployment()
	if error != OK:
		status_label.text = _text("DEPLOY_CONFIRM_ERROR")
		return
	var game_state: Node = get_node("/root/GameState")
	if not bool(game_state.call("start_run_battle", run_manager.current_run)):
		status_label.text = _text("DEPLOY_CONFIRM_ERROR")
		return
	get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")

func _open_roster() -> void:
	get_tree().change_scene_to_file("res://scenes/run/RosterScene.tscn")

func _return_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/run/PathMapScene.tscn")

func _apply_locale() -> void:
	$SafeArea/Layout/Header/Title.text = _text("DEPLOY_TITLE")
	$SafeArea/Layout/Header/Subtitle.text = _text("DEPLOY_SUBTITLE")
	$SafeArea/Layout/Actions/RosterButton.text = _text("ROSTER_MANAGE")
	$SafeArea/Layout/Actions/MapButton.text = _text("DEPLOY_MAP")
	confirm_button.text = _text("DEPLOY_CONFIRM")

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

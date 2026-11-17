class_name PathMapScene
extends Control

@onready var map_view: PathMapView = $SafeArea/Layout/MapPanel/MapScroll/MapView
@onready var map_scroll: ScrollContainer = $SafeArea/Layout/MapPanel/MapScroll
@onready var progress_label: Label = $SafeArea/Layout/Header/ProgressLabel
@onready var current_status: Label = $SafeArea/Layout/CurrentStatus
@onready var seed_label: Label = $SafeArea/Layout/Footer/SeedLabel
@onready var node_overlay: ColorRect = $NodeOverlay
@onready var action_button: Button = $NodeOverlay/Center/Panel/Content/ActionButton
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager

var presented_node_id: StringName = &""
var _progress_pips: Control = null
var _reached_layer: int = 0
var _total_layers: int = 0
var _scrolled_once: bool = false
var _scroll_tween: Tween = null

func _ready() -> void:
	map_view.node_selected.connect(_on_node_selected)
	$SafeArea/Layout/Footer/RosterButton.pressed.connect(_open_roster)
	$SafeArea/Layout/Footer/BackButton.pressed.connect(_return_to_menu)
	$NodeOverlay/Center/Panel/Content/CancelButton.pressed.connect(_hide_node_overlay)
	action_button.pressed.connect(_on_action_pressed)
	_apply_locale()
	_build_progress_pips()
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if run_manager.current_run == null or not run_manager.opening_draft_complete():
		_show_error(_text("MAP_NO_ACTIVE_RUN"))
		return
	if run_manager.current_run.phase == RunPhase.MAP:
		var error: Error = run_manager.ensure_run_map()
		if error != OK:
			_show_error(_text("SAVE_ERROR"))
			return
	elif run_manager.current_run.map_state == null:
		_show_error(_text("MAP_NO_ACTIVE_RUN"))
		return
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if node_overlay.visible:
			_hide_node_overlay()
		else:
			_return_to_menu()

func _render() -> void:
	var run_state: RunState = run_manager.current_run
	if run_state == null or run_state.map_state == null:
		return
	var current: MapNodeState = run_manager.current_map_node()
	var reached_layer: int = current.layer_index + 1 if current != null else 0
	progress_label.text = _text("MAP_PROGRESS") % [reached_layer, run_state.map_state.total_layers]
	_reached_layer = reached_layer
	_total_layers = run_state.map_state.total_layers
	_progress_pips.queue_redraw()
	seed_label.text = _text("DRAFT_SEED") % run_state.run_seed
	var available: Array[StringName] = run_manager.available_map_node_ids()
	map_view.display_map(run_state.map_state, available, run_state.visited_node_ids, run_state.current_node_id)
	_scroll_to_progress.call_deferred()
	if current == null:
		current_status.text = _text("MAP_CHOOSE_ROUTE")
	elif run_manager.map_progress_service.is_current_node_resolved(run_state):
		current_status.text = _text("MAP_CHOOSE_NEXT")
	else:
		var definition: MapNodeDef = MapNodeDefDatabase.get_def(current.node_type_id)
		current_status.text = _text("MAP_RESUME_NODE") % _text(String(definition.display_name_key))

func _scroll_to_progress() -> void:
	await get_tree().process_frame
	if run_manager.current_run == null or run_manager.current_run.map_state == null:
		return
	var center_y: float = map_view.node_vertical_center(run_manager.current_run.current_node_id)
	# Keep the current stop in the lower part of the view so the road ahead is visible.
	var target: int = maxi(0, int(center_y - map_scroll.size.y * 0.68))
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	if not _scrolled_once:
		_scrolled_once = true
		map_scroll.scroll_vertical = target
		return
	_scroll_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_scroll_tween.tween_property(map_scroll, "scroll_vertical", target, 0.5)

func _on_node_selected(node_id: StringName) -> void:
	if run_manager.current_run.phase == RunPhase.NODE_SELECTED and node_id == run_manager.current_run.current_node_id:
		_show_node_overlay(node_id)
		return
	var error: Error = run_manager.select_map_node(node_id)
	if error != OK:
		_show_error(_text("MAP_ROUTE_LOCKED"))
		return
	_render()
	# Let the king walk to the node before the details open.
	if map_view.is_travelling():
		await map_view.token_arrived
	if is_inside_tree() and run_manager.current_run != null and run_manager.current_run.current_node_id == node_id:
		_show_node_overlay(node_id)

func _show_node_overlay(node_id: StringName) -> void:
	var node: MapNodeState = run_manager.current_run.map_state.get_node(node_id)
	if node == null:
		return
	var definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
	presented_node_id = node_id
	$NodeOverlay/Center/Panel/Content/Title.text = "%s  %s" % [definition.icon_text, _text(String(definition.display_name_key))]
	$NodeOverlay/Center/Panel/Content/Description.text = _text(String(definition.description_key))
	$NodeOverlay/Center/Panel/Content/EnemyHint.text = _text("MAP_ENEMY_LABEL") % _text(String(definition.enemy_hint_key))
	$NodeOverlay/Center/Panel/Content/RewardHint.text = _text("MAP_REWARD_LABEL") % _text(String(definition.reward_hint_key))
	action_button.text = _text("MAP_ENTER_BATTLE") if definition.is_battle else _text("MAP_RESOLVE_PLACEHOLDER")
	node_overlay.show()
	action_button.grab_focus()

func _on_action_pressed() -> void:
	if presented_node_id.is_empty() or run_manager.current_run == null:
		return
	var node: MapNodeState = run_manager.current_run.map_state.get_node(presented_node_id)
	var definition: MapNodeDef = MapNodeDefDatabase.get_def(node.node_type_id)
	if definition.is_battle:
		var deployment_error: Error = run_manager.begin_deployment()
		if deployment_error != OK:
			_show_error(_text("SAVE_ERROR"))
			return
		get_tree().change_scene_to_file(AppSceneRoutes.DEPLOYMENT)
		return
	var error: Error = run_manager.begin_current_run_interaction()
	if error != OK:
		_show_error(_text("SAVE_ERROR"))
		return
	get_tree().change_scene_to_file(RunContentService.INTERACTION_SCENE)

## One pip per layer under the title: walked, current and still ahead.
func _build_progress_pips() -> void:
	_progress_pips = Control.new()
	_progress_pips.name = "ProgressPips"
	_progress_pips.custom_minimum_size = Vector2(0, 12)
	_progress_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_pips.draw.connect(_draw_progress_pips)
	$SafeArea/Layout/Header.add_child(_progress_pips)

func _draw_progress_pips() -> void:
	if _total_layers <= 0:
		return
	var spacing: float = 16.0
	var start: float = _progress_pips.size.x * 0.5 - spacing * (_total_layers - 1) * 0.5
	for index: int in range(_total_layers):
		var center: Vector2 = Vector2(start + index * spacing, 6.0)
		var last: bool = index == _total_layers - 1
		if index > 0:
			_progress_pips.draw_line(center - Vector2(spacing - 5.0, 0.0), center - Vector2(5.0, 0.0), Color("#d9b85a") if index < _reached_layer else Color("#2c4054"), 1.0)
		if index < _reached_layer - 1:
			_progress_pips.draw_circle(center, 3.5, Color("#d9b85a"))
		elif index == _reached_layer - 1:
			_progress_pips.draw_circle(center, 5.0, Color("#f1c75c"))
			_progress_pips.draw_circle(center, 2.0, Color("#0b1620"))
		else:
			_progress_pips.draw_circle(center, 4.0 if last else 3.5, Color("#e45b55") if last else Color("#2c4054"))
			_progress_pips.draw_circle(center, 2.0, Color("#0b1620"))

func _hide_node_overlay() -> void:
	node_overlay.hide()
	presented_node_id = &""

func _show_error(message: String) -> void:
	error_dialog.dialog_text = message
	error_dialog.popup_centered()

func _apply_locale() -> void:
	$SafeArea/Layout/Header/Title.text = _text("MAP_TITLE")
	$SafeArea/Layout/Footer/RosterButton.text = _text("ROSTER_MANAGE")
	$SafeArea/Layout/Footer/BackButton.text = _text("COMMON_BACK")
	$NodeOverlay/Center/Panel/Content/CancelButton.text = _text("COMMON_CANCEL")

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

func _open_roster() -> void:
	get_tree().change_scene_to_file(AppSceneRoutes.ROSTER)

func _return_to_menu() -> void:
	get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)

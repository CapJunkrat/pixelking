class_name RosterScene
extends Control

const ACTIVE_SLOT_COUNT := 6
const RESERVE_SLOT_COUNT := 5

@onready var active_list: VBoxContainer = $SafeArea/Layout/Columns/ActivePanel/Content/ActiveList
@onready var reserve_list: VBoxContainer = $SafeArea/Layout/Columns/ReservePanel/Content/ReserveList
@onready var capacity_label: Label = $SafeArea/Layout/CapacityLabel
@onready var status_label: Label = $SafeArea/Layout/StatusLabel
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

func _ready() -> void:
	$SafeArea/Layout/Footer/BackButton.pressed.connect(_return_to_run)
	_apply_locale()
	if run_manager.current_run == null or not run_manager.opening_draft_complete():
		status_label.text = _text("ROSTER_NO_ACTIVE_RUN")
		return
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_run()

func _render() -> void:
	_clear_list(active_list)
	_clear_list(reserve_list)
	var active_pieces: Array[PieceInstanceState] = run_manager.roster_service.active_pieces(run_manager.current_run)
	var reserve_pieces: Array[PieceInstanceState] = run_manager.roster_service.reserve_pieces(run_manager.current_run)
	for slot_index: int in range(ACTIVE_SLOT_COUNT):
		var piece: PieceInstanceState = active_pieces[slot_index] if slot_index < active_pieces.size() else null
		active_list.add_child(_create_piece_card(piece, true, slot_index))
	for slot_index: int in range(RESERVE_SLOT_COUNT):
		var piece: PieceInstanceState = reserve_pieces[slot_index] if slot_index < reserve_pieces.size() else null
		reserve_list.add_child(_create_piece_card(piece, false, slot_index))
	var active_non_king: int = maxi(0, active_pieces.size() - 1)
	capacity_label.text = _text("ROSTER_CAPACITY") % [active_non_king, RunState.MAX_ACTIVE_NON_KING_PIECES, reserve_pieces.size(), RunState.MAX_RESERVE_PIECES]
	status_label.text = _text("ROSTER_INSTRUCTION")

func _create_piece_card(piece: PieceInstanceState, is_active: bool, slot_index: int) -> Button:
	var button: Button = Button.new()
	button.name = "%sSlot%d" % ["Active" if is_active else "Reserve", slot_index]
	button.custom_minimum_size = Vector2(0, 62)
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("is_active_slot", is_active)
	if piece == null:
		button.text = _text("ROSTER_EMPTY_SLOT")
		button.disabled = true
		return button
	button.set_meta("instance_id", piece.instance_id)
	button.set_meta("piece_def_id", piece.piece_def_id)
	var definition: PieceDef = PieceDefDatabase.get_def(String(piece.piece_def_id))
	button.text = "%s\n#%d%s" % [
		_text(String(definition.display_name_key)),
		piece.instance_id,
		" · " + _text("ROSTER_KING_LOCKED") if piece.is_king else "",
	]
	button.icon = piece_skin_manager.call("piece_texture", &"white", piece.piece_def_id) as Texture2D
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 11)
	button.disabled = piece.is_king
	if not piece.is_king:
		button.pressed.connect(_on_piece_pressed.bind(piece.instance_id, is_active))
	return button

func _on_piece_pressed(instance_id: int, currently_active: bool) -> void:
	var error: Error = run_manager.move_roster_piece(instance_id, not currently_active)
	if error != OK:
		status_label.text = _text("ROSTER_CAPACITY_ERROR")
		return
	_render()

func _clear_list(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()

func _apply_locale() -> void:
	$SafeArea/Layout/Header/Title.text = _text("ROSTER_TITLE")
	$SafeArea/Layout/Header/Subtitle.text = _text("ROSTER_SUBTITLE")
	$SafeArea/Layout/Columns/ActivePanel/Content/Title.text = _text("ROSTER_ACTIVE")
	$SafeArea/Layout/Columns/ReservePanel/Content/Title.text = _text("ROSTER_RESERVE")
	$SafeArea/Layout/Footer/BackButton.text = _text("ROSTER_RETURN")

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

func _return_to_run() -> void:
	get_tree().change_scene_to_file(run_manager.resume_scene_path())

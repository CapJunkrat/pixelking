class_name OpeningDraftScene
extends Control

signal fan_transition_completed
signal candidate_info_opened

const TOTAL_ROUNDS := 3
const CARD_WIDTH := 148.0
const CARD_HEIGHT := 282.0
const FAN_ROTATION_DEGREES := 6.0
const FAN_SIDE_DROP := 20.0
const SIDE_CARD_SCALE := 0.78
const FAN_TRANSITION_DURATION := 0.22
const INFO_HOLD_SECONDS := 0.5
const INFO_GRID_SIZE := 5
const INFO_CELL_SIZE := 19.0
const INFO_EMPTY_COLOR := Color("#101b29")
const INFO_MOVE_COLOR := Color("#287a91")
const INFO_ATTACK_COLOR := Color("#a34f3c")
const INFO_BOTH_COLOR := Color("#7160a9")
const INFO_PIECE_COLOR := Color("#d9ad4f")
const COMMON_COLOR := Color("#b9b0a0")
const RARE_COLOR := Color("#39bde8")
const EPIC_COLOR := Color("#ad70ef")
const LEGENDARY_COLOR := Color("#f2bd4d")

@onready var round_label: Label = $SafeArea/Layout/Header/RoundLabel
@onready var instruction_label: Label = $SafeArea/Layout/Header/InstructionLabel
@onready var seed_label: Label = $SafeArea/Layout/Footer/SeedLabel
@onready var candidate_cards: Control = $SafeArea/Layout/CandidateCards
@onready var select_button: Button = $SafeArea/Layout/CandidateCards/SelectButton
@onready var info_popup: PanelContainer = $InfoLayer/CandidateInfoPopup
@onready var info_diagram: GridContainer = $InfoLayer/CandidateInfoPopup/Content/DiagramCenter/Diagram
@onready var selected_roster: HBoxContainer = $SafeArea/Layout/SelectedRoster
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager

var candidate_buttons: Array[Button] = []
var card_pivots: Array[Node2D] = []
var candidate_ids: Array[String] = []
var previewed_candidate_index: int = 1
var pending_info_index: int = -1
## Set when a hold opened the information popup; the release that ends that hold must
## not also count as a click (it would switch the previewed card).
var press_opened_info: bool = false
## The card under a finger or mouse button right now (-1: none).
var held_card_index: int = -1
var info_timer: Timer
var fan_tween: Tween

func _ready() -> void:
	card_pivots = [
		$SafeArea/Layout/CandidateCards/CardPivot0 as Node2D,
		$SafeArea/Layout/CandidateCards/CardPivot1 as Node2D,
		$SafeArea/Layout/CandidateCards/CardPivot2 as Node2D,
	]
	candidate_buttons = [
		$SafeArea/Layout/CandidateCards/CardPivot0/Candidate0 as Button,
		$SafeArea/Layout/CandidateCards/CardPivot1/Candidate1 as Button,
		$SafeArea/Layout/CandidateCards/CardPivot2/Candidate2 as Button,
	]
	for index: int in range(candidate_buttons.size()):
		var card: Button = candidate_buttons[index]
		card.focus_mode = Control.FOCUS_NONE
		card.position = Vector2(-CARD_WIDTH * 0.5, -CARD_HEIGHT * 0.5)
		card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.rotation = 0.0
		card.scale = Vector2.ONE
		card.z_index = 0
		card.pressed.connect(_on_card_preview_pressed.bind(index))
		card.mouse_entered.connect(_start_candidate_info.bind(index))
		card.mouse_exited.connect(_stop_candidate_info)
		card.button_down.connect(_on_card_button_down.bind(index))
		card.button_up.connect(_on_card_button_up)
	select_button.pressed.connect(_on_select_candidate_pressed)
	info_timer = Timer.new()
	info_timer.one_shot = true
	info_timer.wait_time = INFO_HOLD_SECONDS
	info_timer.timeout.connect(_on_info_timer_timeout)
	add_child(info_timer)
	candidate_cards.resized.connect(_layout_card_fan)
	call_deferred("_layout_card_fan")
	$SafeArea/Layout/Footer/BackButton.pressed.connect(_return_to_menu)
	PieceSkinManager.skin_changed.connect(_on_skin_changed)
	_apply_locale()
	if run_manager.current_run == null:
		_show_error(Localization.text("DRAFT_NO_ACTIVE_RUN"))
		return
	var error: Error = run_manager.ensure_opening_draft_pending()
	if error != OK:
		_show_error(Localization.text("SAVE_ERROR"))
		return
	_render()

func _exit_tree() -> void:
	if PieceSkinManager.skin_changed.is_connected(_on_skin_changed):
		PieceSkinManager.skin_changed.disconnect(_on_skin_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()

func _render() -> void:
	var run_state: RunState = run_manager.current_run
	if run_state == null:
		return
	seed_label.text = Localization.text("DRAFT_SEED") % run_state.run_seed
	_render_selected_roster(run_state)
	if run_manager.opening_draft_complete():
		_enter_route_map()
		return
	var choice: Dictionary = run_state.pending_choice
	var round_index: int = int(choice.get("round_index", 0))
	round_label.text = Localization.text("DRAFT_ROUND") % [round_index + 1, TOTAL_ROUNDS]
	candidate_ids = _to_string_array(choice.get("candidate_piece_def_ids", []))
	previewed_candidate_index = 1
	info_popup.hide()
	for index: int in range(candidate_buttons.size()):
		_render_candidate(candidate_buttons[index], candidate_ids[index] if index < candidate_ids.size() else "")
	_layout_card_fan()
	_set_cards_disabled(false)
	select_button.grab_focus()

func _layout_card_fan(animate: bool = false) -> void:
	if candidate_cards == null or candidate_buttons.size() != 3:
		return
	var available_width: float = candidate_cards.size.x
	var available_height: float = candidate_cards.size.y
	if available_width <= 0.0 or available_height <= 0.0:
		return
	if is_instance_valid(fan_tween):
		fan_tween.kill()
	fan_tween = create_tween().set_parallel(true) if animate else null
	if fan_tween != null:
		fan_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var center_x: float = (available_width - CARD_WIDTH) * 0.5
	var center_y: float = maxf(0.0, (available_height - CARD_HEIGHT - 48.0) * 0.28)
	var left_index: int = (previewed_candidate_index + 2) % 3
	var right_index: int = (previewed_candidate_index + 1) % 3
	_apply_card_transform(left_index, Vector2(CARD_WIDTH * 0.5, center_y + FAN_SIDE_DROP + CARD_HEIGHT * 0.5), -FAN_ROTATION_DEGREES, Vector2.ONE * SIDE_CARD_SCALE, 1, animate)
	_apply_card_transform(right_index, Vector2(available_width - CARD_WIDTH * 0.5, center_y + FAN_SIDE_DROP + CARD_HEIGHT * 0.5), FAN_ROTATION_DEGREES, Vector2.ONE * SIDE_CARD_SCALE, 2, animate)
	_apply_card_transform(previewed_candidate_index, Vector2(center_x + CARD_WIDTH * 0.5, center_y + CARD_HEIGHT * 0.5), 0.0, Vector2.ONE, 10, animate)
	_order_cards_for_input(left_index, right_index)
	if fan_tween != null:
		fan_tween.finished.connect(func() -> void: fan_transition_completed.emit(), CONNECT_ONE_SHOT)
	select_button.position = Vector2(center_x, center_y + CARD_HEIGHT + 6.0)
	select_button.size = Vector2(CARD_WIDTH, 42.0)

## Touches go to the last sibling under the finger, whatever the z_index, so the
## sibling order must match what is drawn on top: side cards first, the centered card
## last (just before the Select button). Otherwise a touch on the centered card where a
## side card overlaps it lands on the side card.
func _order_cards_for_input(left_index: int, right_index: int) -> void:
	var order: Array[int] = [left_index, right_index, previewed_candidate_index]
	for position_index: int in range(order.size()):
		candidate_cards.move_child(card_pivots[order[position_index]], position_index)

func _apply_card_transform(index: int, target_position: Vector2, target_rotation: float, target_scale: Vector2, target_z: int, animate: bool) -> void:
	var pivot: Node2D = card_pivots[index]
	pivot.z_index = target_z
	if animate and fan_tween != null:
		fan_tween.tween_property(pivot, "position", target_position, FAN_TRANSITION_DURATION)
		fan_tween.tween_property(pivot, "rotation_degrees", target_rotation, FAN_TRANSITION_DURATION)
		fan_tween.tween_property(pivot, "scale", target_scale, FAN_TRANSITION_DURATION)
	else:
		pivot.position = target_position
		pivot.rotation_degrees = target_rotation
		pivot.scale = target_scale

func _render_candidate(button: Button, piece_def_id: String) -> void:
	var definition: PieceDef = Content.piece(piece_def_id)
	button.disabled = definition == null
	button.set_meta("piece_def_id", piece_def_id)
	var portrait: TextureRect = button.get_node("Content/Portrait") as TextureRect
	var name_label: Label = button.get_node("Content/Text/NameLabel") as Label
	var rarity_label: Label = button.get_node("Content/Text/RarityLabel") as Label
	var description_label: Label = button.get_node("Content/Text/DescriptionLabel") as Label
	if definition == null:
		portrait.texture = null
		name_label.text = "?"
		rarity_label.text = ""
		description_label.text = ""
		return
	portrait.texture = PieceSkinManager.piece_texture(&"white", StringName(piece_def_id))
	name_label.text = Localization.text(String(definition.display_name_key))
	rarity_label.text = Localization.text(_rarity_key(definition.rarity))
	rarity_label.add_theme_color_override("font_color", _rarity_color(definition.rarity))
	# A few one-word traits; the hold-to-inspect card has the full rules.
	var tags: Array[String] = []
	for key: String in PieceRulePreview.tag_keys(definition):
		tags.append(Localization.text(key))
	description_label.text = " · ".join(tags)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Card frames remain stable while candidates rotate between fixed fan slots.
	# Rarity is communicated by the label so runtime theme replacement cannot flash.

func _render_selected_roster(run_state: RunState) -> void:
	for child: Node in selected_roster.get_children():
		child.queue_free()
	var title: Label = Label.new()
	title.text = Localization.text("DRAFT_SELECTED")
	selected_roster.add_child(title)
	for piece: PieceInstanceState in run_state.player_roster:
		var portrait: TextureRect = TextureRect.new()
		portrait.custom_minimum_size = Vector2(38, 38)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.texture = PieceSkinManager.piece_texture(&"white", piece.piece_def_id)
		portrait.tooltip_text = Localization.text(String(Content.piece(String(piece.piece_def_id)).display_name_key))
		selected_roster.add_child(portrait)

func _on_card_preview_pressed(index: int) -> void:
	if press_opened_info:
		press_opened_info = false
		return
	if index < 0 or index >= candidate_ids.size() or index == previewed_candidate_index:
		return
	previewed_candidate_index = index
	info_popup.hide()
	_layout_card_fan(true)

func _on_select_candidate_pressed() -> void:
	if previewed_candidate_index < 0 or previewed_candidate_index >= candidate_ids.size():
		return
	_set_cards_disabled(true)
	var error: Error = run_manager.submit_opening_draft_choice(candidate_ids[previewed_candidate_index])
	if error != OK:
		_set_cards_disabled(false)
		_show_error(Localization.text("SAVE_ERROR"))
		return
	_render()

func _on_card_button_down(index: int) -> void:
	press_opened_info = false
	held_card_index = index
	_start_candidate_info(index)

## A button emits `pressed` before `button_up`, so the release that ends a hold is
## swallowed before the hold is forgotten here.
func _on_card_button_up() -> void:
	held_card_index = -1
	_stop_candidate_info()

func _start_candidate_info(index: int) -> void:
	if index < 0 or index >= candidate_ids.size() or info_timer == null:
		return
	pending_info_index = index
	info_timer.start()

func _stop_candidate_info() -> void:
	pending_info_index = -1
	if info_timer != null:
		info_timer.stop()
	info_popup.hide()

func _on_info_timer_timeout() -> void:
	if pending_info_index < 0 or pending_info_index >= candidate_ids.size():
		return
	var definition: PieceDef = Content.piece(candidate_ids[pending_info_index])
	if definition == null:
		return
	(info_popup.get_node("Content/NameLabel") as Label).text = Localization.text(String(definition.display_name_key))
	(info_popup.get_node("Content/MovementLabel") as Label).text = Localization.text(PieceRulePreview.move_key(definition))
	(info_popup.get_node("Content/AttackLabel") as Label).text = Localization.text(PieceRulePreview.attack_key(definition))
	(info_popup.get_node("Content/LegendLabel") as Label).text = Localization.text("DRAFT_INFO_LEGEND")
	_render_move_diagram(String(definition.id))
	if held_card_index == pending_info_index:
		press_opened_info = true
	info_popup.show()
	candidate_info_opened.emit()

func _render_move_diagram(piece_def_id: String) -> void:
	for child: Node in info_diagram.get_children():
		child.queue_free()
	var pattern: Dictionary = _movement_pattern(piece_def_id)
	var center_value: int = floori(float(INFO_GRID_SIZE) * 0.5)
	var center: Vector2i = Vector2i(center_value, center_value)
	for y_position: int in range(INFO_GRID_SIZE):
		for x_position: int in range(INFO_GRID_SIZE):
			var offset: Vector2i = Vector2i(x_position, y_position) - center
			var role: String = str(pattern.get(offset, "empty"))
			if offset == Vector2i.ZERO:
				role = "piece"
			info_diagram.add_child(_diagram_cell(role))

func _diagram_cell(role: String) -> PanelContainer:
	var cell: PanelContainer = PanelContainer.new()
	cell.custom_minimum_size = Vector2(INFO_CELL_SIZE, INFO_CELL_SIZE)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = _diagram_color(role)
	style.border_color = Color("#26384a")
	style.set_border_width_all(1)
	cell.add_theme_stylebox_override("panel", style)
	if role == "piece":
		var marker: Label = Label.new()
		marker.text = "P"
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.add_theme_color_override("font_color", Color("#16100a"))
		marker.add_theme_font_size_override("font_size", 11)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(marker)
	return cell

func _diagram_color(role: String) -> Color:
	match role:
		"move":
			return INFO_MOVE_COLOR
		"attack":
			return INFO_ATTACK_COLOR
		"both":
			return INFO_BOTH_COLOR
		"piece":
			return INFO_PIECE_COLOR
		_:
			return INFO_EMPTY_COLOR

func _movement_pattern(piece_def_id: String) -> Dictionary:
	return PieceRulePreview.pattern(piece_def_id, INFO_GRID_SIZE)

func _set_cards_disabled(disabled_value: bool) -> void:
	for button: Button in candidate_buttons:
		button.disabled = disabled_value
	select_button.disabled = disabled_value

func _show_error(message: String) -> void:
	error_dialog.dialog_text = message
	error_dialog.popup_centered()

func _apply_locale() -> void:
	$SafeArea/Layout/Header/Title.text = Localization.text("DRAFT_TITLE")
	instruction_label.text = Localization.text("DRAFT_INSTRUCTION")
	$SafeArea/Layout/Footer/BackButton.text = Localization.text("COMMON_BACK")
	select_button.text = Localization.text("DRAFT_SELECT")

func _rarity_key(rarity: PieceDef.Rarity) -> String:
	match rarity:
		PieceDef.Rarity.RARE:
			return "RARITY_RARE"
		PieceDef.Rarity.EPIC:
			return "RARITY_EPIC"
		PieceDef.Rarity.LEGENDARY:
			return "RARITY_LEGENDARY"
		PieceDef.Rarity.MYTHIC:
			return "RARITY_MYTHIC"
		_:
			return "RARITY_COMMON"

func _rarity_color(rarity: PieceDef.Rarity) -> Color:
	match rarity:
		PieceDef.Rarity.RARE:
			return RARE_COLOR
		PieceDef.Rarity.EPIC:
			return EPIC_COLOR
		PieceDef.Rarity.LEGENDARY, PieceDef.Rarity.MYTHIC:
			return LEGENDARY_COLOR
		_:
			return COMMON_COLOR

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			result.append(str(entry))
	return result

func _on_skin_changed(_skin_id: StringName) -> void:
	_render()

func _open_roster() -> void:
	get_tree().change_scene_to_file(AppSceneRoutes.ROSTER)

func _enter_route_map() -> void:
	var error: Error = run_manager.ensure_run_map()
	if error != OK:
		_show_error(Localization.text("SAVE_ERROR"))
		return
	get_tree().change_scene_to_file(AppSceneRoutes.PATH_MAP)

func _return_to_menu() -> void:
	get_tree().change_scene_to_file(AppSceneRoutes.MAIN_MENU)

class_name OpeningDraftScene
extends Control

const TOTAL_ROUNDS := 3
const EXPANDED_CARD_WIDTH := 176.0
const EXPANDED_CARD_HEIGHT := 270.0
const SIDE_CARD_WIDTH := 80.0
const SIDE_CARD_HEIGHT := 220.0
const SELECT_BUTTON_HEIGHT := 40.0
const COMMON_COLOR := Color("#b9b0a0")
const RARE_COLOR := Color("#39bde8")
const EPIC_COLOR := Color("#ad70ef")
const LEGENDARY_COLOR := Color("#f2bd4d")

@onready var round_label: Label = $SafeArea/Layout/Header/RoundLabel
@onready var instruction_label: Label = $SafeArea/Layout/Header/InstructionLabel
@onready var seed_label: Label = $SafeArea/Layout/Footer/SeedLabel
@onready var candidate_cards: Control = $SafeArea/Layout/CandidateCards
@onready var selected_roster: HBoxContainer = $SafeArea/Layout/SelectedRoster
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager

var candidate_buttons: Array[Button] = []
var select_buttons: Array[Button] = []
var candidate_ids: Array[String] = []
var previewed_candidate_index: int = 1

func _ready() -> void:
	candidate_buttons = [
		$SafeArea/Layout/CandidateCards/Slot0/Candidate0 as Button,
		$SafeArea/Layout/CandidateCards/Slot1/Candidate1 as Button,
		$SafeArea/Layout/CandidateCards/Slot2/Candidate2 as Button,
	]
	for index: int in range(candidate_buttons.size()):
		candidate_buttons[index].pressed.connect(_on_card_preview_pressed.bind(index))
	_build_candidate_details_and_actions()
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
	for index: int in range(candidate_buttons.size()):
		_render_candidate(candidate_buttons[index], candidate_ids[index] if index < candidate_ids.size() else "")
	_set_cards_disabled(false)
	_layout_card_fan()
	if candidate_buttons.size() > 1:
		candidate_buttons[1].grab_focus()

func _layout_card_fan(_animate: bool = false) -> void:
	if candidate_cards == null or candidate_buttons.size() != 3 or select_buttons.size() != 3:
		return
	for index: int in range(candidate_buttons.size()):
		var is_previewed: bool = index == previewed_candidate_index
		var slot: VBoxContainer = candidate_cards.get_node("Slot%d" % index) as VBoxContainer
		var button: Button = candidate_buttons[index]
		var spacer: Control = slot.get_node("Spacer") as Control
		slot.custom_minimum_size.x = EXPANDED_CARD_WIDTH if is_previewed else SIDE_CARD_WIDTH
		button.custom_minimum_size = Vector2(EXPANDED_CARD_WIDTH, EXPANDED_CARD_HEIGHT) if is_previewed else Vector2(SIDE_CARD_WIDTH, SIDE_CARD_HEIGHT)
		button.rotation_degrees = 0.0
		spacer.custom_minimum_size.y = 0.0 if is_previewed else EXPANDED_CARD_HEIGHT - SIDE_CARD_HEIGHT
		_update_detail_visibility(button, is_previewed)
		var portrait: TextureRect = button.get_node("Content/Portrait") as TextureRect
		portrait.custom_minimum_size = Vector2(130, 108) if is_previewed else Vector2(56, 108)
		var select_button: Button = select_buttons[index]
		select_button.custom_minimum_size = Vector2(0.0, SELECT_BUTTON_HEIGHT)
		select_button.modulate = Color.WHITE if is_previewed else Color("#aab8b3")

func _update_detail_visibility(button: Button, visible_value: bool) -> void:
	(button.get_node("Content/Text/MovementLabel") as Label).visible = visible_value
	(button.get_node("Content/Text/AttackLabel") as Label).visible = visible_value
	(button.get_node("Content/Text/RarityLabel") as Label).visible = visible_value
	(button.get_node("Content/Text/DescriptionLabel") as Label).visible = visible_value
	var name_label: Label = button.get_node("Content/Text/NameLabel") as Label
	name_label.add_theme_font_size_override("font_size", 20 if visible_value else 14)

func _build_candidate_details_and_actions() -> void:
	for index: int in range(candidate_buttons.size()):
		var text_box: VBoxContainer = candidate_buttons[index].get_node("Content/Text") as VBoxContainer
		var movement_label: Label = _detail_label("MovementLabel", Color("#82d8ea"))
		var attack_label: Label = _detail_label("AttackLabel", Color("#f29a78"))
		text_box.add_child(movement_label)
		text_box.add_child(attack_label)
		var select_button: Button = Button.new()
		select_button.name = "Select%d" % index
		select_button.text = Localization.text("DRAFT_SELECT")
		select_button.focus_mode = Control.FOCUS_ALL
		select_button.add_theme_font_size_override("font_size", 17)
		select_button.add_theme_stylebox_override("normal", _card_style(Color("#123227"), Color("#61c985"), 2))
		select_button.add_theme_stylebox_override("hover", _card_style(Color("#1d4a38"), Color("#f2cf65"), 3))
		select_button.add_theme_stylebox_override("focus", _card_style(Color("#1d4a38"), Color("#f2cf65"), 3))
		select_button.add_theme_stylebox_override("pressed", _card_style(Color("#0b211a"), Color("#61c985"), 2))
		select_button.pressed.connect(_on_select_candidate_pressed.bind(index))
		var slot: VBoxContainer = candidate_cards.get_node("Slot%d" % index) as VBoxContainer
		var spacer: Control = Control.new()
		spacer.name = "Spacer"
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(spacer)
		slot.add_child(select_button)
		select_buttons.append(select_button)

func _detail_label(label_name: String, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = label_name
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 10)
	return label

func _render_candidate(button: Button, piece_def_id: String) -> void:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_def_id)
	button.disabled = definition == null
	button.set_meta("piece_def_id", piece_def_id)
	var portrait: TextureRect = button.get_node("Content/Portrait") as TextureRect
	var name_label: Label = button.get_node("Content/Text/NameLabel") as Label
	var rarity_label: Label = button.get_node("Content/Text/RarityLabel") as Label
	var description_label: Label = button.get_node("Content/Text/DescriptionLabel") as Label
	var movement_label: Label = button.get_node("Content/Text/MovementLabel") as Label
	var attack_label: Label = button.get_node("Content/Text/AttackLabel") as Label
	if definition == null:
		portrait.texture = null
		name_label.text = "?"
		rarity_label.text = ""
		description_label.text = ""
		movement_label.text = ""
		attack_label.text = ""
		return
	portrait.texture = PieceSkinManager.piece_texture(&"white", StringName(piece_def_id))
	name_label.text = Localization.text(String(definition.display_name_key))
	rarity_label.text = Localization.text(_rarity_key(definition.rarity))
	rarity_label.add_theme_color_override("font_color", _rarity_color(definition.rarity))
	description_label.text = Localization.text("DRAFT_POWER") % definition.base_value
	movement_label.text = Localization.text("DRAFT_MOVE_%s" % definition.id.to_upper())
	attack_label.text = Localization.text("DRAFT_ATTACK_%s" % definition.id.to_upper())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var border_color: Color = _rarity_color(definition.rarity)
	button.add_theme_stylebox_override("normal", _card_style(Color("#111d2b"), border_color, 2))
	button.add_theme_stylebox_override("hover", _card_style(Color("#193148"), border_color.lightened(0.18), 3))
	button.add_theme_stylebox_override("focus", _card_style(Color("#193148"), border_color.lightened(0.18), 3))
	button.add_theme_stylebox_override("pressed", _card_style(Color("#0b1520"), border_color, 2))

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
		portrait.tooltip_text = Localization.text(String(PieceDefDatabase.get_def(String(piece.piece_def_id)).display_name_key))
		selected_roster.add_child(portrait)

func _on_card_preview_pressed(index: int) -> void:
	if index < 0 or index >= candidate_ids.size() or index == previewed_candidate_index:
		return
	previewed_candidate_index = index
	_layout_card_fan()

func _on_select_candidate_pressed(index: int) -> void:
	if index < 0 or index >= candidate_ids.size():
		return
	_set_cards_disabled(true)
	var error: Error = run_manager.submit_opening_draft_choice(candidate_ids[index])
	if error != OK:
		_set_cards_disabled(false)
		_show_error(Localization.text("SAVE_ERROR"))
		return
	_render()

func _set_cards_disabled(disabled_value: bool) -> void:
	for button: Button in candidate_buttons:
		button.disabled = disabled_value
	for button: Button in select_buttons:
		button.disabled = disabled_value

func _show_error(message: String) -> void:
	error_dialog.dialog_text = message
	error_dialog.popup_centered()

func _apply_locale() -> void:
	$SafeArea/Layout/Header/Title.text = Localization.text("DRAFT_TITLE")
	instruction_label.text = Localization.text("DRAFT_INSTRUCTION")
	$SafeArea/Layout/Footer/BackButton.text = Localization.text("COMMON_BACK")
	for select_button: Button in select_buttons:
		select_button.text = Localization.text("DRAFT_SELECT")

func _rarity_key(rarity: PieceDef.Rarity) -> String:
	match rarity:
		PieceDef.Rarity.RARE:
			return "RARITY_RARE"
		PieceDef.Rarity.EPIC:
			return "RARITY_EPIC"
		PieceDef.Rarity.LEGENDARY:
			return "RARITY_LEGENDARY"
		_:
			return "RARITY_COMMON"

func _rarity_color(rarity: PieceDef.Rarity) -> Color:
	match rarity:
		PieceDef.Rarity.RARE:
			return RARE_COLOR
		PieceDef.Rarity.EPIC:
			return EPIC_COLOR
		PieceDef.Rarity.LEGENDARY:
			return LEGENDARY_COLOR
		_:
			return COMMON_COLOR

func _card_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _to_string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			result.append(str(entry))
	return result

func _on_skin_changed(_skin_id: StringName) -> void:
	_render()

func _open_roster() -> void:
	get_tree().change_scene_to_file("res://scenes/run/RosterScene.tscn")

func _enter_route_map() -> void:
	var error: Error = run_manager.ensure_run_map()
	if error != OK:
		_show_error(Localization.text("SAVE_ERROR"))
		return
	get_tree().change_scene_to_file("res://scenes/run/PathMapScene.tscn")

func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

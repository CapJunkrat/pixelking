class_name OpeningDraftScene
extends Control

const TOTAL_ROUNDS := 3
const COMMON_COLOR := Color("#b9b0a0")
const RARE_COLOR := Color("#39bde8")
const EPIC_COLOR := Color("#ad70ef")
const LEGENDARY_COLOR := Color("#f2bd4d")

@onready var round_label: Label = $SafeArea/Layout/Header/RoundLabel
@onready var instruction_label: Label = $SafeArea/Layout/Header/InstructionLabel
@onready var seed_label: Label = $SafeArea/Layout/Footer/SeedLabel
@onready var selected_roster: HBoxContainer = $SafeArea/Layout/SelectedRoster
@onready var completion_overlay: ColorRect = $CompletionOverlay
@onready var error_dialog: AcceptDialog = $ErrorDialog
@onready var run_manager: AppRunManager = get_node("/root/RunManager") as AppRunManager

var candidate_buttons: Array[Button] = []
var candidate_ids: Array[String] = []

func _ready() -> void:
	candidate_buttons = [
		$SafeArea/Layout/CandidateCards/Candidate0 as Button,
		$SafeArea/Layout/CandidateCards/Candidate1 as Button,
		$SafeArea/Layout/CandidateCards/Candidate2 as Button,
	]
	for index: int in range(candidate_buttons.size()):
		candidate_buttons[index].pressed.connect(_on_candidate_pressed.bind(index))
	$SafeArea/Layout/Footer/BackButton.pressed.connect(_return_to_menu)
	$CompletionOverlay/Center/Panel/Content/PrototypeBattleButton.pressed.connect(_enter_prototype_battle)
	$CompletionOverlay/Center/Panel/Content/MainMenuButton.pressed.connect(_return_to_menu)
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
	if event.is_action_pressed("ui_cancel") and not completion_overlay.visible:
		_return_to_menu()

func _render() -> void:
	var run_state: RunState = run_manager.current_run
	if run_state == null:
		return
	seed_label.text = Localization.text("DRAFT_SEED") % run_state.run_seed
	_render_selected_roster(run_state)
	if run_manager.opening_draft_complete():
		_show_completion()
		return
	completion_overlay.hide()
	var choice: Dictionary = run_state.pending_choice
	var round_index: int = int(choice.get("round_index", 0))
	round_label.text = Localization.text("DRAFT_ROUND") % [round_index + 1, TOTAL_ROUNDS]
	candidate_ids = _to_string_array(choice.get("candidate_piece_def_ids", []))
	for index: int in range(candidate_buttons.size()):
		_render_candidate(candidate_buttons[index], candidate_ids[index] if index < candidate_ids.size() else "")
	if not candidate_buttons.is_empty():
		candidate_buttons[0].grab_focus()

func _render_candidate(button: Button, piece_def_id: String) -> void:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_def_id)
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
	description_label.text = Localization.text("DRAFT_POWER") % definition.base_value
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

func _on_candidate_pressed(index: int) -> void:
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

func _show_completion() -> void:
	completion_overlay.show()
	$CompletionOverlay/Center/Panel/Content/PrototypeBattleButton.grab_focus()

func _show_error(message: String) -> void:
	error_dialog.dialog_text = message
	error_dialog.popup_centered()

func _apply_locale() -> void:
	$SafeArea/Layout/Header/Title.text = Localization.text("DRAFT_TITLE")
	instruction_label.text = Localization.text("DRAFT_INSTRUCTION")
	$SafeArea/Layout/Footer/BackButton.text = Localization.text("COMMON_BACK")
	$CompletionOverlay/Center/Panel/Content/CompletionTitle.text = Localization.text("DRAFT_COMPLETE")
	$CompletionOverlay/Center/Panel/Content/CompletionDetail.text = Localization.text("DRAFT_COMPLETE_DETAIL")
	$CompletionOverlay/Center/Panel/Content/PrototypeBattleButton.text = Localization.text("DRAFT_PROTOTYPE_BATTLE")
	$CompletionOverlay/Center/Panel/Content/MainMenuButton.text = Localization.text("DRAFT_RETURN_MENU")

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

func _enter_prototype_battle() -> void:
	GameState.start_new_game()
	get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn")

func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

extends Control

@onready var board_view: BattleBoardView = $Margin/Layout/BoardFrame as BattleBoardView
@onready var board_frame: Control = $Margin/Layout/BoardFrame
@onready var board_grid: GridContainer = $Margin/Layout/BoardFrame/BoardCenter/BoardGrid
@onready var settings_overlay: BattleSettingsPanel = $SettingsOverlay as BattleSettingsPanel
@onready var challenger_tray: ChallengerTray = $Margin/Layout/ChallengerPanel as ChallengerTray
@onready var battle_hud: BattleHUD = $Margin/Layout/TopBar as BattleHUD

var selected_square: Vector2i:
	get:
		return board_view.selected_square
	set(value):
		board_view.selected_square = value
var legal_targets: Array[Vector2i]:
	get:
		return board_view.legal_targets
	set(value):
		board_view.legal_targets = value
var square_buttons: Dictionary:
	get:
		return board_view.square_buttons
var challenger_slots: Array[Button] = []
var turn_label: Label
var round_label: Label
var enemy_portrait: TextureRect

func _ready() -> void:
	$Margin/Layout/Title.hide()
	$Margin/Layout/TurnLabel.hide()
	$Margin/Layout/StatusLabel.hide()
	$Margin/Layout/BackButton.hide()
	turn_label = battle_hud.turn_label
	round_label = battle_hud.round_label
	enemy_portrait = battle_hud.enemy_portrait
	battle_hud.settings_requested.connect(settings_overlay.open)
	challenger_slots = challenger_tray.slots()
	board_view.move_requested.connect(_on_board_move_requested)
	board_view.setup(GameState.board, GameState.player_color)
	_refresh_board()
	_refresh_challenger_slots()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_overlay.is_open():
		settings_overlay.close()
		get_viewport().set_input_as_handled()

func _on_board_move_requested(from: Vector2i, to: Vector2i) -> void:
	if GameState.try_move(from, to):
		board_view.clear_selection()
	_refresh_board()

func is_settings_open() -> bool:
	return settings_overlay.is_open()

func clear_board_selection() -> void:
	board_view.clear_selection()

func _refresh_board() -> void:
	var board: BoardState = GameState.board
	if board == null:
		return
	board_view.refresh(board)
	battle_hud.refresh(board, GameState.player_color)

func _refresh_challenger_slots() -> void:
	challenger_tray.refresh(GameState.challenger_items)

func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _board_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#071927")
	style.border_color = Color("#e7c98f")
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.shadow_color = Color(0.01, 0.04, 0.07, 0.8)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	style.anti_aliasing = false
	return style

func _hud_bar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#091c2b")
	style.border_color = Color("#e0c58d")
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.shadow_color = Color(0.01, 0.04, 0.07, 0.75)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 3)
	style.anti_aliasing = false
	return style

func _hud_segment_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0b2031")
	style.border_color = Color("#705f47")
	style.border_width_right = 1
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.anti_aliasing = false
	return style

func _hud_button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	style.anti_aliasing = false
	return style

func _challenger_tray_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#091b2a")
	style.border_color = Color("#c7a96e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.01, 0.04, 0.07, 0.8)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 4)
	style.anti_aliasing = false
	return style

func _challenger_title_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ead49e")
	style.border_color = Color("#172f42")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.01, 0.04, 0.07, 0.65)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.anti_aliasing = false
	return style

func _treasure_slot_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f2dfb0") if hovered else Color("#d9c38f")
	style.border_color = Color("#7c6847")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.02, 0.05, 0.07, 0.7)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	style.anti_aliasing = false
	return style
func _texture_style(path: String, margin: float) -> StyleBoxTexture:
	return _frame_style(path, margin, 0)

func _frame_style(path: String, texture_margin: float, content_margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path) as Texture2D
	style.texture_margin_left = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_bottom = texture_margin
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.draw_center = true
	return style

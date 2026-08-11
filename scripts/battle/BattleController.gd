class_name BattleController
extends Control

@onready var board_view: BattleBoardView = $Margin/Layout/BoardFrame as BattleBoardView
@onready var settings_overlay: BattleSettingsPanel = $SettingsOverlay as BattleSettingsPanel
@onready var challenger_tray: ChallengerTray = $Margin/Layout/ChallengerPanel as ChallengerTray
@onready var battle_hud: BattleHUD = $Margin/Layout/TopBar as BattleHUD
@onready var battle_log: BattleLogPanel = $Margin/Layout/BattleLogPanel as BattleLogPanel
@onready var animation_player: BattleAnimationPlayer = $BattleAnimationLayer as BattleAnimationPlayer

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

func _ready() -> void:
	battle_hud.settings_requested.connect(settings_overlay.open)
	challenger_slots = challenger_tray.slots()
	board_view.move_requested.connect(_on_board_move_requested)
	GameState.battle_events_emitted.connect(_on_battle_events_emitted)
	board_view.setup(GameState.board, GameState.player_color)
	_refresh_board()
	_refresh_challenger_slots()

func _exit_tree() -> void:
	if GameState.battle_events_emitted.is_connected(_on_battle_events_emitted):
		GameState.battle_events_emitted.disconnect(_on_battle_events_emitted)

func _on_battle_events_emitted(events: Array[BattleEvent]) -> void:
	animation_player.enqueue_events(events)
	battle_log.consume(events)
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

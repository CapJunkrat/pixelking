class_name BattleController
extends Control

signal presentation_started(events: Array[BattleEvent])
signal presentation_completed

@onready var board_view: BattleBoardView = $Margin/Layout/BoardFrame as BattleBoardView
@onready var settings_overlay: BattleSettingsPanel = $SettingsOverlay as BattleSettingsPanel
@onready var challenger_tray: ChallengerTray = $Margin/Layout/ChallengerPanel as ChallengerTray
@onready var battle_hud: BattleHUD = $Margin/Layout/TopBar as BattleHUD
@onready var battle_log: BattleLogPanel = $Margin/Layout/BattleLogPanel as BattleLogPanel
@onready var animation_player: BattleAnimationPlayer = $BattleAnimationLayer as BattleAnimationPlayer
@onready var battle_flow: BattleFlowController = $BattleFlow as BattleFlowController

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
var challenger_slots: Array[Button] = []
var pending_item_slot: int = -1
var _presentation_generation: int = 0

func _ready() -> void:
	battle_hud.settings_requested.connect(settings_overlay.open)
	battle_hud.debug_victory_requested.connect(battle_flow.force_debug_victory)
	challenger_tray.item_requested.connect(_on_item_requested)
	challenger_slots = challenger_tray.slots()
	board_view.move_requested.connect(_on_board_move_requested)
	board_view.item_target_requested.connect(_on_item_target_requested)
	GameState.battle_events_emitted.connect(_on_battle_events_emitted)
	board_view.setup(GameState.board, GameState.player_color)
	_refresh_board()
	_refresh_challenger_slots()

func _exit_tree() -> void:
	if GameState.battle_events_emitted.is_connected(_on_battle_events_emitted):
		GameState.battle_events_emitted.disconnect(_on_battle_events_emitted)

func _on_battle_events_emitted(events: Array[BattleEvent]) -> void:
	_presentation_generation += 1
	var generation: int = _presentation_generation
	presentation_started.emit(events)
	animation_player.enqueue_events(events)
	board_view.present_events(events, animation_player.playback_speed)
	battle_log.consume(events)
	_refresh_board()
	_refresh_challenger_slots()
	_await_presentation_completion(generation)

func _await_presentation_completion(generation: int) -> void:
	await animation_player.sequence_completed
	if board_view.is_presenting():
		await board_view.presentations_completed
	if generation == _presentation_generation:
		presentation_completed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_overlay.is_open():
		settings_overlay.close()
		get_viewport().set_input_as_handled()

func _on_item_requested(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameState.challenger_items.size():
		return
	var item: ChallengerItemDef = GameState.challenger_items[slot_index]
	if not item.is_consumable():
		battle_log.append_system_message("%s is a passive relic." % Localization.text(String(item.display_name_key)))
		return
	if item.effect_type == &"remove_piece":
		pending_item_slot = slot_index
		board_view.begin_item_targeting()
		battle_log.append_system_message("Select an enemy non-King piece for %s." % Localization.text(String(item.display_name_key)))
		return
	GameState.try_use_item(slot_index)
	_refresh_board()
	_refresh_challenger_slots()

func _on_item_target_requested(target_position: Vector2i) -> void:
	if pending_item_slot < 0:
		return
	var slot_index: int = pending_item_slot
	pending_item_slot = -1
	if not GameState.try_use_item(slot_index, target_position):
		battle_log.append_system_message("Invalid item target.")
	_refresh_board()
	_refresh_challenger_slots()

func _on_board_move_requested(from: Vector2i, to: Vector2i) -> void:
	if GameState.try_move(from, to):
		board_view.clear_selection()
	_refresh_board()

func set_battle_input_enabled(enabled: bool) -> void:
	board_view.set_input_enabled(enabled)
	challenger_tray.set_input_enabled(enabled)
	_refresh_challenger_slots()

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
	var usable_slots: Array[bool] = []
	for index: int in range(GameState.challenger_items.size()):
		usable_slots.append(GameState.can_use_challenger_item(index))
	challenger_tray.refresh(GameState.challenger_items, usable_slots)

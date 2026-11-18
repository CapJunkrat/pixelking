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
var piece_info: PieceInfoPanel = null

func _ready() -> void:
	battle_hud.settings_requested.connect(settings_overlay.open)
	battle_hud.debug_victory_requested.connect(battle_flow.force_debug_victory)
	battle_hud.end_turn_requested.connect(_on_end_turn_requested)
	challenger_tray.item_requested.connect(_on_item_requested)
	challenger_slots = challenger_tray.slots()
	board_view.move_requested.connect(_on_board_move_requested)
	board_view.item_target_requested.connect(_on_item_target_requested)
	piece_info = PieceInfoPanel.new()
	piece_info.name = "PieceInfo"
	add_child(piece_info)
	board_view.piece_info_requested.connect(_on_piece_info_requested)
	board_view.focus_changed.connect(_on_board_focus_changed)
	GameState.battle_events_emitted.connect(_on_battle_events_emitted)
	board_view.setup(GameState.board, GameState.player_color)
	_refresh_board()
	_refresh_challenger_slots()
	_play_intro()

const BANNER_FONT := preload("res://assets/fonts/battle/PixelMplus10-Bold.ttf")

## Coming from the pre-battle screen: the board glides from where it stood there, the
## battle HUD slides in around it, the enemy wakes with a hop, the opening shields pop
## and a short banner announces the fight. Skipped headless or without a hand-off.
func _play_intro() -> void:
	var source: Rect2 = GameState.entry_board_rect
	var snapshot: Texture2D = GameState.entry_snapshot
	GameState.entry_board_rect = Rect2()
	GameState.entry_snapshot = null
	if source.size == Vector2.ZERO or DisplayServer.get_name() == "headless":
		return
	board_view.intro_locked = true
	board_view.dome_scale = 0.0
	var cover: TextureRect = null
	if snapshot != null:
		# The last pre-battle frame covers the first frames while the layout settles.
		cover = TextureRect.new()
		cover.name = "IntroCover"
		cover.texture = snapshot
		cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cover.stretch_mode = TextureRect.STRETCH_SCALE
		cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(cover)
	var parts: Array[Control] = [battle_hud, challenger_tray, battle_log]
	for part: Control in parts:
		part.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var glide: Tween = board_view.glide_in_from(source, 0.5)
	if cover != null:
		var fade: Tween = create_tween()
		fade.tween_property(cover, "modulate:a", 0.0, 0.12)
		fade.tween_callback(cover.queue_free)
	for index: int in range(parts.size()):
		var part: Control = parts[index]
		var rest: float = part.position.y
		var from_y: float = rest - 36.0 if part == battle_hud else rest + 36.0
		part.position.y = from_y
		var slide: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		slide.tween_interval(0.12 + index * 0.05)
		slide.tween_property(part, "position:y", rest, 0.35)
		slide.parallel().tween_property(part, "modulate:a", 1.0, 0.3)
	await glide.finished
	if not is_inside_tree():
		return
	board_view.hop_pieces(GameRules.PieceColor.BLACK if GameState.player_color == GameRules.PieceColor.WHITE else GameRules.PieceColor.WHITE)
	board_view.pop_domes()
	_show_banner()
	await get_tree().create_timer(0.45).timeout
	if is_inside_tree():
		board_view.intro_locked = false

func _show_banner() -> void:
	var banner: Label = Label.new()
	banner.name = "BattleBanner"
	banner.text = Localization.text("BATTLE_START_BANNER")
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_override("font", BANNER_FONT)
	banner.add_theme_font_size_override("font_size", 40)
	banner.add_theme_color_override("font_color", Color("#f5d58f"))
	banner.add_theme_color_override("font_outline_color", Color("#1a1408"))
	banner.add_theme_constant_override("outline_size", 8)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(banner)
	var board_rect: Rect2 = board_view.get_global_rect()
	banner.size = Vector2(board_rect.size.x, 60.0)
	banner.global_position = Vector2(board_rect.position.x, board_rect.get_center().y - 30.0)
	banner.pivot_offset = banner.size * 0.5
	banner.modulate.a = 0.0
	banner.scale = Vector2(1.5, 1.5)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.22)
	tween.parallel().tween_property(banner, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.45)
	tween.tween_property(banner, "modulate:a", 0.0, 0.25)
	tween.tween_callback(banner.queue_free)

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
	_play_event_sounds(events, animation_player.playback_speed)
	_refresh_board()
	_refresh_challenger_slots()
	_await_presentation_completion(generation)

func _await_presentation_completion(generation: int) -> void:
	await animation_player.sequence_completed
	if board_view.is_presenting():
		await board_view.presentations_completed
	if generation == _presentation_generation:
		presentation_completed.emit()

## The card under the board explains the piece the player tapped.
func _on_board_focus_changed(square: Vector2i) -> void:
	var piece: ChessPiece = GameState.board.get_piece(square) if GameState.board != null and square != BattleBoardView.NO_SQUARE else null
	if piece == null:
		battle_log.clear_piece()
	else:
		battle_log.show_piece(piece, piece.color != GameState.player_color)
		_sfx(&"select", -4.0)

## Sounds for what just happened on the board, timed to the animation: the move at
## once, the hit when the strike lands, the jingle once the battle is decided.
func _play_event_sounds(events: Array[BattleEvent], speed: float) -> void:
	var hit_delay: float = 0.22 / maxf(0.25, speed)
	var played: Dictionary = {}
	for event: BattleEvent in events:
		var sound: StringName = &""
		var delay: float = 0.0
		match event.event_type:
			BattleCommandProcessor.EVENT_PIECE_MOVED:
				sound = &"shot" if bool(event.payload.get("ranged", false)) else &"move"
			BattleCommandProcessor.EVENT_PIECE_CAPTURED:
				sound = &"capture"
				delay = hit_delay
			BattleCommandProcessor.EVENT_PIECE_DESTROYED, BattleCommandProcessor.EVENT_KING_EXECUTION:
				sound = &"explode"
				delay = hit_delay
			BattleCommandProcessor.EVENT_ROCK_BROKEN:
				sound = &"rock"
				delay = hit_delay
			BattleCommandProcessor.EVENT_SHELL_BROKEN:
				sound = &"shell"
				delay = hit_delay
			BattleCommandProcessor.EVENT_CHECK_DECLARED:
				if not bool(event.payload.get("checkmate", false)):
					sound = &"check"
					delay = hit_delay * 2.0
			BattleCommandProcessor.EVENT_ITEM_USED:
				sound = &"item"
			BattleCommandProcessor.EVENT_ACTION_REJECTED:
				sound = &"error"
			BattleCommandProcessor.EVENT_BATTLE_ENDED:
				var won: bool = int(event.payload.get("winner", -1)) == GameState.player_color
				sound = &"victory" if won else &"defeat"
				delay = 0.7 / maxf(0.25, speed)
		if sound.is_empty() or played.has(sound):
			continue
		played[sound] = true
		var audio: Node = get_node_or_null("/root/AudioManager")
		if audio != null:
			audio.call("play_sfx_later", sound, delay)

func _sfx(name: StringName, volume_db: float = 0.0) -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", name, volume_db)

func _on_piece_info_requested(square: Vector2i) -> void:
	piece_info.show_piece(GameState.board, square, GameState.player_color)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and piece_info != null and piece_info.is_open():
		piece_info.close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and settings_overlay.is_open():
		settings_overlay.close()
		get_viewport().set_input_as_handled()

func _on_item_requested(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameState.challenger_items.size():
		return
	var item: ChallengerItemDef = GameState.challenger_items[slot_index]
	if not item.is_consumable():
		battle_log.append_system_message("%s: %s" % [Localization.text(String(item.display_name_key)), Localization.text(String(item.description_key))])
		return
	var target: String = BattleCommandProcessor.item_target(item)
	if target != "none":
		pending_item_slot = slot_index
		board_view.begin_item_targeting()
		battle_log.append_system_message(Localization.text("ITEM_TARGET_ALLY" if target == "ally" else "ITEM_TARGET_ENEMY") % Localization.text(String(item.display_name_key)))
		return
	if GameState.try_use_item(slot_index) and item.effect_type == &"bonus_action":
		battle_log.append_system_message(Localization.text("ITEM_SECOND_WIND_READY"))
	_refresh_board()
	_refresh_challenger_slots()

func _on_item_target_requested(target_position: Vector2i) -> void:
	if pending_item_slot < 0:
		return
	var slot_index: int = pending_item_slot
	pending_item_slot = -1
	if not GameState.try_use_item(slot_index, target_position):
		battle_log.append_system_message(Localization.text("ITEM_TARGET_INVALID"))
	_refresh_board()
	_refresh_challenger_slots()

func _on_end_turn_requested() -> void:
	if GameState.try_end_turn():
		board_view.clear_selection()
	_refresh_board()

func _on_board_move_requested(from: Vector2i, to: Vector2i) -> void:
	if GameState.try_move(from, to):
		board_view.clear_selection()
	_refresh_board()

func set_battle_input_enabled(enabled: bool) -> void:
	board_view.set_input_enabled(enabled)
	if battle_hud.end_turn_button != null:
		battle_hud.end_turn_button.disabled = not enabled
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

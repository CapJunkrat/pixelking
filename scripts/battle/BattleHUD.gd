class_name BattleHUD
extends HBoxContainer

signal settings_requested
signal debug_victory_requested
## The player gives up the bonus action a piece earned this turn.
signal end_turn_requested

@onready var enemy_portrait: TextureRect = $BossPortrait/Portrait
@onready var enemy_label: Label = $EnemySegment/EnemyLabel
@onready var turn_label: Label = $TurnSegment/TurnLabel
@onready var round_label: Label = $RoundSegment/RoundContent/RoundLabel
@onready var settings_button: Button = $SettingsButton
@onready var turn_segment: PanelContainer = $TurnSegment

const DEBUG_VICTORY_CLICK_COUNT := 5
const DEBUG_VICTORY_CLICK_WINDOW_MSEC := 2000

var end_turn_button: Button = null
var _debug_clicks: int = 0
var _debug_click_started_msec: int = 0

func _ready() -> void:
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	turn_segment.gui_input.connect(_on_turn_segment_input)
	enemy_label.text = _text("BATTLE_ENEMY")
	settings_button.tooltip_text = _text("SETTINGS_TITLE")
	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = _text("BATTLE_END_TURN")
	end_turn_button.visible = false
	end_turn_button.focus_mode = Control.FOCUS_NONE
	end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	add_child(end_turn_button)
	move_child(end_turn_button, settings_button.get_index())

func refresh(board: BoardState, player_color: int) -> void:
	if board == null:
		return
	turn_label.text = _text("BATTLE_YOUR_TURN") if board.turn == player_color else _text("BATTLE_ENEMY_TURN")
	turn_label.add_theme_color_override("font_color", Color("#33c8c2") if board.turn == player_color else Color("#f1dfbd"))
	round_label.text = str(floori(float(board.move_history.size()) / 2.0) + 1)
	if end_turn_button != null:
		end_turn_button.visible = board.turn == player_color and board.bonus_instance_id != 0

func _on_turn_segment_input(event: InputEvent) -> void:
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state == null or not bool(game_state.get("debug_mode")):
		return
	var clicked: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		clicked = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		clicked = (event as InputEventScreenTouch).pressed
	if not clicked:
		return
	var now_msec: int = Time.get_ticks_msec()
	if _debug_click_started_msec == 0 or now_msec - _debug_click_started_msec > DEBUG_VICTORY_CLICK_WINDOW_MSEC:
		_debug_click_started_msec = now_msec
		_debug_clicks = 0
	_debug_clicks += 1
	if _debug_clicks >= DEBUG_VICTORY_CLICK_COUNT:
		_debug_clicks = 0
		_debug_click_started_msec = 0
		debug_victory_requested.emit()

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

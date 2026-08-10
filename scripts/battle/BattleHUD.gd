class_name BattleHUD
extends HBoxContainer

signal settings_requested

@onready var enemy_portrait: TextureRect = $BossPortrait/Portrait
@onready var enemy_label: Label = $EnemySegment/EnemyLabel
@onready var turn_label: Label = $TurnSegment/TurnLabel
@onready var round_label: Label = $RoundSegment/RoundContent/RoundLabel
@onready var settings_button: Button = $SettingsButton

func _ready() -> void:
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	enemy_label.text = _text("BATTLE_ENEMY")
	settings_button.tooltip_text = _text("SETTINGS_TITLE")

func refresh(board: BoardState, player_color: int) -> void:
	if board == null:
		return
	turn_label.text = _text("BATTLE_YOUR_TURN") if board.turn == player_color else _text("BATTLE_ENEMY_TURN")
	turn_label.add_theme_color_override("font_color", Color("#33c8c2") if board.turn == player_color else Color("#f1dfbd"))
	round_label.text = str(floori(float(board.move_history.size()) / 2.0) + 1)

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

class_name BattleLogPanel
extends PanelContainer

## The card between the board and the item tray. With a piece tapped (yours or an
## enemy's) it shows that piece: picture, name, how it moves and captures, and its
## abilities. Otherwise it shows the last moves of the battle in plain words, or a
## hint at the start.

const MAX_LINES := 2
const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const GOLD_SOFT := Color("#f5d58f")
const TEAL := Color("#4fd1c5")
const ENEMY := Color("#e07a6a")
const PANEL := Color(0.05, 0.09, 0.16, 0.86)
const LINE := Color("#2b4166")

var log_label: RichTextLabel = null
var lines: Array[String] = []
var _picture: TextureRect = null
var _showing_piece: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.custom_minimum_size = Vector2(34, 34)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.visible = false
	row.add_child(_picture)
	log_label = RichTextLabel.new()
	log_label.name = "Log"
	log_label.bbcode_enabled = true
	log_label.scroll_active = false
	log_label.fit_content = false
	log_label.clip_contents = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.add_theme_font_size_override("normal_font_size", 11)
	log_label.add_theme_font_size_override("bold_font_size", 12)
	log_label.add_theme_color_override("default_color", INK)
	row.add_child(log_label)
	_show_history()

## The tapped piece: what it is and what it does. `enemy` colours it as a foe.
func show_piece(piece: ChessPiece, enemy: bool) -> void:
	if piece == null or piece.def == null:
		clear_piece()
		return
	_showing_piece = true
	var skin: Node = get_node_or_null("/root/PieceSkinManager")
	_picture.texture = skin.call("piece_texture", &"black" if enemy else &"white", StringName(piece.def.id)) as Texture2D if skin != null else null
	_picture.visible = _picture.texture != null
	var accent: String = (ENEMY if enemy else GOLD_SOFT).to_html(false)
	var owner: String = _text("LOG_ENEMY_TAG") if enemy else _text("LOG_YOURS_TAG")
	var text: Array[String] = ["[b][color=#%s]%s[/color][/b]  [color=#%s]%s[/color]" % [accent, _text(String(piece.def.display_name_key)), MUTED.to_html(false), owner]]
	text.append("[color=#%s]%s[/color]" % [MUTED.to_html(false), _text(PieceRulePreview.move_key(piece.def))])
	text.append("[color=#%s]%s[/color]" % [MUTED.to_html(false), _text(PieceRulePreview.attack_key(piece.def))])
	var traits: Array[String] = []
	for key: String in PieceRulePreview.ability_keys(piece.def):
		if key != "CODEX_TRAIT_NONE":
			traits.append(_text(key))
	if not traits.is_empty():
		text.append("[color=#%s]%s[/color]" % [GOLD_SOFT.to_html(false), " · ".join(traits)])
	log_label.text = "\n".join(text)

## Back to the battle's recent moves.
func clear_piece() -> void:
	if not _showing_piece:
		return
	_showing_piece = false
	_show_history()

func consume(events: Array[BattleEvent]) -> void:
	for event: BattleEvent in events:
		var line: String = _format_event(event)
		if not line.is_empty():
			_push(line)

func append_system_message(message: String) -> void:
	if not message.is_empty():
		_push("[color=#%s]%s[/color]" % [GOLD_SOFT.to_html(false), message])

func _push(line: String) -> void:
	lines.append(line)
	while lines.size() > MAX_LINES:
		lines.pop_front()
	_showing_piece = false
	_show_history()

func _show_history() -> void:
	if log_label == null:
		return
	_picture.visible = false
	if lines.is_empty():
		log_label.text = "[color=#%s]%s[/color]" % [MUTED.to_html(false), _text("LOG_HINT")]
		return
	log_label.text = "\n".join(lines)

## A move, capture or other event in plain words, coloured by side.
func _format_event(event: BattleEvent) -> String:
	var data: Dictionary = event.payload
	match event.event_type:
		BattleCommandProcessor.EVENT_PIECE_MOVED:
			return _text("LOG_MOVED") % [_who(str(data.get("piece_def_id", "")), int(data.get("color", 0))), _square(data.get("to", Vector2i.ZERO))]
		BattleCommandProcessor.EVENT_PIECE_CAPTURED:
			return _text("LOG_CAPTURED") % _who(str(data.get("piece_def_id", "")), int(data.get("color", 0)))
		BattleCommandProcessor.EVENT_ITEM_USED:
			var item: ChallengerItemDef = ChallengerItemDatabase.get_def(StringName(str(data.get("item_id", ""))))
			return _text("LOG_ITEM_USED") % (_text(String(item.display_name_key)) if item != null else str(data.get("item_id", "")))
		BattleCommandProcessor.EVENT_CHECK_DECLARED:
			return "" if bool(data.get("checkmate", false)) else "[color=#%s]%s[/color]" % [ENEMY.to_html(false), _text("LOG_CHECK")]
		_:
			return ""

## "Your Knight" in teal or "Enemy Knight" in coral.
func _who(piece_id: String, color: int) -> String:
	var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
	var name: String = _text(String(definition.display_name_key)) if definition != null else piece_id
	var player_color: int = GameRules.PieceColor.WHITE
	var game_state: Node = get_node_or_null("/root/GameState")
	if game_state != null:
		player_color = int(game_state.get("player_color"))
	var yours: bool = color == player_color
	return "[color=#%s]%s[/color]" % [(TEAL if yours else ENEMY).to_html(false), (_text("LOG_YOUR") if yours else _text("LOG_ENEMY")) % name]

func _square(value: Variant) -> String:
	if value is Vector2i:
		var square_position: Vector2i = value
		return "%s%d" % [String.chr(65 + square_position.x), square_position.y + 1]
	return "?"

func _text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

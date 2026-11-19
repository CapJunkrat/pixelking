class_name BattleLogPanel
extends PanelContainer

## The panel between the board and the item tray, with two pages picked by the tab
## buttons down its left side:
## - Piece: the tapped piece (yours or an enemy's): picture, name, how it moves and
##   captures, its abilities; item prompts also show here.
## - Log: every move and capture of the battle so far, newest at the bottom.
## Both pages scroll up and down with a finger.

const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const GOLD_SOFT := Color("#f5d58f")
const GOLD := Color("#f5c860")
const TEAL := Color("#4fd1c5")
const ENEMY := Color("#e07a6a")
const SHIELD := Color("#a9d6ff")
const PROTECTED := Color("#f0a93a")
const PANEL := Color(0.05, 0.09, 0.16, 0.86)
const TAB_IDLE := Color(0.09, 0.14, 0.24, 1.0)
const TAB_ON := Color(0.16, 0.24, 0.4, 1.0)
const LINE := Color("#2b4166")

enum Page { PIECE, LOG }

## Every log line of the battle (BBCode), oldest first.
var lines: Array[String] = []
## The log page's text (kept under this name for tools and tests).
var log_label: RichTextLabel = null
var info_label: RichTextLabel = null
var page: int = Page.PIECE
var _picture: TextureRect = null
var _info_scroll: ScrollContainer = null
var _log_scroll: ScrollContainer = null
var _tabs: Array[Button] = []
var _showing_piece: bool = false
var _last_round: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(row)
	var tab_column: VBoxContainer = VBoxContainer.new()
	tab_column.name = "Tabs"
	tab_column.add_theme_constant_override("separation", 4)
	row.add_child(tab_column)
	for entry: Array in [[Page.PIECE, "LOG_TAB_PIECE"], [Page.LOG, "LOG_TAB_LOG"]]:
		var tab: Button = Button.new()
		tab.name = "Tab%d" % int(entry[0])
		tab.text = _text(str(entry[1]))
		tab.custom_minimum_size = Vector2(40, 30)
		tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_size_override("font_size", 11)
		tab.pressed.connect(show_page.bind(int(entry[0])))
		tab_column.add_child(tab)
		_tabs.append(tab)
	var divider: ColorRect = ColorRect.new()
	divider.color = LINE
	divider.custom_minimum_size = Vector2(1, 0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)
	var pages: Control = Control.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(pages)
	# Piece page: picture on the left, text beside it.
	_info_scroll = _scroll("InfoScroll")
	pages.add_child(_info_scroll)
	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_theme_constant_override("separation", 8)
	_info_scroll.add_child(info_row)
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.custom_minimum_size = Vector2(34, 34)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_picture.visible = false
	info_row.add_child(_picture)
	info_label = _rich("Info")
	info_row.add_child(info_label)
	# Log page.
	_log_scroll = _scroll("LogScroll")
	pages.add_child(_log_scroll)
	log_label = _rich("Log")
	_log_scroll.add_child(log_label)
	DragScroll.enable(_info_scroll)
	DragScroll.enable(_log_scroll)
	_show_hint()
	_render_log()
	show_page(Page.PIECE)

func _scroll(scroll_name: String) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = scroll_name
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	return scroll

func _rich(label_name: String) -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.name = label_name
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 11)
	label.add_theme_font_size_override("bold_font_size", 12)
	label.add_theme_color_override("default_color", INK)
	return label

## Switches between the piece page and the battle log.
func show_page(which: int) -> void:
	page = which
	if _info_scroll == null:
		return
	_info_scroll.visible = which == Page.PIECE
	_log_scroll.visible = which == Page.LOG
	for index: int in range(_tabs.size()):
		var on: bool = index == which
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.bg_color = TAB_ON if on else TAB_IDLE
			box.border_color = GOLD if on else LINE
			box.set_border_width_all(1)
			box.set_corner_radius_all(6)
			_tabs[index].add_theme_stylebox_override(state, box)
		_tabs[index].add_theme_color_override("font_color", GOLD_SOFT if on else MUTED)
		_tabs[index].add_theme_color_override("font_hover_color", GOLD_SOFT if on else INK)
		_tabs[index].add_theme_color_override("font_pressed_color", GOLD_SOFT)
	if which == Page.LOG:
		_scroll_log_to_end()

# --- piece page ---------------------------------------------------------------

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
	if piece.def.is_egg:
		var egg_board: BoardState = _board()
		if egg_board != null:
			text[0] += "  [color=#%s]%s[/color]" % [GOLD_SOFT.to_html(false), _text("LOG_EGG_HATCHES_IN") % egg_board.egg_turns_left(piece)]
	var shield_note: String = _shield_note(piece)
	if not shield_note.is_empty():
		# On the name line: it is why this piece cannot be taken right now.
		text[0] += "  [color=#%s]%s[/color]" % [SHIELD.to_html(false), shield_note]
	text.append("[color=#%s]%s[/color]" % [MUTED.to_html(false), _text(PieceRulePreview.move_key(piece.def))])
	text.append("[color=#%s]%s[/color]" % [MUTED.to_html(false), _text(PieceRulePreview.attack_key(piece.def))])
	var traits: Array[String] = []
	for key: String in PieceRulePreview.ability_keys(piece.def):
		if key != "CODEX_TRAIT_NONE":
			traits.append(_text(key))
	if not traits.is_empty():
		text.append("[color=#%s]%s[/color]" % [GOLD_SOFT.to_html(false), " · ".join(traits)])
	if not enemy:
		# What the marks on its target squares mean.
		text.append("[color=#ff5a52]%s[/color]   [color=#%s]%s[/color]" % [_text("LOG_LEGEND_DANGER"), PROTECTED.to_html(false), _text("LOG_LEGEND_PROTECTED")])
	info_label.text = "\n".join(text)
	_info_scroll.scroll_vertical = 0
	show_page(Page.PIECE)

## Back to the hint (nothing selected).
func clear_piece() -> void:
	if not _showing_piece:
		return
	_showing_piece = false
	_show_hint()

func _show_hint() -> void:
	if info_label == null:
		return
	_picture.visible = false
	info_label.text = "[color=#%s]%s[/color]" % [MUTED.to_html(false), _text("LOG_HINT")]

## A prompt or item description; shown on the piece page.
func append_system_message(message: String) -> void:
	if message.is_empty() or info_label == null:
		return
	_showing_piece = true
	_picture.visible = false
	info_label.text = "[color=#%s]%s[/color]" % [GOLD_SOFT.to_html(false), message]
	show_page(Page.PIECE)

## The shield line blinks after a blocked attack, so the player sees the reason.
func flash_shield_note() -> void:
	if info_label == null:
		return
	var tween: Tween = create_tween()
	for step: int in range(2):
		tween.tween_property(info_label, "modulate", Color(1.6, 1.6, 2.0), 0.08)
		tween.tween_property(info_label, "modulate", Color.WHITE, 0.12)

func _board() -> BoardState:
	var game_state: Node = get_node_or_null("/root/GameState")
	return game_state.get("board") as BoardState if game_state != null else null

## "Opening shield: safe for 2 more turns", or "" when unshielded.
func _shield_note(piece: ChessPiece) -> String:
	var board: BoardState = _board()
	if board == null or not piece.is_shielded(board.turn_serial):
		return ""
	var turns: int = maxi(1, ceili((piece.shield_until_serial - board.turn_serial) / 2.0))
	return _text("LOG_KING_SHIELDED" if piece.def.is_king else "LOG_PIECE_SHIELDED") % turns

# --- log page -----------------------------------------------------------------

func consume(events: Array[BattleEvent]) -> void:
	var added: bool = false
	for event: BattleEvent in events:
		var line: String = _format_event(event)
		if line.is_empty():
			continue
		if event.event_type == BattleCommandProcessor.EVENT_PIECE_MOVED:
			var round_number: int = _round()
			if round_number > 0 and round_number != _last_round:
				_last_round = round_number
				lines.append("[color=#%s]%s[/color]" % [GOLD.to_html(false), _text("LOG_ROUND") % round_number])
		lines.append(line)
		added = true
	if added:
		_render_log()

## The round of the move just played (the board has already passed the turn).
func _round() -> int:
	var board: BoardState = _board()
	if board == null:
		return -1
	return maxi(0, board.turn_serial - 1) / 2 + 1

func _render_log() -> void:
	if log_label == null:
		return
	if lines.is_empty():
		log_label.text = "[color=#%s]%s[/color]" % [MUTED.to_html(false), _text("LOG_EMPTY")]
		return
	log_label.text = "\n".join(lines)
	_scroll_log_to_end()

func _scroll_log_to_end() -> void:
	if _log_scroll == null or not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)

## A move, capture or other event in plain words, coloured by side.
func _format_event(event: BattleEvent) -> String:
	var data: Dictionary = event.payload
	match event.event_type:
		BattleCommandProcessor.EVENT_PIECE_MOVED:
			if bool(data.get("ranged", false)):
				return _text("LOG_SHOT") % [_who(str(data.get("piece_def_id", "")), int(data.get("color", 0))), _square(data.get("target", data.get("to", Vector2i.ZERO)))]
			return _text("LOG_MOVED") % [_who(str(data.get("piece_def_id", "")), int(data.get("color", 0))), _square(data.get("to", Vector2i.ZERO))]
		BattleCommandProcessor.EVENT_PIECE_CAPTURED, BattleCommandProcessor.EVENT_PIECE_DESTROYED:
			return "  " + _text("LOG_CAPTURED") % _who(str(data.get("piece_def_id", "")), int(data.get("color", 0)))
		BattleCommandProcessor.EVENT_KING_EXECUTION:
			return "  " + _text("LOG_CAPTURED") % _who(str(data.get("victim_def_id", "king")), int(data.get("victim_color", 0)))
		BattleCommandProcessor.EVENT_ITEM_USED:
			var item: ChallengerItemDef = ChallengerItemDatabase.get_def(StringName(str(data.get("item_id", ""))))
			return _text("LOG_ITEM_USED") % (_text(String(item.display_name_key)) if item != null else str(data.get("item_id", "")))
		BattleCommandProcessor.EVENT_EGG_LAID:
			return "  [color=#%s]%s[/color]" % [GOLD_SOFT.to_html(false), _text("LOG_EGG_LAID") % _who(_hatchling(str(data.get("piece_def_id", ""))), int(data.get("color", 0)))]
		BattleCommandProcessor.EVENT_PIECE_REVIVED:
			if bool(data.get("hatched", false)):
				return "[color=#%s]%s[/color]" % [GOLD_SOFT.to_html(false), _text("LOG_EGG_HATCHED") % _who(str(data.get("piece_def_id", "")), int(data.get("color", 0)))]
			return ""
		BattleCommandProcessor.EVENT_CHECK_DECLARED:
			return "" if bool(data.get("checkmate", false)) else "  [color=#%s]%s[/color]" % [ENEMY.to_html(false), _text("LOG_CHECK")]
		_:
			return ""

## The bird an egg belongs to (for "Your Ember Bird laid an egg").
func _hatchling(egg_id: String) -> String:
	for piece_id: String in PieceDefDatabase.all_ids():
		var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
		if definition != null and definition.egg_def_id == egg_id:
			return piece_id
	return egg_id

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

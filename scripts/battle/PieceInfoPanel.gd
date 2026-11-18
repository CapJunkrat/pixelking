class_name PieceInfoPanel
extends Control

## Card shown when a piece on the battle board is long-pressed: what it is, where it
## moves and captures (as a grid and in words), its traits and its state right now
## (shield, freeze, shell, growth). Any tap closes it. Read-only: it never changes the
## battle.

const INK := Color("#f1e6cf")
const MUTED := Color("#9aa8bf")
const GOLD := Color("#e0b45c")
const GOLD_SOFT := Color("#f5d58f")
const ALLY := Color("#4fd1c5")
const ENEMY := Color("#e07a6a")
const PANEL := Color("#12203a")
const LINE := Color("#2b4166")
const GRID_SIZE := 7

var shown_square: Vector2i = Vector2i(-1, -1)
var _card: PanelContainer = null
var _body: VBoxContainer = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(300, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = LINE
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)
	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_constant_override("separation", 8)
	_card.add_child(_body)

func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		accept_event()
		close()

func is_open() -> bool:
	return visible

func close() -> void:
	visible = false
	shown_square = Vector2i(-1, -1)

## Opens the card for the piece on `square`. Returns false when the square is empty.
func show_piece(board: BoardState, square: Vector2i, player_color: int) -> bool:
	var piece: ChessPiece = board.get_piece(square) if board != null else null
	if piece == null:
		return false
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var mine: bool = piece.color == player_color
	var side_color: Color = ALLY if mine else ENEMY
	(_card.get_theme_stylebox("panel") as StyleBoxFlat).border_color = side_color
	var definition: PieceDef = piece.def

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = get_node("/root/PieceSkinManager").call("piece_texture", &"white" if piece.color == GameRules.PieceColor.WHITE else &"black", StringName(definition.id)) as Texture2D
	portrait.custom_minimum_size = Vector2(48, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(portrait)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_label(_t(String(definition.display_name_key)), 18, INK))
	var side: String = _t("PIECE_INFO_YOURS" if mine else "PIECE_INFO_ENEMY")
	var value_text: String = _t("PIECE_INFO_KING") if definition.is_king else _t("PREBATTLE_VALUE") % definition.base_value
	titles.add_child(_label("%s · %s" % [side, value_text], 11, side_color))
	head.add_child(titles)
	_body.add_child(head)

	var rules: HBoxContainer = HBoxContainer.new()
	rules.add_theme_constant_override("separation", 10)
	# The player's pieces advance up the screen, the enemy's down it.
	var grid: GridContainer = PieceRulePreview.make_grid(definition.id, GRID_SIZE, 12.0, piece.color == player_color)
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rules.add_child(grid)
	var words: VBoxContainer = VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	words.add_child(_label(_t(PieceRulePreview.move_key(definition)), 11, Color("#8fd8ee")))
	words.add_child(_label(_t(PieceRulePreview.attack_key(definition)), 11, Color("#f0a397")))
	words.add_child(_legend())
	rules.add_child(words)
	_body.add_child(rules)

	var traits: Array[String] = []
	for key: String in PieceRulePreview.ability_keys(definition):
		if key != "CODEX_TRAIT_NONE":
			traits.append("• " + _t(key))
	if not traits.is_empty():
		_body.add_child(_label("\n".join(traits), 11, GOLD_SOFT))

	var status: Array[String] = status_lines(board, square)
	if not status.is_empty():
		_body.add_child(HSeparator.new())
		_body.add_child(_label("\n".join(status), 11, INK))
	_body.add_child(_label(_t("PIECE_INFO_CLOSE"), 10, MUTED))
	shown_square = square
	visible = true
	return true

## What is true of this piece right now, one line each.
func status_lines(board: BoardState, square: Vector2i) -> Array[String]:
	var lines: Array[String] = []
	var piece: ChessPiece = board.get_piece(square)
	if piece == null:
		return lines
	var serial: int = board.turn_serial
	if piece.shield_until_serial > serial:
		lines.append(_t("PIECE_INFO_SHIELDED") % _turns_left(piece.shield_until_serial - serial))
	if piece.frozen_until_serial > serial:
		lines.append(_t("PIECE_INFO_FROZEN") % _turns_left(piece.frozen_until_serial - serial))
	elif board.is_piece_immobilized(square):
		lines.append(_t("PIECE_INFO_PINNED"))
	if piece.shell_left > 0:
		lines.append(_t("PIECE_INFO_SHELL") % piece.shell_left)
	if piece.revives_left > 0:
		lines.append(_t("PIECE_INFO_REVIVES") % piece.revives_left)
	if piece.def.evolve_at_captures > 0:
		lines.append(_t("PIECE_INFO_GROWTH") % [piece.capture_count, piece.def.evolve_at_captures])
	if not piece.learned_def_ids.is_empty():
		var names: Array[String] = []
		for id: String in piece.learned_def_ids:
			var learned: PieceDef = PieceDefDatabase.get_def(id)
			names.append(_t(String(learned.display_name_key)) if learned != null else id)
		lines.append(_t("PIECE_INFO_LEARNED") % ", ".join(names))
	return lines

## Turn serials count every half-move; a side gets a turn every two.
static func _turns_left(serials: int) -> int:
	return maxi(1, ceili(serials / 2.0))

func _legend() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for entry: Array in [["move", "PIECE_INFO_LEGEND_MOVE"], ["attack", "PIECE_INFO_LEGEND_ATTACK"], ["both", "PIECE_INFO_LEGEND_BOTH"]]:
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.color = PieceRulePreview.PATTERN_COLORS[entry[0]]
		row.add_child(swatch)
		row.add_child(_label(_t(entry[1]), 9, MUTED))
	return row

func _label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(10, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _t(key: String) -> String:
	return Localization.text(key)

class_name PieceInfoPanel
extends Control

## Read-only shared piece details. Only the explicit Close button, Escape or a
## backdrop click dismisses it; scrolling / tapping inside never closes the card.
signal closed

var shown_square: Vector2i = Vector2i(-1, -1)
var _card: PanelContainer
var _content: PieceDetailContent
var _scroll: ScrollContainer
var _previous_focus: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 50
	visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.75)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#12203a")
	style.border_color = Color("#e0b45c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	_scroll = ScrollContainer.new()
	_scroll.name = "DetailScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content = PieceDetailContent.new()
	_scroll.add_child(_content)
	column.add_child(_scroll)
	DragScroll.enable(_scroll)
	var back: Button = Button.new()
	back.name = "CloseButton"
	back.custom_minimum_size.y = 44
	back.text = _t("PIECE_INFO_CLOSE")
	back.focus_next = NodePath(".")
	back.focus_previous = NodePath(".")
	back.pressed.connect(close)
	column.add_child(back)
	resized.connect(_layout_card)
	_layout_card()

func _layout_card() -> void:
	if _card == null:
		return
	_card.size = Vector2(minf(520, maxf(1, size.x - 24)), minf(760, maxf(1, size.y - 40)))
	_card.position = (size - _card.size) * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed and not _card.get_rect().has_point(click.position):
			accept_event()
			close()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func is_open() -> bool:
	return visible

func close() -> void:
	visible = false
	shown_square = Vector2i(-1, -1)
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	closed.emit()

## Stable shared API: base PieceDef, optional owner/value context, optional live
## status lines and diagram orientation. Never selects or mutates a piece / Run.
func show_definition(definition: PieceDef, context: String = "", live_status: Array[String] = [], facing_up: bool = true) -> bool:
	if definition == null:
		return false
	if not visible:
		_previous_focus = get_viewport().gui_get_focus_owner()
	shown_square = Vector2i(-1, -1)
	_content.show_definition(definition, context, live_status, facing_up)
	_scroll.scroll_vertical = 0
	(_card.find_child("CloseButton", true, false) as Button).text = _t("PIECE_INFO_CLOSE")
	visible = true
	(_card.find_child("CloseButton", true, false) as Button).grab_focus()
	_layout_card()
	return true

func show_piece(board: BoardState, square: Vector2i, player_color: int) -> bool:
	var piece: ChessPiece = board.get_piece(square) if board != null else null
	if piece == null:
		return false
	var mine: bool = piece.color == player_color
	var context: String = _t("PIECE_INFO_YOURS" if mine else "PIECE_INFO_ENEMY")
	context += " · " + (_t("PIECE_INFO_KING") if piece.def.is_king else _t("PREBATTLE_VALUE") % piece.def.base_value)
	show_definition(piece.def, context, status_lines(board, square), mine)
	shown_square = square
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
	var shot: RangedAttackRule = piece.def.movement_rule(&"ranged_attack") as RangedAttackRule
	if shot != null and not shot.hits_adjacent and RangedAttackRule.is_engaged(board, square, piece.color):
		lines.append(_t("PIECE_INFO_ENGAGED"))
	if piece.def.is_king and board.is_king_guarded(square):
		lines.append(_t("PIECE_INFO_GUARDED"))
	if piece.def.is_egg:
		lines.append(_t("PIECE_INFO_EGG") % board.egg_turns_left(piece))
	if piece.shell_left > 0:
		lines.append(_t("PIECE_INFO_SHELL") % piece.shell_left)
	if piece.revives_left < 0:
		lines.append(_t("PIECE_INFO_REVIVES_ALWAYS"))
	elif piece.revives_left > 0:
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

func _t(key: String) -> String:
	return str(get_node("/root/Localization").call("text", key))

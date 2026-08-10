class_name BattleBoardView
extends Control

signal move_requested(from: Vector2i, to: Vector2i)

const BOARD_PIXELS := 315.0
const LIGHT := Color("#285064")
const DARK := Color("#102f45")

@onready var board_grid: GridContainer = $BoardCenter/BoardGrid
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var selected_square: Vector2i = Vector2i(-1, -1)
var legal_targets: Array[Vector2i] = []
var square_buttons: Dictionary = {}
var board: BoardState = null
var player_color: int = GameRules.PieceColor.WHITE

func _ready() -> void:
	piece_skin_manager.connect("skin_changed", _on_skin_changed)

func _exit_tree() -> void:
	if piece_skin_manager.is_connected("skin_changed", _on_skin_changed):
		piece_skin_manager.disconnect("skin_changed", _on_skin_changed)

func setup(board_value: BoardState, player_color_value: int) -> void:
	board = board_value
	player_color = player_color_value
	selected_square = Vector2i(-1, -1)
	legal_targets.clear()
	_build_squares()
	refresh(board)

func refresh(board_value: BoardState = null) -> void:
	if board_value != null:
		board = board_value
	if board == null:
		return
	if square_buttons.size() != board.board_size * board.board_size:
		_build_squares()
	for position_value: Variant in square_buttons.keys():
		var board_position: Vector2i = position_value
		var button: Button = square_buttons[board_position] as Button
		var piece: ChessPiece = board.get_piece(board_position)
		(button.get_node("Piece") as TextureRect).texture = _piece_texture(piece)
		var marker: TextureRect = button.get_node("MoveMarker") as TextureRect
		marker.texture = null
		marker.hide()
		if board_position == selected_square:
			marker.texture = load("res://assets/ui/battle/modern/selection_brackets.png") as Texture2D
			marker.show()
		elif board_position in legal_targets:
			marker.texture = load("res://assets/ui/battle/modern/attack_ring.png" if piece != null else "res://assets/ui/battle/modern/legal_dot.png") as Texture2D
			marker.show()
		_apply_square_style(button, board_position)

func clear_selection() -> void:
	selected_square = Vector2i(-1, -1)
	legal_targets.clear()
	refresh()

func set_selection_state(square: Vector2i, targets: Array[Vector2i]) -> void:
	selected_square = square
	legal_targets = targets.duplicate()
	refresh()

func _build_squares() -> void:
	for child: Node in board_grid.get_children():
		board_grid.remove_child(child)
		child.queue_free()
	square_buttons.clear()
	if board == null:
		return
	board_grid.custom_minimum_size = Vector2(BOARD_PIXELS, BOARD_PIXELS)
	board_grid.add_theme_constant_override("h_separation", 0)
	board_grid.add_theme_constant_override("v_separation", 0)
	board_grid.columns = board.board_size
	var cell_size: float = floorf(BOARD_PIXELS / float(board.board_size))
	for display_y: int in range(board.board_size):
		var y_position: int = board.board_size - 1 - display_y
		for x_position: int in range(board.board_size):
			var board_position: Vector2i = Vector2i(x_position, y_position)
			var button: Button = Button.new()
			button.name = "Square_%d_%d" % [x_position, y_position]
			button.custom_minimum_size = Vector2(cell_size, cell_size)
			button.focus_mode = Control.FOCUS_NONE
			button.clip_contents = true
			button.pressed.connect(_on_square_pressed.bind(board_position))
			var image: TextureRect = TextureRect.new()
			image.name = "Piece"
			image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(image)
			var marker: TextureRect = TextureRect.new()
			marker.name = "MoveMarker"
			marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
			marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marker.hide()
			button.add_child(marker)
			board_grid.add_child(button)
			square_buttons[board_position] = button

func _on_square_pressed(board_position: Vector2i) -> void:
	if board == null:
		return
	if board_position in legal_targets:
		move_requested.emit(selected_square, board_position)
		return
	var piece: ChessPiece = board.get_piece(board_position)
	if piece != null and piece.color == board.turn and piece.color == player_color:
		selected_square = board_position
		legal_targets = board.get_legal_moves(board_position)
	else:
		selected_square = Vector2i(-1, -1)
		legal_targets.clear()
	refresh()

func _piece_texture(piece: ChessPiece) -> Texture2D:
	if piece == null:
		return null
	var color: StringName = &"white" if piece.color == GameRules.PieceColor.WHITE else &"black"
	return piece_skin_manager.call("piece_texture", color, StringName(piece.def.id)) as Texture2D

func _apply_square_style(button: Button, board_position: Vector2i) -> void:
	var fill: Color = LIGHT if (board_position.x + board_position.y) % 2 == 0 else DARK
	if not board.move_history.is_empty():
		var move: Dictionary = board.move_history[-1]
		if board_position == move.get("from") or board_position == move.get("to"):
			fill = fill.lightened(0.08)
	var normal: StyleBoxFlat = _style(fill)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.06)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", normal)

func _style(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = fill
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _on_skin_changed(_skin_id: StringName) -> void:
	refresh()

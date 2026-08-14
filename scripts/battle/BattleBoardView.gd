class_name BattleBoardView
extends Control

signal move_requested(from: Vector2i, to: Vector2i)
signal item_target_requested(position: Vector2i)

const BOARD_PIXELS := 312.0
const LIGHT := Color("#285064")
const DARK := Color("#102f45")

@onready var board_grid: GridContainer = $BoardCenter/BoardGrid
@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var selected_square: Vector2i = Vector2i(-1, -1)
var legal_targets: Array[Vector2i] = []
var dangerous_targets: Array[Vector2i] = []
var square_buttons: Dictionary = {}
var board: BoardState = null
var player_color: int = GameRules.PieceColor.WHITE
var presentation_speed: float = 1.0
var item_targeting: bool = false
var _presentation_tweens: Array[Tween] = []
var _presentation_proxies: Array[TextureRect] = []

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
	dangerous_targets.clear()
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
		var danger_marker: Label = button.get_node("DangerMarker") as Label
		marker.texture = null
		marker.hide()
		danger_marker.visible = board_position in dangerous_targets
		if board_position == selected_square:
			marker.texture = load("res://assets/ui/battle/modern/selection_brackets.png") as Texture2D
			marker.show()
		elif board_position in legal_targets:
			marker.texture = load("res://assets/ui/battle/modern/attack_ring.png" if piece != null else "res://assets/ui/battle/modern/legal_dot.png") as Texture2D
			marker.show()
		_apply_square_style(button, board_position)

func present_events(events: Array[BattleEvent], speed: float = 1.0) -> void:
	var move_event: BattleEvent = null
	var captured: bool = false
	for event: BattleEvent in events:
		if event.event_type == BattleCommandProcessor.EVENT_PIECE_MOVED:
			move_event = event
		elif event.event_type == BattleCommandProcessor.EVENT_PIECE_CAPTURED:
			captured = true
	if move_event == null:
		return
	var data: Dictionary = move_event.payload
	var from: Vector2i = data.get("from", Vector2i(-1, -1))
	var to: Vector2i = data.get("to", Vector2i(-1, -1))
	if not square_buttons.has(from) or not square_buttons.has(to):
		return
	var source_button: Button = square_buttons[from] as Button
	var target_button: Button = square_buttons[to] as Button
	var piece_id: String = str(data.get("piece_def_id", "queen"))
	var color_id: StringName = &"white" if int(data.get("color", player_color)) == GameRules.PieceColor.WHITE else &"black"
	var proxy: TextureRect = TextureRect.new()
	proxy.texture = piece_skin_manager.call("piece_texture", color_id, StringName(piece_id)) as Texture2D
	proxy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	proxy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	proxy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.size = source_button.size
	proxy.global_position = source_button.global_position
	add_child(proxy)
	_presentation_proxies.append(proxy)
	var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
	var profile: PieceMotionProfile = definition.motion_profile if definition != null and definition.motion_profile != null else PieceMotionProfileDatabase.get_profile(&"queen")
	var duration: float = (profile.capture_duration if captured else profile.move_duration) / maxf(speed, 0.1)
	var tween: Tween = create_tween().bind_node(self).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tweens.append(tween)
	if profile.path_type == PieceMotionProfile.PathType.ARC:
		var midpoint: Vector2 = (source_button.global_position + target_button.global_position) * 0.5 - Vector2(0.0, source_button.size.y * profile.arc_height_cells)
		tween.tween_property(proxy, "global_position", midpoint, duration * 0.5)
		tween.tween_property(proxy, "global_position", target_button.global_position, duration * 0.5)
	else:
		tween.tween_property(proxy, "global_position", target_button.global_position, duration)
	if captured:
		tween.parallel().tween_property(proxy, "modulate", Color(1.35, 0.85, 0.65, 1.0), duration * 0.45)
	tween.tween_callback(_finish_proxy.bind(proxy, tween))

func skip_presentations() -> void:
	for tween: Tween in _presentation_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	for proxy: TextureRect in _presentation_proxies:
		if is_instance_valid(proxy):
			proxy.queue_free()
	_presentation_tweens.clear()
	_presentation_proxies.clear()

func _finish_proxy(proxy: TextureRect, tween: Tween) -> void:
	_presentation_tweens.erase(tween)
	_presentation_proxies.erase(proxy)
	if is_instance_valid(proxy):
		proxy.queue_free()

func begin_item_targeting() -> void:
	item_targeting = true
	selected_square = Vector2i(-1, -1)
	legal_targets.clear()
	dangerous_targets.clear()
	refresh()

func cancel_item_targeting() -> void:
	item_targeting = false

func clear_selection() -> void:
	selected_square = Vector2i(-1, -1)
	legal_targets.clear()
	dangerous_targets.clear()
	refresh()

func set_selection_state(square: Vector2i, targets: Array[Vector2i], dangers: Array[Vector2i] = []) -> void:
	selected_square = square
	legal_targets = targets.duplicate()
	dangerous_targets = dangers.duplicate()
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
			var danger_marker: Label = Label.new()
			danger_marker.name = "DangerMarker"
			danger_marker.text = "!"
			danger_marker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
			danger_marker.position = Vector2(cell_size - 22.0, 2.0)
			danger_marker.size = Vector2(18.0, 22.0)
			danger_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			danger_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			danger_marker.add_theme_color_override("font_color", Color("#ff5a52"))
			danger_marker.add_theme_color_override("font_outline_color", Color("#2a0710"))
			danger_marker.add_theme_constant_override("outline_size", 3)
			danger_marker.add_theme_font_size_override("font_size", 18)
			danger_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			danger_marker.hide()
			button.add_child(danger_marker)
			board_grid.add_child(button)
			square_buttons[board_position] = button

func _on_square_pressed(board_position: Vector2i) -> void:
	if board == null:
		return
	if item_targeting:
		item_targeting = false
		item_target_requested.emit(board_position)
		return
	if board_position in legal_targets:
		move_requested.emit(selected_square, board_position)
		return
	var piece: ChessPiece = board.get_piece(board_position)
	if piece != null and piece.color == board.turn and piece.color == player_color:
		selected_square = board_position
		legal_targets = board.get_executable_moves(board_position)
		dangerous_targets.clear()
		for target: Vector2i in legal_targets:
			if board.is_move_dangerous(board_position, target):
				dangerous_targets.append(target)
	else:
		selected_square = Vector2i(-1, -1)
		legal_targets.clear()
		dangerous_targets.clear()
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

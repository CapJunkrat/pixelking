class_name BattleBoardView
extends Control

## 2.5D battle board. The board is drawn in code on a tilted plane and pieces are
## standing sprites sorted by depth. This node is presentation and input only: it reads
## BoardState and BattleEvents and never changes authoritative battle state.

signal move_requested(from: Vector2i, to: Vector2i)
signal item_target_requested(position: Vector2i)
signal presentations_completed

const NO_SQUARE := Vector2i(-1, -1)
const SELECTED_TINT := Color(0.88, 0.71, 0.36, 0.55)
const CAPTURE_TINT := Color(0.88, 0.40, 0.35, 0.50)
const MOVE_DOT := Color(1.0, 0.94, 0.78, 0.72)
const CHECK_TINT := Color(0.95, 0.2, 0.2, 0.42)
const CHECK_GLOW := Color(1.0, 0.32, 0.28)
const PROMOTION_GLOW := Color(1.0, 0.886, 0.588)
## Speed multipliers applied when the player turns on short battle animations.
const SHORT_STRIKE_SPEED := 2.2
const SHORT_MOVE_SPEED := 1.5
const IMMOBILIZED_MODULATE := Color(0.56, 0.92, 1.0, 0.72)

@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var selected_square: Vector2i = NO_SQUARE
var legal_targets: Array[Vector2i] = []
var dangerous_targets: Array[Vector2i] = []
var board: BoardState = null
var player_color: int = GameRules.PieceColor.WHITE
var presentation_speed: float = 1.0
var item_targeting: bool = false
var input_enabled: bool = true
var projection: BoardProjection = BoardProjection.new()

var _pending_promotion: Vector2i = NO_SQUARE
var _pending_check: Dictionary = {}
var _board_canvas: Node2D = null
var _ground_canvas: Node2D = null
var _air_canvas: Node2D = null
var _strike: StrikeDirector = null
var _piece_layer: Node2D = null
var _overlay: Control = null
var _piece_sprites: Dictionary = {}
var _hidden_squares: Dictionary = {}
var _presentation_tweens: Array[Tween] = []
var _presentation_nodes: Array[Node] = []

func _ready() -> void:
	piece_skin_manager.connect("skin_changed", _on_skin_changed)
	_board_canvas = Node2D.new()
	_board_canvas.name = "BoardCanvas"
	_board_canvas.draw.connect(_draw_board)
	add_child(_board_canvas)
	_ground_canvas = Node2D.new()
	_ground_canvas.name = "GroundFx"
	_ground_canvas.draw.connect(_draw_proxy_shadows)
	add_child(_ground_canvas)
	_piece_layer = Node2D.new()
	_piece_layer.name = "PieceLayer"
	_piece_layer.y_sort_enabled = true
	add_child(_piece_layer)
	_air_canvas = Node2D.new()
	_air_canvas.name = "AirFx"
	_air_canvas.z_index = 10
	add_child(_air_canvas)
	_overlay = Control.new()
	_overlay.name = "MarkerOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_strike = StrikeDirector.new()
	_strike.name = "StrikeDirector"
	add_child(_strike)
	_strike.setup(self)
	_strike.finished.connect(_on_strike_finished)
	resized.connect(_on_resized)
	_update_projection()

func _exit_tree() -> void:
	if piece_skin_manager.is_connected("skin_changed", _on_skin_changed):
		piece_skin_manager.disconnect("skin_changed", _on_skin_changed)

func setup(board_value: BoardState, player_color_value: int) -> void:
	board = board_value
	player_color = player_color_value
	selected_square = NO_SQUARE
	legal_targets.clear()
	dangerous_targets.clear()
	_update_projection()
	refresh(board)

func refresh(board_value: BoardState = null) -> void:
	if board_value != null:
		board = board_value
	if board == null:
		return
	if projection.board_size != board.board_size:
		_update_projection()
	_rebuild_pieces()
	_redraw()

# --- geometry ---------------------------------------------------------------

func square_count() -> int:
	return 0 if board == null else board.board_size * board.board_size

## Centre of a square in this control's local coordinates.
func square_center(square: Vector2i) -> Vector2:
	return projection.square_center(square)

## Square a local point selects. A legal destination wins over a piece that visually
## overlaps it, then standing pieces (nearest first), then the bare square.
func square_at(point: Vector2) -> Vector2i:
	var ground: Vector2i = projection.screen_to_square(point)
	if ground != NO_SQUARE and ground in legal_targets:
		return ground
	if board != null:
		for rank: int in range(board.board_size):
			for file: int in range(board.board_size):
				var square: Vector2i = Vector2i(file, rank)
				var sprite: Sprite2D = _piece_sprites.get(square) as Sprite2D
				if sprite != null and sprite.visible and BoardPainter.sprite_hit_rect(sprite).has_point(point):
					return square
	return ground

## Same entry point as a tap on that square. Used by input handling and scene tests.
func press_square(square: Vector2i) -> void:
	_on_square_pressed(square)

func _redraw() -> void:
	if _board_canvas != null:
		_board_canvas.queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()

# --- hooks for strike animations ----------------------------------------------

func piece_layer() -> Node2D:
	return _piece_layer

func ground_canvas() -> Node2D:
	return _ground_canvas

func air_canvas() -> Node2D:
	return _air_canvas

## Square -> Sprite2D for every piece currently standing on the board.
func standing_sprites() -> Dictionary:
	return _piece_sprites

## How far in front of a square's centre a piece plants its feet, in world units.
func standing_offset() -> float:
	return projection.cell * BoardPainter.STAND_FORWARD_CELLS

func make_piece_sprite(texture: Texture2D) -> Sprite2D:
	return _make_piece_sprite(texture)

## Moves the whole board picture (zoom punch, shake). Identity restores it.
func set_camera(camera: Transform2D) -> void:
	for layer: Node2D in [_board_canvas, _ground_canvas, _piece_layer, _air_canvas]:
		if layer != null:
			layer.transform = camera

func _update_projection() -> void:
	var board_size: int = 8 if board == null else board.board_size
	var view: Vector2 = size if size.x > 0.0 and size.y > 0.0 else custom_minimum_size
	projection = BoardPainter.fit(board_size, view)
	if _strike != null:
		_strike.fx.projection = projection
		_strike.fx.unit = projection.cell / 18.0

func _on_resized() -> void:
	_update_projection()
	refresh()

# --- input ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var square: Vector2i = square_at(click.position)
	if square == NO_SQUARE:
		return
	accept_event()
	_on_square_pressed(square)

func _on_square_pressed(board_position: Vector2i) -> void:
	if board == null or not input_enabled or not board.in_bounds(board_position):
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
		selected_square = NO_SQUARE
		legal_targets.clear()
		dangerous_targets.clear()
	refresh()

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not input_enabled:
		item_targeting = false
		selected_square = NO_SQUARE
		legal_targets.clear()
		dangerous_targets.clear()
		_redraw()

func begin_item_targeting() -> void:
	item_targeting = true
	selected_square = NO_SQUARE
	legal_targets.clear()
	dangerous_targets.clear()
	refresh()

func cancel_item_targeting() -> void:
	item_targeting = false

func clear_selection() -> void:
	selected_square = NO_SQUARE
	legal_targets.clear()
	dangerous_targets.clear()
	refresh()

func set_selection_state(square: Vector2i, targets: Array[Vector2i], dangers: Array[Vector2i] = []) -> void:
	selected_square = square
	legal_targets = targets.duplicate()
	dangerous_targets = dangers.duplicate()
	refresh()

# --- board drawing ----------------------------------------------------------

func _draw_board() -> void:
	BoardPainter.draw_frame(_board_canvas, projection)
	if board == null:
		return
	var last_from: Vector2i = NO_SQUARE
	var last_to: Vector2i = NO_SQUARE
	if not board.move_history.is_empty():
		var move: Dictionary = board.move_history[-1]
		last_from = move.get("from", NO_SQUARE)
		last_to = move.get("to", NO_SQUARE)
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var fill: Color = BoardPainter.square_color(square)
			if square == last_from or square == last_to:
				fill = fill.lightened(0.14)
			BoardPainter.draw_square(_board_canvas, projection, square, fill)
	for color: int in [GameRules.PieceColor.WHITE, GameRules.PieceColor.BLACK]:
		if board.has_king(color) and board.is_in_check(color):
			_draw_square_marker(board.king_pos[color], CHECK_TINT)
	if selected_square != NO_SQUARE:
		_draw_square_marker(selected_square, SELECTED_TINT)
	for target: Vector2i in legal_targets:
		if board.get_piece(target) != null:
			_draw_square_marker(target, CAPTURE_TINT)
		else:
			_draw_ground_ellipse(target, projection.cell * 0.2, MOVE_DOT)
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			if board.get_piece(square) != null and not _hidden_squares.has(square):
				_draw_ground_ellipse(square, projection.cell * 0.33, BoardPainter.SHADOW)

func _draw_square_marker(square: Vector2i, tint: Color) -> void:
	BoardPainter.draw_marker(_board_canvas, projection, square, tint)

func _draw_ground_ellipse(square: Vector2i, radius: float, color: Color) -> void:
	BoardPainter.draw_ground_ellipse(_board_canvas, projection, square, radius, color)

func _draw_overlay() -> void:
	if board == null:
		return
	var font: Font = get_theme_default_font()
	if font == null:
		return
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var immobilized: bool = board.get_piece(square) != null and board.is_piece_immobilized(square)
			if not immobilized and square not in dangerous_targets:
				continue
			var polygon: PackedVector2Array = projection.square_polygon(square)
			var anchor: Vector2 = polygon[1] + Vector2(-13.0, 15.0)
			var text: String = "◆" if immobilized else "!"
			var color: Color = Color("#6ef0f2") if immobilized else Color("#ff5a52")
			_overlay.draw_string_outline(font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, 3, Color("#2a0710"))
			_overlay.draw_string(font, anchor, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, color)

# --- pieces -----------------------------------------------------------------

func _rebuild_pieces() -> void:
	for sprite_value: Variant in _piece_sprites.values():
		var old: Sprite2D = sprite_value as Sprite2D
		if is_instance_valid(old):
			_piece_layer.remove_child(old)
			old.queue_free()
	_piece_sprites.clear()
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var piece: ChessPiece = board.get_piece(square)
			if piece == null:
				continue
			var sprite: Sprite2D = _make_piece_sprite(_piece_texture(piece))
			if sprite == null:
				continue
			sprite.name = "Piece_%d_%d" % [file, rank]
			_place_sprite(sprite, projection.square_world(square))
			if board.is_piece_immobilized(square):
				sprite.modulate = IMMOBILIZED_MODULATE
			sprite.visible = not _hidden_squares.has(square)
			_piece_layer.add_child(sprite)
			_piece_sprites[square] = sprite

func _make_piece_sprite(texture: Texture2D) -> Sprite2D:
	return BoardPainter.make_sprite(texture, projection)

## Positions a piece sprite so its feet rest on `world` (Y lifts it off the board).
func _place_sprite(sprite: Sprite2D, world: Vector3) -> void:
	BoardPainter.place_sprite(sprite, projection, world)

func _piece_texture(piece: ChessPiece) -> Texture2D:
	if piece == null:
		return null
	var color: StringName = &"white" if piece.color == GameRules.PieceColor.WHITE else &"black"
	return piece_skin_manager.call("piece_texture", color, StringName(piece.def.id)) as Texture2D

func _on_skin_changed(_skin_id: StringName) -> void:
	refresh()

# --- move presentation ------------------------------------------------------

func present_events(events: Array[BattleEvent], speed: float = 1.0) -> void:
	var move_event: BattleEvent = null
	var capture_event: BattleEvent = null
	var castled: bool = false
	_pending_promotion = NO_SQUARE
	_pending_check = {}
	for event: BattleEvent in events:
		match event.event_type:
			BattleCommandProcessor.EVENT_PIECE_MOVED:
				move_event = event
			BattleCommandProcessor.EVENT_PIECE_CAPTURED:
				capture_event = event
			BattleCommandProcessor.EVENT_CASTLED:
				castled = true
			BattleCommandProcessor.EVENT_PROMOTED:
				_pending_promotion = event.payload.get("position", NO_SQUARE)
			BattleCommandProcessor.EVENT_CHECK_DECLARED:
				_pending_check = event.payload
	if board == null:
		return
	if move_event == null:
		_play_followups()
		return
	var data: Dictionary = move_event.payload
	var from: Vector2i = data.get("from", NO_SQUARE)
	var to: Vector2i = data.get("to", NO_SQUARE)
	if not board.in_bounds(from) or not board.in_bounds(to):
		_play_followups()
		return
	var short: bool = _short_animations()
	var captured: bool = capture_event != null
	var piece_id: String = str(data.get("piece_def_id", "queen"))
	if captured and _present_strike(data, capture_event.payload, speed * (SHORT_STRIKE_SPEED if short else 1.0)):
		return
	if short:
		speed *= SHORT_MOVE_SPEED
	var proxy: Sprite2D = _make_piece_sprite(_texture_for(int(data.get("color", player_color)), piece_id))
	if proxy == null:
		_play_followups()
		return
	var definition: PieceDef = PieceDefDatabase.get_def(piece_id)
	var profile: PieceMotionProfile = definition.motion_profile if definition != null and definition.motion_profile != null else PieceMotionProfileDatabase.get_profile(&"queen")
	var duration: float = (profile.capture_duration if captured else profile.move_duration) / maxf(speed, 0.1)
	var presentation_kind: StringName = presentation_kind_for(definition, captured)
	var weight: int = definition.weight_class if definition != null else PieceDef.WeightClass.MEDIUM
	var start: Vector3 = projection.square_world(from)
	var finish: Vector3 = projection.square_world(to)
	_place_sprite(proxy, start)
	_piece_layer.add_child(proxy)
	_presentation_nodes.append(proxy)
	# The authoritative board already shows the mover on its destination; keep that
	# sprite hidden until the travelling proxy arrives.
	_hidden_squares[to] = true
	var victim: Sprite2D = null
	if captured:
		var capture_data: Dictionary = capture_event.payload
		victim = _make_piece_sprite(_texture_for(int(capture_data.get("color", player_color)), str(capture_data.get("piece_def_id", ""))))
		if victim != null:
			_place_sprite(victim, projection.square_world(capture_data.get("position", to)))
			_piece_layer.add_child(victim)
			_presentation_nodes.append(victim)

	var tween: Tween = create_tween().bind_node(self).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tweens.append(tween)
	# Anticipation: every piece crouches briefly before it leaves its square.
	tween.tween_method(_stretch.bind(proxy), Vector2.ONE, Vector2(1.12, 0.86), 0.06 / maxf(speed, 0.1))
	match presentation_kind:
		&"teleport":
			tween.tween_property(proxy, "modulate:a", 0.0, duration * 0.35)
			tween.tween_callback(_place_sprite.bind(proxy, finish))
			tween.tween_property(proxy, "modulate:a", 1.0, duration * 0.35)
		&"bent_ray":
			var corner: Vector3 = projection.square_world(_bent_corner_square(definition, from, to))
			tween.tween_method(_travel.bind(proxy, start, corner, 0.0), 0.0, 1.0, duration * 0.35)
			tween.tween_method(_travel.bind(proxy, corner, finish, 0.0), 0.0, 1.0, duration * 0.65)
		&"lob":
			tween.tween_method(_travel.bind(proxy, start, finish, projection.cell * 1.6), 0.0, 1.0, duration)
		_:
			# Light pieces hop, heavy pieces slide; the castling king vaults over its partner.
			var arc: float = 0.0
			if castled:
				arc = projection.cell * 0.7
			elif profile.path_type == PieceMotionProfile.PathType.ARC:
				arc = projection.cell * profile.arc_height_cells
			elif weight == PieceDef.WeightClass.LIGHT:
				arc = projection.cell * 0.3
			var travel: float = maxf(duration, (0.13 + 0.03 * Vector2(to - from).length()) / maxf(speed, 0.1))
			tween.tween_method(_travel.bind(proxy, start, finish, arc), 0.0, 1.0, travel)
			tween.parallel().tween_method(_stretch.bind(proxy), Vector2(0.94, 1.08), Vector2(0.94, 1.08), travel)
	if presentation_kind == &"petrify":
		tween.parallel().tween_property(proxy, "modulate", Color(0.4, 1.25, 1.35, 1.0), duration * 0.6)
	elif presentation_kind == &"chained_capture":
		tween.tween_property(proxy, "modulate", Color(1.4, 1.2, 0.8, 1.0), duration * 0.18)
		tween.tween_property(proxy, "modulate", Color.WHITE, duration * 0.12)
	elif captured:
		tween.parallel().tween_property(proxy, "modulate", Color(1.35, 0.85, 0.65, 1.0), duration * 0.45)
	if victim != null:
		var fade: Tween = create_tween().bind_node(self)
		_presentation_tweens.append(fade)
		fade.tween_interval(duration * 0.8)
		fade.tween_property(victim, "modulate:a", 0.0, maxf(duration * 0.2, 0.01))
		fade.tween_callback(_finish_tween.bind(fade))
	if castled:
		_present_castling_partner(from, to, duration, speed)
	# Landing: a squash and a little dust, heavier pieces kick up more.
	tween.tween_callback(_land.bind(finish, weight))
	tween.tween_method(_stretch.bind(proxy), Vector2(1.16, 0.82), Vector2.ONE, 0.1 / maxf(speed, 0.1))
	tween.tween_callback(_finish_tween.bind(tween))

## Castling swaps the king with its partner: the partner slides back to the king's square.
func _present_castling_partner(king_from: Vector2i, king_to: Vector2i, duration: float, speed: float) -> void:
	var partner_piece: ChessPiece = board.get_piece(king_from)
	var partner: Sprite2D = _make_piece_sprite(_piece_texture(partner_piece))
	if partner == null:
		return
	var start: Vector3 = projection.square_world(king_to)
	var finish: Vector3 = projection.square_world(king_from)
	_place_sprite(partner, start)
	_piece_layer.add_child(partner)
	_presentation_nodes.append(partner)
	_hidden_squares[king_from] = true
	var travel: float = maxf(duration, (0.13 + 0.03 * Vector2(king_to - king_from).length()) / maxf(speed, 0.1))
	var slide: Tween = create_tween().bind_node(self).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tweens.append(slide)
	slide.tween_interval(0.06 / maxf(speed, 0.1))
	slide.tween_method(_travel.bind(partner, start, finish, 0.0), 0.0, 1.0, travel)
	slide.tween_callback(_land.bind(finish, PieceDef.WeightClass.HEAVY))
	slide.tween_method(_stretch.bind(partner), Vector2(1.12, 0.86), Vector2.ONE, 0.1 / maxf(speed, 0.1))
	slide.tween_callback(_finish_tween.bind(slide))

func _stretch(value: Vector2, sprite: Sprite2D) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.set_meta("stretch", value)
	sprite.scale = Vector2.ONE * float(sprite.get_meta("placed_scale", sprite.scale.x)) * value

func _land(world: Vector3, weight: int) -> void:
	if _strike == null:
		return
	_strike.fx.puff(world + Vector3(0.0, _strike.fx.unit, 0.0), 3 + weight * 2, 0.5 + 0.2 * weight)
	if weight == PieceDef.WeightClass.HEAVY:
		_strike.fx.ring(world.x, world.z, projection.cell * 0.5, 0.25)

func _short_animations() -> bool:
	var settings: AppSettingsManager = get_node_or_null("/root/SettingsManager") as AppSettingsManager
	return settings != null and settings.short_battle_animations

## Plays the capture as a full strike animation when the attacker has one. Returns
## false when the simple move presentation should be used instead.
func _present_strike(move_data: Dictionary, capture_data: Dictionary, speed: float) -> bool:
	var from: Vector2i = move_data.get("from", NO_SQUARE)
	var to: Vector2i = move_data.get("to", NO_SQUARE)
	# En passant hits a piece that does not stand on the destination square.
	var victim_square: Vector2i = capture_data.get("position", to)
	if not board.in_bounds(victim_square) or victim_square == from:
		return false
	var attacker_id: String = str(move_data.get("piece_def_id", ""))
	var attacker_def: PieceDef = PieceDefDatabase.get_def(attacker_id)
	if attacker_def == null or not StrikeDirector.can_play(StringName(attacker_id), attacker_def.strike_type):
		return false
	var victim_def: PieceDef = PieceDefDatabase.get_def(str(capture_data.get("piece_def_id", "")))
	var attacker_texture: Texture2D = _texture_for(int(move_data.get("color", player_color)), attacker_id)
	var victim_texture: Texture2D = _texture_for(int(capture_data.get("color", player_color)), str(capture_data.get("piece_def_id", "")))
	if victim_def == null or attacker_texture == null or victim_texture == null:
		return false
	_hidden_squares[to] = true
	_strike.play(StringName(attacker_id), attacker_texture, victim_texture, from, to, attacker_def.strike_type, attacker_def.weight_class, victim_def.weight_class, speed, victim_square)
	return true

func _on_strike_finished() -> void:
	if _presentation_tweens.is_empty():
		_end_presentation()

## Effects that play on the settled board after a move: promotion flash, check alarm.
func _play_followups() -> void:
	if board == null or _strike == null:
		return
	var fx: StrikeFx = _strike.fx
	if _pending_promotion != NO_SQUARE and board.in_bounds(_pending_promotion):
		var world: Vector3 = projection.square_world(_pending_promotion)
		fx.ring(world.x, world.z, projection.cell * 0.9, 0.45, PROMOTION_GLOW)
		fx.ring(world.x, world.z, projection.cell * 0.5, 0.3, PROMOTION_GLOW)
		fx.spark_burst(world + Vector3(0.0, projection.cell * 0.5, 0.0), 14, Vector2.ZERO, 0.0, 0.7)
		var promoted: Sprite2D = _piece_sprites.get(_pending_promotion) as Sprite2D
		if promoted != null:
			var rest: Vector2 = promoted.scale
			promoted.scale = rest * Vector2(0.55, 1.6)
			promoted.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(promoted, "scale", rest, 0.28)
	if not _pending_check.is_empty():
		var color: int = int(_pending_check.get("color", -1))
		if board.has_king(color):
			var king_square: Vector2i = board.king_pos[color]
			var world: Vector3 = projection.square_world(king_square)
			var mate: bool = bool(_pending_check.get("checkmate", false))
			fx.ring(world.x, world.z, projection.cell * (1.3 if mate else 0.9), 0.5, CHECK_GLOW)
			if mate:
				fx.ring(world.x, world.z, projection.cell * 0.7, 0.35, CHECK_GLOW)
			var king: Sprite2D = _piece_sprites.get(king_square) as Sprite2D
			if king != null:
				var home: Vector2 = king.position
				var shake: Tween = king.create_tween()
				for step: int in range(6):
					var reach: float = projection.cell * 0.09 * (1.0 - step / 6.0) * (1.0 if step % 2 == 0 else -1.0)
					shake.tween_property(king, "position", home + Vector2(reach, 0.0), 0.04)
				shake.tween_property(king, "position", home, 0.04)
	_pending_promotion = NO_SQUARE
	_pending_check = {}

func _draw_proxy_shadows() -> void:
	for node: Node in _presentation_nodes:
		if not is_instance_valid(node) or not node.has_meta("world"):
			continue
		var world: Vector3 = node.get_meta("world")
		var shrink: float = maxf(0.4, 1.0 - world.y / (projection.cell * 2.5))
		var radius: float = projection.cell * 0.33 * shrink
		var points: PackedVector2Array = PackedVector2Array()
		for step: int in range(16):
			var angle: float = TAU * step / 16.0
			points.append(projection.project(Vector3(world.x + cos(angle) * radius, 0.0, world.z + sin(angle) * radius)))
		_ground_canvas.draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.34 * shrink * (node as CanvasItem).modulate.a))

## Tween step: moves `sprite` from `start` to `finish`, lifting it along a parabola.
func _travel(progress: float, sprite: Sprite2D, start: Vector3, finish: Vector3, arc_height: float) -> void:
	if not is_instance_valid(sprite):
		return
	var world: Vector3 = start.lerp(finish, progress)
	world.y = arc_height * 4.0 * progress * (1.0 - progress)
	_place_sprite(sprite, world)
	_ground_canvas.queue_redraw()

func _texture_for(color: int, piece_id: String) -> Texture2D:
	var color_id: StringName = &"white" if color == GameRules.PieceColor.WHITE else &"black"
	return piece_skin_manager.call("piece_texture", color_id, StringName(piece_id)) as Texture2D

static func presentation_kind_for(definition: PieceDef, captured: bool = false) -> StringName:
	if definition == null:
		return &"standard"
	for rule: MovementRule in definition.resolved_movement_rules():
		if rule is TeleportMovementRule:
			return &"teleport"
		if rule is BentRayMovementRule:
			return &"bent_ray"
		if rule is SlideMovementRule and (rule as SlideMovementRule).jump_over_occupied:
			return &"lob"
	if definition.immobilizes_adjacent:
		return &"petrify"
	if captured and definition.extra_move_on_capture:
		return &"chained_capture"
	return &"standard"

func _bent_corner_square(definition: PieceDef, from: Vector2i, to: Vector2i) -> Vector2i:
	for rule: MovementRule in definition.resolved_movement_rules():
		var bent_rule: BentRayMovementRule = rule as BentRayMovementRule
		if bent_rule == null:
			continue
		for initial_direction: Vector2i in bent_rule.initial_directions:
			var corner: Vector2i = from + initial_direction
			var delta: Vector2i = to - corner
			for ray_direction: Vector2i in bent_rule.ray_directions:
				if delta.x * ray_direction.x + delta.y * ray_direction.y > 0 and delta.x * ray_direction.y == delta.y * ray_direction.x and board.in_bounds(corner):
					return corner
	return Vector2i(to.x, from.y)

func is_presenting() -> bool:
	return not _presentation_tweens.is_empty() or (_strike != null and _strike.is_playing())

func skip_presentations() -> void:
	for tween: Tween in _presentation_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_presentation_tweens.clear()
	if _strike != null:
		_strike.stop()
	_end_presentation()

func _finish_tween(tween: Tween) -> void:
	_presentation_tweens.erase(tween)
	if _presentation_tweens.is_empty() and not _strike.is_playing():
		_end_presentation()

func _end_presentation() -> void:
	for node: Node in _presentation_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_presentation_nodes.clear()
	_hidden_squares.clear()
	refresh()
	_ground_canvas.queue_redraw()
	_play_followups()
	presentations_completed.emit()

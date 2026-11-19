class_name BattleBoardView
extends Control

## 2.5D battle board. The board is drawn in code on a tilted plane and pieces are
## standing sprites sorted by depth. This node is presentation and input only: it reads
## BoardState and BattleEvents and never changes authoritative battle state.

signal move_requested(from: Vector2i, to: Vector2i)
signal item_target_requested(position: Vector2i)
signal presentations_completed
## A piece was held down long enough to ask what it does (works on either side's turn).
signal piece_info_requested(square: Vector2i)
## The piece the player is looking at changed: their selected piece, an inspected
## enemy, or NO_SQUARE when none.
signal focus_changed(square: Vector2i)
## The player tried to attack a piece that a shield protects (the opening King shield...).
signal shielded_target_tapped(square: Vector2i)

const NO_SQUARE := Vector2i(-1, -1)
const SELECTED_TINT := Color(0.88, 0.71, 0.36, 0.55)
const CAPTURE_TINT := Color(0.88, 0.40, 0.35, 0.50)
const MOVE_DOT := Color(1.0, 0.94, 0.78, 0.72)
const CHECK_TINT := Color(0.95, 0.2, 0.2, 0.42)
const CHECK_GLOW := Color(1.0, 0.32, 0.28)
const PROMOTION_GLOW := Color(1.0, 0.886, 0.588)
const CROSSHAIR := Color(1.0, 0.36, 0.3, 0.95)
const GUARD_GLOW := Color(1.0, 0.86, 0.45, 0.3)
const GUARD_RING := Color(1.0, 0.86, 0.45, 0.9)
## A tapped enemy piece's reach, in violet so it never reads as your own move hints
## (cream dots and red squares): violet dots where it can move, violet squares with
## a ring on your pieces it threatens.
const INSPECT_TINT := Color(0.62, 0.42, 0.95, 0.5)
const INSPECT_DOT := Color(0.74, 0.55, 1.0, 0.85)
const SHELL_PIP := Color("#c9c3b6")
const SHELL_PIP_SHINE := Color("#f4efe4")
const INSPECT_THREAT := Color(0.66, 0.36, 0.98, 0.5)
const INSPECT_RING := Color(0.8, 0.62, 1.0, 0.95)
## Speed multipliers applied when the player turns on short battle animations.
const SHORT_STRIKE_SPEED := 2.2
const SHORT_MOVE_SPEED := 1.5
## The execution blow plays a little faster than a normal King strike.
const EXECUTION_STRIKE_SPEED := 1.35
const STONE_SHADER: Shader = preload("res://assets/shaders/stone_piece.gdshader")
const PETRIFY_SECONDS := 0.8
const CRACK_SECONDS := 0.4
const GAZE_COLOR := Color(0.9, 1.0, 0.55)
const LONG_PRESS_SECONDS := 0.45
## A finger that drifts further than this (pixels) is not holding still.
const LONG_PRESS_SLOP := 14.0

@onready var piece_skin_manager: Node = get_node("/root/PieceSkinManager")

var selected_square: Vector2i = NO_SQUARE
var legal_targets: Array[Vector2i] = []
var dangerous_targets: Array[Vector2i] = []
## An enemy piece tapped to see its reach (NO_SQUARE when none), with the empty squares
## it can move to and the squares of your pieces it can capture.
var inspected_square: Vector2i = NO_SQUARE
var inspect_moves: Array[Vector2i] = []
var inspect_threats: Array[Vector2i] = []
var board: BoardState = null
var player_color: int = GameRules.PieceColor.WHITE
var presentation_speed: float = 1.0
var item_targeting: bool = false
var input_enabled: bool = true
## True while the opening transition plays; taps are ignored.
var intro_locked: bool = false
## Size of the shield domes (0 hides them); the opening transition pops them in.
var dome_scale: float = 1.0
var projection: BoardProjection = BoardProjection.new()

var _pending_promotion: Vector2i = NO_SQUARE
var _pending_check: Dictionary = {}
var _pending_bursts: Array[Vector2i] = []
var _last_speed: float = 1.0
var _pending_rings: Array[Vector2i] = []
## Pieces a blast or splash removes. The board has already lost them, so stand-ins
## keep them on screen until the explosion reaches them: [{square, sprite, def_id}].
var _doomed: Array[Dictionary] = []
var _doom_origin: Vector2i = NO_SQUARE
## &"impact" or &"split": which moment of the running strike sets off the blast.
var _doom_trigger: StringName = &""
## The lone King's fall, played after the move that left it alone (EVENT_KING_EXECUTION).
var _pending_execution: Dictionary = {}
## "Victory" / "Defeat" over the board once the deciding move has played out.
var _pending_banner: Dictionary = {}
var _execution_running: bool = false
## After the execution the winning King stays where it struck (the battle is over).
var _finale_hidden: Dictionary = {}
var _finale_nodes: Array[Node] = []
var _pillar_square: Vector2i = NO_SQUARE
var _pillar_strength: float = 0.0
var _banner: Control = null
## Extra victims of one blow (every enemy a boomerang passes through) each play the
## full hit reaction, in step with the main strike.
var _echo_strikes: Array[StrikeDirector] = []
var _board_canvas: Node2D = null
var _ground_canvas: Node2D = null
var _air_canvas: Node2D = null
var _strike: StrikeDirector = null
var _piece_layer: Node2D = null
var _overlay: Control = null
var _piece_sprites: Dictionary = {}
var _rock_sprites: Array[Sprite2D] = []
var _hidden_squares: Dictionary = {}
var _presentation_tweens: Array[Tween] = []
var _presentation_nodes: Array[Node] = []
## Pieces currently shown as stone (held by a gorgon), keyed by square + piece, so a
## piece that stays held does not replay the petrify animation on every refresh.
var _stone_keys: Dictionary = {}
## Gorgon gaze beams in flight: [gorgon square, target square, seconds elapsed].
var _gazes: Array = []
## The piece being held down for its info card: square, where and how long.
var _hold_square: Vector2i = NO_SQUARE
var _hold_point: Vector2 = Vector2.ZERO
var _hold_seconds: float = 0.0

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
	_air_canvas.draw.connect(_draw_gazes)
	_air_canvas.draw.connect(_draw_pillar)
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
	_strike.impacted.connect(_on_strike_moment.bind(&"impact"))
	_strike.victim_split.connect(_on_strike_moment.bind(&"split"))
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

## Opening transition: the board starts exactly where the pre-battle board stood
## (`source` in global coordinates) and glides into place over `seconds`.
func glide_in_from(source: Rect2, seconds: float) -> Tween:
	var size_now: int = 8 if board == null else board.board_size
	var from_projection: BoardProjection = BoardPainter.fit(size_now, source.size)
	var k: float = from_projection.cell / maxf(projection.cell, 1.0)
	var target_centre: Vector2 = source.position + from_projection.center - get_global_rect().position
	var start: Transform2D = Transform2D(0.0, Vector2(k, k), 0.0, target_centre - projection.center * k)
	set_camera(start)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float) -> void: set_camera(start.interpolate_with(Transform2D.IDENTITY, t)), 0.0, 1.0, seconds)
	return tween

## One side's pieces hop in place, one after another, as if waking up.
func hop_pieces(color: int, stagger: float = 0.035) -> void:
	var index: int = 0
	for square_value: Variant in _piece_sprites:
		var piece: ChessPiece = board.get_piece(square_value)
		var sprite: Sprite2D = _piece_sprites[square_value] as Sprite2D
		if piece == null or piece.color != color or sprite == null:
			continue
		var rest: float = sprite.position.y
		var hop: Tween = create_tween()
		hop.tween_interval(index * stagger)
		hop.tween_property(sprite, "position:y", rest - projection.cell * 0.32, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(sprite, "position:y", rest, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		index += 1

## Pops the shield domes in (they are hidden during the opening glide).
func pop_domes(seconds: float = 0.3) -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_dome_scale, 0.0, 1.0, seconds)

func _set_dome_scale(value: float) -> void:
	dome_scale = value
	if _overlay != null:
		_overlay.queue_redraw()

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
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _hold_square != NO_SQUARE and motion.position.distance_to(_hold_point) > LONG_PRESS_SLOP:
			_hold_square = NO_SQUARE
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not click.pressed:
		_hold_square = NO_SQUARE
		return
	if _execution_running:
		accept_event()
		_skip_execution()
		return
	_hold_square = piece_square_at(click.position)
	_hold_point = click.position
	_hold_seconds = 0.0
	var square: Vector2i = square_at(click.position)
	if square == NO_SQUARE:
		return
	accept_event()
	_on_square_pressed(square)

## The piece under a point, ignoring move targets (for long presses).
func piece_square_at(point: Vector2) -> Vector2i:
	if board == null:
		return NO_SQUARE
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var sprite: Sprite2D = _piece_sprites.get(square) as Sprite2D
			if sprite != null and sprite.visible and BoardPainter.sprite_hit_rect(sprite).has_point(point):
				return square
	var ground: Vector2i = projection.screen_to_square(point)
	return ground if ground != NO_SQUARE and board.get_piece(ground) != null else NO_SQUARE

## Counts a held piece towards a long press. Split out so tests can drive time.
func advance_hold(delta: float) -> void:
	if _hold_square == NO_SQUARE or item_targeting:
		return
	_hold_seconds += delta
	if _hold_seconds >= LONG_PRESS_SECONDS:
		var square: Vector2i = _hold_square
		_hold_square = NO_SQUARE
		if board != null and board.get_piece(square) != null:
			piece_info_requested.emit(square)

func _on_square_pressed(board_position: Vector2i) -> void:
	if board == null or not input_enabled or intro_locked or not board.on_board(board_position):
		return
	if item_targeting:
		item_targeting = false
		item_target_requested.emit(board_position)
		return
	if board_position in legal_targets:
		move_requested.emit(selected_square, board_position)
		return
	var piece: ChessPiece = board.get_piece(board_position)
	if piece != null and piece.color != player_color and selected_square != NO_SQUARE and piece.is_shielded(board.turn_serial):
		_pulse_shield(board_position)
		shielded_target_tapped.emit(board_position)
	var was_inspected: bool = board_position == inspected_square
	clear_inspection(false)
	if piece != null and piece.color != player_color and not was_inspected:
		selected_square = NO_SQUARE
		legal_targets.clear()
		dangerous_targets.clear()
		inspect(board_position)
		focus_changed.emit(board_position)
		return
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
	focus_changed.emit(selected_square)

## Pieces with a shell (Stone Giant) show how many hits it still absorbs: a row of
## pips over the head, filled for each layer left, hollow for each one broken.
func _draw_shell_pips() -> void:
	var piece_pixels: float = projection.cell * BoardPainter.PIECE_HEIGHT_CELLS
	var stand: float = standing_offset()
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var piece: ChessPiece = board.get_piece(square)
			if piece != null and piece.def.is_egg and not _hidden_squares.has(square):
				_draw_egg_count(square, piece, piece_pixels, stand)
				continue
			if piece == null or piece.def.shell_hits <= 0 or _hidden_squares.has(square):
				continue
			var world: Vector3 = projection.square_world(square)
			var top: Vector2 = projection.project(Vector3(world.x, projection.height_for_pixels(piece_pixels * 1.04), world.z + stand))
			var size: float = maxf(6.0, projection.cell * 0.2 * projection.square_scale(square))
			var gap: float = size * 0.5
			var total: int = piece.def.shell_hits
			var width: float = total * size + (total - 1) * gap
			var left: float = top.x - width * 0.5
			for index: int in range(total):
				var rect: Rect2 = Rect2(Vector2(left + index * (size + gap), top.y - size), Vector2(size, size))
				_overlay.draw_rect(rect.grow(1.0), Color("#1a1420"))
				if index < piece.shell_left:
					_overlay.draw_rect(rect, SHELL_PIP)
					_overlay.draw_rect(Rect2(rect.position, Vector2(size, size * 0.35)), SHELL_PIP_SHINE)
				else:
					_overlay.draw_rect(rect, Color(SHELL_PIP, 0.18))

## Turns until an egg hatches, in a small round badge over it.
func _draw_egg_count(square: Vector2i, egg: ChessPiece, piece_pixels: float, stand: float) -> void:
	var font: Font = get_theme_default_font()
	if font == null:
		return
	var world: Vector3 = projection.square_world(square)
	var top: Vector2 = projection.project(Vector3(world.x, projection.height_for_pixels(piece_pixels * 0.78), world.z + stand))
	var radius: float = maxf(7.0, projection.cell * 0.24 * projection.square_scale(square))
	var hard: bool = egg.def.egg_hardened
	_overlay.draw_circle(top, radius + 1.5, Color("#1a1018"))
	_overlay.draw_circle(top, radius, Color("#f5c860") if hard else Color("#ff8a3c"))
	var text: String = str(board.egg_turns_left(egg))
	var font_size: int = int(radius * 1.5)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_overlay.draw_string(font, top + Vector2(-width * 0.5, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#2a1206"))

## A shield flashes when the player tries to attack through it.
func _pulse_shield(square: Vector2i) -> void:
	if _strike == null or projection == null:
		return
	var at: Vector3 = projection.square_world(square)
	_strike.fx.ring(at.x, at.z, projection.cell * 0.75, 0.4, Color(0.67, 0.84, 1.0))
	_strike.fx.ring(at.x, at.z, projection.cell * 0.45, 0.3, Color(0.85, 0.94, 1.0))

## Shows where the enemy piece on `square` can move and what it can capture.
func inspect(square: Vector2i) -> void:
	inspected_square = square
	inspect_moves.clear()
	inspect_threats.clear()
	var piece: ChessPiece = board.get_piece(square) if board != null else null
	if piece == null:
		inspected_square = NO_SQUARE
		refresh()
		return
	# Everything it could do on its own turn (shots and captures included).
	for target: Vector2i in MoveGenerator.generate_pseudo_legal(board, square):
		if board.is_rock(target) or target == square:
			continue
		var occupant: ChessPiece = board.get_piece(target)
		if occupant == null:
			if target not in inspect_moves:
				inspect_moves.append(target)
		elif occupant.color != piece.color and target not in inspect_threats:
			inspect_threats.append(target)
	refresh()

func clear_inspection(redraw: bool = true) -> void:
	if inspected_square == NO_SQUARE:
		return
	inspected_square = NO_SQUARE
	inspect_moves.clear()
	inspect_threats.clear()
	if redraw:
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
	clear_inspection(false)
	item_targeting = true
	selected_square = NO_SQUARE
	legal_targets.clear()
	dangerous_targets.clear()
	refresh()

func cancel_item_targeting() -> void:
	item_targeting = false

func clear_selection() -> void:
	clear_inspection(false)
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
	_draw_bodyguards()
	if inspected_square != NO_SQUARE:
		_draw_square_marker(inspected_square, INSPECT_TINT)
		for target: Vector2i in inspect_threats:
			_draw_square_marker(target, INSPECT_THREAT)
			_board_canvas.draw_polyline(_world_ring(projection.square_world(target), projection.cell * 0.4), INSPECT_RING, maxf(1.5, projection.cell * 0.05))
		for target: Vector2i in inspect_moves:
			_draw_ground_ellipse(target, projection.cell * 0.17, INSPECT_DOT)
	for target: Vector2i in legal_targets:
		if _is_shot(target):
			_draw_square_marker(target, Color(CAPTURE_TINT, CAPTURE_TINT.a * 0.55))
		elif board.get_piece(target) != null:
			_draw_square_marker(target, CAPTURE_TINT)
		else:
			_draw_ground_ellipse(target, projection.cell * 0.2, MOVE_DOT)
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			if board.get_piece(square) != null and not _hidden_squares.has(square):
				_draw_ground_ellipse(square, projection.cell * 0.33, BoardPainter.SHADOW)
	for rock_value: Variant in board.rocks:
		_draw_ground_ellipse(rock_value, projection.cell * 0.4, BoardPainter.SHADOW)

func _is_shot(target: Vector2i) -> bool:
	return selected_square != NO_SQUARE and MoveGenerator.action_kind(board, selected_square, target) == RangedAttackRule.ACTION

## A ranged target: a red sight ring with four ticks, drawn above the pieces at about
## the middle of the target (the shooter stays put).
func _draw_crosshair(square: Vector2i) -> void:
	var piece_pixels: float = projection.cell * BoardPainter.PIECE_HEIGHT_CELLS
	var world: Vector3 = projection.square_world(square)
	var centre_world: Vector3 = Vector3(world.x, projection.height_for_pixels(piece_pixels * 0.3), world.z + standing_offset())
	var radius: float = projection.cell * 0.32
	var ring: PackedVector2Array = _world_ring(centre_world, radius)
	var width: float = maxf(1.5, projection.cell * 0.05)
	for pass_index: int in range(2):
		var colour: Color = Color("#2a0710") if pass_index == 0 else CROSSHAIR
		var line_width: float = width + 2.0 if pass_index == 0 else width
		_overlay.draw_polyline(ring, colour, line_width)
		for direction: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var inner: Vector2 = projection.project(centre_world + direction * radius * 0.7)
			var outer: Vector2 = projection.project(centre_world + direction * radius * 1.3)
			_overlay.draw_line(inner, outer, colour, line_width)

func _world_ring(centre: Vector3, radius: float) -> PackedVector2Array:
	var ring: PackedVector2Array = PackedVector2Array()
	for step: int in range(33):
		var angle: float = TAU * step / 32.0
		ring.append(projection.project(centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)))
	return ring

## Kings that ranged pieces cannot shoot (an ally stands next to them) get a soft gold
## ring, shown only while the other side has a ranged piece.
func _draw_bodyguards() -> void:
	for color: int in [GameRules.PieceColor.WHITE, GameRules.PieceColor.BLACK]:
		if not board.has_king(color) or not _has_ranged(GameRules.opposite(color)):
			continue
		var square: Vector2i = board.king_pos[color]
		if board.is_king_guarded(square):
			_draw_ground_ellipse(square, projection.cell * 0.46, GUARD_GLOW)
			_board_canvas.draw_polyline(_world_ring(projection.square_world(square), projection.cell * 0.46), GUARD_RING, maxf(1.5, projection.cell * 0.05))

func _has_ranged(color: int) -> bool:
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var piece: ChessPiece = board.get_piece(Vector2i(file, rank))
			if piece != null and piece.color == color and piece.def.is_ranged():
				return true
	return false

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
	# Shielded pieces (opening King shield, Martyr, Holy Water, Iron Crown) wear a dome.
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var shielded: ChessPiece = board.get_piece(Vector2i(file, rank))
			if shielded == null or not shielded.is_shielded(board.turn_serial) or _hidden_squares.has(Vector2i(file, rank)):
				continue
			var base: Vector2 = projection.project(projection.square_world(Vector2i(file, rank)))
			var radius: float = projection.cell * 0.5 * projection.square_scale(Vector2i(file, rank)) * dome_scale
			if radius <= 0.5:
				continue
			var dome: PackedVector2Array = PackedVector2Array()
			for step: int in range(25):
				var angle: float = PI + PI * step / 24.0
				dome.append(base + Vector2(cos(angle) * radius, sin(angle) * radius * 3.0 + projection.cell * 0.08))
			_overlay.draw_polyline(dome, Color(0.67, 0.84, 1.0, 0.75), 2.0)
			_overlay.draw_colored_polygon(dome, Color(0.67, 0.84, 1.0, 0.12))
	_draw_shell_pips()
	for target: Vector2i in legal_targets:
		if _is_shot(target):
			_draw_crosshair(target)
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
	for rock: Sprite2D in _rock_sprites:
		if is_instance_valid(rock):
			_piece_layer.remove_child(rock)
			rock.queue_free()
	_rock_sprites.clear()
	for square_value: Variant in board.rocks:
		var square: Vector2i = square_value
		var rock: Sprite2D = _make_piece_sprite(RockArt.texture())
		rock.name = "Rock_%d_%d" % [square.x, square.y]
		_place_sprite(rock, projection.square_world(square))
		_piece_layer.add_child(rock)
		_rock_sprites.append(rock)
	for sprite_value: Variant in _piece_sprites.values():
		var old: Sprite2D = sprite_value as Sprite2D
		if is_instance_valid(old):
			_piece_layer.remove_child(old)
			old.queue_free()
	_piece_sprites.clear()
	var previous_stone: Dictionary = _stone_keys
	_stone_keys = {}
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
				_show_stone(sprite, square, piece, previous_stone)
			sprite.visible = not _hidden_squares.has(square)
			_piece_layer.add_child(sprite)
			_piece_sprites[square] = sprite

## Held pieces turn to stone. A newly held piece petrifies from the feet up under the
## gorgon's gaze; while a move is still animating it waits so the gorgon arrives first.
func _show_stone(sprite: Sprite2D, square: Vector2i, piece: ChessPiece, previous: Dictionary) -> void:
	var key: String = "%d_%d_%s_%d" % [square.x, square.y, piece.def.id, piece.color]
	var known: bool = previous.has(key)
	if not known and is_presenting():
		return
	_stone_keys[key] = true
	var chunks: PieceChunks = PieceChunks.of(sprite.texture)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STONE_SHADER
	material.set_shader_parameter(&"used", chunks.used_uv())
	material.set_shader_parameter(&"aspect", chunks.aspect)
	material.set_shader_parameter(&"seed", float(square.x * 7 + square.y * 3))
	material.set_shader_parameter(&"progress", 1.0 if known else 0.0)
	material.set_shader_parameter(&"crack", 1.0 if known else 0.0)
	sprite.material = material
	if known:
		return
	var gorgon: Vector2i = _holding_gorgon(square, piece)
	if gorgon != NO_SQUARE:
		_gazes.append([gorgon, square, 0.0])
	var tween: Tween = create_tween()
	tween.tween_method(_set_stone.bind(material, &"progress"), 0.0, 1.0, PETRIFY_SECONDS / presentation_speed)
	tween.tween_method(_set_stone.bind(material, &"crack"), 0.0, 1.0, CRACK_SECONDS / presentation_speed)

func _set_stone(value: float, material: ShaderMaterial, parameter: StringName) -> void:
	material.set_shader_parameter(parameter, value)

func _holding_gorgon(square: Vector2i, piece: ChessPiece) -> Vector2i:
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var neighbour: Vector2i = square + Vector2i(dx, dy)
			if neighbour == square or not board.in_bounds(neighbour):
				continue
			var other: ChessPiece = board.get_piece(neighbour)
			if other != null and other.color != piece.color and other.def.immobilizes_adjacent:
				return neighbour
	return NO_SQUARE

func _process(delta: float) -> void:
	advance_hold(delta)
	if _gazes.is_empty():
		return
	for gaze: Array in _gazes:
		gaze[2] = float(gaze[2]) + delta * presentation_speed
	_gazes = _gazes.filter(func(gaze: Array) -> bool: return float(gaze[2]) < 0.6)
	_air_canvas.queue_redraw()

## The gorgon's eyes light up and a wavering beam reaches the piece it holds.
func _draw_gazes() -> void:
	var stand: float = standing_offset()
	for gaze: Array in _gazes:
		var age: float = float(gaze[2])
		var alpha: float = clampf(age / 0.12, 0.0, 1.0) * (1.0 - clampf((age - 0.4) / 0.2, 0.0, 1.0))
		var source: Vector3 = projection.square_world(gaze[0])
		var target: Vector3 = projection.square_world(gaze[1])
		var piece_pixels: float = projection.cell * BoardPainter.PIECE_HEIGHT_CELLS
		var eye_height: float = projection.height_for_pixels(piece_pixels * 0.62)
		var eye: Vector2 = projection.project(Vector3(source.x, eye_height, source.z + stand))
		var hit: Vector2 = projection.project(Vector3(target.x, projection.height_for_pixels(piece_pixels * 0.45), target.z + stand))
		var unit: float = projection.cell / 18.0
		var waver: Vector2 = Vector2(0.0, sin(age * 50.0) * unit)
		_air_canvas.draw_line(eye, hit + waver, Color(GAZE_COLOR, 0.25 * alpha), 4.0 * unit)
		_air_canvas.draw_line(eye - Vector2(unit, 0.0), hit + waver, Color(GAZE_COLOR, alpha), maxf(unit, 1.0))
		_air_canvas.draw_line(eye + Vector2(unit, 0.0), hit - waver, Color(GAZE_COLOR, alpha), maxf(unit, 1.0))
		_air_canvas.draw_rect(Rect2(eye - Vector2(2.0, 0.5) * unit, Vector2(unit, unit)), Color(GAZE_COLOR, alpha))
		_air_canvas.draw_rect(Rect2(eye + Vector2(1.0, -0.5) * unit, Vector2(unit, unit)), Color(GAZE_COLOR, alpha))

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
	clear_inspection(false)
	var move_event: BattleEvent = null
	var capture_event: BattleEvent = null
	var shell_event: BattleEvent = null
	var castled: bool = false
	_pending_promotion = NO_SQUARE
	_pending_check = {}
	_pending_bursts = []
	_pending_rings = []
	_pending_execution = {}
	_pending_banner = {}
	_clear_finale()
	_clear_echoes()
	var destroyed: Array[Dictionary] = []
	var broken_rocks: Array[Vector2i] = []
	for event: BattleEvent in events:
		match event.event_type:
			BattleCommandProcessor.EVENT_PIECE_MOVED:
				move_event = event
			BattleCommandProcessor.EVENT_PIECE_CAPTURED:
				capture_event = event
			BattleCommandProcessor.EVENT_CASTLED, BattleCommandProcessor.EVENT_KING_SWAPPED:
				castled = true
			BattleCommandProcessor.EVENT_KING_EXECUTION:
				# Played after the move: the winning King blinks over and strikes it down.
				_pending_execution = event.payload
			BattleCommandProcessor.EVENT_BATTLE_ENDED:
				if not bool(event.payload.get("draw", false)) and int(event.payload.get("winner", -1)) >= 0:
					_pending_banner = {"won": int(event.payload.get("winner", -1)) == player_color}
			BattleCommandProcessor.EVENT_PIECE_DESTROYED:
				destroyed.append(event.payload)
			BattleCommandProcessor.EVENT_ROCK_BROKEN:
				_pending_bursts.append(event.payload.get("position", NO_SQUARE))
				broken_rocks.append(event.payload.get("position", NO_SQUARE))
			BattleCommandProcessor.EVENT_SHELL_BROKEN:
				if shell_event == null:
					shell_event = event
				else:
					_pending_rings.append(event.payload.get("position", NO_SQUARE))
			BattleCommandProcessor.EVENT_LAST_STAND:
				_pending_rings.append(event.payload.get("position", NO_SQUARE))
			BattleCommandProcessor.EVENT_PIECE_REVIVED, BattleCommandProcessor.EVENT_PIECE_EVOLVED, BattleCommandProcessor.EVENT_FORM_CHANGED, BattleCommandProcessor.EVENT_MOVE_LEARNED:
				_pending_rings.append(event.payload.get("position", NO_SQUARE))
			BattleCommandProcessor.EVENT_EGG_LAID:
				# The egg appears once the bird has fallen.
				var egg_square: Vector2i = event.payload.get("position", NO_SQUARE)
				_hidden_squares[egg_square] = true
				_pending_rings.append(egg_square)
			BattleCommandProcessor.EVENT_PROMOTED:
				_pending_promotion = event.payload.get("position", NO_SQUARE)
			BattleCommandProcessor.EVENT_CHECK_DECLARED:
				_pending_check = event.payload
	if board == null:
		return
	_last_speed = speed
	# Enemies a boomerang passes through react like the main target, at the same moment.
	var pierced: Array[Dictionary] = []
	if capture_event != null:
		for entry: Dictionary in destroyed.duplicate():
			if str(entry.get("cause", "")) == "pierce":
				pierced.append(entry)
				destroyed.erase(entry)
	_spawn_doomed(destroyed, move_event, capture_event)
	# A broken rock stays until the move lands (it bursts with the follow-up effects).
	for square: Vector2i in broken_rocks:
		if board.on_board(square):
			var rock: Sprite2D = _make_piece_sprite(RockArt.texture())
			if rock != null:
				_place_sprite(rock, projection.square_world(square))
				_piece_layer.add_child(rock)
				_presentation_nodes.append(rock)
	if not _pending_execution.is_empty():
		_hold_doomed_king(_pending_execution)
	if move_event == null:
		_finish_without_move()
		return
	var data: Dictionary = move_event.payload
	var from: Vector2i = data.get("from", NO_SQUARE)
	var to: Vector2i = data.get("to", NO_SQUARE)
	if not board.in_bounds(from) or not board.in_bounds(to):
		_finish_without_move()
		return
	var short: bool = _short_animations()
	var captured: bool = capture_event != null
	var piece_id: String = str(data.get("piece_def_id", "queen"))
	if captured and _present_strike(data, capture_event.payload, speed * (SHORT_STRIKE_SPEED if short else 1.0)):
		for entry: Dictionary in pierced:
			_play_echo_strike(data, entry, speed * (SHORT_STRIKE_SPEED if short else 1.0))
		# A Powder Keg goes off when it bursts; any other blast when the blow lands.
		_doom_trigger = &"split" if NewPieceStrikes.victim_reaction(StringName(str(capture_event.payload.get("piece_def_id", "")))) == &"keg" else &"impact"
		return
	if not pierced.is_empty():
		var fallback: Array[Dictionary] = []
		fallback.assign(pierced)
		_spawn_doomed(fallback, move_event, capture_event)
	# A shell that absorbed the blow: the strike plays, the victim stays, the attacker bounces back.
	if not captured and shell_event != null:
		var shelled_square: Vector2i = shell_event.payload.get("position", NO_SQUARE)
		var shelled: ChessPiece = board.get_piece(shelled_square)
		if shelled != null and shelled_square == data.get("target", NO_SQUARE):
			var shell_data: Dictionary = {"position": shelled_square, "piece_def_id": shelled.def.id, "color": shelled.color}
			if _present_strike(data, shell_data, speed * (SHORT_STRIKE_SPEED if short else 1.0)):
				_hidden_squares[shelled_square] = true
				_doom_trigger = &"impact"
				return
		_pending_rings.append(shelled_square)
	if short:
		speed *= SHORT_MOVE_SPEED
	var proxy: Sprite2D = _make_piece_sprite(_texture_for(int(data.get("color", player_color)), piece_id))
	if proxy == null:
		_finish_without_move()
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
		fade.tween_callback(_detonate_doomed)
		fade.tween_property(victim, "modulate:a", 0.0, maxf(duration * 0.2, 0.01))
		fade.tween_callback(_finish_tween.bind(fade))
	elif not _doomed.is_empty():
		tween.tween_callback(_detonate_doomed)
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
	if attacker_def == null:
		return false
	# Forms of one piece (Squire levels, tide states) share that piece's attack.
	# Hybrids moving like a knight borrow the knight's stomp (see StrikeDirector.resolve_attack).
	var aim: Vector2i = move_data.get("target", to)
	var attack: Array = StrikeDirector.resolve_attack(StringName(attacker_def.art_key()), attacker_def.strike_type, from, aim)
	var attack_id: StringName = attack[0]
	var strike_type: int = attack[1]
	if not StrikeDirector.can_play(attack_id, strike_type):
		return false
	var victim_def: PieceDef = PieceDefDatabase.get_def(str(capture_data.get("piece_def_id", "")))
	var attacker_texture: Texture2D = _texture_for(int(move_data.get("color", player_color)), attacker_id)
	var victim_texture: Texture2D = _texture_for(int(capture_data.get("color", player_color)), str(capture_data.get("piece_def_id", "")))
	if victim_def == null or attacker_texture == null or victim_texture == null:
		return false
	_hidden_squares[to] = true
	var corner: Vector2i = NO_SQUARE
	if presentation_kind_for(attacker_def) == &"bent_ray":
		corner = _bent_corner_square(attacker_def, from, to)
	_strike.mimic_texture = _texture_for(int(move_data.get("color", player_color)), str(capture_data.get("piece_def_id", "")))
	_strike.play(attack_id, attacker_texture, victim_texture, from, to, strike_type, attacker_def.weight_class, victim_def.weight_class, speed, victim_square, corner, StringName(victim_def.id))
	return true

func _on_strike_finished() -> void:
	if _presentation_tweens.is_empty() and not _echoes_playing():
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
	for square: Vector2i in _pending_bursts:
		if board.on_board(square):
			var burst_at: Vector3 = projection.square_world(square)
			fx.puff(burst_at + Vector3(0.0, fx.unit * 4.0, 0.0), 10, 1.0)
			fx.spark_burst(burst_at + Vector3(0.0, projection.cell * 0.3, 0.0), 12, Vector2.ZERO, 0.0, 0.9)
	for square: Vector2i in _pending_rings:
		if board.in_bounds(square):
			var ring_at: Vector3 = projection.square_world(square)
			fx.ring(ring_at.x, ring_at.z, projection.cell * 0.8, 0.4, PROMOTION_GLOW)
	_pending_bursts = []
	_pending_rings = []
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
	world.y = lerpf(start.y, finish.y, progress) + arc_height * 4.0 * progress * (1.0 - progress)
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
		if rule is RangeTeleportMovementRule and (rule as RangeTeleportMovementRule).once_ability.is_empty():
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
	return not _presentation_tweens.is_empty() or (_strike != null and _strike.is_playing()) or _echoes_playing()

func _echoes_playing() -> bool:
	for echo: StrikeDirector in _echo_strikes:
		if is_instance_valid(echo) and echo.is_playing():
			return true
	return false

## The hit reaction of one extra victim of the current blow (same attack, same timing).
func _play_echo_strike(move_data: Dictionary, entry: Dictionary, speed: float) -> void:
	var from: Vector2i = move_data.get("from", NO_SQUARE)
	var to: Vector2i = move_data.get("to", NO_SQUARE)
	var victim_square: Vector2i = entry.get("position", NO_SQUARE)
	var attacker_id: String = str(move_data.get("piece_def_id", ""))
	var attacker_def: PieceDef = PieceDefDatabase.get_def(attacker_id)
	var victim_def: PieceDef = PieceDefDatabase.get_def(str(entry.get("piece_def_id", "")))
	if attacker_def == null or victim_def == null or not board.in_bounds(victim_square):
		return
	var attack: Array = StrikeDirector.resolve_attack(StringName(attacker_def.art_key()), attacker_def.strike_type, from, victim_square)
	var attacker_texture: Texture2D = _texture_for(int(move_data.get("color", player_color)), attacker_id)
	var victim_texture: Texture2D = _texture_for(int(entry.get("color", player_color)), victim_def.id)
	if attacker_texture == null or victim_texture == null or not StrikeDirector.can_play(attack[0], attack[1]):
		return
	var echo: StrikeDirector = StrikeDirector.new()
	echo.name = "EchoStrike"
	echo.victim_only = true
	add_child(echo)
	echo.setup(self)
	echo.finished.connect(_on_echo_finished)
	_echo_strikes.append(echo)
	echo.play(attack[0], attacker_texture, victim_texture, from, to, attack[1], attacker_def.weight_class, victim_def.weight_class, speed, victim_square, NO_SQUARE, StringName(victim_def.id))
	echo.align_impact(_strike)

func _on_echo_finished() -> void:
	if _presentation_tweens.is_empty() and not _strike.is_playing() and not _echoes_playing():
		_end_presentation()

## Echo strikes that have finished and faded are removed before the next blow.
func _clear_echoes(force: bool = false) -> void:
	var kept: Array[StrikeDirector] = []
	for echo: StrikeDirector in _echo_strikes:
		if not is_instance_valid(echo):
			continue
		if force or not echo.is_playing():
			echo.stop()
			echo.queue_free()
		else:
			kept.append(echo)
	_echo_strikes = kept

## A tap during the execution jumps straight to the banner.
func _skip_execution() -> void:
	_execution_running = false
	if _finale_nodes.is_empty():
		_finale_hidden.clear()
	for tween: Tween in _presentation_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_presentation_tweens.clear()
	_pillar_square = NO_SQUARE
	_air_canvas.queue_redraw()
	if _strike != null:
		_strike.stop()
	_clear_echoes(true)
	_end_presentation()

func skip_presentations() -> void:
	_pending_execution = {}
	for tween: Tween in _presentation_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_presentation_tweens.clear()
	if _strike != null:
		_strike.stop()
	_clear_echoes(true)
	_end_presentation()

func _finish_tween(tween: Tween) -> void:
	_presentation_tweens.erase(tween)
	if _presentation_tweens.is_empty() and not _strike.is_playing() and not _echoes_playing():
		_end_presentation()

func _end_presentation() -> void:
	_detonate_doomed()
	if not _presentation_tweens.is_empty():
		return
	for node: Node in _presentation_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_presentation_nodes.clear()
	_hidden_squares = _finale_hidden.duplicate()
	_execution_running = false
	_strike.time_scale = 1.0
	refresh()
	for node: Node in _finale_nodes:
		if is_instance_valid(node):
			(node as CanvasItem).visible = true
	_ground_canvas.queue_redraw()
	_play_followups()
	# The battle's last word: the execution, then the banner, then the result screen.
	if not _pending_execution.is_empty():
		var execution: Dictionary = _pending_execution
		_pending_execution = {}
		_start_execution(execution)
		return
	if not _pending_banner.is_empty():
		var banner: Dictionary = _pending_banner
		_pending_banner = {}
		_show_banner(bool(banner.get("won", true)))
		return
	presentations_completed.emit()

## A move-less action (an item) or a move that could not be animated.
func _finish_without_move() -> void:
	if not _doomed.is_empty():
		_doom_origin = _doomed[0]["square"]
		_detonate_doomed()
		return
	if not _pending_execution.is_empty() or not _pending_banner.is_empty():
		_end_presentation()
		return
	_play_followups()

# --- blasts: pieces caught by an explosion or splash ----------------------------

## Stand-ins for the pieces a blast will remove, so they stay on the board until the
## explosion reaches them. The attacker blown up with a Powder Keg is left to the strike.
func _spawn_doomed(destroyed: Array[Dictionary], move_event: BattleEvent, capture_event: BattleEvent) -> void:
	_doomed = []
	_doom_trigger = &""
	_doom_origin = NO_SQUARE
	if capture_event != null:
		_doom_origin = capture_event.payload.get("position", NO_SQUARE)
	var landing: Vector2i = move_event.payload.get("to", NO_SQUARE) if move_event != null else NO_SQUARE
	for entry: Dictionary in destroyed:
		var square: Vector2i = entry.get("position", NO_SQUARE)
		if not board.in_bounds(square):
			continue
		if square == landing and capture_event != null:
			_pending_bursts.append(square)
			continue
		var sprite: Sprite2D = _make_piece_sprite(_texture_for(int(entry.get("color", player_color)), str(entry.get("piece_def_id", ""))))
		if sprite == null:
			_pending_bursts.append(square)
			continue
		_place_sprite(sprite, projection.square_world(square))
		_piece_layer.add_child(sprite)
		_presentation_nodes.append(sprite)
		_doomed.append({"square": square, "sprite": sprite, "def_id": str(entry.get("piece_def_id", ""))})
	if _doom_origin == NO_SQUARE and not _doomed.is_empty():
		_doom_origin = _doomed[0]["square"]

func _sfx(sound: StringName, volume_db: float = 0.0) -> void:
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", sound, volume_db)

func _on_strike_moment(moment: StringName) -> void:
	if not _doomed.is_empty() and moment == _doom_trigger:
		_detonate_doomed()
	if moment == &"impact" and _execution_running and not _short_animations():
		_slow_motion()

## The blast reaches the doomed pieces one after another, nearest first: each one
## flashes, is thrown clear of the blast and fades in a puff of smoke.
func _detonate_doomed() -> void:
	if _doomed.is_empty():
		return
	var doomed: Array[Dictionary] = _doomed
	_doomed = []
	var origin: Vector2i = _doom_origin
	doomed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a["square"] - origin).length() < Vector2(b["square"] - origin).length())
	var speed: float = maxf(_last_speed * (SHORT_STRIKE_SPEED if _short_animations() else 1.0), 0.1)
	for index: int in range(doomed.size()):
		var entry: Dictionary = doomed[index]
		var sprite: Sprite2D = entry["sprite"]
		var square: Vector2i = entry["square"]
		if not is_instance_valid(sprite):
			continue
		var away: Vector2 = Vector2(square - origin)
		if away.length() < 0.1:
			away = Vector2(randf_range(-1.0, 1.0), -1.0)
		away = away.normalized()
		var start: Vector3 = projection.square_world(square)
		var finish: Vector3 = start + Vector3(away.x, 0.0, -away.y) * projection.cell * 1.3
		var flight: float = 0.5 / speed
		var tween: Tween = create_tween().bind_node(self)
		_presentation_tweens.append(tween)
		tween.tween_interval((0.04 + 0.09 * index) / speed)
		tween.tween_callback(_blast_hit.bind(square, entry["def_id"] == "powder_keg"))
		tween.tween_property(sprite, "modulate", Color(2.2, 1.5, 0.9, 1.0), 0.05 / speed)
		tween.tween_method(_travel.bind(sprite, start, finish, projection.cell * 0.9), 0.0, 1.0, flight)
		tween.parallel().tween_property(sprite, "rotation", (1.0 if away.x >= 0.0 else -1.0) * 2.4, flight)
		tween.parallel().tween_property(sprite, "modulate", Color(0.35, 0.3, 0.3, 0.0), flight).set_ease(Tween.EASE_IN)
		tween.tween_callback(_finish_tween.bind(tween))

func _blast_hit(square: Vector2i, keg: bool) -> void:
	if _strike == null:
		return
	_sfx(&"explode", -3.0 if not keg else 0.0)
	var fx: StrikeFx = _strike.fx
	var at: Vector3 = projection.square_world(square)
	fx.puff(at + Vector3(0.0, fx.unit * 4.0, 0.0), 14 if keg else 8, 1.4 if keg else 1.0)
	fx.spark_burst(at + Vector3(0.0, projection.cell * 0.3, 0.0), 16 if keg else 10, Vector2.ZERO, 0.0, 1.0, Color(1.0, 0.59, 0.24))
	if keg:
		fx.ring(at.x, at.z, projection.cell * 1.6, 0.5, Color(1.0, 0.59, 0.24))

# --- the end of a battle: execution and banner --------------------------------

## The lone King's fall: it trembles, the winning King dissolves into light and
## reappears beside it, then strikes it down (slow motion on the blow).
func _start_execution(execution: Dictionary) -> void:
	var winner_square: Vector2i = execution.get("from", NO_SQUARE)
	var loser_square: Vector2i = execution.get("to", NO_SQUARE)
	if not board.in_bounds(winner_square) or not board.in_bounds(loser_square):
		_end_presentation()
		return
	_execution_running = true
	var short: bool = _short_animations()
	var speed: float = maxf(_last_speed, 0.1) * (2.2 if short else 1.0)
	var winner_color: int = int(execution.get("color", player_color))
	var loser_color: int = int(execution.get("victim_color", GameRules.opposite(winner_color)))
	var killer_id: String = str(execution.get("piece_def_id", "king"))
	var victim_id: String = str(execution.get("victim_def_id", "king"))
	var approach: Vector2i = execution_approach(board, loser_square, winner_square)
	_hidden_squares[winner_square] = true
	_finale_hidden[winner_square] = true
	refresh()
	var king: Sprite2D = _make_piece_sprite(_texture_for(winner_color, killer_id))
	var doomed_king: Sprite2D = _make_piece_sprite(_texture_for(loser_color, victim_id))
	if king == null or doomed_king == null:
		_end_presentation()
		return
	var home: Vector3 = projection.square_world(winner_square)
	var beside: Vector3 = projection.square_world(approach)
	_place_sprite(king, home)
	_place_sprite(doomed_king, projection.square_world(loser_square))
	for sprite: Sprite2D in [king, doomed_king]:
		_piece_layer.add_child(sprite)
		_presentation_nodes.append(sprite)
	_hidden_squares[loser_square] = true
	var tween: Tween = create_tween().bind_node(self)
	_presentation_tweens.append(tween)
	# 1. A beat of silence; the doomed King trembles.
	var doomed_rest: Vector2 = doomed_king.position
	tween.tween_method(_tremble.bind(doomed_king, doomed_rest), 0.0, 1.0, 0.4 / speed)
	# 2. The winner crouches and dissolves into golden motes...
	tween.tween_method(_stretch.bind(king), Vector2.ONE, Vector2(1.16, 0.8), 0.15 / speed)
	tween.parallel().tween_method(_tremble.bind(doomed_king, doomed_rest), 0.0, 1.0, 0.15 / speed)
	tween.tween_callback(_motes.bind(winner_square))
	tween.tween_property(king, "modulate", Color(2.4, 2.0, 0.9, 0.0), 0.2 / speed)
	tween.parallel().tween_method(_stretch.bind(king), Vector2(1.16, 0.8), Vector2(0.4, 1.5), 0.2 / speed)
	tween.parallel().tween_method(_tremble.bind(doomed_king, doomed_rest), 0.0, 1.0, 0.2 / speed)
	# ...and drops out of a pillar of light beside the doomed King.
	tween.tween_callback(_begin_pillar.bind(approach))
	tween.tween_callback(_stretch.bind(Vector2.ONE, king))
	tween.tween_method(_set_pillar, 0.0, 1.0, 0.08 / speed)
	tween.tween_method(_travel.bind(king, beside + Vector3(0.0, projection.cell * 1.2, 0.0), beside, 0.0), 0.0, 1.0, 0.16 / speed)
	tween.parallel().tween_property(king, "modulate", Color(1.6, 1.4, 0.9, 1.0), 0.16 / speed)
	tween.parallel().tween_method(_tremble.bind(doomed_king, doomed_rest), 0.0, 1.0, 0.16 / speed)
	tween.tween_callback(_land.bind(beside, PieceDef.WeightClass.HEAVY))
	tween.tween_property(king, "modulate", Color.WHITE, 0.12 / speed)
	tween.parallel().tween_method(_set_pillar, 1.0, 0.0, 0.25 / speed)
	# 3. The blow: the King's own strike from beside the victim.
	tween.tween_callback(_execution_strike.bind(execution, approach, loser_square, winner_color, loser_color, speed, king, doomed_king))
	tween.tween_callback(_finish_tween.bind(tween))

## The board has already lost the lone King; keep it standing until its execution.
func _hold_doomed_king(execution: Dictionary) -> void:
	var square: Vector2i = execution.get("to", NO_SQUARE)
	if not board.in_bounds(square):
		return
	var color: int = int(execution.get("victim_color", GameRules.opposite(int(execution.get("color", player_color)))))
	var sprite: Sprite2D = _make_piece_sprite(_texture_for(color, str(execution.get("victim_def_id", "king"))))
	if sprite == null:
		return
	_place_sprite(sprite, projection.square_world(square))
	_piece_layer.add_child(sprite)
	_presentation_nodes.append(sprite)

func _execution_strike(execution: Dictionary, approach: Vector2i, loser_square: Vector2i, winner_color: int, loser_color: int, speed: float, king: Sprite2D, doomed_king: Sprite2D) -> void:
	var move_data: Dictionary = {"from": approach, "to": loser_square, "target": loser_square, "piece_def_id": str(execution.get("piece_def_id", "king")), "color": winner_color}
	var capture_data: Dictionary = {"position": loser_square, "piece_def_id": str(execution.get("victim_def_id", "king")), "color": loser_color}
	_finale_king(str(execution.get("piece_def_id", "king")), winner_color, loser_square)
	if _present_strike(move_data, capture_data, speed * EXECUTION_STRIKE_SPEED):
		for sprite: Sprite2D in [king, doomed_king]:
			if is_instance_valid(sprite):
				sprite.visible = false
		return
	# No strike animation for this King: a plain blow and burst.
	_blast_hit(loser_square, false)
	if is_instance_valid(doomed_king):
		doomed_king.visible = false

## Where the winning King appears: the empty square next to the doomed King that is
## closest to where it stood (any neighbour if all are taken).
static func execution_approach(state: BoardState, loser_square: Vector2i, winner_square: Vector2i) -> Vector2i:
	var best: Vector2i = NO_SQUARE
	var best_distance: float = INF
	var fallback: Vector2i = NO_SQUARE
	var fallback_distance: float = INF
	for offset: Vector2i in BoardState.NEIGHBORS:
		var square: Vector2i = loser_square + offset
		if not state.on_board(square):
			continue
		var distance: float = Vector2(square - winner_square).length()
		if distance < fallback_distance and not state.is_rock(square):
			fallback = square
			fallback_distance = distance
		if state.get_piece(square) == null and not state.is_rock(square) and distance < best_distance:
			best = square
			best_distance = distance
	if best != NO_SQUARE:
		return best
	return fallback if fallback != NO_SQUARE else winner_square

## A new move after the end (only in tests and replays): forget the last finale.
func _clear_finale() -> void:
	for node: Node in _finale_nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	_finale_nodes.clear()
	_finale_hidden.clear()
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	_banner = null

## The winning King keeps its final place until the battle screen closes.
func _finale_king(piece_id: String, color: int, square: Vector2i) -> void:
	for node: Node in _finale_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_finale_nodes.clear()
	var sprite: Sprite2D = _make_piece_sprite(_texture_for(color, piece_id))
	if sprite == null:
		return
	sprite.name = "FinaleKing"
	_place_sprite(sprite, projection.square_world(square))
	sprite.visible = false
	_piece_layer.add_child(sprite)
	_finale_nodes.append(sprite)
	_finale_hidden[square] = true

func _tremble(progress: float, sprite: Sprite2D, rest: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	var reach: float = projection.cell * 0.05 * (0.6 + 0.4 * progress)
	sprite.position = rest + Vector2(sin(Time.get_ticks_msec() * 0.07) * reach, 0.0)

func _motes(square: Vector2i) -> void:
	if _strike == null:
		return
	var at: Vector3 = projection.square_world(square)
	_strike.fx.spark_burst(at + Vector3(0.0, projection.cell * 0.4, 0.0), 22, Vector2.ZERO, 0.0, 0.8, Color(1.0, 0.85, 0.45))
	_strike.fx.ring(at.x, at.z, projection.cell * 0.7, 0.35, Color(1.0, 0.85, 0.45))

func _begin_pillar(square: Vector2i) -> void:
	_pillar_square = square
	_pillar_strength = 0.0
	if _strike != null:
		var at: Vector3 = projection.square_world(square)
		_strike.fx.ring(at.x, at.z, projection.cell * 0.9, 0.4, Color(1.0, 0.9, 0.6))

func _set_pillar(value: float) -> void:
	_pillar_strength = value
	if value <= 0.0:
		_pillar_square = NO_SQUARE
	_air_canvas.queue_redraw()

func _draw_pillar() -> void:
	if _pillar_square == NO_SQUARE or _pillar_strength <= 0.0:
		return
	var at: Vector3 = projection.square_world(_pillar_square)
	var foot: Vector2 = projection.project(at + Vector3(0.0, 0.0, standing_offset()))
	var width: float = projection.cell * 0.55 * projection.square_scale(_pillar_square) * _pillar_strength
	var height: float = projection.cell * 5.0
	var bands: int = 8
	for band: int in range(bands):
		var q: float = float(band) / bands
		var rect: Rect2 = Rect2(foot.x - width * 0.5, foot.y - height * (1.0 - q), width, height / bands + 1.0)
		_air_canvas.draw_rect(rect, Color(1.0, 0.92, 0.65, 0.75 * _pillar_strength * q))
	_air_canvas.draw_rect(Rect2(foot.x - width * 0.15, foot.y - height, width * 0.3, height), Color(1.0, 1.0, 0.9, 0.6 * _pillar_strength))

## The killing blow plays in slow motion for a moment.
func _slow_motion() -> void:
	_strike.time_scale = 0.3
	var timer: SceneTreeTimer = get_tree().create_timer(0.6)
	timer.timeout.connect(func() -> void:
		if _strike != null:
			_strike.time_scale = 1.0)

## "Victory" (gold) or "Defeat" (dim) slams down over the board, then the battle ends.
func _show_banner(won: bool) -> void:
	var short: bool = _short_animations()
	if _banner != null and is_instance_valid(_banner):
		_banner.queue_free()
	_banner = Control.new()
	_banner.name = "EndBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_banner)
	var band: ColorRect = ColorRect.new()
	band.color = Color(0.08, 0.05, 0.02, 0.72) if won else Color(0.06, 0.03, 0.06, 0.78)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.size = Vector2(size.x, 92.0)
	band.position = Vector2(0.0, size.y * 0.42 - 46.0)
	_banner.add_child(band)
	for edge_y: float in [0.0, 90.0]:
		var edge: ColorRect = ColorRect.new()
		edge.color = Color("#f5c860") if won else Color("#8a6a74")
		edge.size = Vector2(size.x, 2.0)
		edge.position = Vector2(0.0, edge_y)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(edge)
	var label: Label = Label.new()
	label.text = _banner_text("BATTLE_BANNER_VICTORY" if won else "BATTLE_BANNER_DEFEAT")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = band.size
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", Color("#ffd876") if won else Color("#c9a0a8"))
	label.add_theme_color_override("font_outline_color", Color("#3a2304") if won else Color("#1a0d12"))
	label.add_theme_constant_override("outline_size", 10)
	label.pivot_offset = band.size * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(label)
	band.pivot_offset = band.size * 0.5
	var rest_y: float = band.position.y
	band.position.y = -band.size.y
	var speed: float = 2.0 if short else 1.0
	var tween: Tween = create_tween().bind_node(self)
	_presentation_tweens.append(tween)
	tween.tween_property(band, "position:y", rest_y, 0.28 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_banner_landed.bind(won))
	tween.tween_property(label, "scale", Vector2(1.14, 1.14), 0.08 / speed)
	tween.tween_property(label, "scale", Vector2.ONE, 0.14 / speed)
	tween.tween_interval(0.7 / speed)
	tween.tween_callback(_finish_tween.bind(tween))

func _banner_landed(won: bool) -> void:
	_sfx(&"victory" if won else &"defeat")
	if _strike == null:
		return
	var centre: Vector3 = projection.square_world(Vector2i(board.board_size / 2, board.board_size / 2))
	if won:
		for color: Color in [Color("#f5c860"), Color("#fff2c4"), Color("#4fd1c5")]:
			_strike.fx.spark_burst(centre + Vector3(0.0, projection.cell * 2.0, 0.0), 18, Vector2.ZERO, 0.0, 1.4, color)
	else:
		_strike.fx.puff(centre + Vector3(0.0, projection.cell, 0.0), 10, 1.2)

func _banner_text(key: String) -> String:
	var localization: Node = get_node_or_null("/root/Localization")
	return str(localization.call("text", key)) if localization != null else key

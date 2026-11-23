class_name BoardMarkerLayer
extends RefCounted

## Everything the battle board draws about the position besides the pieces themselves.
## On the board canvas: squares, last move, check, selection, move and capture hints,
## an inspected enemy's reach, bodyguard rings and shadows. On the overlay above the
## pieces: shield domes, shell pips, egg timers, sights for shots, held pieces, and
## the safety marks on the selected piece's destinations (BoardInputHandler sorts them).

const NO_SQUARE := Vector2i(-1, -1)
const SELECTED_TINT := Color(0.88, 0.71, 0.36, 0.55)
const CAPTURE_TINT := Color(0.88, 0.40, 0.35, 0.50)
const MOVE_DOT := Color(1.0, 0.94, 0.78, 0.72)
const CHECK_TINT := Color(0.95, 0.2, 0.2, 0.42)
const CROSSHAIR := Color(1.0, 0.36, 0.3, 0.95)
const GUARD_GLOW := Color(1.0, 0.86, 0.45, 0.3)
const GUARD_RING := Color(1.0, 0.86, 0.45, 0.9)
## A tapped enemy piece's reach, in violet so it never reads as your own move hints
## (cream dots and red squares): violet dots where it can move, violet squares with
## a ring on your pieces it threatens.
const INSPECT_TINT := Color(0.62, 0.42, 0.95, 0.5)
const INSPECT_DOT := Color(0.74, 0.55, 1.0, 0.85)
const INSPECT_THREAT := Color(0.66, 0.36, 0.98, 0.5)
const INSPECT_RING := Color(0.8, 0.62, 1.0, 0.95)
const SHELL_PIP := Color("#c9c3b6")
const SHELL_PIP_SHINE := Color("#f4efe4")
const PROTECTED_MARK := Color("#f0a93a")
## Shells and shields: the same ice blue as the shield domes and shell pips.
const SHELL_MARK := Color("#a9d6ff")
const DANGER_MARK := Color("#ff5a52")

var view: BattleBoardView = null
var _board_canvas: Node2D = null
var _overlay: Control = null

func _init(owner_view: BattleBoardView, board_canvas: Node2D, overlay: Control) -> void:
	view = owner_view
	_board_canvas = board_canvas
	_overlay = overlay

# --- board canvas ---------------------------------------------------------------

func draw_board() -> void:
	var projection: BoardProjection = view.projection
	BoardPainter.draw_frame(_board_canvas, projection)
	var board: BoardState = view.board
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
	if view.selected_square != NO_SQUARE:
		_draw_square_marker(view.selected_square, SELECTED_TINT)
	_draw_bodyguards()
	if view.inspected_square != NO_SQUARE:
		_draw_square_marker(view.inspected_square, INSPECT_TINT)
		for target: Vector2i in view.inspect_threats:
			_draw_square_marker(target, INSPECT_THREAT)
			_board_canvas.draw_polyline(_world_ring(projection.square_world(target), projection.cell * 0.4), INSPECT_RING, maxf(1.5, projection.cell * 0.05))
		for target: Vector2i in view.inspect_moves:
			_draw_ground_ellipse(target, projection.cell * 0.17, INSPECT_DOT)
	for target: Vector2i in view.legal_targets:
		if _is_shot(target):
			_draw_square_marker(target, Color(CAPTURE_TINT, CAPTURE_TINT.a * 0.55))
		elif board.get_piece(target) != null:
			_draw_square_marker(target, CAPTURE_TINT)
		else:
			_draw_ground_ellipse(target, projection.cell * 0.2, MOVE_DOT)
	var hidden: Dictionary = view.pieces.hidden
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			if board.get_piece(square) != null and not hidden.has(square):
				_draw_ground_ellipse(square, projection.cell * 0.33, BoardPainter.SHADOW)
	for rock_value: Variant in board.rocks:
		_draw_ground_ellipse(rock_value, projection.cell * 0.4, BoardPainter.SHADOW)

func _is_shot(target: Vector2i) -> bool:
	return view.selected_square != NO_SQUARE and MoveGenerator.action_kind(view.board, view.selected_square, target) == RangedAttackRule.ACTION

func _world_ring(centre: Vector3, radius: float) -> PackedVector2Array:
	var ring: PackedVector2Array = PackedVector2Array()
	for step: int in range(33):
		var angle: float = TAU * step / 32.0
		ring.append(view.projection.project(centre + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)))
	return ring

## Kings that ranged pieces cannot shoot (an ally stands next to them) get a soft gold
## ring, shown only while the other side has a ranged piece.
func _draw_bodyguards() -> void:
	var board: BoardState = view.board
	var projection: BoardProjection = view.projection
	for color: int in [GameRules.PieceColor.WHITE, GameRules.PieceColor.BLACK]:
		if not board.has_king(color) or not _has_ranged(GameRules.opposite(color)):
			continue
		var square: Vector2i = board.king_pos[color]
		if board.is_king_guarded(square):
			_draw_ground_ellipse(square, projection.cell * 0.46, GUARD_GLOW)
			_board_canvas.draw_polyline(_world_ring(projection.square_world(square), projection.cell * 0.46), GUARD_RING, maxf(1.5, projection.cell * 0.05))

func _has_ranged(color: int) -> bool:
	var board: BoardState = view.board
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var piece: ChessPiece = board.get_piece(Vector2i(file, rank))
			if piece != null and piece.color == color and piece.def.is_ranged():
				return true
	return false

func _draw_square_marker(square: Vector2i, tint: Color) -> void:
	BoardPainter.draw_marker(_board_canvas, view.projection, square, tint)

func _draw_ground_ellipse(square: Vector2i, radius: float, color: Color) -> void:
	BoardPainter.draw_ground_ellipse(_board_canvas, view.projection, square, radius, color)

# --- overlay --------------------------------------------------------------------

func draw_overlay() -> void:
	var board: BoardState = view.board
	if board == null:
		return
	var font: Font = view.get_theme_default_font()
	if font == null:
		return
	var projection: BoardProjection = view.projection
	var hidden: Dictionary = view.pieces.hidden
	# Shielded pieces (opening King shield, Martyr, Holy Water, Iron Crown) wear a dome.
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var shielded: ChessPiece = board.get_piece(Vector2i(file, rank))
			if shielded == null or not shielded.is_shielded(board.turn_serial) or hidden.has(Vector2i(file, rank)):
				continue
			var base: Vector2 = projection.project(projection.square_world(Vector2i(file, rank)))
			var radius: float = projection.cell * 0.5 * projection.square_scale(Vector2i(file, rank)) * view.dome_scale
			if radius <= 0.5:
				continue
			var dome: PackedVector2Array = PackedVector2Array()
			for step: int in range(25):
				var angle: float = PI + PI * step / 24.0
				dome.append(base + Vector2(cos(angle) * radius, sin(angle) * radius * 3.0 + projection.cell * 0.08))
			_overlay.draw_polyline(dome, Color(0.67, 0.84, 1.0, 0.75), 2.0)
			_overlay.draw_colored_polygon(dome, Color(0.67, 0.84, 1.0, 0.12))
	_draw_shell_pips()
	for target: Vector2i in view.legal_targets:
		if _is_shot(target):
			_draw_crosshair(target)
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var immobilized: bool = board.get_piece(square) != null and board.is_piece_immobilized(square)
			if not immobilized:
				_draw_target_mark(square, font)
				continue
			var polygon: PackedVector2Array = projection.square_polygon(square)
			var anchor: Vector2 = polygon[1] + Vector2(-13.0, 15.0)
			_overlay.draw_string_outline(font, anchor, "◆", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, 3, Color("#2a0710"))
			_overlay.draw_string(font, anchor, "◆", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#6ef0f2"))

## A ranged target: a red sight ring with four ticks, drawn above the pieces at about
## the middle of the target (the shooter stays put).
func _draw_crosshair(square: Vector2i) -> void:
	var projection: BoardProjection = view.projection
	var piece_pixels: float = projection.cell * BoardPainter.PIECE_HEIGHT_CELLS
	var world: Vector3 = projection.square_world(square)
	var centre_world: Vector3 = Vector3(world.x, projection.height_for_pixels(piece_pixels * 0.3), world.z + view.standing_offset())
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

## The marks in the top-right corner of a destination square (see
## BoardInputHandler._mark_targets).
func _draw_target_mark(square: Vector2i, font: Font) -> void:
	var corner: Vector2 = view.projection.square_polygon(square)[1]
	if square in view.dangerous_targets:
		_draw_bang(font, corner + Vector2(-13.0, 15.0), 16)
	elif square in view.protected_targets:
		_draw_shield_icon(corner + Vector2(-18.0, 9.0), 1.0, PROTECTED_MARK, 1.0, false)
		_draw_bang(font, corner + Vector2(-10.0, 16.0), 15)
	elif square in view.shell_risk_targets:
		_draw_shield_icon(corner + Vector2(-18.0, 9.0), 1.0, SHELL_MARK, 1.0, true)
		_draw_bang(font, corner + Vector2(-10.0, 16.0), 15)
	elif square in view.guarded_targets:
		_draw_shield_icon(corner + Vector2(-8.0, 8.0), 0.7, PROTECTED_MARK, 0.5, false)
	if square in view.shell_strike_targets:
		var left_corner: Vector2 = view.projection.square_polygon(square)[0]
		_draw_shield_icon(left_corner + Vector2(9.0, 9.0), 0.9, SHELL_MARK, 1.0, true)

func _draw_bang(font: Font, anchor: Vector2, font_size: int) -> void:
	_overlay.draw_string_outline(font, anchor, "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, Color("#2a0710"))
	_overlay.draw_string(font, anchor, "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, DANGER_MARK)

## A small heater shield. Amber: another of your pieces covers the square. Ice blue
## and cracked: a shell takes the blow and breaks.
func _draw_shield_icon(centre: Vector2, scale_value: float, fill: Color, alpha: float, cracked: bool) -> void:
	var w: float = 6.5 * scale_value
	var h: float = 8.0 * scale_value
	var shield: PackedVector2Array = PackedVector2Array([
		centre + Vector2(-w, -h), centre + Vector2(w, -h), centre + Vector2(w, h * 0.15),
		centre + Vector2(0.0, h), centre + Vector2(-w, h * 0.15),
	])
	var outline: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in shield:
		outline.append(centre + (point - centre) * 1.3)
	_overlay.draw_colored_polygon(outline, Color(Color("#1a1420"), alpha))
	_overlay.draw_colored_polygon(shield, Color(fill, alpha))
	var line: float = maxf(1.0, 1.5 * scale_value)
	if cracked:
		var crack: PackedVector2Array = PackedVector2Array([
			centre + Vector2(-w * 0.2, -h), centre + Vector2(w * 0.25, -h * 0.35),
			centre + Vector2(-w * 0.3, h * 0.1), centre + Vector2(w * 0.15, h * 0.6), centre + Vector2(0.0, h),
		])
		_overlay.draw_polyline(crack, Color(Color("#1a1420"), alpha), line + 0.5)
	else:
		var shine: Color = Color(Color("#fff1c4"), alpha)
		_overlay.draw_line(centre + Vector2(0.0, -h + 2.0 * scale_value), centre + Vector2(0.0, h - 2.5 * scale_value), shine, line)
		_overlay.draw_line(centre + Vector2(-w + 2.0 * scale_value, -h * 0.25), centre + Vector2(w - 2.0 * scale_value, -h * 0.25), shine, line)

## Pieces with a shell (Stone Giant) show how many hits it still absorbs: a row of
## pips over the head, filled for each layer left, hollow for each one broken.
func _draw_shell_pips() -> void:
	var board: BoardState = view.board
	var projection: BoardProjection = view.projection
	var hidden: Dictionary = view.pieces.hidden
	var piece_pixels: float = projection.cell * BoardPainter.PIECE_HEIGHT_CELLS
	var stand: float = view.standing_offset()
	for rank: int in range(board.board_size):
		for file: int in range(board.board_size):
			var square: Vector2i = Vector2i(file, rank)
			var piece: ChessPiece = board.get_piece(square)
			if piece != null and piece.def.is_egg and not hidden.has(square):
				_draw_egg_count(square, piece, piece_pixels, stand)
				continue
			if piece == null or piece.def.shell_hits <= 0 or hidden.has(square):
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
	var font: Font = view.get_theme_default_font()
	if font == null:
		return
	var projection: BoardProjection = view.projection
	var world: Vector3 = projection.square_world(square)
	var top: Vector2 = projection.project(Vector3(world.x, projection.height_for_pixels(piece_pixels * 0.78), world.z + stand))
	var radius: float = maxf(7.0, projection.cell * 0.24 * projection.square_scale(square))
	var hard: bool = egg.def.egg_hardened
	_overlay.draw_circle(top, radius + 1.5, Color("#1a1018"))
	_overlay.draw_circle(top, radius, Color("#f5c860") if hard else Color("#ff8a3c"))
	var text: String = str(view.board.egg_turns_left(egg))
	var font_size: int = int(radius * 1.5)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_overlay.draw_string(font, top + Vector2(-width * 0.5, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#2a1206"))

## A shield flashes when the player tries to attack through it.
func pulse_shield(square: Vector2i) -> void:
	var fx: StrikeFx = view.strike_fx()
	if fx == null or view.projection == null:
		return
	var at: Vector3 = view.projection.square_world(square)
	fx.ring(at.x, at.z, view.projection.cell * 0.75, 0.4, Color(0.67, 0.84, 1.0))
	fx.ring(at.x, at.z, view.projection.cell * 0.45, 0.3, Color(0.85, 0.94, 1.0))

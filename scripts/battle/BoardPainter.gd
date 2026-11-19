class_name BoardPainter
extends RefCounted

## Shared look of the 2.5D board: frame, squares, markers and standing piece sprites.
## Used by the battle board and the deployment board so both read as the same table.

const BOARD_MARGIN := 6.0
const BOARD_THICKNESS := 9.0
const PIECE_HEIGHT_CELLS := 1.28
const STAND_FORWARD_CELLS := 0.2
const SQUARE_LIGHT := Color("#b89b68")
const SQUARE_DARK := Color("#2a4458")
const FRAME_TOP := Color("#3b2a20")
const FRAME_INLAY := Color("#6b4d34")
const FRAME_SIDE := Color("#2a1c14")
const FRAME_SIDE_DARK := Color("#1d130d")
const SHADOW := Color(0.0, 0.0, 0.0, 0.34)

## Largest projection whose board (with frame) fits inside `view`.
static func fit(board_size: int, view: Vector2, center_y: float = 0.535) -> BoardProjection:
	var near_scale: float = BoardProjection.DISTANCE_CELLS / (BoardProjection.DISTANCE_CELLS - board_size * 0.5 * cos(deg_to_rad(BoardProjection.PITCH_DEGREES)))
	var cell: float = floorf((minf(view.x, view.y) - BOARD_MARGIN * 2.0 * near_scale - 4.0) / (board_size * near_scale))
	return BoardProjection.new(board_size, cell, Vector2(view.x * 0.5, view.y * center_y))

static func square_color(square: Vector2i) -> Color:
	return SQUARE_DARK if (square.x + square.y) % 2 == 0 else SQUARE_LIGHT

static func draw_frame(canvas: CanvasItem, projection: BoardProjection) -> void:
	var top: PackedVector2Array = projection.board_polygon(BOARD_MARGIN)
	var bottom: PackedVector2Array = projection.board_polygon(BOARD_MARGIN, -BOARD_THICKNESS)
	for index: int in range(4):
		var next: int = (index + 1) % 4
		canvas.draw_colored_polygon(PackedVector2Array([top[index], top[next], bottom[next], bottom[index]]), FRAME_SIDE if index % 2 == 0 else FRAME_SIDE_DARK)
	canvas.draw_colored_polygon(top, FRAME_TOP)
	var inlay: PackedVector2Array = projection.board_polygon(1.5)
	inlay.append(inlay[0])
	canvas.draw_polyline(inlay, FRAME_INLAY, 1.0)

static func draw_square(canvas: CanvasItem, projection: BoardProjection, square: Vector2i, fill: Color) -> void:
	var polygon: PackedVector2Array = projection.square_polygon(square)
	canvas.draw_colored_polygon(polygon, fill)
	# One-pixel bevel so squares read as inlaid tiles rather than flat paint.
	canvas.draw_line(polygon[0], polygon[1], fill.lightened(0.12), 1.0)
	canvas.draw_line(polygon[3], polygon[2], fill.darkened(0.18), 1.0)

static func draw_marker(canvas: CanvasItem, projection: BoardProjection, square: Vector2i, tint: Color) -> void:
	var outline: PackedVector2Array = projection.square_polygon(square, 1.0)
	canvas.draw_colored_polygon(outline, tint)
	outline.append(outline[0])
	canvas.draw_polyline(outline, Color(tint, 0.95), 1.0)

static func draw_ground_ellipse(canvas: CanvasItem, projection: BoardProjection, square: Vector2i, radius: float, color: Color) -> void:
	var world: Vector3 = projection.square_world(square)
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(16):
		var angle: float = TAU * step / 16.0
		points.append(projection.project(world + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)))
	canvas.draw_colored_polygon(points, color)

## A piece sprite anchored on the bottom-centre of its painted pixels.
static func make_sprite(texture: Texture2D, projection: BoardProjection) -> Sprite2D:
	if texture == null:
		return null
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	var used: Rect2i = PieceChunks.of(texture).used
	sprite.offset = -Vector2(used.position.x + used.size.x * 0.5, used.end.y)
	sprite.set_meta("base_scale", projection.cell * PIECE_HEIGHT_CELLS / float(maxi(texture.get_width(), 1)))
	return sprite

## Stands `sprite` on `world` (Y lifts it off the board).
static func place_sprite(sprite: Sprite2D, projection: BoardProjection, world: Vector3) -> void:
	var ground: Vector3 = Vector3(world.x, 0.0, world.z + projection.cell * STAND_FORWARD_CELLS)
	var scale_value: float = float(sprite.get_meta("base_scale", 1.0)) * projection.scale_at(ground)
	sprite.set_meta("placed_scale", scale_value)
	sprite.set_meta("world", world)
	sprite.scale = Vector2(scale_value, scale_value) * (sprite.get_meta("stretch", Vector2.ONE) as Vector2)
	sprite.position = projection.project(Vector3(ground.x, world.y, ground.z))

## Whether a screen point lands on the painted figure of `sprite`.
static func sprite_hit(sprite: Sprite2D, point: Vector2) -> bool:
	if sprite == null or not sprite.visible or sprite.texture == null:
		return false
	if not sprite_hit_rect(sprite).has_point(point):
		return false
	if sprite.scale.x == 0.0 or sprite.scale.y == 0.0:
		return false
	var pixel: Vector2 = (point - sprite.position) / sprite.scale - sprite.offset
	return PieceChunks.of(sprite.texture).covers(Vector2i(floori(pixel.x), floori(pixel.y)))

## Squares of the pieces under a tap, in the order repeated taps cycle through them:
## the piece standing on the tapped board square first, then every other piece whose
## figure covers the point, the one drawn on top first. `sprites` maps square -> Sprite2D.
static func pieces_under(point: Vector2, ground: Vector2i, sprites: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var ground_sprite: Sprite2D = sprites.get(ground) as Sprite2D
	if ground_sprite != null and ground_sprite.visible:
		result.append(ground)
	var covering: Array = []
	for key: Variant in sprites:
		var square: Vector2i = key
		if square == ground:
			continue
		var sprite: Sprite2D = sprites[key] as Sprite2D
		if sprite_hit(sprite, point):
			covering.append([sprite.position.y, square])
	covering.sort_custom(func(left: Array, right: Array) -> bool: return float(left[0]) > float(right[0]))
	for entry: Array in covering:
		result.append(entry[1])
	return result

## Screen rectangle a tap must land in to count as touching the piece.
static func sprite_hit_rect(sprite: Sprite2D) -> Rect2:
	var used: Rect2i = PieceChunks.of(sprite.texture).used
	var rect_size: Vector2 = Vector2(used.size) * sprite.scale
	var rect: Rect2 = Rect2(sprite.position + Vector2(-rect_size.x * 0.5, -rect_size.y), rect_size)
	return rect.grow_individual(-rect_size.x * 0.12, 0.0, -rect_size.x * 0.12, 0.0)

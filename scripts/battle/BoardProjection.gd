class_name BoardProjection
extends RefCounted

## Presentation-only 2.5D camera for the battle board.
##
## World space: X runs right, Y runs up, Z runs toward the viewer. The board lies on
## the Y = 0 plane and is centred on the origin. Board rank 0 is nearest the viewer.
## Nothing here participates in rules; it only converts between squares and pixels.

const PITCH_DEGREES := 58.0
## Camera distance in cells. Smaller values exaggerate the perspective.
const DISTANCE_CELLS := 18.0

var board_size: int = 8
var cell: float = 36.0
var center: Vector2 = Vector2.ZERO

var _sin_pitch: float = sin(deg_to_rad(PITCH_DEGREES))
var _cos_pitch: float = cos(deg_to_rad(PITCH_DEGREES))

func _init(p_board_size: int = 8, p_cell: float = 36.0, p_center: Vector2 = Vector2.ZERO) -> void:
	board_size = maxi(p_board_size, 1)
	cell = p_cell
	center = p_center

func distance() -> float:
	return DISTANCE_CELLS * cell

## Perspective scale at a world point. 1.0 at the board centre, larger when nearer.
func scale_at(world: Vector3) -> float:
	var toward: float = world.z * _cos_pitch + world.y * _sin_pitch
	return distance() / maxf(distance() - toward, 0.001)

func project(world: Vector3) -> Vector2:
	var k: float = scale_at(world)
	return center + Vector2(world.x, world.z * _sin_pitch - world.y * _cos_pitch) * k

## World height that covers `pixels` on screen for something standing at the centre.
func height_for_pixels(pixels: float) -> float:
	return pixels / _cos_pitch

func square_world(square: Vector2i) -> Vector3:
	var half: float = (board_size - 1) * 0.5
	return Vector3((square.x - half) * cell, 0.0, (half - square.y) * cell)

func square_center(square: Vector2i) -> Vector2:
	return project(square_world(square))

func square_scale(square: Vector2i) -> float:
	return scale_at(square_world(square))

func square_polygon(square: Vector2i, inset: float = 0.0) -> PackedVector2Array:
	var world: Vector3 = square_world(square)
	var half: float = cell * 0.5 - inset
	return PackedVector2Array([
		project(world + Vector3(-half, 0.0, -half)),
		project(world + Vector3(half, 0.0, -half)),
		project(world + Vector3(half, 0.0, half)),
		project(world + Vector3(-half, 0.0, half)),
	])

## Board outline on the Y = `height` plane, expanded by `margin` world units.
func board_polygon(margin: float = 0.0, height: float = 0.0) -> PackedVector2Array:
	var half: float = board_size * cell * 0.5 + margin
	return PackedVector2Array([
		project(Vector3(-half, height, -half)),
		project(Vector3(half, height, -half)),
		project(Vector3(half, height, half)),
		project(Vector3(-half, height, half)),
	])

## Inverse of project() for points on the board plane.
func screen_to_world(point: Vector2) -> Vector3:
	var local: Vector2 = point - center
	var denominator: float = _sin_pitch * distance() + local.y * _cos_pitch
	if absf(denominator) < 0.0001:
		return Vector3.ZERO
	var z: float = local.y * distance() / denominator
	var k: float = scale_at(Vector3(0.0, 0.0, z))
	return Vector3(local.x / k, 0.0, z)

## Returns the square under a screen point, or (-1, -1) when it is off the board.
func screen_to_square(point: Vector2) -> Vector2i:
	var world: Vector3 = screen_to_world(point)
	var half: float = board_size * 0.5
	var file: int = floori(world.x / cell + half)
	var rank: int = floori(half - world.z / cell)
	if file < 0 or rank < 0 or file >= board_size or rank >= board_size:
		return Vector2i(-1, -1)
	return Vector2i(file, rank)

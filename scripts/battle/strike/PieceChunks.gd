class_name PieceChunks
extends RefCounted

## Coarse grid sampled from a piece texture. Strike animations use it to spawn debris
## that matches the art, and the strike shader cuts the sprite along the same grid.
##
## Points are isotropic: x and y are measured in sprite heights from the top-left of
## the painted area, so a point's x runs from 0 to `aspect` and y from 0 to 1.

const ROWS := 16

static var _cache: Dictionary = {}

var used: Rect2i = Rect2i()
var texture_size: Vector2 = Vector2.ONE
var aspect: float = 1.0
var points: PackedVector2Array = PackedVector2Array()
var colors: PackedColorArray = PackedColorArray()

static func of(texture: Texture2D) -> PieceChunks:
	var key: int = texture.get_rid().get_id()
	if _cache.has(key):
		return _cache[key]
	var chunks: PieceChunks = PieceChunks.new()
	chunks._build(texture)
	_cache[key] = chunks
	return chunks

func _build(texture: Texture2D) -> void:
	texture_size = texture.get_size()
	used = Rect2i(Vector2i.ZERO, Vector2i(texture_size))
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return
	if image.is_compressed():
		image.decompress()
	var painted: Rect2i = image.get_used_rect()
	if painted.size.x > 0 and painted.size.y > 0:
		used = painted
	aspect = float(used.size.x) / float(used.size.y)
	var step: float = float(used.size.y) / ROWS
	var columns: int = ceili(used.size.x / step)
	for row: int in range(ROWS):
		for column: int in range(columns):
			var x: int = mini(used.position.x + int((column + 0.5) * step), used.end.x - 1)
			var y: int = mini(used.position.y + int((row + 0.5) * step), used.end.y - 1)
			var color: Color = image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			color.a = 1.0
			points.append(Vector2((column + 0.5) / ROWS, (row + 0.5) / ROWS))
			colors.append(color)

## Painted area as a UV rectangle (position, size) for the strike shader.
func used_uv() -> Vector4:
	return Vector4(
		used.position.x / texture_size.x,
		used.position.y / texture_size.y,
		used.size.x / texture_size.x,
		used.size.y / texture_size.y)

func all_indices() -> PackedInt32Array:
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(points.size())
	for index: int in range(points.size()):
		indices[index] = index
	return indices

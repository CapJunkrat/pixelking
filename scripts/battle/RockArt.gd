class_name RockArt
extends RefCounted

## A pixel-art boulder drawn in code, in the same 128 px frame as the piece pictures so
## BoardPainter can stand it on a square like a piece (it is about half a piece tall).

const SIZE := 128
const PIXEL := 4
const OUTLINE := Color("#1b1a1f")
const DARK := Color("#4a4651")
const MID := Color("#6f6a77")
const LIGHT := Color("#9a94a2")
const SHINE := Color("#c4bfc9")
const MOSS := Color("#5d7a45")

static var _texture: Texture2D = null

static func texture() -> Texture2D:
	if _texture == null:
		_texture = ImageTexture.create_from_image(_paint())
	return _texture

## Paints at 32 x 32 and scales up 4x so the pixels match the chunky piece art.
static func _paint() -> Image:
	var low: int = SIZE / PIXEL
	var image: Image = Image.create(low, low, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var centre: Vector2 = Vector2(16.0, 24.0)
	var inside: Dictionary = {}
	for y: int in range(low):
		for x: int in range(low):
			# A lumpy dome: wider than tall, flat bottom, a bump on the left shoulder.
			var dx: float = (x + 0.5 - centre.x) / 12.5
			var dy: float = (y + 0.5 - centre.y) / 10.0
			var lump: float = 0.12 * sin(x * 0.9) + (0.18 if x < 13 and y < 20 else 0.0)
			if dy <= 0.35 and dx * dx + dy * dy <= 1.0 + lump:
				inside[Vector2i(x, y)] = true
	for cell: Vector2i in inside:
		var edge: bool = false
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not inside.has(cell + offset):
				edge = true
		var color: Color = MID
		# Light from the upper left.
		var shade: float = (cell.x - centre.x) * 0.6 + (cell.y - (centre.y - 8.0)) * 0.9
		if shade < -6.0:
			color = SHINE
		elif shade < -1.0:
			color = LIGHT
		elif shade > 7.0:
			color = DARK
		if (cell.x * 7 + cell.y * 3) % 11 == 0 and cell.y < 22 and color != DARK:
			color = MOSS
		# A crack.
		if (cell.x == 19 and cell.y >= 18 and cell.y <= 22) or (cell.x == 20 and cell.y == 17):
			color = DARK
		image.set_pixelv(cell, OUTLINE if edge else color)
	image.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	return image

extends SceneTree

## Draws the egg pieces (Ember Egg, Phoenix Egg) for the default piece style:
##   Godot --headless --path . --script res://scripts/visual_review/draw_egg_pieces.gd
## Pixel art at 32x32, scaled ×4 like the other piece pictures, resting on the same
## baseline as the Pawn.

const ROOT := "res://assets/chess/piece_skins/carved_figurine"
const SIZE := 32

const PALETTES := {
	"white_ember_egg": {"shell": "#f3e2c0", "shade": "#c9a77a", "light": "#fff8e8", "spot": "#e8743a", "spot2": "#ffb15c", "line": "#3a2416", "ash": "#7a6a60"},
	"black_ember_egg": {"shell": "#3c3238", "shade": "#241d22", "light": "#5a4c54", "spot": "#ff8a3c", "spot2": "#ffd27a", "line": "#0e0a0c", "ash": "#4a403c"},
	"white_phoenix_egg": {"shell": "#f2c75c", "shade": "#c8902e", "light": "#fff1b8", "spot": "#e0502a", "spot2": "#ff9a3c", "line": "#4a2208", "ash": "#7a6a60"},
	"black_phoenix_egg": {"shell": "#6a2026", "shade": "#401216", "light": "#8e3a3a", "spot": "#f5b042", "spot2": "#ffe08a", "line": "#14060a", "ash": "#4a403c"},
}

func _initialize() -> void:
	var baseline: int = _baseline(load(ROOT + "/white_pawn.png") as Texture2D)
	for name: String in PALETTES:
		var image: Image = _egg(PALETTES[name], name.ends_with("phoenix_egg"))
		image.resize(SIZE * 4, SIZE * 4, Image.INTERPOLATE_NEAREST)
		var placed: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		var shift: int = baseline - _last_row(image)
		placed.blit_rect(image, Rect2i(0, 0, 128, 128), Vector2i(0, shift))
		placed.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ROOT, name]))
		print("drew ", name)
	quit()

## Lowest opaque row of a picture (where the piece stands).
func _baseline(texture: Texture2D) -> int:
	return _last_row(texture.get_image()) if texture != null else 120

func _last_row(image: Image) -> int:
	if image.is_compressed():
		image.decompress()
	for y: int in range(image.get_height() - 1, -1, -1):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.5:
				return y
	return image.get_height() - 1

func _egg(palette: Dictionary, phoenix: bool) -> Image:
	var image: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var line: Color = Color(palette["line"])
	var shell: Color = Color(palette["shell"])
	var shade: Color = Color(palette["shade"])
	var light: Color = Color(palette["light"])
	var spot: Color = Color(palette["spot"])
	var spot2: Color = Color(palette["spot2"])
	var ash: Color = Color(palette["ash"])
	var cx: float = 15.5
	var cy: float = 17.0
	# Egg outline: narrower towards the top.
	var inside: Dictionary = {}
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var dy: float = (y + 0.5 - cy) / 11.0
			var rx: float = 8.5 * (1.0 - 0.18 * clampf(-dy, 0.0, 1.0))
			var dx: float = (x + 0.5 - cx) / rx
			if dx * dx + dy * dy <= 1.0:
				inside[Vector2i(x, y)] = true
	for cell: Vector2i in inside:
		var u: float = (cell.x + 0.5 - cx) / 8.5
		var v: float = (cell.y + 0.5 - cy) / 11.0
		var color: Color = shell
		if u + v * 0.4 > 0.45:
			color = shade
		elif u + v * 0.5 < -0.55 and v < -0.1:
			color = light
		image.set_pixelv(cell, color)
	# Markings: speckles for the Ember Egg, a band of flames for the Phoenix Egg.
	if phoenix:
		for x: int in range(SIZE):
			var crest: int = 19 + int(round(2.0 * sin(x * 1.3)))
			for y: int in range(crest, crest + 3):
				var cell: Vector2i = Vector2i(x, y)
				if inside.has(cell):
					image.set_pixelv(cell, spot if y < crest + 2 else spot2)
		for cell: Vector2i in [Vector2i(13, 10), Vector2i(18, 12), Vector2i(15, 14)]:
			if inside.has(cell):
				image.set_pixelv(cell, spot2)
	else:
		for cell: Vector2i in [Vector2i(12, 11), Vector2i(17, 9), Vector2i(19, 15), Vector2i(13, 18), Vector2i(17, 21), Vector2i(11, 23), Vector2i(20, 24), Vector2i(15, 14)]:
			if inside.has(cell):
				image.set_pixelv(cell, spot)
				if inside.has(cell + Vector2i(1, 0)):
					image.set_pixelv(cell + Vector2i(1, 0), spot2)
	# Dark outline around the shell.
	for cell: Vector2i in inside:
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var out: Vector2i = cell + offset
			if not inside.has(out) and out.x >= 0 and out.y >= 0 and out.x < SIZE and out.y < SIZE:
				image.set_pixelv(out, line)
	# A small heap of warm ash for it to sit in.
	for y: int in range(27, 30):
		var half: int = 9 - (y - 27) * 1
		for x: int in range(int(cx) - half, int(cx) + half + 1):
			if image.get_pixel(x, y).a < 0.5:
				image.set_pixel(x, y, ash if (x + y) % 3 != 0 else ash.lightened(0.15))
	for x: int in [10, 14, 19, 22]:
		image.set_pixel(x, 27, spot2 if phoenix else spot)
	return image

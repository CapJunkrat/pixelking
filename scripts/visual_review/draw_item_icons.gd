extends SceneTree

## Usage: godot --headless --script res://scripts/visual_review/draw_item_icons.gd -- <out dir> <S_Wind02.png from the CC0 pack>
## Writes iron_crown, war_banner and royal_bomb (drawn here) and second_wind (the pack's
## wind icon, tinted). Copy the results into assets/ui/items/ under their item ids.

## Draws the Iron Crown, War Banner and Royal Bomb icons at 34x34 in the style of the CC0 pack:
## flat shapes, a 1 px dark outline, a light top-left edge and a dark bottom-right edge.

const S := 34
const OUTLINE := Color("#1b1622")

var img: Image
var layer: Dictionary = {}   # Vector2i -> base colour key

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	_crown()
	_finish(out + "/relic_iron_crown.png")
	_banner()
	_finish(out + "/relic_war_banner.png")
	_bomb()
	_finish(out + "/consumable_royal_bomb.png")
	_tint(OS.get_cmdline_user_args()[1], out + "/consumable_second_wind.png", Color("#7fe3c8"))
	quit()

func _begin() -> void:
	img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	layer.clear()

func _poly(points: PackedVector2Array, key: Array) -> void:
	for y in range(S):
		for x in range(S):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				layer[Vector2i(x, y)] = key

func _rect(r: Rect2i, key: Array) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			layer[Vector2i(x, y)] = key

func _disc(c: Vector2, radius: float, key: Array) -> void:
	for y in range(S):
		for x in range(S):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= radius:
				layer[Vector2i(x, y)] = key

## key = [light, mid, dark]: each pixel takes mid, light on its top/left edge
## within its own shape, dark on its bottom/right edge.
func _finish(path: String) -> void:
	for p: Vector2i in layer:
		var key: Array = layer[p]
		var up: bool = layer.get(p + Vector2i(0, -1), []) != key
		var left: bool = layer.get(p + Vector2i(-1, 0), []) != key
		var down: bool = layer.get(p + Vector2i(0, 1), []) != key
		var right: bool = layer.get(p + Vector2i(1, 0), []) != key
		var colour: Color = key[1]
		if up or left:
			colour = key[0]
		elif down or right:
			colour = key[2]
		img.set_pixelv(p, colour)
	for y in range(S):
		for x in range(S):
			var p: Vector2i = Vector2i(x, y)
			if layer.has(p):
				continue
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if layer.has(p + n):
					img.set_pixelv(p, OUTLINE)
					break
	img.save_png(path)

func _crown() -> void:
	_begin()
	var steel: Array = [Color("#e9edf3"), Color("#a9b2c2"), Color("#646d80")]
	var steel_dark: Array = [Color("#b9c1cf"), Color("#7d8698"), Color("#4a5163")]
	var gem_blue: Array = [Color("#bfe0ff"), Color("#4d86f0"), Color("#263f9c")]
	var gem_red: Array = [Color("#ffc0b8"), Color("#e04a4a"), Color("#8a1f28")]
	# Five points rising from the band.
	_poly(PackedVector2Array([Vector2(5, 22), Vector2(5, 11), Vector2(10, 17), Vector2(13, 8), Vector2(17, 15), Vector2(21, 8), Vector2(24, 17), Vector2(29, 11), Vector2(29, 22)]), steel)
	# The band.
	_rect(Rect2i(4, 21, 26, 7), steel_dark)
	_rect(Rect2i(5, 22, 24, 5), steel)
	# Balls on the tips.
	_disc(Vector2(5.5, 10.0), 2.0, steel)
	_disc(Vector2(13.5, 7.0), 2.0, steel)
	_disc(Vector2(21.0, 7.0), 2.0, steel)
	_disc(Vector2(28.5, 10.0), 2.0, steel)
	# Gems: a red one in the middle point, blue ones on the band.
	_poly(PackedVector2Array([Vector2(17, 14), Vector2(19.5, 17), Vector2(17, 20), Vector2(14.5, 17)]), gem_red)
	_disc(Vector2(10.0, 24.5), 1.8, gem_blue)
	_disc(Vector2(17.0, 24.5), 1.8, gem_red)
	_disc(Vector2(24.0, 24.5), 1.8, gem_blue)

func _banner() -> void:
	_begin()
	var wood: Array = [Color("#d9a46a"), Color("#9c6a3a"), Color("#5e3c1f")]
	var gold: Array = [Color("#fff1a8"), Color("#f2c443"), Color("#a8741c")]
	var cloth: Array = [Color("#ff8a7a"), Color("#d23a3f"), Color("#7e1a26")]
	var trim: Array = [Color("#fff1a8"), Color("#e8b53a"), Color("#9b6a18")]
	# Pole with a gold tip and a crossbar.
	_rect(Rect2i(8, 5, 3, 27), wood)
	_poly(PackedVector2Array([Vector2(9.5, 1), Vector2(12, 4.5), Vector2(9.5, 7), Vector2(7, 4.5)]), gold)
	_rect(Rect2i(8, 7, 21, 2), gold)
	# Swallow-tailed cloth.
	_poly(PackedVector2Array([Vector2(11, 9), Vector2(28, 9), Vector2(28, 27), Vector2(23.5, 22.5), Vector2(19.5, 27), Vector2(11, 23)]), cloth)
	# Gold trim along the top of the cloth and a gold rook emblem.
	_rect(Rect2i(11, 9, 17, 1), trim)
	_rect(Rect2i(15, 12, 2, 2), trim)
	_rect(Rect2i(18, 12, 2, 2), trim)
	_rect(Rect2i(21, 12, 2, 2), trim)
	_rect(Rect2i(15, 14, 8, 2), trim)
	_rect(Rect2i(16, 16, 6, 4), trim)
	_rect(Rect2i(15, 20, 8, 2), trim)

func _bomb() -> void:
	_begin()
	var iron: Array = [Color("#8c93a8"), Color("#3a3d4c"), Color("#1f2130")]
	var gold: Array = [Color("#fff1a8"), Color("#f2c443"), Color("#a8741c")]
	var fuse: Array = [Color("#e9d2a0"), Color("#b08850"), Color("#6e5028")]
	var flame: Array = [Color("#fff7c2"), Color("#ffb43a"), Color("#e0532b")]
	_disc(Vector2(16, 21), 10.5, iron)
	# A gold crown band round the bomb and its neck.
	_rect(Rect2i(6, 19, 21, 3), gold)
	for x: int in [8, 13, 18, 23]:
		_rect(Rect2i(x, 17, 2, 2), gold)
	_rect(Rect2i(13, 8, 6, 3), iron)
	# Fuse and spark.
	_poly(PackedVector2Array([Vector2(17, 8), Vector2(20, 4), Vector2(22, 4), Vector2(19, 9)]), fuse)
	_poly(PackedVector2Array([Vector2(23, 0.5), Vector2(26, 3.5), Vector2(23.5, 7), Vector2(20.5, 3.5)]), flame)
	# A shine on the iron.
	_rect(Rect2i(9, 24, 2, 3), [Color("#8c93a8"), Color("#8c93a8"), Color("#8c93a8")])

## Recolours a grey icon: keeps its light and dark, takes the hue of `tint`.
func _tint(source: String, path: String, tint: Color) -> void:
	var image: Image = Image.load_from_file(source)
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.a < 0.05 or c.v < 0.18:
				continue
			var shaded: Color = Color.from_hsv(tint.h, tint.s * 0.85, clampf(c.v * 1.05, 0.0, 1.0), c.a)
			image.set_pixel(x, y, shaded)
	image.save_png(path)

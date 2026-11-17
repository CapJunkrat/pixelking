class_name PieceIconRenderer
extends SceneTree

const SIZE = 32
const PIECES: Array[String] = ["assassin", "royal_guard", "catapult", "bowman", "portal_mage", "unicorn_cavalry", "centaur", "manticore", "gryphon", "gorgon"]

func _init() -> void:
	for skin: String in ["royal_forge", "modern_parchment"]:
		for piece_id: String in PIECES:
			for color: String in ["white", "black"]:
				var image: Image = _render(piece_id, skin, color)
				var output_size: int = 64 if skin == "royal_forge" else 128
				image.resize(output_size, output_size, Image.INTERPOLATE_NEAREST)
				var path: String = "res://assets/chess/piece_skins/%s/%s_%s.png" % [skin, color, piece_id]
				var error: Error = image.save_png(ProjectSettings.globalize_path(path))
				if error != OK:
					push_error("Failed to save %s" % path)
		print("Rendered deliverable icon set: ", skin)
	quit()

func _render(piece_id: String, skin: String, color: String) -> Image:
	var main: PackedByteArray = _mask()
	var accent: PackedByteArray = _mask()
	var glow: PackedByteArray = _mask()
	_draw_common_base(main, accent, skin)
	match piece_id:
		"assassin": _draw_assassin(main, accent, glow, skin)
		"royal_guard": _draw_royal_guard(main, accent, glow, skin)
		"catapult": _draw_catapult(main, accent, glow, skin)
		"bowman": _draw_bowman(main, accent, glow, skin)
		"portal_mage": _draw_portal_mage(main, accent, glow, skin)
		"unicorn_cavalry": _draw_unicorn(main, accent, glow, skin)
		"centaur": _draw_centaur(main, accent, glow, skin)
		"gryphon": _draw_gryphon(main, accent, glow, skin)
		"gorgon": _draw_gorgon(main, accent, glow, skin)
	if skin == "modern_parchment":
		_dilate_horizontal(main)
	var image: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var palette: Dictionary = _palette(skin, color)
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var index: int = _index(x, y)
			if glow[index] == 1:
				image.set_pixel(x, y, palette["glow"] as Color)
			elif accent[index] == 1:
				image.set_pixel(x, y, palette["accent"] as Color)
			elif main[index] == 1:
				var top_edge: bool = y == 0 or main[_index(x, y - 1)] == 0
				var body_color: Color = palette["highlight"] as Color if top_edge else (palette["body"] as Color if (x + y) % 4 != 0 else palette["shadow"] as Color)
				image.set_pixel(x, y, body_color)
			elif _touches(main, x, y) or _touches(accent, x, y):
				image.set_pixel(x, y, palette["outline"] as Color)
	return image

func _palette(skin: String, color: String) -> Dictionary:
	if skin == "modern_parchment":
		if color == "white":
			return {"outline": Color("#241923"), "shadow": Color("#765944"), "body": Color("#d9bf91"), "highlight": Color("#fff0c5"), "accent": Color("#a86732"), "glow": Color("#54d8dc")}
		return {"outline": Color("#110d16"), "shadow": Color("#321829"), "body": Color("#733149"), "highlight": Color("#c96371"), "accent": Color("#d9a65d"), "glow": Color("#55c9d4")}
	if color == "white":
		return {"outline": Color("#101521"), "shadow": Color("#5b4231"), "body": Color("#b98345"), "highlight": Color("#efd08a"), "accent": Color("#f5df9c"), "glow": Color("#4ddde0")}
	return {"outline": Color("#090d16"), "shadow": Color("#301428"), "body": Color("#76233f"), "highlight": Color("#c64d62"), "accent": Color("#d89d55"), "glow": Color("#45cbd5")}

func _draw_common_base(main: PackedByteArray, accent: PackedByteArray, skin: String) -> void:
	var left: int = 8 if skin == "modern_parchment" else 9
	var right: int = 23 if skin == "modern_parchment" else 22
	_rect(main, left + 2, 23, right - 2, 25)
	_rect(main, left, 26, right, 28)
	_line(accent, Vector2i(left + 1, 26), Vector2i(right - 1, 26), 1)
	if skin == "modern_parchment":
		_mark(accent, 10, 28)
		_mark(accent, 21, 28)

func _draw_assassin(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_poly(main, [Vector2i(10, 18), Vector2i(11, 9), Vector2i(15, 5), Vector2i(20, 9), Vector2i(21, 18), Vector2i(19, 23), Vector2i(12, 23)])
	_ellipse(main, Rect2i(12, 9, 8, 9))
	_rect(glow, 14, 12, 17, 12)
	_line(accent, Vector2i(8, 20), Vector2i(21, 8), 1)
	_line(accent, Vector2i(23, 20), Vector2i(10, 8), 1)
	_mark(accent, 7, 21); _mark(accent, 24, 21)
	if skin == "modern_parchment": _line(accent, Vector2i(13, 18), Vector2i(18, 18), 1)

func _draw_royal_guard(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_ellipse(main, Rect2i(11, 7, 10, 10))
	_poly(main, [Vector2i(10, 17), Vector2i(22, 17), Vector2i(20, 24), Vector2i(12, 24)])
	_line(accent, Vector2i(8, 6), Vector2i(8, 23), 1)
	_line(accent, Vector2i(6, 8), Vector2i(10, 8), 1)
	_poly(accent, [Vector2i(11, 8), Vector2i(11, 5), Vector2i(13, 7), Vector2i(16, 4), Vector2i(19, 7), Vector2i(21, 5), Vector2i(21, 9)])
	_poly(accent, [Vector2i(13, 17), Vector2i(19, 17), Vector2i(18, 22), Vector2i(16, 23), Vector2i(14, 22)])
	_rect(glow, 14, 12, 17, 12)
	if skin == "modern_parchment": _line(accent, Vector2i(12, 10), Vector2i(20, 10), 1)

func _draw_catapult(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_ellipse(main, Rect2i(8, 20, 7, 7)); _ellipse(main, Rect2i(18, 20, 7, 7))
	_poly(main, [Vector2i(10, 21), Vector2i(16, 11), Vector2i(22, 21)])
	_line(accent, Vector2i(16, 19), Vector2i(21, 6), 2)
	_ellipse(main, Rect2i(20, 4, 5, 5))
	_line(accent, Vector2i(11, 21), Vector2i(22, 21), 1)
	_mark(glow, 22, 6)
	if skin == "modern_parchment": _line(accent, Vector2i(13, 18), Vector2i(19, 18), 1)

func _draw_bowman(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_poly(main, [Vector2i(11, 17), Vector2i(12, 9), Vector2i(16, 6), Vector2i(20, 9), Vector2i(21, 17), Vector2i(19, 24), Vector2i(13, 24)])
	_line(accent, Vector2i(23, 6), Vector2i(25, 10), 1); _line(accent, Vector2i(25, 10), Vector2i(25, 19), 1); _line(accent, Vector2i(25, 19), Vector2i(22, 23), 1)
	_line(accent, Vector2i(10, 15), Vector2i(25, 15), 1)
	_poly(accent, [Vector2i(9, 15), Vector2i(12, 13), Vector2i(12, 17)])
	_rect(glow, 15, 11, 17, 11)
	if skin == "modern_parchment": _line(accent, Vector2i(14, 19), Vector2i(18, 22), 1)

func _draw_portal_mage(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_ellipse(main, Rect2i(7, 5, 18, 18)); _clear_ellipse(main, Rect2i(10, 8, 12, 12))
	_ellipse(glow, Rect2i(9, 7, 14, 14)); _clear_ellipse(glow, Rect2i(11, 9, 10, 10))
	_poly(main, [Vector2i(12, 23), Vector2i(13, 13), Vector2i(16, 10), Vector2i(19, 13), Vector2i(20, 23)])
	_rect(accent, 15, 14, 16, 20)
	_mark(glow, 16, 12)
	if skin == "modern_parchment": _mark(accent, 8, 10); _mark(accent, 23, 17)

func _draw_unicorn(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_poly(main, [Vector2i(10, 22), Vector2i(11, 12), Vector2i(15, 7), Vector2i(21, 9), Vector2i(23, 14), Vector2i(20, 18), Vector2i(18, 24), Vector2i(12, 24)])
	_poly(main, [Vector2i(12, 11), Vector2i(9, 7), Vector2i(14, 8)])
	_line(accent, Vector2i(17, 8), Vector2i(22, 3), 1)
	_mark(glow, 20, 12)
	_line(accent, Vector2i(12, 20), Vector2i(19, 20), 1)
	if skin == "modern_parchment": _line(accent, Vector2i(12, 14), Vector2i(17, 9), 1)

func _draw_centaur(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_poly(main, [Vector2i(8, 18), Vector2i(21, 18), Vector2i(24, 21), Vector2i(21, 24), Vector2i(10, 24)])
	_rect(main, 12, 11, 18, 19); _ellipse(main, Rect2i(13, 7, 5, 5))
	_line(main, Vector2i(11, 23), Vector2i(10, 27), 2); _line(main, Vector2i(20, 23), Vector2i(22, 27), 2)
	_line(accent, Vector2i(20, 6), Vector2i(20, 22), 1); _poly(accent, [Vector2i(20, 4), Vector2i(18, 8), Vector2i(22, 8)])
	_mark(glow, 16, 9)
	if skin == "modern_parchment": _line(accent, Vector2i(13, 15), Vector2i(18, 15), 1)

func _draw_manticore(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_poly(main, [Vector2i(7, 18), Vector2i(5, 12), Vector2i(11, 15), Vector2i(12, 8), Vector2i(16, 5), Vector2i(20, 8), Vector2i(21, 15), Vector2i(27, 12), Vector2i(25, 19), Vector2i(21, 22), Vector2i(11, 22)])
	_ellipse(main, Rect2i(10, 7, 12, 12)); _ellipse(accent, Rect2i(13, 10, 6, 6))
	_line(accent, Vector2i(22, 17), Vector2i(27, 8), 1); _line(accent, Vector2i(27, 8), Vector2i(24, 4), 1)
	_mark(glow, 14, 12); _mark(glow, 18, 12)
	if skin == "modern_parchment": _mark(accent, 16, 16)

func _draw_gryphon(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_poly(main, [Vector2i(11, 23), Vector2i(9, 16), Vector2i(4, 12), Vector2i(7, 21), Vector2i(13, 18), Vector2i(19, 18), Vector2i(25, 21), Vector2i(28, 12), Vector2i(22, 16), Vector2i(20, 23)])
	_ellipse(main, Rect2i(12, 7, 9, 10)); _poly(accent, [Vector2i(20, 10), Vector2i(25, 12), Vector2i(20, 14)])
	_poly(main, [Vector2i(14, 8), Vector2i(16, 4), Vector2i(18, 8)])
	_mark(glow, 18, 10)
	_line(accent, Vector2i(7, 16), Vector2i(12, 18), 1); _line(accent, Vector2i(24, 16), Vector2i(19, 18), 1)
	if skin == "modern_parchment": _line(accent, Vector2i(13, 20), Vector2i(19, 20), 1)

func _draw_gorgon(main: PackedByteArray, accent: PackedByteArray, glow: PackedByteArray, skin: String) -> void:
	_ellipse(main, Rect2i(11, 8, 10, 12)); _poly(main, [Vector2i(11, 18), Vector2i(21, 18), Vector2i(20, 24), Vector2i(12, 24)])
	for start_x: int in [11, 14, 17, 20]:
		_line(main, Vector2i(start_x, 10), Vector2i(start_x - 3 + (start_x % 2) * 6, 5), 2)
		_mark(accent, start_x - 3 + (start_x % 2) * 6, 4)
	_rect(glow, 14, 13, 17, 13); _mark(accent, 16, 13)
	_line(accent, Vector2i(13, 20), Vector2i(19, 20), 1)
	if skin == "modern_parchment": _mark(glow, 16, 12)

func _mask() -> PackedByteArray:
	var value: PackedByteArray = PackedByteArray()
	value.resize(SIZE * SIZE)
	value.fill(0)
	return value

func _index(x: int, y: int) -> int:
	return y * SIZE + x

func _mark(mask: PackedByteArray, x: int, y: int) -> void:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE:
		mask[_index(x, y)] = 1

func _rect(mask: PackedByteArray, left: int, top: int, right: int, bottom: int) -> void:
	for y: int in range(top, bottom + 1):
		for x: int in range(left, right + 1):
			_mark(mask, x, y)

func _ellipse(mask: PackedByteArray, rect: Rect2i) -> void:
	var center: Vector2 = Vector2(rect.position) + Vector2(rect.size - Vector2i.ONE) * 0.5
	var radius: Vector2 = Vector2(rect.size) * 0.5
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var delta: Vector2 = (Vector2(x, y) - center) / radius
			if delta.length_squared() <= 1.0:
				_mark(mask, x, y)

func _clear_ellipse(mask: PackedByteArray, rect: Rect2i) -> void:
	var center: Vector2 = Vector2(rect.position) + Vector2(rect.size - Vector2i.ONE) * 0.5
	var radius: Vector2 = Vector2(rect.size) * 0.5
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var delta: Vector2 = (Vector2(x, y) - center) / radius
			if delta.length_squared() <= 1.0 and x >= 0 and x < SIZE and y >= 0 and y < SIZE:
				mask[_index(x, y)] = 0

func _line(mask: PackedByteArray, from: Vector2i, to: Vector2i, width: int = 1) -> void:
	var delta_x: int = absi(to.x - from.x)
	var step_x: int = 1 if from.x < to.x else -1
	var delta_y: int = -absi(to.y - from.y)
	var step_y: int = 1 if from.y < to.y else -1
	var error: int = delta_x + delta_y
	var point: Vector2i = from
	while true:
		for oy: int in range(-width / 2, width / 2 + 1):
			for ox: int in range(-width / 2, width / 2 + 1):
				_mark(mask, point.x + ox, point.y + oy)
		if point == to:
			break
		var error2: int = error * 2
		if error2 >= delta_y:
			error += delta_y
			point.x += step_x
		if error2 <= delta_x:
			error += delta_x
			point.y += step_y

func _poly(mask: PackedByteArray, points: Array[Vector2i]) -> void:
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			if _inside_polygon(Vector2(x + 0.5, y + 0.5), points):
				_mark(mask, x, y)

func _inside_polygon(point: Vector2, points: Array[Vector2i]) -> bool:
	var inside: bool = false
	var previous: Vector2i = points.back()
	for current: Vector2i in points:
		if ((current.y > point.y) != (previous.y > point.y)) and point.x < float(previous.x - current.x) * (point.y - float(current.y)) / float(previous.y - current.y) + float(current.x):
			inside = not inside
		previous = current
	return inside

func _dilate_horizontal(mask: PackedByteArray) -> void:
	var original: PackedByteArray = mask.duplicate()
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			if original[_index(x, y)] == 1:
				_mark(mask, x - 1, y)
				_mark(mask, x + 1, y)

func _touches(mask: PackedByteArray, x: int, y: int) -> bool:
	for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var target: Vector2i = Vector2i(x, y) + offset
		if target.x >= 0 and target.x < SIZE and target.y >= 0 and target.y < SIZE and mask[_index(target.x, target.y)] == 1:
			return true
	return false

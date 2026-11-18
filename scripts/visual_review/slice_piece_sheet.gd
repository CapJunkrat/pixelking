extends SceneTree

## Turns ONE generated piece sheet (any grid, white or black) into skin textures:
## 128x128 transparent PNGs named <color>_<piece>.png, every base on the same line.
##
## Usage:
##   Godot --headless --path . --script res://scripts/visual_review/slice_piece_sheet.gd -- \
##       <sheet> <white|black> <output folder> <id,id,-,id,...>
##
## Ids are listed in reading order (row by row, left to right). Use "-" for a piece on the
## sheet that should be skipped (a duplicate, a rejected design).
##
## Unlike slice_piece_sheets.gd this does not cut along empty gaps, so detached parts
## (sound arcs, floating masks, halos, sparks) stay with their piece: the biggest blobs
## are the pieces, and every smaller blob joins the piece it sits closest to.

## Share of the 128 px frame each piece's height fills.
const TIER: Dictionary = {
	"vanguard": 0.62, "sentry": 0.86, "powder_keg": 0.62, "martyr": 0.64, "lantern_bearer": 0.66, "squire": 0.6,
	"tide_knight": 0.78, "antelope": 0.8, "echo": 0.76, "stand_in": 0.64, "ranger": 0.64, "sun_moon_monk": 0.74,
	"falconer": 0.68, "gargoyle": 0.84, "chameleon": 0.74, "crystal_mage": 0.76, "ember_bird": 0.72, "stone_giant": 0.9,
	"swift_courier": 0.68, "blast_catapult": 0.86, "sky_archer": 0.8, "flame_phoenix": 0.84, "thousand_faces": 0.8,
	"war_king": 0.95, "shadow_king": 0.95, "shield_king": 0.95,
}
const DEFAULT_TIER := 0.75
const FRAME := 128
const MAX_WIDTH := 124
## Blobs smaller than this are compression noise.
const MIN_BLOB := 12

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("usage: -- <sheet> <white|black> <output folder> <id,id,...>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[2])
	quit(0 if _slice(args[0], args[1], args[2], args[3].split(",")) else 1)

func _slice(path: String, color: String, out_dir: String, ids: PackedStringArray) -> bool:
	var sheet: Image = Image.load_from_file(path)
	if sheet == null or sheet.is_empty():
		push_error("cannot read %s" % path)
		return false
	sheet.convert(Image.FORMAT_RGBA8)
	_remove_background(sheet)
	var blobs: Array[Dictionary] = _blobs(sheet)
	if blobs.size() < ids.size():
		push_error("%s: found %d blobs, expected at least %d pieces" % [path, blobs.size(), ids.size()])
		return false
	blobs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pixels.size() > b.pixels.size())
	var pieces: Array = []
	for i: int in range(ids.size()):
		pieces.append([blobs[i]])
	for i: int in range(ids.size(), blobs.size()):
		var best: int = 0
		var best_distance: float = INF
		for p: int in range(pieces.size()):
			var d: float = _rect_distance(blobs[i].rect, pieces[p][0].rect)
			if d < best_distance:
				best_distance = d
				best = p
		pieces[best].append(blobs[i])
	_sort_reading_order(pieces)
	for index: int in range(ids.size()):
		var id: String = ids[index].strip_edges()
		if id == "-" or id.is_empty():
			continue
		var cut: Image = _extract(sheet, pieces[index])
		var framed: Image = _frame(cut, float(TIER.get(id, DEFAULT_TIER)))
		framed.save_png("%s/%s_%s.png" % [out_dir, color, id])
		print("saved %s_%s (%d parts)" % [color, id, pieces[index].size()])
	return true

## Magenta, and the magenta-tinted fringe that compression leaves around outlines.
func _is_magenta(c: Color) -> bool:
	return minf(c.r, c.b) - c.g > 0.3

func _is_fringe(c: Color) -> bool:
	return c.r - c.g > 0.12 and c.b - c.g > 0.12 and absf(c.r - c.b) < 0.3

func _remove_background(img: Image) -> void:
	var width: int = img.get_width()
	var height: int = img.get_height()
	for y: int in range(height):
		for x: int in range(width):
			if _is_magenta(img.get_pixel(x, y)):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	for _pass: int in range(3):
		var source: Image = img.duplicate()
		for y: int in range(height):
			for x: int in range(width):
				var c: Color = source.get_pixel(x, y)
				if c.a < 0.5 or not _is_fringe(c):
					continue
				for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + step
					if q.x < 0 or q.y < 0 or q.x >= width or q.y >= height or source.get_pixelv(q).a < 0.5:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
						break

## Connected opaque regions (8-neighbour), each with its pixels and bounding rect.
func _blobs(img: Image) -> Array[Dictionary]:
	var width: int = img.get_width()
	var height: int = img.get_height()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(width * height)
	var result: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			if seen[y * width + x] == 1 or img.get_pixel(x, y).a < 0.5:
				continue
			var pixels: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[y * width + x] = 1
			var lo: Vector2i = Vector2i(x, y)
			var hi: Vector2i = Vector2i(x, y)
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				pixels.append(p)
				lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
				hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var q: Vector2i = p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= width or q.y >= height:
							continue
						var i: int = q.y * width + q.x
						if seen[i] == 0 and img.get_pixelv(q).a >= 0.5:
							seen[i] = 1
							stack.append(q)
			if pixels.size() >= MIN_BLOB:
				result.append({"pixels": pixels, "rect": Rect2i(lo, hi - lo + Vector2i.ONE)})
	return result

func _rect_distance(a: Rect2i, b: Rect2i) -> float:
	var dx: int = maxi(0, maxi(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy: int = maxi(0, maxi(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(float(dx * dx + dy * dy))

## Rows by where the main blob's base sits, then left to right.
func _sort_reading_order(pieces: Array) -> void:
	pieces.sort_custom(func(a: Array, b: Array) -> bool:
		var ra: Rect2i = a[0].rect
		var rb: Rect2i = b[0].rect
		if absi(ra.end.y - rb.end.y) > 60:
			return ra.end.y < rb.end.y
		return ra.position.x < rb.position.x)

func _extract(sheet: Image, parts: Array) -> Image:
	var rect: Rect2i = parts[0].rect
	for part: Dictionary in parts:
		rect = rect.merge(part.rect)
	var cut: Image = Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	for part: Dictionary in parts:
		for p: Vector2i in part.pixels:
			cut.set_pixelv(p - rect.position, sheet.get_pixelv(p))
	return cut

func _frame(piece: Image, tier: float) -> Image:
	var scale: float = minf(FRAME * tier / piece.get_height(), float(MAX_WIDTH) / piece.get_width())
	var width: int = maxi(1, roundi(piece.get_width() * scale))
	var height: int = maxi(1, roundi(piece.get_height() * scale))
	piece.resize(width, height, Image.INTERPOLATE_LANCZOS)
	# Hard alpha keeps the pixel-art edge crisp after resampling.
	for y: int in range(height):
		for x: int in range(width):
			var c: Color = piece.get_pixel(x, y)
			piece.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0 if c.a >= 0.5 else 0.0))
	var canvas: Image = Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i((FRAME - width) / 2, FRAME - height))
	return canvas

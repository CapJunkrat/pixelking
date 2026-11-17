extends SceneTree

## Turns two generated piece sheets (white and black, 6 columns x 3 rows in the order
## below) into a piece skin: 128x128 transparent PNGs named <color>_<piece>.png.
##
## Usage:
##   Godot --headless --path . --script res://scripts/visual_review/slice_piece_sheets.gd -- \
##       <white sheet> <black sheet> <output folder>
##
## The sheets may use a flat magenta background or a checkerboard drawn into the image;
## both are removed. Each piece is scaled to the height of its weight tier and stands
## centred on the bottom edge, so every base sits on the same line.

const ORDER: Array[String] = [
	"pawn", "knight", "bishop", "rook", "queen", "king",
	"assassin", "bowman", "catapult", "lancer", "portal_mage", "royal_guard",
	"centaur", "unicorn_cavalry", "gryphon", "manticore", "archmage", "gorgon",
]
## Share of the 128 px frame each piece's height fills (light 60%, medium 75%,
## heavy 88%, king and queen 95%).
const TIER: Dictionary = {
	"pawn": 0.6, "knight": 0.75, "bishop": 0.75, "rook": 0.88, "queen": 0.95, "king": 0.95,
	"assassin": 0.62, "bowman": 0.62, "catapult": 0.86, "lancer": 0.78, "portal_mage": 0.75, "royal_guard": 0.88,
	"centaur": 0.78, "unicorn_cavalry": 0.88, "gryphon": 0.8, "manticore": 0.86, "archmage": 0.8, "gorgon": 0.78,
}
const FRAME := 128
const MAX_WIDTH := 124
const MIN_GAP := 12

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <white sheet> <black sheet> <output folder>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[2])
	var ok: bool = _slice(args[0], "white", args[2]) and _slice(args[1], "black", args[2])
	quit(0 if ok else 1)

func _slice(path: String, color: String, out_dir: String) -> bool:
	var sheet: Image = Image.load_from_file(path)
	if sheet == null or sheet.is_empty():
		push_error("cannot read %s" % path)
		return false
	sheet.convert(Image.FORMAT_RGBA8)
	_remove_background(sheet)
	var pieces: Array[Image] = _cut(sheet)
	if pieces.size() != ORDER.size():
		push_error("%s: found %d pieces, expected %d" % [path, pieces.size(), ORDER.size()])
		return false
	for index: int in range(ORDER.size()):
		var id: String = ORDER[index]
		var framed: Image = _frame(pieces[index], float(TIER[id]))
		framed.save_png("%s/%s_%s.png" % [out_dir, color, id])
		print("saved %s_%s" % [color, id])
	return true

## Background pixels are light and colourless (magenta is handled separately).
func _is_background(c: Color) -> bool:
	if minf(c.r, c.b) - c.g > 0.3:
		return true
	return c.get_luminance() > 0.7 and maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < 0.05

func _remove_background(img: Image) -> void:
	var width: int = img.get_width()
	var height: int = img.get_height()
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(width * height)
	# Every connected patch of background colour that touches the border, or is big
	# enough to be a checker square trapped between a weapon and a body, is cleared.
	for y: int in range(height):
		for x: int in range(width):
			var start: int = y * width + x
			if visited[start] == 1 or not _is_background(img.get_pixel(x, y)):
				continue
			var patch: Array[Vector2i] = []
			var touches_edge: bool = false
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			visited[start] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				patch.append(p)
				if p.x == 0 or p.y == 0 or p.x == width - 1 or p.y == height - 1:
					touches_edge = true
				for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + step
					if q.x < 0 or q.y < 0 or q.x >= width or q.y >= height:
						continue
					var index: int = q.y * width + q.x
					if visited[index] == 0 and _is_background(img.get_pixelv(q)):
						visited[index] = 1
						stack.append(q)
			if touches_edge or patch.size() >= 60:
				for p: Vector2i in patch:
					img.set_pixelv(p, Color(0, 0, 0, 0))
	# Soft pale fringe left by compression around the outline.
	for _pass: int in range(2):
		var source: Image = img.duplicate()
		for y: int in range(height):
			for x: int in range(width):
				var c: Color = source.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var spread: float = maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
				if spread > 0.08 or c.get_luminance() < 0.5:
					continue
				for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + step
					if q.x >= 0 and q.y >= 0 and q.x < width and q.y < height and source.get_pixelv(q).a < 0.5:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
						break

## Splits the sheet into rows, then each row into pieces, along empty gaps.
func _cut(img: Image) -> Array[Image]:
	var result: Array[Image] = []
	for rows: Vector2i in _runs(img, Rect2i(Vector2i.ZERO, img.get_size()), false):
		var band: Rect2i = Rect2i(0, rows.x, img.get_width(), rows.y - rows.x)
		for columns: Vector2i in _runs(img, band, true):
			var cell: Image = img.get_region(Rect2i(columns.x, rows.x, columns.y - columns.x, rows.y - rows.x))
			result.append(cell.get_region(cell.get_used_rect()))
	return result

func _runs(img: Image, rect: Rect2i, along_x: bool) -> Array[Vector2i]:
	var runs: Array[Vector2i] = []
	var length: int = rect.size.x if along_x else rect.size.y
	var depth: int = rect.size.y if along_x else rect.size.x
	var start: int = -1
	for i: int in range(length + 1):
		var filled: bool = false
		if i < length:
			for j: int in range(depth):
				var p: Vector2i = rect.position + (Vector2i(i, j) if along_x else Vector2i(j, i))
				if img.get_pixelv(p).a > 0.5:
					filled = true
					break
		if filled and start < 0:
			start = i
		elif not filled and start >= 0:
			if i - start > MIN_GAP:
				runs.append(Vector2i(start, i))
			start = -1
	return runs

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

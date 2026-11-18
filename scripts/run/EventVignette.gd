class_name EventVignette
extends Control

## The little scene drawn above an event: a sky in the event's colours, hills, a glow,
## and the props and pieces that stand in it (EventDef.props). A painted picture at
## res://assets/events/<id>.png is used instead when one exists.

const PICTURE_PATH := "res://assets/events/%s.png"
const FRAME := Color("#2b4166")
const STONE := Color("#6b7389")
const STONE_DARK := Color("#454b5e")
const WOOD := Color("#7a5232")
const WOOD_DARK := Color("#4e321e")
const CLOTH := Color("#a8423a")
const GOLD := Color("#e0b45c")
const PIECE_SIZE := 84.0

var event_id: String = ""
var sky_top: Color = Color("#141c33")
var sky_bottom: Color = Color("#3a2b4a")
var glow: Color = Color("#f5d58f")
var props: Array[String] = []
var picture: Texture2D = null
var _time: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 132)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func show_event(definition: EventDef) -> void:
	event_id = String(definition.id)
	sky_top = definition.sky_top
	sky_bottom = definition.sky_bottom
	glow = definition.glow
	props = definition.props.duplicate()
	var path: String = PICTURE_PATH % event_id
	picture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_place_pieces()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_pieces()

## Pieces stand in the scene as picture nodes, placed where _draw puts their shadows.
func _place_pieces() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if picture != null:
		return
	var skins: Node = get_node_or_null("/root/PieceSkinManager")
	var ordered: Array[String] = _ordered_props()
	for index: int in range(ordered.size()):
		var prop: String = ordered[index]
		if not prop.contains(":") or skins == null:
			continue
		var parts: PackedStringArray = prop.split(":")
		var texture: Texture2D = skins.call("piece_texture", &"white" if parts[0] == "piece" else &"black", StringName(parts[1])) as Texture2D
		if texture == null:
			continue
		var foot: Vector2 = _foot(index, ordered.size())
		var art: TextureRect = TextureRect.new()
		art.name = "Prop_%d" % index
		art.texture = texture
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.size = Vector2(PIECE_SIZE, PIECE_SIZE)
		art.position = foot - Vector2(PIECE_SIZE * 0.5, PIECE_SIZE - 6.0)
		add_child(art)

## Structures first so pieces stand in front of them.
func _ordered_props() -> Array[String]:
	var ordered: Array[String] = []
	for prop: String in props:
		if not prop.contains(":"):
			ordered.append(prop)
	for prop: String in props:
		if prop.contains(":"):
			ordered.append(prop)
	return ordered

func _foot(index: int, count: int) -> Vector2:
	return Vector2(size.x * (float(index) + 1.0) / (float(count) + 1.0), size.y * 0.8 + 6.0)

func _process(delta: float) -> void:
	# Only flames and glows move; a slow tick keeps them alive without busy redraws.
	_time += delta
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	if picture != null:
		draw_texture_rect(picture, area, false)
		draw_rect(area, FRAME, false, 2.0)
		return
	var w: float = size.x
	var h: float = size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))
	# Stars on dark skies.
	if sky_top.get_luminance() < 0.2:
		var seed_value: int = event_id.hash()
		for index: int in range(26):
			var x: float = float(absi((seed_value >> (index % 16)) * (index + 7) * 97) % int(maxf(w, 1.0)))
			var y: float = float(absi(seed_value * (index + 3) * 31) % int(maxf(h * 0.5, 1.0)))
			var twinkle: float = 0.5 + 0.5 * sin(_time * 2.0 + index)
			draw_rect(Rect2(x, y, 2, 2), Color(1, 1, 1, 0.35 + 0.4 * twinkle))
	# Moon or sun with a halo in the event's light.
	var orb: Vector2 = Vector2(w * 0.82, h * 0.26)
	for ring: int in range(4):
		draw_circle(orb, 22.0 + ring * 9.0, Color(glow, 0.07))
	draw_circle(orb, 15.0, glow.lightened(0.35))
	# Two rows of hills, then the ground the props stand on.
	var far: Color = sky_bottom.darkened(0.35)
	var near: Color = sky_bottom.darkened(0.6)
	draw_colored_polygon(_hills(h * 0.62, 18.0, 0.011, 1.3), far)
	draw_colored_polygon(_hills(h * 0.72, 12.0, 0.018, 4.1), near)
	var ground_y: float = h * 0.8
	draw_rect(Rect2(0, ground_y, w, h - ground_y), sky_bottom.darkened(0.75))
	draw_line(Vector2(0, ground_y), Vector2(w, ground_y), sky_bottom.darkened(0.45), 2.0)
	# Props spread across the ground; pieces are child nodes standing on these shadows.
	var ordered: Array[String] = _ordered_props()
	for index: int in range(ordered.size()):
		_draw_prop(ordered[index], _foot(index, ordered.size()))
	# Vignette edges and frame.
	for edge: int in range(6):
		draw_rect(Rect2(edge * 2.0, edge * 2.0, w - edge * 4.0, h - edge * 4.0), Color(0, 0, 0, 0.06), false, 2.0)
	draw_rect(area, FRAME, false, 2.0)

func _hills(base: float, height: float, frequency: float, phase: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(0, size.y))
	var steps: int = 24
	for step: int in range(steps + 1):
		var x: float = size.x * float(step) / float(steps)
		points.append(Vector2(x, base - height * (0.5 + 0.5 * sin(x * frequency * TAU + phase))))
	points.append(Vector2(size.x, size.y))
	return points

## Draws one prop standing with its feet at `foot`.
func _draw_prop(prop: String, foot: Vector2) -> void:
	if prop.begins_with("piece:") or prop.begins_with("enemy:"):
		_shadow(foot, 22.0)
		return
	match prop:
		"altar":
			_halo(foot + Vector2(0, -40), 34.0)
			_shadow(foot, 30.0)
			draw_rect(Rect2(foot.x - 22, foot.y - 30, 44, 30), STONE)
			draw_rect(Rect2(foot.x - 28, foot.y - 38, 56, 9), STONE.lightened(0.15))
			draw_rect(Rect2(foot.x - 22, foot.y - 30, 44, 4), STONE_DARK)
			draw_arc(foot + Vector2(0, -16), 8.0, 0, TAU, 20, Color(glow, 0.6 + 0.3 * sin(_time * 3.0)), 2.0)
			draw_rect(Rect2(foot.x - 2, foot.y - 50, 4, 10), glow)
		"cart":
			_shadow(foot, 40.0)
			draw_rect(Rect2(foot.x - 38, foot.y - 34, 64, 22), WOOD)
			draw_rect(Rect2(foot.x - 38, foot.y - 34, 64, 4), WOOD.lightened(0.2))
			draw_colored_polygon(PackedVector2Array([Vector2(foot.x - 40, foot.y - 34), Vector2(foot.x - 30, foot.y - 58), Vector2(foot.x + 18, foot.y - 58), Vector2(foot.x + 28, foot.y - 34)]), CLOTH)
			for stripe: int in range(3):
				draw_rect(Rect2(foot.x - 26 + stripe * 16, foot.y - 57, 6, 23), CLOTH.lightened(0.25))
			draw_line(Vector2(foot.x + 26, foot.y - 18), Vector2(foot.x + 44, foot.y - 10), WOOD_DARK, 3.0)
			for wheel: float in [-24.0, 12.0]:
				draw_circle(Vector2(foot.x + wheel, foot.y - 8), 9.0, WOOD_DARK)
				draw_circle(Vector2(foot.x + wheel, foot.y - 8), 4.0, WOOD)
		"campfire":
			_halo(foot + Vector2(0, -14), 40.0)
			for log_angle: float in [-0.35, 0.35]:
				var dir: Vector2 = Vector2(cos(log_angle), sin(log_angle)) * 16.0
				draw_line(foot - dir + Vector2(0, -3), foot + dir + Vector2(0, -3), WOOD_DARK, 5.0)
			var flicker: float = sin(_time * 9.0) * 2.0
			draw_colored_polygon(PackedVector2Array([foot + Vector2(-11, -5), foot + Vector2(flicker, -34), foot + Vector2(11, -5)]), Color("#ff6a2a"))
			draw_colored_polygon(PackedVector2Array([foot + Vector2(-6, -5), foot + Vector2(-flicker * 0.5, -22), foot + Vector2(6, -5)]), Color("#ffd36a"))
		"signpost":
			_shadow(foot, 12.0)
			draw_rect(Rect2(foot.x - 3, foot.y - 66, 6, 66), WOOD)
			draw_colored_polygon(PackedVector2Array([Vector2(foot.x - 3, foot.y - 60), Vector2(foot.x + 34, foot.y - 60), Vector2(foot.x + 42, foot.y - 53), Vector2(foot.x + 34, foot.y - 46), Vector2(foot.x - 3, foot.y - 46)]), WOOD.lightened(0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(foot.x + 3, foot.y - 40), Vector2(foot.x - 34, foot.y - 40), Vector2(foot.x - 42, foot.y - 33), Vector2(foot.x - 34, foot.y - 26), Vector2(foot.x + 3, foot.y - 26)]), WOOD.lightened(0.05))
			draw_rect(Rect2(foot.x + 6, foot.y - 55, 22, 2), GOLD)
		"well":
			_shadow(foot, 30.0)
			draw_rect(Rect2(foot.x - 24, foot.y - 26, 48, 26), STONE)
			for brick: int in range(3):
				draw_line(Vector2(foot.x - 24, foot.y - 8 - brick * 8), Vector2(foot.x + 24, foot.y - 8 - brick * 8), STONE_DARK, 1.0)
			draw_rect(Rect2(foot.x - 26, foot.y - 30, 52, 6), STONE.lightened(0.2))
			draw_rect(Rect2(foot.x - 22, foot.y - 62, 4, 32), WOOD)
			draw_rect(Rect2(foot.x + 18, foot.y - 62, 4, 32), WOOD)
			draw_colored_polygon(PackedVector2Array([Vector2(foot.x - 32, foot.y - 60), Vector2(foot.x, foot.y - 78), Vector2(foot.x + 32, foot.y - 60)]), CLOTH.darkened(0.2))
			draw_circle(foot + Vector2(0, -28), 3.0 + sin(_time * 2.0), Color(glow, 0.8))
		"table":
			_shadow(foot, 26.0)
			draw_rect(Rect2(foot.x - 24, foot.y - 26, 48, 26), WOOD)
			draw_rect(Rect2(foot.x - 24, foot.y - 26, 48, 4), WOOD.lightened(0.25))
			for cup: int in range(3):
				var cx: float = foot.x - 14 + cup * 14
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, foot.y - 26), Vector2(cx - 3, foot.y - 38), Vector2(cx + 3, foot.y - 38), Vector2(cx + 5, foot.y - 26)]), STONE.lightened(0.3))
			draw_circle(Vector2(foot.x + 20, foot.y - 29), 3.0, GOLD)
		"tent":
			_shadow(foot, 34.0)
			draw_colored_polygon(PackedVector2Array([Vector2(foot.x - 36, foot.y), Vector2(foot.x, foot.y - 56), Vector2(foot.x + 36, foot.y)]), Color("#c8b07a").darkened(0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(foot.x - 10, foot.y), Vector2(foot.x, foot.y - 26), Vector2(foot.x + 10, foot.y)]), Color("#2a1c12"))
			draw_line(Vector2(foot.x, foot.y - 56), Vector2(foot.x, foot.y - 66), WOOD_DARK, 2.0)
			draw_rect(Rect2(foot.x, foot.y - 66, 10, 6), CLOTH)
		"chest":
			_halo(foot + Vector2(0, -16), 26.0)
			_shadow(foot, 22.0)
			draw_rect(Rect2(foot.x - 20, foot.y - 22, 40, 22), WOOD)
			draw_rect(Rect2(foot.x - 20, foot.y - 30, 40, 9), WOOD.lightened(0.2))
			draw_rect(Rect2(foot.x - 20, foot.y - 22, 40, 2), GOLD)
			draw_rect(Rect2(foot.x - 3, foot.y - 24, 6, 8), GOLD)
		"banner":
			_shadow(foot, 10.0)
			draw_rect(Rect2(foot.x - 2, foot.y - 74, 4, 74), WOOD_DARK)
			var sway: float = sin(_time * 1.6) * 2.0
			draw_colored_polygon(PackedVector2Array([Vector2(foot.x + 2, foot.y - 72), Vector2(foot.x + 28 + sway, foot.y - 72), Vector2(foot.x + 28 + sway, foot.y - 38), Vector2(foot.x + 15 + sway, foot.y - 44), Vector2(foot.x + 2, foot.y - 38)]), CLOTH)
			draw_circle(Vector2(foot.x + 15 + sway * 0.5, foot.y - 58), 5.0, GOLD)

func _shadow(foot: Vector2, radius: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for step: int in range(20):
		var angle: float = TAU * float(step) / 20.0
		points.append(foot + Vector2(cos(angle) * radius, sin(angle) * radius * 0.3))
	draw_colored_polygon(points, Color(0, 0, 0, 0.35))

func _halo(centre: Vector2, radius: float) -> void:
	var pulse: float = 1.0 + 0.06 * sin(_time * 2.5)
	for ring: int in range(3):
		draw_circle(centre, radius * pulse * (1.0 - ring * 0.25), Color(glow, 0.08))

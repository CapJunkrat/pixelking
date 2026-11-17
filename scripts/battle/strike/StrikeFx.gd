class_name StrikeFx
extends RefCounted

## Small world-space particle toolkit for strike animations: debris chunks, sparks,
## ground rings, smoke puffs and crack decals. Presentation only.
##
## Positions are board world coordinates (see BoardProjection). Speeds and sizes that
## callers pass as plain numbers are in "design units" (one unit is 1/18 of a cell, the
## scale the animations were tuned at) and are multiplied by `unit` here.

const DECAL_LIFE := 4.0
const SMOKE_COLOR := Color(0.91, 0.88, 0.8)
const DEFAULT_RING := Color(0.9, 0.84, 0.7)

class Part:
	var pos: Vector3
	var vel: Vector3
	var color: Color
	var life: float
	var age: float = 0.0
	var size: float
	var gravity: float
	var bounced: int = 0

class Spark:
	var color: Color = Color(0.0, 0.0, 0.0, 0.0)
	var pos: Vector3
	var prev: Vector3
	var vel: Vector3
	var life: float
	var age: float = 0.0

class Ring:
	var x: float
	var z: float
	var max_radius: float
	var life: float
	var color: Color
	var age: float = 0.0

class Smoke:
	var pos: Vector3
	var vel: Vector3
	var radius: float
	var life: float
	var age: float = 0.0

class Crack:
	var points: PackedVector3Array = PackedVector3Array()
	var age: float = 0.0

var projection: BoardProjection = null
var unit: float = 1.0

var parts: Array[Part] = []
var sparks: Array[Spark] = []
var rings: Array[Ring] = []
var smoke: Array[Smoke] = []
var decals: Array[Crack] = []

func is_empty() -> bool:
	return parts.is_empty() and sparks.is_empty() and rings.is_empty() and smoke.is_empty() and decals.is_empty()

func clear() -> void:
	parts.clear()
	sparks.clear()
	rings.clear()
	smoke.clear()
	decals.clear()

# --- spawners ---------------------------------------------------------------

func add_part(pos: Vector3, vel: Vector3, color: Color, size: float, life: float, gravity: float) -> void:
	var part: Part = Part.new()
	part.pos = pos
	part.vel = vel
	part.color = color
	part.size = size
	part.life = life
	part.gravity = gravity
	parts.append(part)

func puff(pos: Vector3, count: int = 8, big: float = 1.0) -> void:
	for _index: int in range(count):
		var angle: float = randf() * TAU
		var item: Smoke = Smoke.new()
		item.pos = pos + Vector3(cos(angle) * 3.0, randf_range(0.0, 6.0), sin(angle) * 3.0) * unit
		item.vel = Vector3(cos(angle) * randf_range(10.0, 30.0) * big, randf_range(5.0, 25.0), sin(angle) * randf_range(10.0, 30.0) * big) * unit
		item.radius = randf_range(1.5, 3.0) * big * unit
		item.life = randf_range(0.3, 0.55)
		smoke.append(item)

## `color` with zero alpha keeps the default warm spark colour.
func spark_burst(pos: Vector3, count: int, direction: Vector2 = Vector2.ZERO, bias: float = 0.0, speed: float = 1.0, color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	for _index: int in range(count):
		var angle: float = randf() * TAU
		var magnitude: float = randf_range(70.0, 160.0) * speed
		var item: Spark = Spark.new()
		item.pos = pos
		item.prev = pos
		item.vel = Vector3(cos(angle) * magnitude + direction.x * bias, randf_range(20.0, 110.0) * speed, sin(angle) * magnitude + direction.y * bias) * unit
		item.life = randf_range(0.18, 0.34)
		item.color = color
		sparks.append(item)

## `max_radius` is in world units.
func ring(x: float, z: float, max_radius: float, life: float = 0.38, color: Color = DEFAULT_RING) -> void:
	var item: Ring = Ring.new()
	item.x = x
	item.z = z
	item.max_radius = max_radius
	item.life = life
	item.color = color
	rings.append(item)

## `length` is in world units.
func crack_decal(x: float, z: float, count: int, length: float) -> void:
	var step: float = 1.5 * unit
	for index: int in range(count):
		var angle: float = float(index) / count * TAU + randf_range(-0.3, 0.3)
		var decal: Crack = Crack.new()
		var px: float = x
		var pz: float = z
		decal.points.append(Vector3(px, 0.0, pz))
		var total: float = length * randf_range(0.55, 1.0)
		var travelled: float = 0.0
		while travelled < total:
			angle += randf_range(-0.35, 0.35)
			px += cos(angle) * step
			pz += sin(angle) * step
			decal.points.append(Vector3(px, 0.0, pz))
			travelled += step
		decals.append(decal)

# --- simulation -------------------------------------------------------------

func step(dt: float) -> void:
	for part: Part in parts:
		part.age += dt
		part.vel.y -= part.gravity * dt
		part.pos += part.vel * dt
		if part.pos.y < 0.0:
			part.pos.y = 0.0
			if part.bounced < 2:
				part.vel.y *= -0.32
				part.vel.x *= 0.55
				part.vel.z *= 0.55
				part.bounced += 1
			else:
				part.vel.y = 0.0
				part.vel.x *= 0.8
				part.vel.z *= 0.8
	parts = parts.filter(func(part: Part) -> bool: return part.age < part.life)
	for spark: Spark in sparks:
		spark.age += dt
		spark.vel.y -= 200.0 * unit * dt
		spark.prev = spark.pos
		spark.pos += spark.vel * dt
	sparks = sparks.filter(func(spark: Spark) -> bool: return spark.age < spark.life)
	for item: Ring in rings:
		item.age += dt
	rings = rings.filter(func(item: Ring) -> bool: return item.age < item.life)
	for item: Smoke in smoke:
		item.age += dt
		item.pos += item.vel * dt
		item.vel.x *= 0.9
		item.vel.z *= 0.9
		item.vel.y *= 0.92
	smoke = smoke.filter(func(item: Smoke) -> bool: return item.age < item.life)
	for decal: Crack in decals:
		decal.age += dt
	decals = decals.filter(func(decal: Crack) -> bool: return decal.age < DECAL_LIFE)

# --- drawing ----------------------------------------------------------------

## Everything that lies on the board surface. Draw below the pieces.
func draw_ground(canvas: CanvasItem) -> void:
	for decal: Crack in decals:
		var fade: float = clampf((DECAL_LIFE - decal.age) / 1.0, 0.0, 1.0)
		var line: PackedVector2Array = PackedVector2Array()
		for point: Vector3 in decal.points:
			line.append(projection.project(point))
		if line.size() >= 2:
			canvas.draw_polyline(line, Color(0.055, 0.035, 0.024, 0.85 * fade), maxf(unit, 1.0))
	for item: Ring in rings:
		var progress: float = item.age / item.life
		var radius: float = 3.0 * unit + (1.0 - (1.0 - progress) * (1.0 - progress)) * item.max_radius
		var outline: PackedVector2Array = PackedVector2Array()
		for index: int in range(33):
			var angle: float = TAU * index / 32.0
			outline.append(projection.project(Vector3(item.x + cos(angle) * radius, 0.0, item.z + sin(angle) * radius)))
		canvas.draw_polyline(outline, Color(item.color, 0.75 * (1.0 - progress)), maxf(unit * 1.2, 1.0))
	for part: Part in parts:
		if part.pos.y <= 0.01:
			_draw_part(canvas, part)

## Everything in the air. Draw above the pieces.
func draw_air(canvas: CanvasItem) -> void:
	for part: Part in parts:
		if part.pos.y > 0.01:
			_draw_part(canvas, part)
	for item: Smoke in smoke:
		var progress: float = item.age / item.life
		canvas.draw_circle(projection.project(item.pos), item.radius * (1.0 + progress * 1.4), Color(SMOKE_COLOR, 0.55 * (1.0 - progress)))
	for spark: Spark in sparks:
		var fade: float = 1.0 - spark.age / spark.life
		var color: Color = Color(spark.color, fade) if spark.color.a > 0.0 else Color(1.0, randf_range(0.78, 1.0), 0.47, fade)
		canvas.draw_line(projection.project(spark.prev), projection.project(spark.pos), color, maxf(unit, 1.0))

func _draw_part(canvas: CanvasItem, part: Part) -> void:
	var size: float = part.size * projection.scale_at(part.pos)
	var at: Vector2 = projection.project(part.pos)
	var color: Color = Color(part.color, clampf((part.life - part.age) / 0.35, 0.0, 1.0))
	canvas.draw_rect(Rect2(at - Vector2(size * 0.5, size), Vector2(size, size)), color)

class_name SquireStrike
extends StrikeAttack

## Hops in and fences: a wobbling first hit, then the thrust; levels up in a golden
## ring.

const TIMING := {"impact": 0.52, "done": 1.9, "end": 2.4, "hitstop": 0.09, "shake": 0.5}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.4, _wobble_hit], [1.05, _level_up]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var hit: Vector3 = s.toward(0.5)
	if u < 0.14:
		o.sy = 0.9
		o.sx = 1.06
	elif u < 0.34:
		var q: float = (u - 0.14) / 0.2
		o.at(a.lerp(hit, q))
		o.y = absf(sin(q * PI * 2.0)) * s.n(2.0)
	elif u < 0.75:
		var k: float = sin(s.progress(u, 0.34, 0.1) * PI) if u < 0.44 else sin(s.progress(u, 0.44, 0.12) * PI)
		o.at(s.along(hit, s.n(3.0) * k))
		o.sx = 1.0 + 0.08 * k
		o.sy = 1.0 - 0.06 * k
	else:
		s.settle_into(o, hit, u, 0.75, 0.25, 2.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	fx.spark_burst(s.up(b, 9.0), 9, s.dir, 80.0, 0.6)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	if u > 0.3 and u < 0.6:
		var hand: Vector3 = Vector3(o.x, o.y + s.ah(7.0), o.z)
		s.pixel_line(canvas, s.screen(hand), s.screen(Vector3(hand.x + s.dir.x * s.n(8.0), hand.y, hand.z + s.dir.y * s.n(8.0))), Color("#dfe6f0"))
	if u > 1.05 and u < 1.85:
		var k: float = (u - 1.05) / 0.8
		var arrow: Vector2 = s.screen(Vector3(o.x, o.y + s.ah(16.0), o.z)) - Vector2(0.0, k * s.n(8.0))
		var color: Color = Color(1.0, 0.886, 0.47, 1.0 - k)
		canvas.draw_rect(Rect2(arrow, Vector2(1.0, 5.0) * s.unit), color)
		canvas.draw_rect(Rect2(arrow + Vector2(-1.0, 1.0) * s.unit, Vector2(3.0, 1.0) * s.unit), color)
		canvas.draw_rect(Rect2(arrow + Vector2(-2.0, 2.0) * s.unit, Vector2(5.0, 1.0) * s.unit), color)

func _wobble_hit() -> void:
	s.fx.spark_burst(s.up(s.b, 9.0), 4, s.dir, 40.0, 0.4)
	s.wobble_time = s.t

func _level_up() -> void:
	s.fx.ring(s.dest.x, s.dest.z, s.cell * 0.7, 0.45, StrikePalette.GOLDEN)
	s.fx.ring(s.dest.x, s.dest.z, s.cell * 0.4, 0.3, StrikePalette.GOLDEN)
	for index: int in range(10):
		var angle: float = randf() * TAU
		s.part(Vector3(s.dest.x + cos(angle) * s.n(4.0), s.ah(12.0), s.dest.z), Vector3(cos(angle) * 12.0, randf_range(20.0, 40.0), 0.0), Color("#ffe08a"), randf_range(0.5, 0.9), -10.0)

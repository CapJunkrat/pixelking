class_name SkyArcherStrike
extends StrikeAttack

## Shoots an arrow straight up; it comes down on the target as a falling star.

const TIMING := {"impact": 1.2, "done": 1.3, "end": 2.5, "hitstop": 0.14, "shake": 1.1}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var a: Vector3 = s.a
	return [[0.45, s.event_sparks.bind(Vector3(a.x, s.ah(14.0), a.z), 6, 0.0, 0.5)]]

func pose(u: float, o: StrikePose) -> void:
	var face: float = s.face
	if u < 0.4:
		var sv: float = s.smooth01(u / 0.4)
		o.sy = 1.0 - 0.12 * sv
		o.sx = 1.0 + 0.05 * sv
		o.rot = -0.15 * sv * face
	elif u < 0.45:
		o.sy = 0.88
		o.rot = -0.15 * face
	elif u < 0.65:
		var q: float = (u - 0.45) / 0.2
		o.sy = lerpf(0.86, 1.0, s.smooth01(q))
		o.rot = -0.15 * face * (1.0 - q)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 1.3, 0.5, StrikePalette.GOLDEN)
	fx.ring(b.x, b.z, cell * 0.6, 0.3, Color(1.0, 0.98, 0.9))
	fx.spark_burst(s.up(b, 4.0), 14, Vector2.ZERO, 0.0, 0.8, StrikePalette.GOLDEN)
	for index: int in range(14):
		s.part(Vector3(b.x + randf_range(-8.0, 8.0) * s.unit, s.vh(randf_range(12.0, 24.0)), b.z), Vector3(randf_range(-8.0, 8.0), randf_range(-4.0, 4.0), 0.0), Color("#ffe08a") if randf() < 0.5 else StrikePalette.HOLY_WHITE, randf_range(1.2, 1.8), 12.0)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var c: float = s.cell
	if u > 0.45 and u < 0.72:
		var y: float = s.ah(14.0) + (u - 0.45) / 0.27 * c * 7.0
		var head: Vector2 = s.screen(Vector3(s.a.x, y, s.a.z))
		s.pixel_line(canvas, head + Vector2(0.0, s.n(10.0)), head, Color("#ffe08a"))
		s.pixel(canvas, head, Color.WHITE)
	if u > 0.68 and u < 0.9:
		var k: float = sin((u - 0.68) / 0.22 * PI)
		var star: Vector2 = s.screen(Vector3(s.b.x, c * 5.0, s.b.z))
		var r: float = roundf(1.0 + 3.0 * k)
		canvas.draw_rect(Rect2(star + Vector2(-r - 0.5, -0.5) * s.unit, Vector2(2.0 * r + 1.0, 1.0) * s.unit), Color("#fff3c4"))
		canvas.draw_rect(Rect2(star + Vector2(-0.5, -r - 0.5) * s.unit, Vector2(1.0, 2.0 * r + 1.0) * s.unit), Color("#fff3c4"))
	if u > 0.86 and not s.impacted:
		var q: float = s.progress(u, 0.86, float(TIMING["impact"]) - 0.86)
		var at: Vector2 = s.screen(Vector3(s.b.x, lerpf(c * 5.0, s.vh(14.0), s.ease_in01(q)), s.b.z))
		canvas.draw_line(at - Vector2(0.0, s.n(30.0)), at, Color(1.0, 0.886, 0.588, 0.45), 3.0 * s.unit)
		for index: int in range(1, 8):
			s.pixel(canvas, at + Vector2(-index, -2.0 - index) * s.unit, Color("#ffd27a"))
			s.pixel(canvas, at + Vector2(index, -2.0 - index) * s.unit, Color("#ffd27a"))
		canvas.draw_rect(Rect2(at + Vector2(-0.5, -6.0) * s.unit, Vector2(1.0, 7.0) * s.unit), Color("#fff3c4"))

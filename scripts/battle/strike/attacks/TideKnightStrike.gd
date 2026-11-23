class_name TideKnightStrike
extends StrikeAttack

## Rides a wave in, crashes into the target in a burst of spray and rolls past it.

const TIMING := {"impact": 0.62, "done": 1.25, "end": 2.3, "hitstop": 0.12, "shake": 1.2}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var a: Vector3 = s.a
	return [[0.22, s.ring_at.bind(a, 0.6, 0.35, StrikePalette.WATER)]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var c: float = s.cell
	var hit: Vector3 = s.toward(0.5)
	var past: Vector3 = s.along(hit, s.n(5.0))
	if u < 0.25:
		var sv: float = sin(u / 0.25 * PI)
		o.rot = -0.32 * sv * face
		o.y = c * 0.15 * sv
	elif u < 0.62:
		var q: float = (u - 0.25) / 0.37
		o.at(a.lerp(hit, s.ease_in01(q)))
		o.y = c * 0.18 * q + absf(sin(q * PI * 3.0)) * s.n(2.0)
		o.rot = 0.1 * face
		o.trail = q > 0.3
	elif u < 0.8:
		var q: float = (u - 0.62) / 0.18
		o.at(hit.lerp(past, s.ease_out01(q)))
		o.y = c * 0.18 * (1.0 - q)
		o.rot = 0.1 * face * (1.0 - q)
	else:
		s.settle_into(o, past, u, 0.9, 0.3, 1.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 1.3, 0.5, StrikePalette.WATER)
	fx.ring(b.x, b.z, cell * 0.7, 0.32, StrikePalette.FOAM)
	fx.spark_burst(s.up(b, 8.0), 18, s.dir, 60.0, 1.0, StrikePalette.WATER)
	for index: int in range(30):
		s.part(Vector3(b.x + randf_range(-5.0, 5.0) * s.unit, s.vh(randf_range(2.0, 10.0)), b.z), Vector3(randf_range(-50.0, 50.0) + s.dir.x * 40.0, randf_range(40.0, 110.0), randf_range(-20.0, 20.0) + s.dir.y * 40.0), StrikePalette.WATER if randf() < 0.5 else StrikePalette.FOAM, randf_range(0.5, 0.9), 260.0, 2.0 if randf() < 0.3 else 1.0)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	if u > 0.25 and u < 0.62:
		var q: float = (u - 0.25) / 0.37
		var base: Vector2 = s.screen(Vector3(o.x, 0.0, o.z))
		var along: Vector2 = s.screen_dir()
		var height: float = s.n(3.0 + 7.0 * q)
		for index: int in range(-9, 5):
			var foot: Vector2 = base - along * index * s.n(1.5)
			var top: float = height * maxf(0.0, 1.0 - absf(index + 2) / 8.0)
			canvas.draw_rect(Rect2(foot.x, foot.y - top, s.unit, top + s.unit), Color(0.31, 0.59, 0.9, 0.85))
			s.pixel(canvas, Vector2(foot.x + s.unit * 0.5, foot.y - top), StrikePalette.FOAM)
		if randf() < 0.8:
			s.part(Vector3(o.x + randf_range(-4.0, 4.0) * s.unit, height, o.z), Vector3(randf_range(-20.0, 20.0) - s.dir.x * 30.0, randf_range(20.0, 50.0), randf_range(-6.0, 6.0) - s.dir.y * 30.0), StrikePalette.WATER if randf() < 0.5 else StrikePalette.FOAM, randf_range(0.3, 0.5), 220.0)

class_name SwiftCourierStrike
extends StrikeAttack

## Hops halfway in, darts at the target with a quick cut and dashes past it, trailing
## speed lines.

const TIMING := {"impact": 0.44, "done": 1.05, "end": 2.0, "hitstop": 0.11, "shake": 0.6}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var a: Vector3 = s.a
	return [[0.06, s.event_puff.bind(s.up(a, 1.0), 4, 0.5)], [0.26, s.event_puff.bind(s.up(a.lerp(s.b, 0.5), 1.0), 6, 0.7)]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var c: float = s.cell
	var middle: Vector3 = a.lerp(s.b, 0.5)
	var hit: Vector3 = s.toward(0.45)
	var over: Vector3 = s.along(hit, s.n(4.0))
	if u < 0.06:
		o.sy = 0.88
		o.sx = 1.08
	elif u < 0.26:
		var q: float = (u - 0.06) / 0.2
		o.at(a.lerp(middle, q))
		o.y = c * 0.4 * 4.0 * q * (1.0 - q)
	elif u < 0.3:
		o.at(middle)
		o.sy = 0.85
		o.sx = 1.1
	elif u < 0.44:
		var q: float = (u - 0.3) / 0.14
		o.at(middle.lerp(hit, s.ease_in01(q)))
		o.rot = 0.08 * face
		o.sx = 1.12
		o.sy = 0.92
		o.trail = true
	elif u < 0.58:
		var q: float = (u - 0.44) / 0.14
		o.at(hit.lerp(over, s.ease_out01(q)))
		o.rot = 0.08 * face * (1.0 - q)
	else:
		s.settle_into(o, over, u, 0.75, 0.25, 1.5)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	s.slash_age = 0.0
	fx.spark_burst(s.up(b, 9.0), 9, s.dir, 60.0, 0.7, StrikePalette.FOAM)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	if u > 0.3 and u < 0.55:
		for _i: int in range(3):
			var back: float = randf_range(4.0, 14.0)
			var p: Vector2 = s.screen(Vector3(o.x - s.dir.x * s.n(back), o.y + s.ah(randf_range(2.0, 12.0)), o.z - s.dir.y * s.n(back)))
			s.pixel_line(canvas, p, p - s.screen_dir() * s.n(randf_range(4.0, 8.0)), Color(0.9, 0.96, 1.0, 0.55))

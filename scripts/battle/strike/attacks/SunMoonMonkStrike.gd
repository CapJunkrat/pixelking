class_name SunMoonMonkStrike
extends StrikeAttack

## Dashes in and strikes twice: a sun palm, then a moon palm.

const TIMING := {"impact": 0.62, "done": 1.2, "end": 2.3, "hitstop": 0.13, "shake": 1.0}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.4, _sun_palm]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var hit: Vector3 = s.toward(0.6)
	if u < 0.28:
		var sv: float = s.smooth01(u / 0.28)
		o.sy = 1.0 - 0.1 * sv
		o.sx = 1.0 + 0.06 * sv
		o.white = 0.35 * sv * (0.6 + 0.4 * sin(u * 40.0))
	elif u < 0.4:
		var q: float = (u - 0.28) / 0.12
		o.at(a.lerp(hit, s.ease_in01(q)))
		o.sx = 1.1
		o.rot = 0.1 * face
	elif u < 0.52:
		var q: float = (u - 0.4) / 0.12
		o.at(s.along(hit, -s.n(2.0) * sin(q * PI)))
		o.rot = lerpf(0.1, -0.18, s.smooth01(q)) * face
	elif u < 0.62:
		var q: float = (u - 0.52) / 0.1
		o.at(s.along(hit, s.n(2.0) * q))
		o.rot = lerpf(-0.18, 0.16, s.ease_in01(q)) * face
		o.sx = 1.0 + 0.12 * q
	elif u < 0.85:
		var q: float = (u - 0.62) / 0.23
		o.at(s.along(hit, s.n(2.0) * (1.0 - q)))
		o.rot = 0.16 * face * (1.0 - q)
	else:
		s.settle_into(o, hit, u, 0.9, 0.28, 1.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 1.2, 0.45, StrikePalette.MOON)
	fx.ring(b.x, b.z, cell * 0.6, 0.3, Color(0.9, 0.94, 1.0))
	fx.spark_burst(s.up(b, 8.0), 12, s.dir, 60.0, 0.8, StrikePalette.MOON)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	if u > 0.3 and u < 0.62:
		var palm: Vector3 = Vector3(o.x + s.dir.x * s.n(5.0), o.y + s.ah(7.0), o.z + s.dir.y * s.n(5.0))
		s.pixel(canvas, s.screen(palm), Color("#ffe08a") if u < 0.45 else Color("#a0c8ff"), 3.0)

func _sun_palm() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.8, 0.35, StrikePalette.GOLDEN)
	s.fx.spark_burst(s.up(s.b, 8.0), 10, s.dir, 40.0, 0.6, StrikePalette.GOLDEN)
	s.wobble_time = s.t
	s.hs = 0.06
	s.shake = maxf(s.shake, 0.5)

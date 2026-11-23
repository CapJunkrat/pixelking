class_name WarKingStrike
extends StrikeAttack

## Glows, leaps high above the target and smashes down on it.

const TIMING := {"impact": 0.68, "done": 1.3, "end": 2.5, "hitstop": 0.15, "shake": 1.6}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var a: Vector3 = s.a
	return [[0.28, s.event_puff.bind(s.up(a, 1.0), 8, 1.0)]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var c: float = s.cell
	var hit: Vector3 = s.toward(0.45)
	if u < 0.28:
		var sv: float = s.smooth01(u / 0.28)
		o.sy = 1.0 - 0.15 * sv
		o.sx = 1.0 + 0.08 * sv
		o.white = 0.5 * sv * (0.7 + 0.3 * sin(u * 50.0))
	elif u < 0.55:
		var q: float = (u - 0.28) / 0.27
		o.at(a.lerp(hit, q))
		o.y = c * 2.2 * s.ease_out01(q)
		o.rot = -0.15 * face
		o.white = 0.5
	elif u < 0.6:
		o.at(hit)
		o.y = c * 2.2
		o.rot = -0.2 * face
		o.white = 0.6
	elif u < 0.68:
		var q: float = (u - 0.6) / 0.08
		o.at(hit)
		o.y = c * 2.2 * (1.0 - s.ease_in01(q))
		o.rot = 0.2 * face
		o.sy = 1.15
		o.sx = 0.9
		o.trail = true
	elif u < 1.0:
		o.at(hit)
		if u < 0.85:
			var q: float = (u - 0.68) / 0.17
			var w: float = sin(q * PI)
			o.sx = 1.0 + 0.25 * w
			o.sy = 1.0 - 0.2 * w
			o.rot = 0.2 * face * (1.0 - q)
	else:
		s.settle_into(o, hit, u, 1.0, 0.3, 1.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	s.slash_age = 0.0
	fx.ring(b.x, b.z, cell * 1.6, 0.55, StrikePalette.GOLDEN)
	fx.ring(b.x, b.z, cell * 0.9, 0.35, StrikePalette.GOLDEN)
	fx.puff(s.up(b, 2.0), 12, 1.3)
	fx.crack_decal(b.x, b.z, 10, cell * 1.3)
	fx.spark_burst(s.up(b, 6.0), 16, Vector2.ZERO, 0.0, 0.9, StrikePalette.GOLDEN)

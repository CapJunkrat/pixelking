class_name AntelopeStrike
extends StrikeAttack

## Leaps high in a long arc, lands by the target and butts it with its horns.

const TIMING := {"impact": 0.74, "done": 1.5, "end": 2.4, "hitstop": 0.1, "shake": 0.9}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var a: Vector3 = s.a
	return [[0.22, s.event_puff.bind(s.up(a, 1.0), 7, 0.9)], [0.6, s.event_puff.bind(s.up(s.toward(0.55), 1.0), 6, 0.8)]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var c: float = s.cell
	var hit: Vector3 = s.toward(0.55)
	if u < 0.22:
		var sv: float = sin(u / 0.22 * PI * 0.5)
		o.sy = 1.0 - 0.2 * sv
		o.sx = 1.0 + 0.1 * sv
	elif u < 0.6:
		var q: float = (u - 0.22) / 0.38
		o.at(a.lerp(hit, q))
		o.y = c * 2.4 * 4.0 * q * (1.0 - q)
		o.rot = lerpf(-0.25, 0.2, q) * face
		o.trail = q > 0.3
	elif u < 1.2:
		o.at(hit)
		if u < 0.66:
			var q: float = (u - 0.6) / 0.06
			o.sy = 1.0 - 0.15 * sin(q * PI)
			o.sx = 1.0 + 0.1 * sin(q * PI)
		elif u < 0.74:
			o.rot = 0.35 * (u - 0.66) / 0.08 * face
			o.sy = 0.92
		elif u < 0.9:
			var q: float = (u - 0.74) / 0.16
			o.rot = lerpf(0.35, -0.3, s.ease_out01(q)) * face
			o.y = c * 0.15 * sin(q * PI)
		elif u < 1.05:
			o.rot = -0.3 * face * (1.0 - (u - 0.9) / 0.15)
	else:
		s.settle_into(o, hit, u, 1.2, 0.3, 2.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	fx.spark_burst(s.up(b, 6.0), 8, s.dir, 40.0, 0.6)
	fx.puff(s.up(b, 2.0), 6, 0.8)

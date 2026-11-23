class_name RoyalGuardStrike
extends StrikeAttack

## Steps back with a glint of its shield, then rams the victim shield first.

const TIMING := {"impact": 0.52, "done": 0.94, "end": 2.3, "hitstop": 0.1, "shake": 1.3}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.22, s.event_sparks.bind(Vector3(s.along(s.a, 4.0 * s.unit).x, 8.0 * s.unit, s.along(s.a, 4.0 * s.unit).z), 4, 0.0, 0.25)]]

func pose(u: float, o: StrikePose) -> void:
	var back: Vector3 = s.along(s.a, -s.cell * 0.22)
	var contact: Vector3 = s.along(s.b, -s.cell * 0.55)
	if u < 0.3:
		var q: float = s.ease_out(u / 0.3)
		o.at(s.a.lerp(back, q))
		o.sx = 1.0 + 0.08 * q
		o.sy = 1.0 - 0.1 * q
		o.white = 0.5 if u > 0.18 and u < 0.28 else 0.0
		return
	if u < 0.52:
		var q: float = (u - 0.3) / 0.22
		o.at(back.lerp(contact, s.ease_in(q)))
		o.sx = 0.92
		o.sy = 1.08
		o.trail = true
		return
	if u < 0.62:
		var q: float = (u - 0.52) / 0.1
		o.at(contact)
		o.sx = 1.0 + 0.2 * sin(q * PI)
		o.sy = 1.0 - 0.18 * sin(q * PI)
		return
	s.settle_into(o, contact, u, 0.62, 0.32, 1.5)

func impact() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 1.3, 0.5, StrikePalette.GOLD)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.7, 0.3)
	s.fx.puff(s.up(s.b, 2.0), 9, 1.2)
	s.fx.spark_burst(s.up(s.b, 7.0), 8, s.dir, 40.0, 0.7)

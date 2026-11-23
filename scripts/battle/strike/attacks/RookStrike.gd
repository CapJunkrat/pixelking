class_name RookStrike
extends StrikeAttack

## Rumbles backwards, then charges and rams the victim, squashing on contact.

const TIMING := {"impact": 0.56, "done": 0.96, "end": 2.3, "hitstop": 0.1, "shake": 1.5}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.1, _event_rook_rumble.bind(0.0, 4, 0.6)], [0.25, _event_rook_rumble.bind(-4.0, 5, 0.7)]]

func pose(u: float, o: StrikePose) -> void:
	var back: Vector3 = s.along(s.a, -s.cell * 0.28)
	var contact: Vector3 = s.along(s.b, -s.cell * 0.55)
	if u < 0.38:
		var q: float = u / 0.38
		o.at(s.a.lerp(back, s.ease_out(q)))
		o.x += (randf() - 0.5) * 2.0 * s.unit * q
		o.sy = 1.0 - 0.1 * q
		o.sx = 1.0 + 0.06 * q
		return
	if u < 0.56:
		var q: float = (u - 0.38) / 0.18
		o.at(back.lerp(contact, s.ease_in(q)))
		o.sx = 0.9
		o.sy = 1.12
		o.trail = true
		return
	if u < 0.64:
		var q: float = (u - 0.56) / 0.08
		o.at(contact)
		o.sx = 1.0 + 0.22 * sin(q * PI)
		o.sy = 1.0 - 0.2 * sin(q * PI)
		return
	var q: float = clampf((u - 0.64) / 0.3, 0.0, 1.0)
	o.at(contact.lerp(s.b, s.smooth(q)))

func impact() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 1.4, 0.5)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.8, 0.32)
	s.fx.puff(s.up(s.b, 2.0), 10, 1.4)
	s.fx.spark_burst(s.up(s.b, 6.0), 8, s.dir, 40.0, 0.7)

func _event_rook_rumble(back: float, count: int, big: float) -> void:
	s.fx.puff(s.up(s.along(s.a, back * s.unit), 2.0), count, big)

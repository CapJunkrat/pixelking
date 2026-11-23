class_name CentaurStrike
extends StrikeAttack

## Gallops along the line, cuts while passing, wheels round and trots back.

const TIMING := {"impact": 0.47, "done": 1.38, "end": 2.2, "hitstop": 0.11, "shake": 0.7}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.2, s.event_puff.bind(s.up(s.a, 2.0), 6, 0.8)]]

func adjust_timing() -> bool:
	# The cut lands as the gallop passes the target, wherever that is on the line.
	var past: Vector3 = _centaur_past()
	var reach: float = Vector2(past.x - s.a.x, past.z - s.a.z).length()
	var hit: float = Vector2(s.b.x - s.a.x, s.b.z - s.a.z).length() / maxf(reach, 0.001)
	s.impact_time = 0.2 + 0.32 * clampf(hit, 0.2, 1.0)
	s.done_time = maxf(s.done_time, s.impact_time + 0.9)
	return true

func pose(u: float, o: StrikePose) -> void:
	var past: Vector3 = _centaur_past()
	if u < 0.2:
		var sv: float = sin(u / 0.2 * PI * 0.5)
		o.rot = -0.28 * sv * s.face
		o.y = s.cell * 0.1 * sv
		return
	if u < 0.52:
		var q: float = (u - 0.2) / 0.32
		o.at(s.a.lerp(past, q))
		o.y = absf(sin(q * PI * 4.0)) * 2.5 * s.unit
		o.rot = 0.08 * s.face
		o.trail = true
		o.white = 0.6 if absf(u - s.impact_time) < 0.04 else 0.0
		return
	o.at(past)
	if u < 0.8:
		o.rot = lerpf(0.08, -0.12, s.ease_out((u - 0.52) / 0.28)) * s.face
		return
	if u < 1.0:
		o.sx = lerpf(1.0, -1.0, s.smooth((u - 0.8) / 0.2))
		return
	var q: float = clampf((u - 1.0) / 0.38, 0.0, 1.0)
	o.sx = -1.0 if q < 1.0 else 1.0
	o.at(past.lerp(s.dest, s.smooth(q)))
	o.y = absf(sin(q * PI * 2.0)) * 2.0 * s.unit

func impact() -> void:
	s.slash_age = 0.0
	s.fx.spark_burst(s.up(s.b, 9.0), 10, s.dir, 70.0, 0.8)

func _centaur_past() -> Vector3:
	var past: Vector3 = s.along(s.b, s.cell * 0.75)
	return past if s.on_board(past) else s.along(s.b, s.cell * 0.35)

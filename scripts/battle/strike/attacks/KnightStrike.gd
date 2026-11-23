class_name KnightStrike
extends StrikeAttack

## Crouches, leaps over the corner square and stomps down on the victim, riding it down
## as it collapses.

const TIMING := {"impact": 0.84, "done": 1.1, "end": 2.6, "hitstop": 0.1, "shake": 1.35}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.24, _event_knight_crouch], [0.5, _event_knight_turn]]

func pose(u: float, o: StrikePose) -> void:
	var high: float = s.cell * 1.9
	var peak: float = s.cell * 2.2
	if u < 0.24:
		var sv: float = sin(u / 0.24 * PI * 0.5)
		o.rot = -0.32 * sv * s.face
		o.sx = 1.0 + 0.14 * sv
		o.sy = 1.0 - 0.18 * sv
		return
	if u < 0.5:
		var q: float = (u - 0.24) / 0.26
		var stretch: float = sin(q * PI)
		o.at(s.a.lerp(s.corner, q))
		o.y = high * s.ease_out(q)
		o.rot = lerpf(-0.32, -0.1, q) * s.face
		o.sy = 1.0 + 0.12 * stretch
		o.sx = 1.0 - 0.08 * stretch
		o.trail = true
		return
	if u < 0.66:
		var q: float = (u - 0.5) / 0.16
		var e: float = s.smooth(q)
		o.at(s.corner.lerp(s.b, e))
		o.y = lerpf(high, peak, q)
		o.rot = lerpf(-0.1, 0.38, e) * s.face
		o.trail = true
		return
	o.at(s.b)
	if u < 0.74:
		var q: float = (u - 0.66) / 0.08
		o.y = peak + 2.0 * s.unit * sin(q * PI)
		o.rot = 0.42 * s.face
		o.sx = 1.08
		o.sy = 0.94
		return
	if u < 0.84:
		var q: float = (u - 0.74) / 0.1
		o.y = lerpf(peak, s.victim_top(), s.ease_in(q))
		o.rot = 0.42 * s.face
		o.sx = 0.86
		o.sy = 1.22
		o.trail = true
		return
	var settle: float = clampf((u - 0.84) / 0.2, 0.0, 1.0)
	var squash: float = sin(clampf((u - 0.84) / 0.16, 0.0, 1.0) * PI) * (1.0 - settle * 0.3)
	o.y = s.victim_top()
	o.rot = lerpf(0.42, 0.0, s.ease_out(settle)) * s.face
	o.sx = 1.0 + 0.25 * squash
	o.sy = 1.0 - 0.22 * squash

func impact() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 1.3, 0.5)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.7, 0.3)
	s.fx.puff(s.up(s.b, 2.0), 12, 1.3)
	s.fx.crack_decal(s.b.x, s.b.z, 7, s.cell * 0.95)
	s.fx.spark_burst(s.up(s.b, 4.0), 6, Vector2.ZERO, 0.0, 0.6)

func _event_knight_crouch() -> void:
	s.fx.puff(s.up(s.a, 2.0), 6, 0.8)

func _event_knight_turn() -> void:
	s.fx.spark_burst(Vector3(s.corner.x, s.cell * 1.9, s.corner.z), 5, Vector2.ZERO, 0.0, 0.35)
	s.fx.ring(s.corner.x, s.corner.z, s.cell * 0.4, 0.25, StrikePalette.AMBER)

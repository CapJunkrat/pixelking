class_name BishopStrike
extends StrikeAttack

## Draws back glowing, then slashes straight through the victim and stops past it,
## leaving a long ghost trail.

const TIMING := {"impact": 0.36, "done": 1.14, "end": 2.2, "hitstop": 0.12, "shake": 0.8}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	var past: Vector3 = s.along(s.b, s.cell * 0.7)
	if not s.on_board(past):
		past = s.along(s.b, s.cell * 0.3)
	var wound: Vector3 = s.along(s.a, -2.0 * s.unit)
	if u < 0.28:
		var sv: float = sin(u / 0.28 * PI * 0.5)
		o.rot = -0.22 * sv * s.face
		o.sx = 1.0 + 0.1 * sv
		o.sy = 1.0 - 0.12 * sv
		o.at(s.along(s.a, -2.0 * s.unit * sv))
		o.white = 0.55 * sv * (0.7 + 0.3 * sin(u * 60.0))
		return
	if u < 0.36:
		var q: float = (u - 0.28) / 0.08
		o.at(wound.lerp(past, q))
		o.sx = 1.25
		o.sy = 0.82
		o.white = 0.8
		o.trail = true
		o.rot = 0.1 * s.face
		return
	if u < 0.9:
		var q: float = (u - 0.36) / 0.54
		o.at(past)
		o.rot = lerpf(0.18, 0.0, s.smooth(q)) * s.face
		o.white = 0.8 * (1.0 - clampf(q * 2.0, 0.0, 1.0))
		return
	var back: float = clampf((u - 0.9) / 0.22, 0.0, 1.0)
	o.at(past.lerp(s.b, s.smooth(back)))
	o.y = 4.0 * back * (1.0 - back) * 4.0 * s.unit

func trail_limit() -> int:
	return StrikeDirector.MAX_GHOSTS

func ghost_alpha_step() -> float:
	return 0.03

func impact() -> void:
	s.slash_age = 0.0
	s.fx.spark_burst(s.up(s.b, 9.0), 10, s.dir, 60.0, 0.8)

class_name AssassinStrike
extends StrikeAttack

## Vanishes in smoke, reappears behind the target and cuts backhanded.

const TIMING := {"impact": 0.62, "done": 1.43, "end": 2.0, "hitstop": 0.12, "shake": 0.7}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.16, s.event_puff.bind(s.up(s.a, 2.0), 9, 0.8)], [0.34, s.event_puff.bind(s.up(_assassin_behind(), 2.0), 7, 0.7)]]

func pose(u: float, o: StrikePose) -> void:
	var behind: Vector3 = _assassin_behind()
	if u < 0.16:
		var sv: float = u / 0.16
		o.sx = 1.0 + 0.15 * sv
		o.sy = 1.0 - 0.3 * sv
		o.alpha = 1.0 - 0.4 * sv
		return
	if u < 0.34:
		o.alpha = 0.0
		return
	o.at(behind)
	if u < 0.46:
		var q: float = (u - 0.34) / 0.12
		o.alpha = q
		o.sy = 0.75 + 0.25 * q
		return
	if u < 0.62:
		var q: float = (u - 0.46) / 0.16
		o.rot = lerpf(0.3, -0.4, s.ease_in(q)) * -s.face
		o.at(s.along(behind, -2.5 * s.unit * q))
		o.white = 0.45 * q
		o.trail = q > 0.6
		return
	if u < 1.15:
		var q: float = clampf((u - 0.62) / 0.25, 0.0, 1.0)
		o.at(s.along(behind, -2.5 * s.unit * (1.0 - q)))
		o.rot = 0.4 * s.face * (1.0 - s.smooth(q))
		return
	s.settle_into(o, behind, u, 1.15, 0.28, 3.0)

func impact() -> void:
	s.slash_age = 0.0
	s.fx.spark_burst(s.up(s.b, 9.0), 8, -s.dir, 50.0, 0.7)

func _assassin_behind() -> Vector3:
	var behind: Vector3 = s.along(s.b, s.cell * 0.62)
	return behind if s.on_board(behind) else s.along(s.b, s.cell * 0.35)

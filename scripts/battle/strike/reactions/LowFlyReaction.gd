class_name LowFlyReaction
extends StrikeReaction

## A heavier blunt attacker knocks a medium piece low and far; it skids to a stop.

func split_time() -> float:
	return 0.05

func on_split() -> void:
	var body: StrikeBody = s.make_body({})
	body.kind = &"low_fly"
	body.vx = (s.dir.x * 115.0 + s.face * 20.0) * s.unit
	body.vz = s.dir.y * 115.0 * s.unit
	body.vy = 38.0 * s.unit
	body.vr = 10.0 * s.face

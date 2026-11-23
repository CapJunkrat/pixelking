class_name BluntFlyReaction
extends StrikeReaction

## A blunt blow sends a light piece flying.

func split_time() -> float:
	return 0.06

func on_split() -> void:
	var body: StrikeBody = s.make_body({})
	body.vx = (s.dir.x * 70.0 + s.face * 25.0) * s.power * s.unit
	body.vz = s.dir.y * 70.0 * s.power * s.unit
	body.vy = 130.0 * s.power * s.unit
	body.vr = 15.0 * s.face
	body.gravity = 300.0 * s.unit
	body.shatter_ground = true
	body.poof = true

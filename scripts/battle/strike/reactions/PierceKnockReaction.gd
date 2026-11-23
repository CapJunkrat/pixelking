class_name PierceKnockReaction
extends StrikeReaction

## A pierce carries a light piece away.

func split_time() -> float:
	return 0.05

func on_split() -> void:
	var body: StrikeBody = s.make_body({})
	body.vx = s.dir.x * 150.0 * s.unit
	body.vz = s.dir.y * 150.0 * s.unit
	body.vy = 28.0 * s.unit
	body.vr = 1.5 * s.face
	body.gravity = 240.0 * s.unit
	body.shatter_ground = true
	body.poof = true

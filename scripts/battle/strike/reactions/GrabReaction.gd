class_name GrabReaction
extends StrikeReaction

## Carried up in the gryphon's talons and dropped from the top of the climb.

func split_time() -> float:
	return 0.0

func on_split() -> void:
	var body: StrikeBody = s.make_body({})
	body.kind = &"grab"
	body.base_y = body.y

func step_body(body: StrikeBody, dt: float) -> bool:
	if body.kind != &"grab":
		return false
	_step_grab(body, dt)
	return true

## Hangs from the gryphon's talons, then is dropped from the top of the climb.
func _step_grab(body: StrikeBody, dt: float) -> void:
	if s.rt < 0.5:
		var carrier: StrikePose = s.pose_at.call(s.t)
		body.x = carrier.x + (body.pivot.x - s.victim_chunks.aspect * 0.5) * s.victim_height
		body.z = carrier.z
		body.y = maxf(body.base_y, carrier.y - s.victim_at(0.55))
		body.rot = sin(body.age * 14.0) * 0.15 * clampf(body.age / 0.2, 0.0, 1.0)
		return
	if not body.released:
		body.released = true
		body.vy = 10.0 * s.unit
		body.vr = 6.0 * s.face
	body.vy -= 330.0 * s.unit * dt
	body.y += body.vy * dt
	body.rot += body.vr * dt
	if body.y < s.proj.height_for_pixels(3.0 * s.unit):
		s.shatter(body, 1.1)
		s.fx.ring(body.x, body.z, s.cell * 0.9, 0.42)
		s.fx.puff(Vector3(body.x, 2.0 * s.unit, body.z), 12, 1.2)
		s.fx.crack_decal(body.x, body.z, 5, s.cell * 0.7)
		s.shake = maxf(s.shake, 0.9)

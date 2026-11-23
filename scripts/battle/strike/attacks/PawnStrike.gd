class_name PawnStrike
extends StrikeAttack

## Hops in and jabs. Against a much heavier piece the first hit bounces off: it staggers
## back dizzy, takes a run-up and hits again.

const TIMING := {"impact": 0.38, "done": 0.74, "end": 2.1, "hitstop": 0.07, "shake": 0.55}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	if s.underdog:
		return [[0.38, _knock_brick_out]]
	return []

func done_time() -> float:
	return s.settle_time + 0.22

func pose(u: float, o: StrikePose) -> void:
	var contact: Vector3 = s.along(s.b, -s.cell * 0.38)
	var low_contact: Vector3 = s.along(s.b, -s.cell * 0.42)
	if u < 0.14:
		var sv: float = sin(u / 0.14 * PI * 0.5)
		o.sx = 1.0 + 0.2 * sv
		o.sy = 1.0 - 0.22 * sv
		return
	if u < 0.38:
		var q: float = (u - 0.14) / 0.24
		if s.underdog:
			o.at(s.a.lerp(low_contact, q))
			o.y = s.cell * 0.35 * 4.0 * q * (1.0 - q)
			o.rot = 0.6 * s.smooth(q) * s.face
			o.sy = 0.85
			o.sx = 1.1
			o.trail = true
		else:
			o.at(s.a.lerp(contact, q))
			o.y = s.cell * 0.75 * 4.0 * q * (1.0 - q) + s.cell * 0.25 * q
			o.rot = 0.4 * s.smooth(q) * s.face
			o.sy = 1.0 + 0.1 * sin(q * PI)
		return
	if s.underdog and u < 1.2:
		# First hit bounced off: stagger back dizzy, then take a run-up for the second.
		var rest: Vector3 = low_contact.lerp(s.a, 0.7)
		var runup: Vector3 = s.along(rest, -s.cell * 0.3)
		if u < 0.6:
			var q: float = (u - 0.38) / 0.22
			o.at(low_contact.lerp(rest, s.ease_out(q)))
			o.y = s.cell * 0.6 * 4.0 * q * (1.0 - q)
			o.rot = lerpf(0.6, -0.5, q) * s.face
			return
		o.at(rest)
		if u < 0.84:
			var q: float = (u - 0.6) / 0.24
			var w: float = sin(clampf(q * 3.0, 0.0, 1.0) * PI)
			o.rot = sin(q * PI * 3.0) * 0.18 * (1.0 - q)
			o.sy = 1.0 - 0.15 * w
			o.sx = 1.0 + 0.12 * w
			o.dizzy = true
			return
		if u < 0.96:
			var q: float = (u - 0.84) / 0.12
			o.at(rest.lerp(runup, s.smooth(q)))
			o.sy = 1.0 - 0.15 * q
			o.sx = 1.0 + 0.1 * q
			o.rot = -0.15 * q * s.face
			return
		var q: float = (u - 0.96) / 0.24
		o.at(runup.lerp(contact, s.ease_in(q)))
		if q < 0.55:
			o.y = absf(sin(q / 0.55 * PI * 2.0)) * 3.0 * s.unit
		else:
			o.y = s.cell * 0.55 * sin((q - 0.55) / 0.45 * PI * 0.75)
		o.rot = 0.45 * s.face
		o.trail = q > 0.35
		return
	var recoil: Vector3 = s.along(contact, -3.0 * s.unit)
	if u < s.impact_time + 0.14:
		var q: float = (u - s.impact_time) / 0.14
		o.at(contact.lerp(recoil, s.ease_out(q)))
		o.y = s.cell * 0.25 * (1.0 - q)
		o.rot = lerpf(0.4, -0.1, q) * s.face
		return
	if u < s.settle_time:
		o.at(recoil)
		o.rot = -0.1 * s.face
		return
	var q: float = clampf((u - s.settle_time) / 0.2, 0.0, 1.0)
	o.at(recoil.lerp(s.dest, s.smooth(q)))
	o.y = 4.0 * q * (1.0 - q) * 3.0 * s.unit
	o.rot = lerpf(-0.1, 0.0, q) * s.face

func impact() -> void:
	s.fx.spark_burst(s.up(s.b, 10.0), 10 if s.underdog else 7, s.dir, 30.0, 0.6)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.55, 0.28)

## Pawn against a heavy piece, first hit: a brick flies out of the far side of the base.
func _knock_brick_out() -> void:
	s.brick_out = true
	s.victim_material.set_shader_parameter(&"brick_mode", 1.0)
	var brick: StrikeBody = s.make_body({"brick_mode": 2.0})
	brick.vx = (s.dir.x * 50.0 + s.face * 50.0) * s.unit
	brick.vz = s.dir.y * 50.0 * s.unit
	brick.vy = 55.0 * s.unit
	brick.vr = 10.0 * s.face
	brick.gravity = 300.0 * s.unit
	brick.shatter_ground = true
	s.fx.spark_burst(s.up(s.b, 3.0), 8, s.dir, 40.0, 0.6)
	s.fx.puff(Vector3(s.b.x + s.face * 6.0 * s.unit, 2.0 * s.unit, s.b.z), 5, 0.7)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.45, 0.25)
	s.wobble_time = s.t
	s.hs = 0.06
	s.shake = 0.45

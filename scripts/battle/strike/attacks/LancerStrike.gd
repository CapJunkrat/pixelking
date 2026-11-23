class_name LancerStrike
extends StrikeAttack

## Lowers the lance, gallops in and spears the victim, then settles on the square.

const TIMING := {"impact": 0.58, "done": 1.25, "end": 2.2, "hitstop": 0.1, "shake": 0.9}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	var contact: Vector3 = s.along(s.b, -s.cell * 0.55)
	if u < 0.24:
		var sv: float = sin(u / 0.24 * PI * 0.5)
		o.rot = -0.25 * sv * s.face
		o.sy = 1.0 - 0.08 * sv
		return
	if u < 0.58:
		var q: float = (u - 0.24) / 0.34
		o.at(s.a.lerp(contact, s.ease_in(q)))
		o.y = absf(sin(q * PI * 3.0)) * 3.0 * s.unit
		o.rot = 0.1 * s.face
		o.trail = q > 0.4
		return
	if u < 0.95:
		var q: float = clampf((u - 0.58) / 0.15, 0.0, 1.0)
		o.at(s.along(contact, 3.0 * s.unit * sin(q * PI)))
		return
	s.settle_into(o, contact, u, 0.95, 0.3, 2.0)

func impact() -> void:
	s.fx.spark_burst(s.up(s.b, 8.0), 10, s.dir, 90.0, 0.7)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.7, 0.3)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var thin: float = maxf(s.unit, 1.0)
	if s.impacted and s.rt > 0.3:
		return
	var along: Vector2 = s.screen_dir()
	var lower: float = s.smooth(clampf((u - 0.06) / 0.2, 0.0, 1.0))
	var aim: Vector2 = Vector2(lerpf(along.x * 0.35, along.x, lower), lerpf(-0.95, along.y, lower)).normalized()
	var grip: Vector2 = s.proj.project(Vector3(s.pose.x, s.pose.y + s.attacker_at(0.5), s.pose.z + s.stand))
	var tip: Vector2 = grip + aim * 12.0 * s.unit
	canvas.draw_line(grip, tip, Color("#d9c79e"), thin)
	canvas.draw_rect(Rect2(tip - Vector2(0.5, 0.5) * s.unit, Vector2(s.unit, s.unit)), Color.WHITE)

class_name BowmanStrike
extends StrikeAttack

## Draws, looses an arrow on an arching flight, then trots in.

const TIMING := {"impact": 0.74, "done": 1.65, "end": 2.2, "hitstop": 0.08, "shake": 0.5}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.46, s.event_sparks.bind(Vector3(s.a.x, s.attacker_at(0.6), s.a.z), 3, 40.0, 0.25)]]

func pose(u: float, o: StrikePose) -> void:
	if u < 0.44:
		var sv: float = sin(clampf(u / 0.38, 0.0, 1.0) * PI * 0.5)
		o.rot = -0.14 * sv * s.face
		o.sx = 1.0 - 0.06 * sv
		o.sy = 1.0 + 0.04 * sv
		return
	if u < 0.6:
		var q: float = (u - 0.44) / 0.16
		o.at(s.along(s.a, -2.5 * s.unit * sin(q * PI)))
		o.rot = lerpf(0.12, 0.0, q) * s.face
		return
	if u < 1.2:
		return
	var q: float = clampf((u - 1.2) / 0.45, 0.0, 1.0)
	o.at(s.a.lerp(s.dest, s.smooth(q)))
	o.y = absf(sin(q * PI * 3.0)) * 2.5 * s.unit

func impact() -> void:
	s.fx.spark_burst(s.up(s.b, 9.0), 9, s.dir, 90.0, 0.6)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.5, 0.26)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var thin: float = maxf(s.unit, 1.0)
	if u < 0.08:
		return
	if u < 0.44:
		var hand: Vector2 = s.proj.project(Vector3(s.a.x, s.attacker_at(0.6), s.a.z + s.stand))
		var pull: float = clampf(u / 0.38, 0.0, 1.0) * 3.0 * s.unit
		var along: Vector2 = s.screen_dir()
		canvas.draw_line(hand - along * pull, hand + along * (6.0 * s.unit - pull), Color("#e8d9b0"), thin)
		return
	if s.impacted:
		return
	var q: float = clampf((u - 0.46) / (float(s.attack["impact"]) - 0.46), 0.0, 1.0)
	var head: Vector2 = _arrow_at(q)
	var tail: Vector2 = _arrow_at(maxf(0.0, q - 0.1))
	canvas.draw_line(tail, head, Color(1.0, 0.94, 0.78, 0.25), 3.0 * s.unit)
	canvas.draw_line(tail, head, Color("#e8d9b0"), thin)
	canvas.draw_rect(Rect2(head - Vector2(0.5, 0.5) * s.unit, Vector2(s.unit, s.unit)), Color.WHITE)
	var across: Vector2 = Vector2(-(head - tail).normalized().y, (head - tail).normalized().x) * s.unit
	canvas.draw_rect(Rect2(tail + across - Vector2(0.5, 0.5) * s.unit, Vector2(s.unit, s.unit)), Color("#d0564f"))
	canvas.draw_rect(Rect2(tail - across - Vector2(0.5, 0.5) * s.unit, Vector2(s.unit, s.unit)), Color("#d0564f"))

func _arrow_at(q: float) -> Vector2:
	var height: float = lerpf(s.attacker_at(0.6), s.victim_at(0.5), q) + s.cell * 0.7 * 4.0 * q * (1.0 - q)
	return s.proj.project(Vector3(lerpf(s.a.x, s.b.x, q), height, lerpf(s.a.z, s.b.z, q) + s.stand))

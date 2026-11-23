class_name PortalMageStrike
extends StrikeAttack

## Floats while the void gate opens, then blinks out and reappears on the square.

const TIMING := {"impact": 0.7, "done": 2.6, "end": 3.4, "hitstop": 0.06, "shake": 0.4}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var vanish: float = _portal_vanish()
	return [[vanish, s.event_puff.bind(s.up(s.a, 3.0), 8, 0.7)], [vanish + 0.25, _event_portal_arrive]]

func adjust_timing() -> bool:
	s.done_time = _portal_vanish() + 0.45
	return true

func pose(u: float, o: StrikePose) -> void:
	var vanish: float = _portal_vanish()
	o.y = s.cell * 0.22 * s.ease_out(clampf(u / 0.3, 0.0, 1.0)) + sin(u * 9.0) * 0.8 * s.unit
	o.white = 0.3 * clampf(u / 0.3, 0.0, 1.0) * (0.7 + 0.3 * sin(u * 40.0)) if u < 0.75 else 0.0
	if u < vanish:
		return
	if u < vanish + 0.1:
		var k: float = (u - vanish) / 0.1
		o.alpha = 1.0 - k
		o.sy = 1.0 + 0.3 * k
		o.sx = 1.0 - 0.4 * k
		return
	o.at(s.dest)
	o.y = 0.0
	if u < vanish + 0.25:
		o.alpha = 0.0
		return
	var q: float = clampf((u - vanish - 0.25) / 0.2, 0.0, 1.0)
	o.alpha = q
	o.y = s.cell * 0.25 * (1.0 - q)
	o.sy = 1.2 - 0.2 * q
	o.sx = 0.7 + 0.3 * q

func impact() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.9, 0.45, StrikePalette.VOID_COLOR)
	s.fx.spark_burst(s.up(s.b, 4.0), 6, Vector2.ZERO, 0.0, 0.4, StrikePalette.VOID_COLOR)

func draw_ground(canvas: CanvasItem) -> void:
	var u: float = s.t
	var foot: Vector3 = s.foot(s.b)
	if u < 0.2:
		return
	var radius: float = s.cell * 0.58 * s.ease_out(clampf((u - 0.2) / 0.5, 0.0, 1.0))
	var total: float = s.absorb_duration()
	if s.impacted and s.rt > total + 0.1:
		radius *= 1.0 - clampf((s.rt - total - 0.1) / 0.25, 0.0, 1.0)
	if radius < 0.5 * s.unit:
		return
	s.ground_disc(canvas, foot, radius + s.unit, Color(StrikePalette.VOID_DEEP, 0.55))
	s.ground_disc(canvas, foot, radius, Color(0.086, 0.024, 0.14, 0.96))
	s.ground_dots(canvas, foot, radius, 28, u * 5.0, Color("#d9b8ff"))
	s.ground_dots(canvas, foot, radius * 0.6, 18, -u * 7.0, StrikePalette.VOID_DEEP)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u > 0.1 and u < 0.75:
		var hand: Vector2 = s.proj.project(Vector3(s.pose.x, s.pose.y + s.attacker_at(0.85), s.pose.z + s.stand))
		canvas.draw_rect(Rect2(hand + Vector2(4.0, -2.0) * s.unit, Vector2(2.0, 2.0) * s.unit), Color(0.85, 0.72, 1.0, 0.6 + 0.4 * sin(u * 50.0)))

func _portal_vanish() -> float:
	return 0.7 + s.absorb_duration() + 0.45

func _event_portal_arrive() -> void:
	s.fx.puff(s.up(s.dest, 3.0), 8, 0.7)
	s.fx.ring(s.dest.x, s.dest.z, s.cell * 0.55, 0.3, StrikePalette.VOID_COLOR)

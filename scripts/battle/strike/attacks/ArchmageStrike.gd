class_name ArchmageStrike
extends StrikeAttack

## Hovers over a rune circle drawn under the victim, fires a beam from the staff, then
## glides onto the square.

const TIMING := {"impact": 0.76, "done": 2.6, "end": 3.4, "hitstop": 0.12, "shake": 0.9}

func timing() -> Dictionary:
	return TIMING

func adjust_timing() -> bool:
	s.done_time = _archmage_glide() + 0.45
	return true

func pose(u: float, o: StrikePose) -> void:
	var hover: float = s.cell * 0.32
	var glide: float = _archmage_glide()
	if u < glide:
		o.y = hover * s.ease_out(clampf(u / 0.3, 0.0, 1.0)) + sin(u * 8.0) * 0.8 * s.unit
		o.white = 0.35 * clampf(u / 0.3, 0.0, 1.0) * (0.7 + 0.3 * sin(u * 45.0)) if u < 0.8 else 0.0
		if u > 0.56 and u < 0.7:
			o.rot = 0.12 * s.face * sin((u - 0.56) / 0.14 * PI)
		return
	var q: float = clampf((u - glide) / 0.45, 0.0, 1.0)
	o.at(s.a.lerp(s.dest, s.smooth(q)))
	o.y = hover * (1.0 - s.ease_in(q))
	o.trail = q > 0.05 and q < 0.9

func impact() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.9, 0.4, StrikePalette.ARCANE_COLOR)
	s.fx.spark_burst(s.up(s.b, 8.0), 8, Vector2.ZERO, 0.0, 0.5, StrikePalette.ARCANE_COLOR)

func draw_ground(canvas: CanvasItem) -> void:
	var u: float = s.t
	var foot: Vector3 = s.foot(s.b)
	if u < 0.12:
		return
	var strength: float = clampf((u - 0.12) / 0.25, 0.0, 1.0)
	if s.impacted:
		strength *= 1.0 - clampf((s.rt - s.arcane_duration()) / 0.3, 0.0, 1.0)
	if strength <= 0.0:
		return
	var radius: float = s.cell * 0.62 * s.ease_out(strength)
	s.ground_dots(canvas, foot, radius, 40, u * 2.0, Color(StrikePalette.ARCANE_COLOR, strength))
	s.ground_dots(canvas, foot, radius * 0.72, 28, -u * 3.0, Color(StrikePalette.ARCANE_DEEP, 0.8 * strength))
	for index: int in range(6):
		var angle: float = TAU * index / 6.0 + u * 2.0
		var inner: Vector2 = s.proj.project(Vector3(foot.x + cos(angle) * radius * 0.72, 0.0, foot.z + sin(angle) * radius * 0.72))
		var outer: Vector2 = s.proj.project(Vector3(foot.x + cos(angle) * radius, 0.0, foot.z + sin(angle) * radius))
		canvas.draw_line(inner, outer, Color(StrikePalette.ARCANE_COLOR, strength), maxf(s.unit, 1.0))

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	# A beam from the staff: it shoots out, holds while the victim lifts, then fades.
	if u < 0.58:
		return
	var fade: float = 1.0 - clampf((s.rt - 0.25) / 0.3, 0.0, 1.0) if s.impacted else 1.0
	if fade <= 0.0:
		return
	var q: float = s.ease_in(clampf((u - 0.6) / 0.16, 0.0, 1.0))
	var staff: Vector2 = s.proj.project(Vector3(s.pose.x + s.face * 5.0 * s.unit, s.pose.y + s.attacker_at(1.0), s.pose.z + s.stand))
	var tip: Vector2 = staff.lerp(s.victim_centre(), q)
	var flicker: float = 0.85 + 0.15 * sin(u * 70.0)
	canvas.draw_line(staff, tip, Color(0.47, 0.78, 1.0, 0.28 * fade), 9.0 * s.unit)
	canvas.draw_line(staff, tip, Color(StrikePalette.ARCANE_COLOR, 0.75 * fade * flicker), 4.0 * s.unit)
	canvas.draw_line(staff, tip, Color(0.92, 0.99, 1.0, fade), 1.6 * s.unit)
	canvas.draw_circle(staff, 3.5 * s.unit, Color(0.92, 0.99, 1.0, 0.8 * fade))
	canvas.draw_circle(tip, 5.0 * s.unit * (0.6 + 0.4 * flicker), Color(0.47, 0.78, 1.0, 0.45 * fade))

func _archmage_glide() -> float:
	return 0.76 + s.arcane_duration() + 0.55

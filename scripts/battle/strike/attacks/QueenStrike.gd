class_name QueenStrike
extends StrikeAttack

## Rises glowing while a lance of light forms, draws back and flies through the target;
## then glides onto the square.

const TIMING := {"impact": 0.62, "done": 1.49, "end": 2.4, "hitstop": 0.12, "shake": 0.9}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	var hover: float = s.cell * 0.45
	if u < 0.3:
		var q: float = u / 0.3
		o.y = hover * s.ease_out(q)
		o.white = 0.35 * q
		o.sy = 1.0 + 0.06 * q
		return
	if u < 0.62:
		o.y = hover + sin(u * 18.0) * 0.8 * s.unit
		o.white = 0.35 + 0.15 * sin(u * 50.0)
		if u > 0.5:
			o.at(s.along(s.a, -2.0 * s.unit * (u - 0.5) / 0.12))
		return
	if u < 1.05:
		var q: float = (u - 0.62) / 0.43
		o.at(s.along(s.a, -2.0 * s.unit * (1.0 - q)))
		o.y = hover + sin(u * 18.0) * 0.8 * s.unit
		o.white = 0.4 * (1.0 - q)
		return
	var q: float = clampf((u - 1.05) / 0.42, 0.0, 1.0)
	o.at(s.a.lerp(s.b, s.smooth(q)))
	o.y = hover * (1.0 - s.ease_in(q))
	o.trail = q > 0.05 and q < 0.9

func impact() -> void:
	s.fx.spark_burst(s.up(s.b, 9.0), 14, s.dir, 120.0, 0.8)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.7, 0.3, StrikePalette.GOLD)

func draw_air(canvas: CanvasItem) -> void:
	_draw_lance(canvas)

## Queen: a lance of light forms in front of her, draws back, then flies through the target.
func _draw_lance(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u < 0.08 or (s.impacted and s.rt > 0.4):
		return
	var start: Vector2 = s.proj.project(Vector3(s.pose.x, s.pose.y + s.proj.height_for_pixels(8.0 * s.unit), s.pose.z + s.stand))
	var target: Vector2 = s.proj.project(Vector3(s.b.x, s.proj.height_for_pixels(7.0 * s.unit), s.b.z + s.stand))
	var distance: float = start.distance_to(target)
	if distance < 0.001:
		return
	var along: Vector2 = (target - start) / distance
	var across: Vector2 = Vector2(-along.y, along.x) * s.unit
	var full: float = 18.0 * s.unit
	var length: float = full
	var tail: float = 7.0 * s.unit
	var alpha: float = 1.0
	if u < 0.3:
		length = full * s.ease_out((u - 0.08) / 0.22)
		alpha = (u - 0.08) / 0.22
	elif u < 0.5:
		tail = (7.0 - 4.0 * s.smooth((u - 0.3) / 0.2)) * s.unit
	elif not s.impacted:
		tail = lerpf(3.0 * s.unit, distance - full + 9.0 * s.unit, s.ease_in(clampf((u - 0.5) / 0.12, 0.0, 1.0)))
	else:
		tail = distance - full + 9.0 * s.unit
		alpha = 1.0 - s.rt / 0.4
	var back: Vector2 = start + along * tail
	var tip: Vector2 = back + along * length
	canvas.draw_line(back, tip, Color(1.0, 0.86, 0.51, 0.3 * alpha), 5.0 * s.unit)
	if u > 0.5 and not s.impacted:
		canvas.draw_line(start, back, Color(1.0, 0.94, 0.75, 0.35), 2.0 * s.unit)
	var shoulder: Vector2 = tip - along * 3.0 * s.unit
	canvas.draw_line(back - across, shoulder - across, Color(StrikePalette.AMBER, alpha), maxf(s.unit, 1.0))
	canvas.draw_line(back + across, shoulder + across, Color(StrikePalette.AMBER, alpha), maxf(s.unit, 1.0))
	canvas.draw_line(back, tip, Color(1.0, 1.0, 1.0, alpha), maxf(s.unit, 1.0))

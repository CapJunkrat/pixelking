class_name EmberBirdStrike
extends StrikeAttack

## Melee: takes off, dives claws first into the target, hovers over it while it burns,
## then lands on its square.

const TIMING := {"impact": 0.62, "done": 2.3, "end": 3.2, "hitstop": 0.08, "shake": 0.5}

func timing() -> Dictionary:
	return TIMING

func adjust_timing() -> bool:
	var burn: float = s.burn_time()
	s.done_time = 0.75 + burn + 0.7
	s.end_time = 0.75 + burn + 1.4
	return true

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var c: float = s.cell
	# Melee: takes off, dives claws first into the target, hovers over it while
	# it burns, then lands on its square.
	var lift: Vector3 = s.along(a, -c * 0.15)
	var hit: Vector3 = s.toward(0.3)
	var hover: Vector3 = s.toward(0.55)
	var land: float = 0.75 + s.burn_time()
	o.sy = 1.0 + 0.1 * sin(u * 28.0)
	o.sx = 1.0 - 0.05 * sin(u * 28.0)
	if u < 0.3:
		var sv: float = s.smooth01(u / 0.3)
		o.at(a.lerp(lift, sv))
		o.y = c * 0.8 * sv
	elif u < 0.62:
		var q: float = s.ease_in01((u - 0.3) / 0.32)
		o.at(lift.lerp(hit, q))
		o.y = lerpf(c * 0.8, c * 0.3, q)
		o.rot = 0.3 * face * q
		o.sx = 1.12
		o.sy = 0.9
		o.trail = true
	elif u < 0.85:
		var q: float = s.smooth01((u - 0.62) / 0.23)
		o.at(hit.lerp(hover, q))
		o.y = lerpf(c * 0.3, c * 0.6, q)
		o.rot = 0.3 * face * (1.0 - q)
	elif u < land:
		o.at(hover)
		o.y = c * 0.6 + c * 0.05 * sin(u * 6.0)
	else:
		var q: float = s.progress(u, land, 0.45)
		o.at(hover.lerp(s.dest, s.smooth01(q)))
		o.y = c * 0.6 * (1.0 - s.smooth01(q))
		if q >= 1.0:
			o.sx = 1.0
			o.sy = 1.0

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	fx.spark_burst(s.up(b, 8.0), 8, Vector2.ZERO, 0.0, 0.5, StrikePalette.ORANGE)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	var face: float = s.face
	# Embers stream off the diving bird; three burning claw marks rake the target.
	if u > 0.3 and u < 0.62 and randf() < 0.8:
		s.part(Vector3(o.x, o.y + s.ah(6.0), o.z), Vector3(randf_range(-8.0, 8.0), randf_range(0.0, 12.0), 0.0), StrikePalette.FIRE[1 + randi() % 3], randf_range(0.15, 0.35), -20.0)
	if s.impacted and s.rt < 0.3:
		var fade: float = 1.0 - s.rt / 0.3
		var centre: Vector2 = s.screen(s.vc(0.55))
		for index: int in range(3):
			var offset: Vector2 = Vector2((index - 1) * 3.0, 0.0) * s.unit
			var top: Vector2 = centre + offset + Vector2(2.5 * face, -5.0) * s.unit
			var bottom: Vector2 = centre + offset + Vector2(-2.5 * face, 5.0) * s.unit
			canvas.draw_line(top, bottom, Color(1.0, 0.55, 0.2, fade), 1.5 * s.unit)
			canvas.draw_line(top.lerp(bottom, 0.3), top.lerp(bottom, 0.7), Color(1.0, 0.94, 0.7, fade), 0.8 * s.unit)

class_name ManticoreStrike
extends StrikeAttack

## Pounces along its bent path, coils the tail and stings; walks in once the victim melts.

const TIMING := {"impact": 0.64, "done": 2.6, "end": 3.4, "hitstop": 0.1, "shake": 0.6}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.45, s.event_puff.bind(s.up(s.along(s.b, -s.cell * 0.5), 1.0), 6, 0.8)]]

## Turns after one straight step along the longer side.
func corner(from: Vector2i, to: Vector2i) -> Variant:
	var delta: Vector2i = to - from
	return s.proj.square_world(from + (Vector2i(signi(delta.x), 0) if absi(delta.x) > absi(delta.y) else Vector2i(0, signi(delta.y))))

func adjust_timing() -> bool:
	s.done_time = _manticore_walk() + 0.4
	return true

func pose(u: float, o: StrikePose) -> void:
	var contact: Vector3 = s.along(s.b, -s.cell * 0.5)
	if u < 0.22:
		var sv: float = sin(u / 0.22 * PI * 0.5)
		o.sy = 1.0 - 0.18 * sv
		o.sx = 1.0 + 0.12 * sv
		o.rot = -0.1 * sv * s.face
		return
	if u < 0.45:
		var q: float = (u - 0.22) / 0.23
		if q < 0.4:
			o.at(s.a.lerp(s.corner, q / 0.4))
		else:
			o.at(s.corner.lerp(contact, (q - 0.4) / 0.6))
		o.y = s.cell * 0.9 * sin(q * PI)
		o.rot = 0.12 * s.face
		o.trail = true
		return
	o.at(contact)
	if u < 0.52:
		var w: float = sin((u - 0.45) / 0.07 * PI)
		o.sx = 1.0 + 0.18 * w
		o.sy = 1.0 - 0.16 * w
		return
	if u < 0.6:
		o.rot = -0.2 * (u - 0.52) / 0.08 * s.face
		return
	if u < 0.66:
		o.rot = lerpf(-0.2, 0.25, (u - 0.6) / 0.06) * s.face
		return
	var walk: float = _manticore_walk()
	if u < walk:
		o.rot = 0.25 * s.face * (1.0 - clampf((u - 0.66) / 0.2, 0.0, 1.0))
		return
	s.settle_into(o, contact, u, walk, 0.4, 1.5)

func impact() -> void:
	s.fx.spark_burst(s.up(s.b, 8.0), 6, s.dir, 40.0, 0.5, StrikePalette.VENOM_COLOR)

func draw_ground(canvas: CanvasItem) -> void:
	var foot: Vector3 = s.foot(s.b)
	if not s.impacted or s.rt < 0.25:
		return
	var melt: float = s.melt_duration()
	var radius: float = s.cell * 0.52 * s.ease_out(clampf((s.rt - 0.25) / melt, 0.0, 1.0))
	var fade: float = 1.0 - clampf((s.rt - 0.25 - melt - 0.6) / 0.6, 0.0, 1.0)
	if radius > 0.5 * s.unit and fade > 0.0:
		s.ground_disc(canvas, foot, radius, Color(0.27, 0.55, 0.22, 0.6 * fade))
		s.ground_disc(canvas, foot, radius * 0.55, Color(0.55, 0.86, 0.39, 0.35 * fade))

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var thin: float = maxf(s.unit, 1.0)
	if u < 0.58 or (s.impacted and s.rt > 0.1):
		return
	var start: Vector2 = s.proj.project(Vector3(s.pose.x - s.dir.x * 4.0 * s.unit, s.pose.y + s.attacker_at(0.95), s.pose.z - s.dir.y * 4.0 * s.unit + s.stand))
	var finish: Vector2 = s.victim_centre(0.55)
	var bend: Vector2 = Vector2((start.x + finish.x) * 0.5, minf(start.y, finish.y) - 10.0 * s.unit)
	var reach: float = clampf((u - 0.6) / 0.04, 0.0, 1.0)
	var points: PackedVector2Array = PackedVector2Array([start])
	for index: int in range(1, int(16.0 * reach) + 1):
		var sv: float = index / 16.0
		points.append(start * (1.0 - sv) * (1.0 - sv) + bend * 2.0 * (1.0 - sv) * sv + finish * sv * sv)
	if points.size() >= 2:
		canvas.draw_polyline(points, Color("#9be36a"), thin)

func _manticore_walk() -> float:
	return 0.64 + 0.25 + s.melt_duration() + 0.3

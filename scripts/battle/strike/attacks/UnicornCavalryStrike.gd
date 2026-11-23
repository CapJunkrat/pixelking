class_name UnicornCavalryStrike
extends StrikeAttack

## Rears up shimmering, charges horn first trailing sparkles, then settles.

const TIMING := {"impact": 0.56, "done": 1.25, "end": 2.3, "hitstop": 0.12, "shake": 1.0}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	var contact: Vector3 = s.along(s.b, -s.cell * 0.5)
	if u < 0.3:
		var sv: float = sin(u / 0.3 * PI)
		o.rot = -0.35 * sv * s.face
		o.y = s.cell * 0.18 * sv
		o.white = 0.35 * clampf(u / 0.2, 0.0, 1.0) * (0.6 + 0.4 * sin(u * 60.0))
		return
	if u < 0.56:
		var q: float = (u - 0.3) / 0.26
		o.at(s.a.lerp(contact, s.ease_in(q)))
		o.rot = 0.14 * s.face
		o.trail = true
		o.white = 0.25
		o.y = absf(sin(q * PI * 2.0)) * 2.0 * s.unit
		return
	if u < 0.95:
		var q: float = clampf((u - 0.56) / 0.14, 0.0, 1.0)
		o.at(s.along(contact, 3.0 * s.unit * sin(q * PI)))
		o.rot = 0.14 * s.face * (1.0 - q)
		return
	s.settle_into(o, contact, u, 0.95, 0.3, 2.0)

func impact() -> void:
	s.fx.spark_burst(s.up(s.b, 9.0), 14, s.dir, 110.0, 0.8)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.75, 0.3, StrikePalette.GOLD)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u < 0.3 or s.impacted:
		return
	var colors: Array[Color] = [Color("#ffe6f5"), Color("#d8f2ff"), Color("#fff3c4")]
	for index: int in range(3):
		var back: float = randf_range(4.0, 16.0) * s.unit
		var spark: Vector2 = s.proj.project(Vector3(s.pose.x - s.dir.x * back, s.pose.y + randf_range(4.0, 18.0) * s.unit, s.pose.z - s.dir.y * back + s.stand))
		canvas.draw_rect(Rect2(spark - Vector2(0.5, 0.5) * s.unit, Vector2(s.unit, s.unit)), colors[index])

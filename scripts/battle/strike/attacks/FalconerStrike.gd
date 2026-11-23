class_name FalconerStrike
extends StrikeAttack

## Looses its falcon, which arcs over, dives into the target and flies back to the arm.

const TIMING := {"impact": 0.62, "done": 1.25, "end": 2.0, "hitstop": 0.08, "shake": 0.45}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	var face: float = s.face
	if u < 0.3:
		o.rot = -0.12 * s.smooth01(u / 0.3) * face
		o.sy = 1.0 + 0.05 * s.smooth01(u / 0.3)
	elif u < 0.45:
		o.rot = lerpf(-0.12, 0.0, (u - 0.3) / 0.15) * face
	elif u > 1.05 and u < 1.2:
		o.sy = 1.0 - 0.06 * sin((u - 1.05) / 0.15 * PI)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.spark_burst(s.up(b, 10.0), 9, s.dir, 50.0, 0.6)
	fx.ring(b.x, b.z, cell * 0.5, 0.26)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	_draw_bird(canvas, _falcon_at(u), sin(u * 40.0), Color("#c8a070"))

## The falcon leaves the arm, arcs over, dives into the target and flies back.
func _falcon_at(u: float) -> Vector3:
	var arm: Vector3 = Vector3(s.a.x + s.face * s.n(4.0), s.ah(11.0), s.a.z)
	var hit: Vector3 = s.vc(0.6)
	var top: Vector3 = Vector3((arm.x + hit.x) * 0.5, s.cell * 2.2, (arm.z + hit.z) * 0.5)
	if u < 0.3:
		return arm
	if u < 0.62:
		var q: float = (u - 0.3) / 0.32
		return arm.lerp(top, q).lerp(top.lerp(hit, q), s.ease_in01(q))
	if u < 0.75:
		return hit + Vector3(0.0, (u - 0.62) * 30.0 * s.unit, 0.0)
	if u < 1.1:
		var q: float = (u - 0.75) / 0.35
		var from: Vector3 = hit + Vector3(0.0, s.n(4.0), 0.0)
		var p: Vector3 = from.lerp(arm, s.smooth01(q))
		p.y = lerpf(from.y, arm.y, q) + s.cell * 1.2 * 4.0 * q * (1.0 - q)
		return p
	return arm

func _draw_bird(canvas: CanvasItem, at: Vector3, flap: float, color: Color) -> void:
	var centre: Vector2 = s.screen(at)
	var wing: float = -1.0 if flap > 0.0 else 1.0
	canvas.draw_rect(Rect2(centre - Vector2(1.5, 1.5) * s.unit, Vector2(3.0, 3.0) * s.unit), Color("#2a1e2e"))
	s.pixel(canvas, centre, color)
	canvas.draw_rect(Rect2(centre + Vector2(-3.5, wing - 0.5) * s.unit, Vector2(2.0, 1.0) * s.unit), Color("#2a1e2e"))
	canvas.draw_rect(Rect2(centre + Vector2(1.5, wing - 0.5) * s.unit, Vector2(2.0, 1.0) * s.unit), Color("#2a1e2e"))
	s.pixel(canvas, centre + Vector2(2.0 * s.face, 0.0) * s.unit, Color("#e0b45c"))

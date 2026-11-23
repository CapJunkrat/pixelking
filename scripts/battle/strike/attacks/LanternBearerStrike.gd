class_name LanternBearerStrike
extends StrikeAttack

## Stays put, raises its lantern and bathes the target in light.

const TIMING := {"impact": 0.62, "done": 1.9, "end": 2.4, "hitstop": 0.08, "shake": 0.4}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	ranged(u, o, 0.5, 0.12, 1.45, 0.45, 0.06)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 0.8, 0.4, StrikePalette.GOLDEN)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var face: float = s.face
	if u < 0.1 or (s.impacted and s.rt > 0.7):
		return
	var lamp: Vector2 = s.screen(Vector3(s.a.x + face * s.n(5.0), s.ah(12.0), s.a.z))
	var glow: float = s.progress(u, 0.1, 0.4)
	canvas.draw_circle(lamp, s.n(3.0 + 4.0 * glow), Color(1.0, 0.86, 0.51, 0.25 * glow))
	if u > 0.45:
		var target: Vector2 = s.screen(s.vc(0.5))
		var beam: float = 1.0 - s.rt / 0.7 if s.impacted else s.progress(u, 0.45, 0.17)
		canvas.draw_colored_polygon(PackedVector2Array([lamp, target + Vector2(-7.0, -8.0) * s.unit, target + Vector2(7.0, 8.0) * s.unit]), Color(1.0, 0.925, 0.667, 0.22 * beam))

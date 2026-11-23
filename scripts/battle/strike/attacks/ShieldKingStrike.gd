class_name ShieldKingStrike
extends StrikeAttack

## Dashes in behind a shield of moonlight and slams the target.

const TIMING := {"impact": 0.56, "done": 1.15, "end": 2.3, "hitstop": 0.11, "shake": 1.3}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	dash(u, o, 0.2, 0.34, 0.22, 0.55, 0.32, 1.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 1.3, 0.5, StrikePalette.MOON)
	fx.ring(b.x, b.z, cell * 0.7, 0.3)
	fx.puff(s.up(b, 2.0), 9, 1.2)
	fx.spark_burst(s.up(b, 7.0), 8, s.dir, 40.0, 0.7, StrikePalette.MOON)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	if u < 0.7:
		var alpha: float = u / 0.1 if u < 0.1 else (1.0 if u < 0.5 else 1.0 - (u - 0.5) / 0.2)
		var centre: Vector2 = s.screen(Vector3(o.x, o.y + s.ah(7.0), o.z))
		s.ellipse(canvas, centre, s.n(10.5), Color(StrikePalette.MOON, 0.5 * alpha))
		canvas.draw_circle(centre, s.n(10.0), Color(StrikePalette.MOON, 0.08 * alpha))

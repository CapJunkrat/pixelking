class_name SentryStrike
extends StrikeAttack

## Dashes in and thrusts its spear.

const TIMING := {"impact": 0.44, "done": 0.95, "end": 2.0, "hitstop": 0.1, "shake": 0.8}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	dash(u, o, 0.12, 0.3, 0.14, 0.5, 0.3, 0.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.spark_burst(s.up(b, 8.0), 10, s.dir, 90.0, 0.7)
	fx.ring(b.x, b.z, cell * 0.7, 0.3)

func draw_air(canvas: CanvasItem) -> void:
	var o: StrikePose = s.pose
	if s.impacted and s.rt > 0.25:
		return
	var reach: float = 13.0
	var hand: Vector3 = Vector3(o.x, o.y + s.ah(8.0), o.z)
	var tip: Vector3 = Vector3(hand.x + s.dir.x * s.n(reach), hand.y, hand.z + s.dir.y * s.n(reach))
	s.pixel_line(canvas, s.screen(hand), s.screen(tip), Color("#cfc2a0"))
	s.pixel(canvas, s.screen(tip), Color.WHITE)

class_name VanguardStrike
extends StrikeAttack

## Dashes in and jabs with its short spear.

const TIMING := {"impact": 0.4, "done": 0.9, "end": 1.9, "hitstop": 0.08, "shake": 0.55}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	dash(u, o, 0.15, 0.24, 0.16, 0.5, 0.28, 1.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	fx.spark_burst(s.up(b, 8.0), 8, s.dir, 80.0, 0.6)

func draw_air(canvas: CanvasItem) -> void:
	var o: StrikePose = s.pose
	if s.impacted and s.rt > 0.25:
		return
	var reach: float = 11.0
	var hand: Vector3 = Vector3(o.x, o.y + s.ah(7.0), o.z)
	var tip: Vector3 = Vector3(hand.x + s.dir.x * s.n(reach), hand.y, hand.z + s.dir.y * s.n(reach))
	s.pixel_line(canvas, s.screen(hand), s.screen(tip), Color("#cfc2a0"))
	s.pixel(canvas, s.screen(tip), Color.WHITE)

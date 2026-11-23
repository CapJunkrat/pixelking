class_name PowderKegStrike
extends StrikeAttack

## Hops in with its fuse sparking and rams the target.

const TIMING := {"impact": 0.5, "done": 1.1, "end": 2.0, "hitstop": 0.08, "shake": 0.7}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	dash(u, o, 0.18, 0.28, 0.22, 0.55, 0.3, 1.0, 0.0, 2.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.spark_burst(s.up(b, 8.0), 8, s.dir, 40.0, 0.6)
	fx.ring(b.x, b.z, cell * 0.6, 0.3)
	fx.puff(s.up(b, 2.0), 6, 0.9)

func draw_air(canvas: CanvasItem) -> void:
	var o: StrikePose = s.pose
	if randf() < 0.6:
		s.part(Vector3(o.x, o.y + s.ah(13.0), o.z), Vector3(randf_range(-15.0, 15.0), randf_range(15.0, 40.0), 0.0), Color("#ffd27a") if randf() < 0.5 else Color("#ff8a3c"), randf_range(0.15, 0.3), 80.0)

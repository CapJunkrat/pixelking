class_name CrystalMageStrike
extends StrikeAttack

## Stays put and flings three crystal shards at the target.

const TIMING := {"impact": 0.66, "done": 1.8, "end": 2.3, "hitstop": 0.1, "shake": 0.6}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	ranged(u, o, 0.5, 0.16, 1.3, 0.45, 0.08)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.spark_burst(s.up(b, 9.0), 12, s.dir, 80.0, 0.7, StrikePalette.GLASS[0])
	fx.ring(b.x, b.z, cell * 0.6, 0.3, StrikePalette.GLASS[0])

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u < 0.1 or s.impacted:
		return
	var alpha: float = s.progress(u, 0.1, 0.2)
	for index: int in range(3):
		var at: Vector2 = s.screen(_shard(index, u))
		canvas.draw_rect(Rect2(at - Vector2(0.5, 1.5) * s.unit, Vector2(1.0, 3.0) * s.unit), Color(0.75, 0.95, 1.0, alpha))
		canvas.draw_rect(Rect2(at - Vector2(1.5, 0.5) * s.unit, Vector2(3.0, 1.0) * s.unit), Color(0.75, 0.95, 1.0, alpha))
		s.pixel(canvas, at, Color(1.0, 1.0, 1.0, alpha))

func _shard(index: int, u: float) -> Vector3:
	var angle: float = u * 9.0 + index * 2.1
	var home: Vector3 = Vector3(s.a.x + cos(angle) * s.n(7.0), s.ah(13.0) + sin(angle * 0.7) * s.n(2.0), s.a.z + sin(angle) * s.n(3.0))
	var start: float = 0.5 + index * 0.055
	if u < start:
		return home
	return home.lerp(s.vc(0.5), s.ease_in01((u - start) / 0.11))

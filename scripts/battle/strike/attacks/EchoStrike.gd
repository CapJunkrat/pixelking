class_name EchoStrike
extends StrikeAttack

## Stays put and sends rings of sound at the target.

const TIMING := {"impact": 0.72, "done": 2.05, "end": 2.6, "hitstop": 0.06, "shake": 0.5}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	ranged(u, o, 0.3, 0.1, 1.55, 0.45, -0.06)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 0.7, 0.35, StrikePalette.SOUND)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u < 0.05 or (s.impacted and s.rt > 0.6):
		return
	var src: Vector3 = Vector3(s.a.x, s.ah(8.0), s.a.z)
	var dst: Vector3 = s.vc(0.5)
	for index: int in range(6):
		var phase: float = u * 2.2 - index * 0.17
		if phase < 0.0 or phase > 1.0:
			continue
		var centre: Vector2 = s.screen(src.lerp(dst, phase))
		s.ellipse(canvas, centre, s.n(3.0 + 5.0 * phase), Color(StrikePalette.SOUND, 0.8 * (1.0 - absf(phase - 0.5))))
	if s.impacted:
		var centre: Vector2 = s.screen(dst)
		for index: int in range(2):
			s.ellipse(canvas, centre, s.n(6.0 + fmod(s.rt * 40.0 + index * 6.0, 12.0)), Color(StrikePalette.SOUND, 0.6 * (1.0 - s.rt / 0.6)))

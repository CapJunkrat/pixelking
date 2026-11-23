class_name ChameleonStrike
extends StrikeAttack

## Crouches and shoots its tongue at the target to swallow it, then learns its move and
## walks over.

const TIMING := {"impact": 0.5, "done": 1.95, "end": 2.6, "hitstop": 0.08, "shake": 0.4}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[1.0, _chameleon_learn]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	if u < 0.3:
		var sv: float = s.smooth01(u / 0.3)
		o.sy = 1.0 - 0.12 * sv
		o.sx = 1.0 + 0.08 * sv
		o.white = 0.3 if u > 0.2 else 0.0
	elif u < 0.95:
		o.sy = 0.88
		o.sx = 1.08
		o.rot = 0.05 * face
	elif u < 1.15:
		var w: float = sin((u - 0.95) / 0.2 * PI)
		o.sx = 1.0 + 0.2 * w
		o.sy = 1.0 - 0.1 * w
	elif u < 1.3:
		o.white = 0.4 * absf(sin(u * 40.0))
	else:
		var q: float = s.progress(u, 1.3, 0.6)
		o.at(a.lerp(s.dest, s.smooth01(q)))
		o.y = absf(sin(q * PI * 4.0)) * s.n(1.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	fx.spark_burst(s.up(b, 9.0), 4, Vector2.ZERO, 0.0, 0.3, Color("#f08aa0"))

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u < 0.3 or u > 1.0 or (s.split and s.reaction == &"swallow"):
		return
	var mouth: Vector3 = s.mouth()
	var tip: Vector3 = mouth.lerp(s.vc(0.55), s.ease_out01((u - 0.3) / 0.2))
	if s.impacted and s.reaction == &"swallow":
		var q: float = clampf(s.rt / s.split_time(), 0.0, 1.0)
		tip = s.vc(0.5).lerp(mouth, s.ease_in01(q))
	s.pixel_line(canvas, s.screen(mouth), s.screen(tip), Color("#d4607a"), 2.0)
	s.pixel(canvas, s.screen(tip), Color("#f08aa0"), 3.0)

func _chameleon_learn() -> void:
	var green: Color = Color(0.59, 0.9, 0.59)
	s.fx.ring(s.a.x, s.a.z, s.cell * 0.55, 0.35, green)
	s.fx.spark_burst(s.up(s.a, 8.0), 8, Vector2.ZERO, 0.0, 0.4, green)

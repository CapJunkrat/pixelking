class_name RangerStrike
extends StrikeAttack

## Stays put and throws a spinning boomerang that knocks the target over and comes back.

const TIMING := {"impact": 0.58, "done": 1.9, "end": 2.3, "hitstop": 0.1, "shake": 0.6}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	if u < 0.3:
		var sv: float = s.smooth01(u / 0.3)
		o.rot = -0.22 * sv * face
		o.sx = 1.0 + 0.05 * sv
	elif u < 0.42:
		o.rot = lerpf(-0.22, 0.18, s.ease_out01((u - 0.3) / 0.12)) * face
	elif u < 0.6:
		o.rot = 0.18 * face * (1.0 - (u - 0.42) / 0.18)
	elif u > 1.05 and u < 1.2:
		o.sy = 1.0 - 0.06 * sin((u - 1.05) / 0.15 * PI)
	elif u >= 1.35:
		var q: float = s.progress(u, 1.35, 0.5)
		o.at(a.lerp(s.dest, s.smooth01(q)))
		o.y = absf(sin(q * PI * 3.0)) * s.n(2.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	# A thud, not a cut: the boomerang knocks the victim over and flies on.
	fx.spark_burst(s.up(b, 9.0), 10, s.dir, 50.0, 0.7, Color("#e8c890"))
	fx.ring(b.x, b.z, cell * 0.7, 0.3, Color("#e8c890"))
	fx.puff(s.up(b, 3.0), 6, 0.8)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	# A spinning wooden boomerang with a faint wake, out along the line and back.
	for echo: int in range(3, -1, -1):
		var boomerang: Variant = _boomerang(u - echo * 0.025)
		if boomerang == null:
			continue
		var at: Vector2 = s.screen(boomerang as Vector3)
		var spin: float = (u - echo * 0.025) * 34.0
		var alpha: float = 1.0 if echo == 0 else 0.22 / echo
		_draw_boomerang(canvas, at, spin, alpha)

func _draw_boomerang(canvas: CanvasItem, at: Vector2, spin: float, alpha: float) -> void:
	var arm: float = 6.0 * s.unit
	var width: float = maxf(2.2 * s.unit, 1.5)
	for side: float in [-1.0, 1.0]:
		var direction: Vector2 = Vector2(cos(spin + side * 0.95), sin(spin + side * 0.95))
		canvas.draw_line(at, at + direction * arm, Color(0.24, 0.13, 0.05, alpha), width + 2.0)
		canvas.draw_line(at, at + direction * arm, Color(0.8, 0.58, 0.32, alpha), width)
		canvas.draw_line(at, at + direction * arm * 0.7, Color(0.95, 0.8, 0.55, alpha), maxf(width * 0.4, 1.0))

func _boomerang(u: float) -> Variant:
	if u < 0.38 or u > 1.12:
		return null
	var hand: Vector3 = Vector3(s.a.x + s.face * s.n(3.0), s.ah(9.0), s.a.z)
	var target: Vector3 = s.vc(0.5)
	var side: Vector3 = Vector3(-s.dir.y, 0.0, s.dir.x) * s.cell * 1.2
	var q: float = (u - 0.38) / 0.74
	var angle: float = q * TAU
	var along: float = (1.0 - cos(angle)) * 0.5
	var out: float = sin(angle)
	var far: Vector3 = Vector3(target.x + s.dir.x * s.n(6.0), target.y, target.z + s.dir.y * s.n(6.0))
	var p: Vector3 = hand.lerp(far, along) + side * out * 0.5
	p.y = lerpf(hand.y, target.y, minf(1.0, along * 1.2)) + s.n(3.0) * sin(angle)
	return p

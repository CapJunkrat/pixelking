class_name StandInStrike
extends StrikeAttack

## Throws a hook rope at the target, yanks itself in and kicks, then steps back.

const TIMING := {"impact": 0.7, "done": 1.25, "end": 2.2, "hitstop": 0.11, "shake": 0.8}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var c: float = s.cell
	var hit: Vector3 = s.toward(0.5)
	var back: Vector3 = s.along(hit, -s.n(4.0))
	if u < 0.25:
		o.rot = -0.15 * s.smooth01(u / 0.25) * face
	elif u < 0.5:
		o.rot = lerpf(-0.15, 0.05, (u - 0.25) / 0.25) * face
	elif u < 0.54:
		o.sy = 0.85
		o.sx = 1.1
	elif u < 0.7:
		var q: float = (u - 0.54) / 0.16
		o.at(a.lerp(hit, s.ease_in01(q)))
		o.y = c * 0.45 * sin(q * PI * 0.9)
		o.sx = 1.15
		o.sy = 0.9
		o.trail = true
	elif u < 0.86:
		var q: float = (u - 0.7) / 0.16
		o.at(hit.lerp(back, sin(q * PI * 0.5)))
		o.y = c * 0.1 * (1.0 - q)
	else:
		s.settle_into(o, back, u, 0.95, 0.28, 2.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.spark_burst(s.up(b, 10.0), 9, s.dir, 50.0, 0.6)
	fx.ring(b.x, b.z, cell * 0.5, 0.26)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	var face: float = s.face
	if u < 0.25 or u > 0.72:
		return
	var hand: Vector3 = Vector3(o.x + face * s.n(3.0), o.y + s.ah(8.0), o.z)
	var hook: Vector3 = hand.lerp(s.vc(0.6), s.ease_out01((u - 0.25) / 0.21)) if u < 0.46 else s.vc(0.6)
	var from: Vector2 = s.screen(hand)
	var to: Vector2 = s.screen(hook)
	var sag: Vector2 = Vector2(0.0, s.n(3.0) if u < 0.5 else 0.0)
	var rope: PackedVector2Array = PackedVector2Array()
	for index: int in range(9):
		var sv: float = index / 8.0
		rope.append(from.lerp(to, sv) + sag * 4.0 * sv * (1.0 - sv))
	canvas.draw_polyline(rope, Color("#8a7a5a"), maxf(s.unit, 1.0))
	s.pixel(canvas, to, Color("#dfe6f0"), 3.0)

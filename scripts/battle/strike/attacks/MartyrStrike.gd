class_name MartyrStrike
extends StrikeAttack

## Stays put and swings a smoking censer into the target.

const TIMING := {"impact": 0.6, "done": 1.75, "end": 2.2, "hitstop": 0.08, "shake": 0.5}

func timing() -> Dictionary:
	return TIMING

func pose(u: float, o: StrikePose) -> void:
	ranged(u, o, 0.45, 0.15, 1.3, 0.45, 0.1)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.spark_burst(s.up(b, 10.0), 7, s.dir, 30.0, 0.5, StrikePalette.GOLDEN)
	fx.puff(s.up(b, 6.0), 10, 0.9)
	fx.ring(b.x, b.z, cell * 0.6, 0.3, StrikePalette.GOLDEN)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var face: float = s.face
	if u < 0.08 or u > 0.95:
		return
	var hand: Vector3 = Vector3(s.a.x + face * s.n(3.0), s.ah(8.0), s.a.z)
	var censer: Vector3 = _censer(u)
	var from: Vector2 = s.screen(hand)
	var to: Vector2 = s.screen(censer)
	for index: int in range(0, 10, 2):
		canvas.draw_line(from.lerp(to, index / 10.0), from.lerp(to, (index + 1) / 10.0), Color("#b8a070"), maxf(s.unit, 1.0))
	canvas.draw_rect(Rect2(to - Vector2(2.5, 1.5) * s.unit, Vector2(5.0, 4.0) * s.unit), Color("#2a1e2e"))
	canvas.draw_rect(Rect2(to - Vector2(1.5, 0.5) * s.unit, Vector2(3.0, 2.0) * s.unit), Color("#e0b45c"))
	if randf() < 0.5:
		s.part(censer, Vector3(randf_range(-4.0, 4.0), randf_range(4.0, 10.0), 0.0), Color(0.85, 0.83, 0.8, 0.6), randf_range(0.4, 0.7), -5.0, 2.0)

func _censer(u: float) -> Vector3:
	var hand: Vector3 = Vector3(s.a.x + s.face * s.n(3.0), s.ah(8.0), s.a.z)
	if u < 0.1:
		return hand
	if u < 0.45:
		var angle: float = (u - 0.1) / 0.35 * PI * 4.0
		return hand + Vector3(cos(angle) * s.n(6.0), s.n(2.0) + sin(angle) * s.n(2.0), sin(angle) * s.n(6.0) * 0.6)
	var hit: Vector3 = s.vc(0.6)
	if u < 0.6:
		var q: float = s.ease_in01((u - 0.45) / 0.15)
		var p: Vector3 = hand.lerp(hit, q)
		p.y += s.cell * 0.6 * sin(q * PI)
		return p
	if u < 0.9:
		return hit.lerp(hand, s.smooth01((u - 0.6) / 0.3))
	return hand

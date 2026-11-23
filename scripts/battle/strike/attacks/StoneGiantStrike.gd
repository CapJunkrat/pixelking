class_name StoneGiantStrike
extends StrikeAttack

## Walks up in three heavy steps, raises both stone fists and pounds the target.

const TIMING := {"impact": 1.0, "done": 2.45, "end": 2.9, "hitstop": 0.16, "shake": 1.8}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var a: Vector3 = s.a
	var stand: Vector3 = s.toward(1.0)
	return [[0.1, _giant_step.bind(a.lerp(stand, 1.0 / 3.0))], [0.32, _giant_step.bind(a.lerp(stand, 2.0 / 3.0))], [0.54, _giant_step.bind(stand)]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var stand: Vector3 = s.toward(1.0)
	if u < 0.1:
		o.sy = 0.92
		o.sx = 1.05
	elif u < 0.76:
		var q: float = (u - 0.1) / 0.66
		var step: int = mini(2, floori(q * 3.0))
		var local: float = q * 3.0 - step
		o.at(a.lerp(stand, (step + s.smooth01(local)) / 3.0))
		o.y = sin(local * PI) * s.n(2.5)
		o.rot = (0.06 if step % 2 == 1 else -0.06) * face * sin(local * PI)
		var land: float = (local - 0.85) / 0.15 if local > 0.85 else 0.0
		o.sy = 1.0 - 0.08 * land
		o.sx = 1.0 + 0.05 * land
	elif u < 2.0:
		o.at(stand)
		if u < 0.9:
			var sv: float = s.smooth01((u - 0.76) / 0.14)
			o.sy = 1.0 + 0.15 * sv
			o.sx = 1.0 - 0.06 * sv
			o.white = 0.15 * sv
		elif u < 1.0:
			var q: float = s.ease_in01((u - 0.9) / 0.1)
			o.sy = lerpf(1.15, 0.9, q)
			o.sx = lerpf(0.94, 1.1, q)
			o.at(s.along(stand, s.n(3.0) * q))
		elif u < 1.75:
			o.sy = 0.9
			o.sx = 1.1
			o.at(s.along(stand, s.n(3.0)))
		elif u < 1.95:
			var q: float = s.smooth01((u - 1.75) / 0.2)
			o.sy = lerpf(0.9, 1.0, q)
			o.sx = lerpf(1.1, 1.0, q)
			o.at(s.along(stand, s.n(3.0) * (1.0 - q)))
	else:
		s.settle_into(o, stand, u, 2.0, 0.45, 0.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 1.6, 0.55, StrikePalette.STONE)
	fx.ring(b.x, b.z, cell * 0.9, 0.35)
	fx.crack_decal(b.x, b.z, 11, cell * 1.3)
	fx.spark_burst(s.up(b, 14.0), 10, Vector2.ZERO, 0.0, 0.7, StrikePalette.STONE)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var fists: Variant = _fists(u)
	if fists == null:
		return
	# Two big stone fists with knuckles, drawn in the piece's ivory stone.
	for side: float in [-1.0, 1.0]:
		var at: Vector2 = s.screen((fists as Vector3) + Vector3(side * s.n(4.5), 0.0, 0.0))
		canvas.draw_rect(Rect2(at - Vector2(4.5, 7.0) * s.unit, Vector2(9.0, 8.0) * s.unit), Color("#2a1e2e"))
		canvas.draw_rect(Rect2(at - Vector2(3.5, 6.0) * s.unit, Vector2(7.0, 6.0) * s.unit), Color("#d9c9a3"))
		canvas.draw_rect(Rect2(at - Vector2(3.5, 6.0) * s.unit, Vector2(7.0, 1.0) * s.unit), Color("#fff3d6"))
		canvas.draw_rect(Rect2(at - Vector2(3.5, 1.0) * s.unit, Vector2(7.0, 1.0) * s.unit), Color("#9c8a68"))
		for knuckle: int in range(3):
			canvas.draw_rect(Rect2(at + Vector2(-2.0 + knuckle * 2.0, -5.0) * s.unit, Vector2(1.0, 3.0) * s.unit), Color("#9c8a68"))

func _giant_step(at: Vector3) -> void:
	s.fx.puff(s.up(at, 1.0), 6, 0.9)
	s.shake = maxf(s.shake, 0.45)

func _fists(u: float) -> Variant:
	if u < 0.76 or u > 1.95:
		return null
	var o: StrikePose = s.pose
	var shoulder: Vector3 = Vector3(o.x, o.y + s.ah(14.0), o.z)
	var overhead: Vector3 = Vector3(o.x, o.y + s.ah(22.0), o.z)
	var squash: float = s.flatten_y() if s.impacted and s.reaction == &"flatten" else 1.0
	var top: Vector3 = Vector3(s.b.x, s.victim_at(squash) + s.n(1.0), s.b.z)
	if u < 0.9:
		return shoulder.lerp(overhead, s.smooth01((u - 0.76) / 0.14))
	if u < 1.0:
		var q: float = s.ease_in01((u - 0.9) / 0.1)
		var p: Vector3 = overhead.lerp(top, q)
		p.y += s.cell * 0.8 * sin(q * PI)
		return p
	if u < 1.75:
		return top
	return top.lerp(shoulder, s.smooth01((u - 1.75) / 0.2))

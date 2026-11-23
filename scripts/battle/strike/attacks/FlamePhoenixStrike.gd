class_name FlamePhoenixStrike
extends StrikeAttack

## Melee: rises on burning wings, dives talons first onto the target, holds it in its
## flames, then hops down onto the square.

const TIMING := {"impact": 0.72, "done": 1.95, "end": 2.6, "hitstop": 0.12, "shake": 1.2}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var a: Vector3 = s.a
	return [[0.2, s.ring_at.bind(a, 0.8, 0.4, StrikePalette.ORANGE)], [0.2, s.event_puff.bind(s.up(a, 1.0), 6, 0.8)]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var c: float = s.cell
	# Melee: rises, dives talons first onto the target, holds it in its flames,
	# then hops down onto the square.
	var hit: Vector3 = s.toward(0.25)
	if u < 0.4:
		var sv: float = s.smooth01(u / 0.4)
		o.y = c * 1.1 * sv
		o.sy = 1.0 + 0.1 * sin(u * 30.0)
		o.white = 0.15 * sv
	elif u < 0.72:
		var q: float = s.ease_in01((u - 0.4) / 0.32)
		o.at(a.lerp(hit, q))
		o.y = lerpf(c * 1.1, c * 0.3, q)
		o.rot = 0.25 * face * q
		o.sx = 1.15
		o.sy = 0.9
		o.trail = true
		o.white = 0.2
	elif u < 0.86:
		var q: float = (u - 0.72) / 0.14
		o.at(hit)
		o.y = c * 0.3 * (1.0 - 0.3 * sin(q * PI))
		o.sx = 1.15 - 0.15 * q
		o.sy = 0.85 + 0.15 * q
		o.rot = 0.25 * face * (1.0 - q)
	elif u < 1.4:
		var q: float = s.smooth01((u - 0.86) / 0.54)
		o.at(hit)
		o.y = lerpf(c * 0.3, c * 0.55, q)
	elif u < 1.75:
		var q: float = s.smooth01((u - 1.4) / 0.35)
		o.at(hit.lerp(s.dest, q))
		o.y = c * 0.55 * (1.0 - q) + c * 0.2 * sin(q * PI)
	else:
		o.at(s.dest)
		if u < 1.9:
			var w: float = sin((u - 1.75) / 0.15 * PI)
			o.sy = 1.0 - 0.15 * w
			o.sx = 1.0 + 0.12 * w

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 1.3, 0.5, StrikePalette.ORANGE)
	fx.ring(b.x, b.z, cell * 0.7, 0.35, Color(1.0, 0.9, 0.55))
	fx.spark_burst(s.up(b, 6.0), 18, s.dir, 40.0, 1.0, StrikePalette.ORANGE)

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var o: StrikePose = s.pose
	var wings: float = 0.0
	if u < 0.4:
		wings = s.smooth01(u / 0.4)
	elif u < 0.86:
		wings = 1.0
	elif u < 1.4:
		wings = 1.0 - 0.4 * (u - 0.86) / 0.54
	elif u < 1.75:
		wings = 0.6 * (1.0 - (u - 1.4) / 0.35)
	if wings > 0.0:
		var flap: float = sin(u * 22.0) * 2.0
		for side: float in [-1.0, 1.0]:
			for index: int in range(2, 11):
				var k: float = index / 10.0
				var at: Vector2 = s.screen(Vector3(o.x + side * s.n(index) * wings, o.y + s.ah(8.0 + (5.0 * sin(k * PI) + flap * k) * wings), o.z))
				canvas.draw_rect(Rect2(at, Vector2(1.0, 2.0) * s.unit), StrikePalette.FIRE[mini(3, index / 3)])
		if randf() < 0.8:
			s.part(Vector3(o.x + randf_range(-9.0, 9.0) * s.unit * wings, o.y + s.ah(randf_range(6.0, 12.0)), o.z), Vector3(randf_range(-6.0, 6.0), randf_range(5.0, 20.0), 0.0), s.fire_color(), randf_range(0.2, 0.4), -30.0)
	if u > 0.4 and u < 0.72:
		for _i: int in range(2):
			s.part(Vector3(o.x + randf_range(-2.0, 2.0) * s.unit, 0.0, o.z + randf_range(-2.0, 2.0) * s.unit), Vector3(randf_range(-3.0, 3.0), randf_range(8.0, 20.0), 0.0), s.fire_color(), randf_range(0.4, 0.8), -25.0)

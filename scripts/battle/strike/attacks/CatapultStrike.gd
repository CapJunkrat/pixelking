class_name CatapultStrike
extends StrikeAttack

## Winds the arm back, flings a boulder, later rolls onto the square.

const TIMING := {"impact": 0.94, "done": 1.85, "end": 2.7, "hitstop": 0.13, "shake": 1.5}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.1, s.event_puff.bind(s.up(s.a, 1.0), 3, 0.5)], [0.4, _event_catapult_release]]

func pose(u: float, o: StrikePose) -> void:
	if u < 0.38:
		var sv: float = clampf(u / 0.34, 0.0, 1.0)
		o.rot = -0.1 * sv * s.face
		o.sy = 1.0 - 0.1 * sv
		o.sx = 1.0 + 0.05 * sv
		o.x += (randf() - 0.5) * 1.4 * s.unit * sv
		return
	if u < 0.62:
		var q: float = (u - 0.38) / 0.24
		o.rot = lerpf(0.16, 0.0, s.ease_out(q)) * s.face
		o.sx = 1.0 + 0.06 * (1.0 - q)
		return
	if u < 1.3:
		return
	var q: float = clampf((u - 1.3) / 0.55, 0.0, 1.0)
	o.at(s.a.lerp(s.dest, s.smooth(q)))
	o.y = absf(sin(q * PI * 5.0)) * s.unit

func impact() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 1.4, 0.5)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.8, 0.32)
	s.fx.puff(s.up(s.b, 2.0), 14, 1.4)
	s.fx.crack_decal(s.b.x, s.b.z, 8, s.cell * 1.05)
	s.fx.spark_burst(s.up(s.b, 4.0), 8, Vector2.ZERO, 0.0, 0.7)
	var chunk: float = s.victim_height / PieceChunks.ROWS
	for index: int in range(16):
		var angle: float = randf() * TAU
		var speed: float = randf_range(20.0, 70.0) * s.unit
		s.fx.add_part(Vector3(s.b.x, s.victim_at(0.6), s.b.z + s.stand), Vector3(cos(angle) * speed, randf_range(40.0, 110.0) * s.unit, sin(angle) * speed * 0.6), StrikePalette.ROCK_COLORS[index % StrikePalette.ROCK_COLORS.size()], chunk * (1.7 if index % 4 == 0 else 1.0), randf_range(1.0, 1.6), 260.0 * s.unit)

func draw_ground(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u >= 0.4 and not s.impacted:
		var flight: Array = _boulder(u)
		var at: Vector3 = flight[0]
		var q: float = flight[1]
		s.ground_disc(canvas, Vector3(at.x, 0.0, at.z + s.stand), (2.0 + 4.0 * q) * s.unit, Color(0.0, 0.0, 0.0, 0.15 + 0.3 * q))

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u < 0.4 or s.impacted:
		return
	var at: Vector3 = _boulder(u)[0]
	var centre: Vector2 = s.proj.project(Vector3(at.x, at.y, at.z + s.stand))
	canvas.draw_rect(Rect2(centre - Vector2(2.5, 2.5) * s.unit, Vector2(5.0, 5.0) * s.unit), Color("#3b3a40"))
	canvas.draw_rect(Rect2(centre - Vector2(2.5, 2.5) * s.unit, Vector2(4.0, 4.0) * s.unit), Color("#7d7b84"))
	canvas.draw_rect(Rect2(centre - Vector2(1.5, 1.5) * s.unit, Vector2(2.0, 1.0) * s.unit), Color("#a9a7b0"))

## World position of the boulder in flight, and how far along it is.
func _boulder(u: float) -> Array:
	var q: float = clampf((u - 0.4) / (float(s.attack["impact"]) - 0.4), 0.0, 1.0)
	var height: float = lerpf(s.attacker_at(0.8), s.victim_at(1.0), q) + s.cell * 3.4 * 4.0 * q * (1.0 - q)
	return [Vector3(lerpf(s.a.x, s.b.x, q), height, lerpf(s.a.z, s.b.z, q)), q]

func _event_catapult_release() -> void:
	s.fx.puff(s.up(s.a, 2.0), 6, 0.8)
	s.shake = maxf(s.shake, 0.35)

class_name BlastCatapultStrike
extends StrikeAttack

## Lobs a burning powder keg that explodes over the target's whole neighbourhood.

const TIMING := {"impact": 1.05, "done": 1.2, "end": 2.6, "hitstop": 0.16, "shake": 2.0}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.42, _catapult_release]]

func pose(u: float, o: StrikePose) -> void:
	var face: float = s.face
	if u < 0.4:
		var sv: float = s.smooth01(u / 0.4)
		o.sx = 1.0 + 0.06 * sv
		o.sy = 1.0 - 0.1 * sv
		o.rot = -0.07 * sv * face
	elif u < 0.52:
		o.rot = lerpf(-0.07, 0.1, s.ease_out01((u - 0.4) / 0.12)) * face
		o.sy = 1.05
	elif u < 0.8:
		o.rot = 0.1 * face * (1.0 - (u - 0.52) / 0.28)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	s.flash = 1.0
	fx.ring(b.x, b.z, cell * 2.0, 0.6, StrikePalette.ORANGE)
	fx.ring(b.x, b.z, cell * 1.3, 0.45, Color(1.0, 0.9, 0.55))
	fx.ring(b.x, b.z, cell * 0.7, 0.3, StrikePalette.ORANGE)
	fx.spark_burst(s.up(b, 8.0), 30, Vector2.ZERO, 0.0, 1.4, StrikePalette.ORANGE)
	fx.puff(s.up(b, 4.0), 22, 2.0)
	fx.crack_decal(b.x, b.z, 12, cell * 1.5)

func draw_ground(canvas: CanvasItem) -> void:
	var u: float = s.t
	var shell: Array = _keg_shell(u)
	var glow: float = 0.0
	if s.impacted:
		glow = 0.55 * maxf(0.0, 1.0 - s.rt / 0.9)
	elif not shell.is_empty() and float(shell[1]) > 0.35:
		glow = 0.18 + 0.18 * sin(u * 40.0)
	if glow > 0.0:
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				var centre: Vector3 = Vector3(s.b.x + dx * s.cell, 0.0, s.b.z + dz * s.cell)
				var corners: PackedVector2Array = PackedVector2Array()
				for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
					corners.append(s.proj.project(Vector3(centre.x + corner.x * s.cell, 0.0, centre.z + corner.y * s.cell)))
				canvas.draw_colored_polygon(corners, Color(1.0, 0.55 if s.impacted else 0.31, 0.2, glow))
	if not shell.is_empty():
		var at: Vector3 = shell[0]
		var q: float = shell[1]
		s.ground_disc(canvas, Vector3(at.x, 0.0, at.z + s.stand), s.n(1.5 + 3.0 * q), Color(0.0, 0.0, 0.0, 0.15 + 0.3 * q))

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	var shell: Array = _keg_shell(u)
	if shell.is_empty():
		return
	var at: Vector2 = s.screen(shell[0])
	var flip: bool = floori(u * 20.0) % 2 == 0
	canvas.draw_rect(Rect2(at - Vector2(2.5, 2.5) * s.unit, Vector2(5.0, 5.0) * s.unit), Color("#2a1e2e"))
	canvas.draw_rect(Rect2(at - Vector2(1.5, 1.5) * s.unit, Vector2(3.0, 3.0) * s.unit), Color("#8a5a3a"))
	canvas.draw_rect(Rect2(at + Vector2(-1.5 if flip else -0.5, -1.5) * s.unit, Vector2(1.0, 3.0) * s.unit), Color("#e0b45c"))
	s.part(shell[0] + Vector3(0.0, s.n(3.0), 0.0), Vector3(randf_range(-10.0, 10.0), randf_range(0.0, 15.0), 0.0), s.fire_color(), randf_range(0.15, 0.3), 60.0)

func _catapult_release() -> void:
	s.fx.puff(s.up(s.a, 4.0), 6, 0.8)
	s.shake = maxf(s.shake, 0.4)

## [world position, progress] of the powder keg in flight, or [] when not flying.
func _keg_shell(u: float) -> Array:
	var land: float = float(TIMING["impact"])
	if u < 0.42 or u > land:
		return []
	var q: float = (u - 0.42) / (land - 0.42)
	var p: Vector3 = Vector3(s.a.x, s.ah(15.0), s.a.z).lerp(Vector3(s.b.x, s.vh(4.0), s.b.z), q)
	p.y += s.cell * 3.2 * 4.0 * q * (1.0 - q)
	return [p, q]

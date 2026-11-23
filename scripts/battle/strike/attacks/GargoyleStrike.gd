class_name GargoyleStrike
extends StrikeAttack

## Rears up and slams the ground; a crack runs along the board to the target; then walks
## over in two steps.

const TIMING := {"impact": 0.66, "done": 2.15, "end": 2.6, "hitstop": 0.12, "shake": 1.2}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.38, _gargoyle_slam]]

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var c: float = s.cell
	if u < 0.3:
		var sv: float = s.smooth01(u / 0.3)
		o.sy = 1.0 + 0.12 * sv
		o.y = c * 0.1 * sv
	elif u < 0.38:
		var q: float = (u - 0.3) / 0.08
		o.y = c * 0.1 * (1.0 - q)
		o.sy = 1.12 - 0.32 * q
		o.sx = 1.0 + 0.2 * q
	elif u < 0.55:
		var q: float = (u - 0.38) / 0.17
		o.sy = 0.8 + 0.2 * q
		o.sx = 1.2 - 0.2 * q
	elif u >= 1.5:
		var q: float = s.progress(u, 1.5, 0.6)
		var step: int = mini(1, floori(q * 2.0))
		var local: float = q * 2.0 - step
		o.at(a.lerp(s.dest, (step + s.smooth01(local)) * 0.5))
		o.y = sin(local * PI) * s.n(3.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var cell: float = s.cell
	fx.ring(b.x, b.z, cell * 1.2, 0.45)
	fx.puff(s.up(b, 2.0), 12, 1.3)
	fx.crack_decal(b.x, b.z, 8, cell * 0.9)

func draw_ground(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u < 0.38 or (s.impacted and s.rt > 1.2):
		return
	var reach: int = floori(s.progress(u, 0.38, 0.28) * 40.0)
	var fade: float = 1.0 - s.rt / 1.2 if s.impacted else 1.0
	for index: int in range(reach):
		var k: float = index / 40.0
		var wiggle: float = sin(index * 1.7) * s.n(2.5)
		var at: Vector3 = Vector3(lerpf(s.a.x, s.b.x, k) + s.dir.y * wiggle, 0.0, lerpf(s.a.z, s.b.z, k) - s.dir.x * wiggle)
		s.pixel(canvas, s.screen(at), Color(0.055, 0.035, 0.024, 0.85 * fade))

func _gargoyle_slam() -> void:
	s.fx.puff(s.up(s.a, 1.0), 10, 1.1)
	s.fx.ring(s.a.x, s.a.z, s.cell * 0.9, 0.4)
	s.shake = maxf(s.shake, 0.8)

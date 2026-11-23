class_name KingStrike
extends StrikeAttack

## Glows while a pillar of judgement aims at the target and drops on it, then walks over
## in two heavy steps.

const TIMING := {"impact": 0.72, "done": 2.0, "end": 2.7, "hitstop": 0.13, "shake": 1.4}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[1.52, _event_king_step.bind(0.5, 4, 0.6, 0.3)], [1.86, _event_king_step.bind(1.0, 5, 0.7, 0.35)]]

func pose(u: float, o: StrikePose) -> void:
	var middle: Vector3 = s.a.lerp(s.b, 0.5)
	if u < 0.72:
		var q: float = clampf(u / 0.35, 0.0, 1.0)
		o.sy = 1.0 + 0.08 * q
		o.sx = 1.0 - 0.03 * q
		o.white = 0.45 * q * (0.75 + 0.25 * sin(u * 40.0))
		return
	if u < 1.3:
		var q: float = (u - 0.72) / 0.58
		o.sy = 1.0 + 0.08 * (1.0 - q)
		o.white = 0.45 * (1.0 - q)
		return
	if u < 1.52:
		_hop(o, s.a, middle, (u - 1.3) / 0.22)
		return
	if u < 1.64:
		var w: float = sin((u - 1.52) / 0.12 * PI)
		o.at(middle)
		o.sx = 1.0 + 0.12 * w
		o.sy = 1.0 - 0.12 * w
		return
	if u < 1.86:
		_hop(o, middle, s.b, (u - 1.64) / 0.22)
		return
	var w: float = sin(clampf((u - 1.86) / 0.12, 0.0, 1.0) * PI)
	o.at(s.b)
	o.sx = 1.0 + 0.12 * w
	o.sy = 1.0 - 0.12 * w

func impact() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 1.4, 0.5, StrikePalette.GOLD)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.8, 0.32, StrikePalette.GOLD)
	s.fx.puff(s.up(s.b, 2.0), 12, 1.3)
	s.fx.crack_decal(s.b.x, s.b.z, 8, s.cell * 1.05)
	s.fx.spark_burst(s.up(s.b, 4.0), 12, Vector2.ZERO, 0.0, 0.8)

func draw_air(canvas: CanvasItem) -> void:
	_draw_judgment(canvas)

func _event_king_step(progress: float, count: int, big: float, shake: float) -> void:
	s.fx.puff(s.up(s.a.lerp(s.b, progress), 1.0), count, big)
	s.shake = maxf(s.shake, shake)

func _hop(o: StrikePose, start: Vector3, finish: Vector3, q: float) -> void:
	o.at(start.lerp(finish, s.smooth(q)))
	o.y = s.cell * 0.35 * 4.0 * q * (1.0 - q)

## King: an aiming line over the target, then a pillar of light drops on it.
func _draw_judgment(canvas: CanvasItem) -> void:
	var u: float = s.t
	var foot: Vector2 = s.proj.project(s.b)
	var top: float = foot.y - s.cell * 14.0
	if u > 0.15 and u < 0.6:
		canvas.draw_rect(Rect2(foot.x - s.unit * 0.5, top, s.unit, foot.y - top), Color(StrikePalette.AMBER, 0.35 + 0.3 * sin(u * 60.0)))
		var radius: float = s.cell * 0.5 * (1.4 - 0.4 * clampf((u - 0.15) / 0.4, 0.0, 1.0))
		for index: int in range(20):
			var angle: float = TAU * index / 20.0 + u * 4.0
			var dot: Vector2 = s.proj.project(Vector3(s.b.x + cos(angle) * radius, 0.0, s.b.z + sin(angle) * radius))
			canvas.draw_rect(Rect2(dot - Vector2(0.5, 0.5) * s.unit, Vector2(s.unit, s.unit)), StrikePalette.AMBER)
	if u >= 0.6 and not s.impacted:
		var bottom: float = lerpf(top, foot.y, s.ease_in(clampf((u - 0.6) / 0.12, 0.0, 1.0)))
		canvas.draw_rect(Rect2(foot.x - 4.5 * s.unit, top, 9.0 * s.unit, bottom - top), Color(StrikePalette.AMBER, 0.85))
		canvas.draw_rect(Rect2(foot.x - 2.5 * s.unit, top, 5.0 * s.unit, bottom - top), Color("#fffbe8"))
	if s.impacted and s.rt < 0.45:
		var k: float = 1.0 - s.rt / 0.45
		var half: float = maxf(1.0, roundf(6.0 * k)) * s.unit
		canvas.draw_rect(Rect2(foot.x - half - 2.5 * s.unit, top, half * 2.0 + 5.0 * s.unit, foot.y - top), Color(StrikePalette.AMBER, 0.75 * k))
		canvas.draw_rect(Rect2(foot.x - half, top, half * 2.0, foot.y - top), Color(1.0, 0.98, 0.91, k))

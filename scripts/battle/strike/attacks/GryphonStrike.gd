class_name GryphonStrike
extends StrikeAttack

## Climbs diagonally, glides over the target, dives. Light and medium prey is carried
## up and dropped; heavy prey is raked and the gryphon bounces back up.

const TIMING := {"impact": 0.72, "done": 1.85, "end": 2.6, "hitstop": 0.1, "shake": 0.8}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	return [[0.2, _event_gryphon_takeoff]]

## Climbs over the first diagonal square.
func corner(from: Vector2i, to: Vector2i) -> Variant:
	var delta: Vector2i = to - from
	return s.proj.square_world(from + Vector2i(signi(delta.x), signi(delta.y)))

func pose(u: float, o: StrikePose) -> void:
	var high: float = s.cell * 2.8
	var top: float = s.victim_at(1.0)
	if u < 0.2:
		var sv: float = sin(u / 0.2 * PI * 0.5)
		o.sy = 1.0 - 0.18 * sv
		o.sx = 1.0 + 0.1 * sv
		return
	if u < 0.42:
		var q: float = (u - 0.2) / 0.22
		o.at(s.a.lerp(s.corner, q))
		o.y = high * s.ease_out(q)
		_flap(o, u, 40.0)
		o.trail = true
		return
	if u < 0.55:
		o.at(s.corner.lerp(s.b, s.smooth((u - 0.42) / 0.13)))
		o.y = high
		o.rot = -0.08 * s.face
		return
	o.at(s.b)
	if u < 0.62:
		o.y = high + 2.0 * s.unit * sin(u * 30.0)
		_flap(o, u, 50.0)
		return
	if u < 0.72:
		o.y = lerpf(high, top, s.ease_in((u - 0.62) / 0.1))
		o.rot = 0.2 * s.face
		o.sx = 0.9
		o.sy = 1.15
		o.trail = true
		return
	if s.victim_weight == PieceDef.WeightClass.HEAVY:
		var hover: float = s.cell * 1.3
		if u < 0.95:
			o.y = lerpf(top, hover, s.ease_out((u - 0.72) / 0.23))
			_flap(o, u, 45.0)
		elif u < 1.5:
			o.y = hover + sin(u * 10.0) * 1.5 * s.unit
			_flap(o, u, 45.0)
		else:
			var q: float = clampf((u - 1.5) / 0.35, 0.0, 1.0)
			o.y = hover * (1.0 - s.smooth(q))
			_flap(o, u, 30.0 * (1.0 - q))
		return
	if u < 0.8:
		o.y = top
		o.sx = 1.1
		o.sy = 0.9
		return
	if u < 1.15:
		o.y = lerpf(top, high * 0.95, s.ease_out((u - 0.8) / 0.35))
		_flap(o, u, 48.0)
		return
	if u < 1.45:
		o.y = high * 0.95 + sin(u * 12.0) * 1.5 * s.unit
		_flap(o, u, 45.0)
		return
	var q: float = clampf((u - 1.45) / 0.4, 0.0, 1.0)
	o.y = high * 0.95 * (1.0 - s.smooth(q))
	_flap(o, u, 30.0 * (1.0 - q))

func impact() -> void:
	s.fx.spark_burst(Vector3(s.b.x, s.victim_at(1.0), s.b.z), 8, Vector2.ZERO, 0.0, 0.6)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.7, 0.3)
	s.fx.puff(s.up(s.b, 2.0), 6, 0.8)

func _flap(o: StrikePose, u: float, rate: float) -> void:
	o.sy = 1.0 + 0.1 * sin(u * rate)
	o.sx = 1.0 - 0.06 * sin(u * rate)

func _event_gryphon_takeoff() -> void:
	s.fx.puff(s.up(s.a, 1.0), 8, 1.0)
	s.fx.ring(s.a.x, s.a.z, s.cell * 0.6, 0.3)

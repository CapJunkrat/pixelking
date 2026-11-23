class_name ShadowKingStrike
extends StrikeAttack

## Dissolves into shadow, reappears behind the target and cuts; blinks home when it
## struck from its own square.

const TIMING := {"impact": 0.66, "done": 1.45, "end": 2.2, "hitstop": 0.13, "shake": 0.8}

func timing() -> Dictionary:
	return TIMING

func events() -> Array:
	var a: Vector3 = s.a
	return [[0.16, s.event_puff.bind(s.up(a, 3.0), 10, 0.9)], [0.4, s.event_puff.bind(s.up(s.along(s.b, s.cell * 0.6), 3.0), 8, 0.8)]]

## Its own pose handles the blink home after either a kill or a shell hit.
func keeps_bounce() -> bool:
	return not s.dest.is_equal_approx(s.a)

func pose(u: float, o: StrikePose) -> void:
	var a: Vector3 = s.a
	var face: float = s.face
	var c: float = s.cell
	var behind: Vector3 = s.along(s.b, c * 0.6)
	if not s.on_board(behind):
		behind = s.along(s.b, c * 0.35)
	if u < 0.16:
		var sv: float = u / 0.16
		o.alpha = 1.0 - 0.5 * sv
		o.sy = 1.0 + 0.1 * sv
		o.sx = 1.0 - 0.2 * sv
	elif u < 0.4:
		o.alpha = 0.0
	elif u < 1.1:
		o.at(behind)
		if u < 0.52:
			o.alpha = (u - 0.4) / 0.12
		elif u < 0.66:
			var q: float = (u - 0.52) / 0.14
			o.rot = lerpf(0.25, -0.35, s.ease_in01(q)) * -face
			o.at(s.along(behind, -s.n(2.0) * q))
			o.white = 0.3
		else:
			var q: float = s.progress(u, 0.66, 0.25)
			o.at(s.along(behind, -s.n(2.0) * (1.0 - q)))
			o.rot = 0.35 * face * (1.0 - q)
	elif s.dest.is_equal_approx(a):
		# Shadow strikes return by blinking, not by walking across the board.
		if u < 1.26:
			o.at(behind)
			o.alpha = 1.0 - s.progress(u, 1.1, 0.16)
		else:
			o.at(a)
			o.alpha = s.progress(u, 1.26, 0.19) if s.returning_attacker_alive else 0.0
	else:
		s.settle_into(o, behind, u, 1.1, 0.35, 1.0)

func impact() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	s.slash_age = 0.0
	fx.spark_burst(s.up(b, 9.0), 8, -s.dir, 50.0, 0.6, Color(0.7, 0.59, 0.86))

func draw_air(canvas: CanvasItem) -> void:
	var u: float = s.t
	if u > 0.16 and u < 0.42:
		var q: float = (u - 0.16) / 0.26
		for index: int in range(4):
			var angle: float = index / 4.0 * TAU + 0.6
			var radius: float = s.cell * 1.6 * (1.0 - q)
			var at: Vector2 = s.screen(Vector3(s.b.x + cos(angle) * radius, s.vh(6.0), s.b.z + sin(angle) * radius))
			canvas.draw_circle(at, s.n(4.0), Color(0.16, 0.1, 0.24, 0.35 * (1.0 - q * 0.5)))
			canvas.draw_circle(at, s.n(2.0), Color(0.43, 0.35, 0.55, 0.5 * (1.0 - q * 0.5)))

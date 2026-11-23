class_name EmberReaction
extends StrikeReaction

## The Ember Bird's own reaction: it bursts into embers and its spark flies to where its
## egg is laid.

func split_time() -> float:
	return 0.3

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var split: float = s.split_time()
	var q: float = clampf(rt / split, 0.0, 1.0) if split < INF else 0.0
	var state: Dictionary = {}
	s.set_tint(material, StrikePalette.ORANGE, (0.7 if s.reaction == &"ember" else 0.8) * q)
	state["jitter"] = roundf(randf_range(-1.0, 1.0) * q)
	apply_state(state, look_value)

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var foot: Vector3 = s.foot(b)
	s.debris(whole, s.foot_pivot(), foot, {"vel": Vector3(0.0, 30.0 * s.unit, 0.0), "spread": 25.0, "gravity": -50.0, "life_min": 0.8, "life_max": 1.4, "radial": 1.5, "color": StrikePalette.FIRE[2]})
	fx.spark_burst(s.up(b, 6.0), 14, Vector2.ZERO, 0.0, 0.7, StrikePalette.ORANGE)
	fx.ring(b.x, b.z, s.cell * 0.8, 0.4, StrikePalette.ORANGE)

func draw_air(canvas: CanvasItem) -> void:
	if not s.impacted:
		return
	var rt: float = s.rt
	var b: Vector3 = s.b
	# The spark of a fallen bird flies to the square where its egg is laid.
	if not s.split:
		return
	var q: float = clampf((rt - 0.25) / 0.8, 0.0, 1.0)
	var home: Vector3 = s.rebirth_corner()
	if q < 1.0:
		var p: Vector3 = Vector3(b.x, s.vh(8.0), b.z).lerp(Vector3(home.x, s.vh(5.0), home.z), s.smooth01(q))
		p.y += s.cell * 3.0 * sin(q * PI)
		var at: Vector2 = s.screen(p)
		canvas.draw_circle(at, s.n(5.0), Color(1.0, 0.59, 0.24, 0.35))
		canvas.draw_rect(Rect2(at - Vector2(2.5, 2.5) * s.unit, Vector2(5.0, 5.0) * s.unit), Color("#ff8a3c"))
		canvas.draw_rect(Rect2(at - Vector2(1.5, 1.5) * s.unit, Vector2(3.0, 3.0) * s.unit), Color("#fff0b0"))
		s.part(p, Vector3(randf_range(-6.0, 6.0), randf_range(-4.0, 8.0), 0.0), s.fire_color(), randf_range(0.25, 0.45), -10.0)
		if q > 0.97 and s.once(&"landed"):
			s.fx.ring(home.x, home.z, s.cell * 0.6, 0.4, StrikePalette.ORANGE)
			s.fx.spark_burst(s.up(home, 4.0), 10, Vector2.ZERO, 0.0, 0.6, StrikePalette.ORANGE)
		return
	var foot: Vector2 = s.screen(Vector3(home.x, 0.0, home.z))
	var pulse: float = 0.6 + 0.4 * sin(rt * 9.0)
	canvas.draw_circle(foot - Vector2(0.0, s.n(4.0)), s.n(6.0), Color(1.0, 0.59, 0.24, 0.3 * pulse))
	for index: int in range(-2, 3):
		var height: float = roundf((6.0 - absi(index) * 2.0) * (0.8 + 0.2 * sin(rt * 20.0 + index)))
		canvas.draw_rect(Rect2(foot + Vector2(index, -height) * s.unit, Vector2(1.0, height) * s.unit), Color("#fff0b0") if index == 0 else Color("#ff8a3c"))

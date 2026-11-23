class_name InfernoReaction
extends StrikeReaction

## Engulfed in a pillar of fire and burnt away.

func split_time() -> float:
	return s.weight3([0.45, 0.6, 0.75])

func tick() -> void:
	if s.hs > 0.0:
		return
	var b: Vector3 = s.b
	if randf() < 0.9:
		s.part(Vector3(b.x + randf_range(-5.0, 5.0) * s.unit, s.vh(randf_range(0.0, 6.0)), b.z), Vector3(randf_range(-4.0, 4.0), randf_range(30.0, 60.0), 0.0), s.fire_color(), randf_range(0.3, 0.6), -20.0)

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var split: float = s.split_time()
	var q: float = clampf(rt / split, 0.0, 1.0) if split < INF else 0.0
	var state: Dictionary = {}
	s.set_tint(material, StrikePalette.ORANGE.lerp(Color.WHITE, clampf(q * 2.0 - 1.0, 0.0, 1.0)), 0.3 + 0.6 * clampf(q * 2.0, 0.0, 1.0))
	state["jitter"] = roundf(randf_range(-1.0, 1.0) * q)
	apply_state(state, look_value)

func on_split() -> void:
	var b: Vector3 = s.b
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var foot: Vector3 = s.foot(b)
	s.debris(whole, s.foot_pivot(), foot, {"vel": Vector3(0.0, 40.0 * s.unit, 0.0), "spread": 12.0, "gravity": -60.0, "life_min": 0.5, "life_max": 0.9, "radial": 0.8, "color": StrikePalette.HOLY_WHITE})
	for index: int in range(whole.size() / 3):
		s.part(Vector3(b.x + randf_range(-5.0, 5.0) * s.unit, s.vh(randf_range(0.0, 12.0)), b.z), Vector3(randf_range(-6.0, 6.0), randf_range(30.0, 50.0), 0.0), s.fire_color(), randf_range(0.5, 0.9), -60.0)

func draw_air(canvas: CanvasItem) -> void:
	if not s.impacted:
		return
	var rt: float = s.rt
	var b: Vector3 = s.b
	var split: float = s.split_time()
	if rt > split + 0.5:
		return
	var grow: float = clampf(rt / 0.15, 0.0, 1.0)
	var fade: float = 1.0 - (rt - split) / 0.5 if rt > split else 1.0
	var foot: Vector2 = s.screen(Vector3(b.x, 0.0, b.z))
	for dx: int in range(-5, 6):
		var height: float = 30.0 * grow * (1.0 - absf(dx) / 6.0) * (0.75 + 0.25 * sin(rt * 35.0 + dx * 1.7))
		var green: float = 0.9 if absi(dx) < 2 else (0.63 if absi(dx) < 4 else 0.35)
		canvas.draw_rect(Rect2(foot + Vector2(dx, -height) * s.unit, Vector2(1.0, height) * s.unit), Color(1.0, green, 0.24, 0.55 * fade))

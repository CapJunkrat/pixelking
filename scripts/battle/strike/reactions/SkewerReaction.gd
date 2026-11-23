class_name SkewerReaction
extends StrikeReaction

## Run through from above by a falling bolt, then split down the middle.

func split_time() -> float:
	return s.weight3([0.28, 0.36, 0.45])

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var state: Dictionary = {}
	state["jitter"] = float(randi_range(-1, 1)) if rt < 0.2 else 0.0
	if s.reaction == &"shell":
		material.set_shader_parameter(&"crack_progress", clampf(rt / 0.3, 0.0, 1.0))
	apply_state(state, look_value)

func on_split() -> void:
	var keep_angle: float = s.slash_angle
	s.slash_angle = PI * 0.5
	for side: float in [-1.0, 1.0]:
		var half: StrikeBody = s.make_body({"plane_keep": side})
		half.material.set_shader_parameter(&"plane_dir", Vector2(0.0, 1.0))
		half.vx = -side * 35.0 * s.unit
		half.vy = 30.0 * s.unit
		half.vr = -side * 4.0
		half.gravity = 260.0 * s.unit
		half.shatter_ground = true
	s.slash_angle = keep_angle

func draw_air(canvas: CanvasItem) -> void:
	if not s.impacted:
		return
	var rt: float = s.rt
	var b: Vector3 = s.b
	if rt > 1.6:
		return
	var alpha: float = 1.0 if rt < 1.0 else 1.0 - (rt - 1.0) / 0.6
	var foot: Vector2 = s.screen(Vector3(b.x, 0.0, b.z))
	var top: Vector2 = s.screen(Vector3(b.x, s.victim_at(1.0) + s.vh(8.0), b.z))
	s.pixel_line(canvas, foot, top, Color(1.0, 0.878, 0.541, alpha))
	canvas.draw_rect(Rect2(top + Vector2(-1.5, 0.0) * s.unit, Vector2(3.0, 1.0) * s.unit), Color(1.0, 0.965, 0.847, alpha))
	canvas.draw_rect(Rect2(top + Vector2(-2.5, 1.0) * s.unit, Vector2(5.0, 1.0) * s.unit), Color(1.0, 0.965, 0.847, alpha))

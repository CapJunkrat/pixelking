class_name ChipReaction
extends StrikeReaction

## The Stone Giant's shell takes the blow: a corner chips off and one shell pip goes
## dark.

func split_time() -> float:
	return INF

## The shell absorbs the blow; the victim stays standing.
func survives() -> bool:
	return true

func tick() -> void:
	if s.hs > 0.0:
		return
	var b: Vector3 = s.b
	if s.once(&"chip"):
		s.brick = Rect2(0.0, 0.0, s.victim_chunks.aspect * 0.5, 0.5)
		s.victim_material.set_shader_parameter(&"brick", Vector4(0.0, 0.0, s.brick.end.x, s.brick.end.y))
		s.victim_material.set_shader_parameter(&"brick_mode", 1.0)
		var chunk: StrikeBody = s.make_body({"brick_mode": 2.0})
		chunk.material.set_shader_parameter(&"brick", Vector4(0.0, 0.0, s.brick.end.x, s.brick.end.y))
		chunk.vx = (-s.dir.y * 25.0 - 20.0) * s.unit
		chunk.vz = s.dir.x * 25.0 * s.unit
		chunk.vy = 70.0 * s.unit
		chunk.vr = -7.0
		chunk.gravity = 300.0 * s.unit
		chunk.shatter_ground = true
		chunk.poof = true
		s.fx.puff(s.up(b, 6.0), 8, 1.0)
		s.fx.spark_burst(s.up(b, 10.0), 8, Vector2.ZERO, 0.0, 0.6, StrikePalette.STONE)

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var state: Dictionary = {}
	state["jitter"] = float(randi_range(-1, 1)) if rt < 0.2 else 0.0
	if s.reaction == &"shell":
		material.set_shader_parameter(&"crack_progress", clampf(rt / 0.3, 0.0, 1.0))
	apply_state(state, look_value)

func draw_air(canvas: CanvasItem) -> void:
	if not s.impacted:
		return
	var rt: float = s.rt
	var b: Vector3 = s.b
	var at: Vector2 = s.screen(Vector3(b.x, s.victim_at(1.0) + s.vh(4.0), b.z))
	for index: int in range(3):
		var pip: Vector2 = at + Vector2(-4.0 + index * 4.0, 0.0) * s.unit
		var lost: bool = index == 0 and rt > 0.35
		canvas.draw_rect(Rect2(pip - Vector2(1.5, 1.5) * s.unit, Vector2(3.0, 3.0) * s.unit), Color("#0d0a14"))
		s.pixel(canvas, pip, Color("#3a3540") if lost else Color("#bdbbc1"))

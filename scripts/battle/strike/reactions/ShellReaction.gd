class_name ShellReaction
extends StrikeReaction

## A shell takes the blow (Gargoyle, hard eggs): it cracks and sheds chips, and the
## piece stays standing.

func split_time() -> float:
	return INF

## The shell absorbs the blow; the victim stays standing.
func survives() -> bool:
	return true

func tick() -> void:
	if s.hs > 0.0:
		return
	var b: Vector3 = s.b
	if s.once(&"shell"):
		var edge: PackedInt32Array = s.select(func(p: Vector2) -> bool: return randf() < 0.3)
		s.debris(edge, s.foot_pivot(), s.foot(b), {"vel": Vector3(s.dir.x * 30.0, 40.0, s.dir.y * 30.0) * s.unit, "spread": 35.0, "radial": 2.5})
		s.fx.puff(s.up(b, 3.0), 8, 1.0)

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var state: Dictionary = {}
	state["jitter"] = float(randi_range(-1, 1)) if rt < 0.2 else 0.0
	if s.reaction == &"shell":
		material.set_shader_parameter(&"crack_progress", clampf(rt / 0.3, 0.0, 1.0))
	apply_state(state, look_value)

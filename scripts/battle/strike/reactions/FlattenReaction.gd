class_name FlattenReaction
extends StrikeReaction

## Squashed flat, then bursts sideways.

func split_time() -> float:
	return s.weight3([0.55, 0.65, 0.75])

func tick() -> void:
	if s.hs > 0.0:
		return
	var b: Vector3 = s.b
	if randf() < 0.3:
		s.fx.puff(Vector3(b.x + randf_range(-6.0, 6.0) * s.unit, s.unit, b.z), 1, 0.5)

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var state: Dictionary = {}
	var sy: float = s.flatten_y()
	state["stretch"] = Vector2(lerpf(1.0, 1.7, (1.0 - sy) / 0.8), sy)
	state["jitter"] = roundf(randf_range(-1.0, 1.0) * (1.0 - sy))
	apply_state(state, look_value)

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var foot: Vector3 = s.foot(b)
	s.debris(whole, s.foot_pivot(), foot, {"vel": Vector3(0.0, 6.0 * s.unit, 0.0), "spread": 45.0, "radial": 3.5, "gravity": 300.0})
	fx.puff(s.up(b, 1.0), 12, 1.4)
	s.shake = maxf(s.shake, 0.8)

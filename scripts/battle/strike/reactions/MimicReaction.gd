class_name MimicReaction
extends StrikeReaction

## Fades to grey as its likeness is drawn out, then crumbles.

func split_time() -> float:
	return s.weight3([0.75, 0.9, 1.05])

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var split: float = s.split_time()
	var q: float = clampf(rt / split, 0.0, 1.0) if split < INF else 0.0
	var state: Dictionary = {}
	s.set_tint(material, Color(0.55, 0.54, 0.58), clampf(q * 1.6, 0.0, 1.0))
	state["jitter"] = 0.0
	apply_state(state, look_value)

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var foot: Vector3 = s.foot(b)
	s.debris(whole, s.foot_pivot(), foot, {"vel": Vector3(0.0, 6.0 * s.unit, 0.0), "spread": 14.0, "radial": 0.6, "gravity": 220.0, "life_min": 0.8, "life_max": 1.3, "color": Color(0.55, 0.54, 0.58)})
	fx.puff(s.up(b, 2.0), 8, 0.8)

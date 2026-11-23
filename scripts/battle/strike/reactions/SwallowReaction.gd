class_name SwallowReaction
extends StrikeReaction

## Swallowed: the piece shrinks and spins into the attacker's mouth.

func split_time() -> float:
	return s.weight3([0.45, 0.55, 0.7])

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var split: float = s.split_time()
	var q: float = clampf(rt / split, 0.0, 1.0) if split < INF else 0.0
	var state: Dictionary = {}
	var sc: float = 1.0 - 0.85 * s.ease_in01(q)
	var centre: Vector3 = s.vc(0.5).lerp(s.mouth(), s.ease_in01(q))
	state["world"] = Vector3(centre.x, maxf(0.0, centre.y - s.victim_at(0.5) * sc), centre.z + s.stand)
	state["stretch"] = Vector2(sc, sc)
	state["rot"] = q * q * 6.0 * s.face
	state["jitter"] = 0.0
	apply_state(state, look_value)

func on_split() -> void:
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var mouth: Vector3 = s.mouth()
	s.debris(whole, s.foot_pivot(), Vector3(mouth.x, s.unit * 2.0, mouth.z + s.stand), {"vel": Vector3(0.0, 10.0 * s.unit, 0.0), "spread": 12.0, "every": 6, "life_min": 0.4, "life_max": 0.7})

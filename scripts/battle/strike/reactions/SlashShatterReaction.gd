class_name SlashShatterReaction
extends StrikeReaction

## A slash shatters a light piece into glittering chunks.

func split_time() -> float:
	return 0.2

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	material.set_shader_parameter(&"sparkle", (s.rt - 0.06) * 4.0 if s.rt > 0.06 else 0.0)
	material.set_shader_parameter(&"sparkle_time", s.rt)

func on_split() -> void:
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	s.debris(whole, s.foot_pivot(), s.foot(s.b), {"vel": Vector3(-sin(s.slash_angle) * 10.0 * s.unit, 15.0 * s.unit, 0.0), "spread": 22.0, "gravity": 70.0, "life_min": 1.1, "life_max": 1.8, "radial": 1.2})
	s.fx.spark_burst(s.up(s.b, 8.0), 6, Vector2.ZERO, 0.0, 0.4)

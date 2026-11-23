class_name HoleReaction
extends StrikeReaction

## A pierce leaves a glowing hole that webs out before the piece breaks.

func split_time() -> float:
	return 0.48

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var jitter: float = look_value.jitter
	var total: float = s.split_time()
	material.set_shader_parameter(&"hole_radius", 1.7 / PieceChunks.ROWS)
	material.set_shader_parameter(&"hole_glow", 0.9 * (1.0 - clampf(s.rt / total, 0.0, 1.0) * 0.6))
	material.set_shader_parameter(&"web_progress", clampf((s.rt - 0.12) / (total - 0.2), 0.0, 1.0))
	jitter = roundf(randf_range(-1.0, 1.0) * (0.4 + clampf(s.rt / total, 0.0, 1.0))) if s.rt > 0.1 else 0.0
	look_value.jitter = jitter

func on_split() -> void:
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var heavy: bool = s.reaction == &"hole_heavy"
	s.debris(whole, s.foot_pivot(), s.foot(s.b), {"vel": Vector3(s.dir.x * 55.0, 30.0, s.dir.y * 55.0) * s.unit, "spread": 35.0, "radial": 2.5})
	s.fx.puff(s.up(s.b, 4.0), 10, 1.1)
	s.fx.ring(s.b.x, s.b.z, s.cell * (1.0 if heavy else 0.7), 0.4, StrikePalette.GOLD)
	s.shake = maxf(s.shake, 0.9 if heavy else 0.6)

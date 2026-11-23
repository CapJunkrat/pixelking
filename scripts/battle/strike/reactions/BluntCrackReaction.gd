class_name BluntCrackReaction
extends StrikeReaction

## An equal blunt blow cracks a heavy piece across the middle.

func split_time() -> float:
	return 0.22

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	material.set_shader_parameter(&"crack_progress", clampf((s.rt - 0.04) / 0.16, 0.0, 1.0))

func on_split() -> void:
	var top: StrikeBody = s.make_body({"jag_keep": 1.0})
	top.vx = s.dir.x * 50.0 * s.unit
	top.vz = s.dir.y * 50.0 * s.unit
	top.vy = 70.0 * s.unit
	top.vr = 7.0 * s.face
	top.gravity = 260.0 * s.unit
	top.shatter_ground = true
	var bottom: StrikeBody = s.make_body({"jag_keep": -1.0})
	bottom.jitter = true
	bottom.shatter_at = s.rt + 0.3
	bottom.crumble = true
	var seam: PackedInt32Array = s.select(func(p: Vector2) -> bool: return absf(p.y - s.jag(p.x)) < 1.25 / PieceChunks.ROWS)
	s.debris(seam, s.foot_pivot(), s.foot(s.b), {"vel": Vector3(s.dir.x * 30.0, 40.0, s.dir.y * 30.0) * s.unit, "spread": 25.0, "every": 2})
	s.fx.puff(Vector3(s.b.x, s.proj.height_for_pixels(6.0 * s.unit), s.b.z), 4, 0.6)

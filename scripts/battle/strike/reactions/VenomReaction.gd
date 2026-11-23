class_name VenomReaction
extends StrikeReaction

## Venom tints the piece, then it melts from the top down.

func split_time() -> float:
	return 0.25 + s.melt_duration()

func tick() -> void:
	if s.hs > 0.0:
		return
	if s.rt < 0.25:
		var index: int = s.random_chunk()
		if index >= 0 and randf() < 0.5:
			s.debris(PackedInt32Array([index]), s.foot_pivot(), s.foot(s.b), {"vel": Vector3(0.0, 8.0 * s.unit, 0.0), "spread": 6.0, "gravity": -50.0, "life_min": 0.3, "life_max": 0.5, "radial": 0.0, "color": StrikePalette.VENOM_COLOR})
	elif randf() < 0.7:
		var row: int = floori(clampf((s.rt - 0.25) / s.melt_duration(), 0.0, 1.0) * PieceChunks.ROWS)
		var front: PackedInt32Array = s.select(func(p: Vector2) -> bool: return int(p.y * PieceChunks.ROWS) == row)
		if not front.is_empty():
			var pick: int = front[randi() % front.size()]
			s.debris(PackedInt32Array([pick]), s.foot_pivot(), s.foot(s.b), {"vel": Vector3.ZERO, "spread": 5.0, "gravity": 160.0, "life_min": 0.4, "life_max": 0.7, "radial": 0.3, "color": StrikePalette.VENOM_COLOR if randf() < 0.5 else StrikePalette.VENOM_DARK})

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var stretch: Vector2 = look_value.stretch
	var jitter: float = look_value.jitter
	if s.rt < 0.25:
		var q: float = s.rt / 0.25
		s.set_tint(material, StrikePalette.VENOM_COLOR, 0.55 * q * (0.7 + 0.3 * sin(s.rt * 50.0)))
		jitter = roundf(randf_range(-1.0, 1.0) * q)
	else:
		var melt: float = clampf((s.rt - 0.25) / s.melt_duration(), 0.0, 1.0)
		material.set_shader_parameter(&"clip_y", Vector2(floorf(melt * PieceChunks.ROWS) / PieceChunks.ROWS, 1.0))
		s.set_tint(material, StrikePalette.VENOM_COLOR, 0.55)
		stretch = Vector2(1.0 + 0.3 * melt, 1.0)
		jitter = 0.0
	look_value.stretch = stretch
	look_value.jitter = jitter

func on_split() -> void:
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.6, 0.4, StrikePalette.VENOM_COLOR)
	s.fx.puff(s.up(s.b, 1.0), 4, 0.5)

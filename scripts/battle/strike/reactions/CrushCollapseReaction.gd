class_name CrushCollapseReaction
extends StrikeReaction

## A crush collapses a medium piece from the top, row by row.

func split_time() -> float:
	return 0.36

func standing_pixels() -> float:
	return s.victim_height * (1.0 - float(_collapsed_rows()) / PieceChunks.ROWS)

func tick() -> void:
	var rows: int = _collapsed_rows()
	while s.rows_broken < rows:
		var row: int = s.rows_broken
		s.rows_broken += 1
		var indices: PackedInt32Array = s.select(func(p: Vector2) -> bool: return int(p.y * PieceChunks.ROWS) == row)
		s.debris(indices, s.foot_pivot(), s.foot(s.b), {"vel": Vector3(0.0, 25.0 * s.unit, 0.0), "spread": 40.0, "radial": 4.0})

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var jitter: float = look_value.jitter
	material.set_shader_parameter(&"clip_y", Vector2(float(_collapsed_rows()) / PieceChunks.ROWS, 1.0))
	jitter = 0.0
	look_value.jitter = jitter

func on_split() -> void:
	s.fx.puff(s.up(s.b, 1.0), 8, 1.0)

func _collapsed_rows() -> int:
	return mini(PieceChunks.ROWS, floori(clampf(s.rt / 0.32, 0.0, 1.0) * PieceChunks.ROWS))

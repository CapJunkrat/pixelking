class_name ResonanceReaction
extends StrikeReaction

## Sound waves shake the piece until it cracks and bursts in bands.

func split_time() -> float:
	return s.weight3([0.45, 0.6, 0.8])

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var split: float = s.split_time()
	var q: float = clampf(rt / split, 0.0, 1.0) if split < INF else 0.0
	var state: Dictionary = {}
	state["jitter"] = roundf(sin(rt * (60.0 + 80.0 * q)) * (0.5 + 2.0 * q))
	material.set_shader_parameter(&"crack_progress", q)
	s.set_tint(material, StrikePalette.SOUND, 0.25 * q)
	apply_state(state, look_value)

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var foot: Vector3 = s.foot(b)
	for row: int in range(0, PieceChunks.ROWS, 3):
		var band: PackedInt32Array = s.select(func(p: Vector2) -> bool: return int(p.y * PieceChunks.ROWS) >= row and int(p.y * PieceChunks.ROWS) < row + 3)
		s.debris(band, s.foot_pivot(), foot, {"vel": Vector3(0.0, (20.0 + (PieceChunks.ROWS - row) * 2.0) * s.unit, 0.0), "spread": 35.0, "radial": 3.0})
	fx.ring(b.x, b.z, s.cell * 1.1, 0.45, StrikePalette.SOUND)
	fx.spark_burst(s.up(b, 8.0), 10, Vector2.ZERO, 0.0, 0.6, StrikePalette.SOUND)
	s.shake = maxf(s.shake, 0.6)

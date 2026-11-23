class_name RadianceReaction
extends StrikeReaction

## Holy light: the piece turns gold and dissolves upwards into motes.

func split_time() -> float:
	return 0.75

func tick() -> void:
	if s.hs > 0.0:
		return
	var rt: float = s.rt
	var b: Vector3 = s.b
	if rt > 0.25:
		var row: float = clampf((rt - 0.25) / 0.5, 0.0, 1.0)
		var front: PackedInt32Array = s.select(func(p: Vector2) -> bool: return absf(p.y - row) < 1.0 / PieceChunks.ROWS)
		for _i: int in range(2):
			if front.is_empty():
				break
			var pick: int = front[randi() % front.size()]
			s.debris(PackedInt32Array([pick]), s.foot_pivot(), s.foot(b), {"vel": Vector3(0.0, 25.0 * s.unit, 0.0), "spread": 6.0, "gravity": -40.0, "life_min": 0.6, "life_max": 1.0, "radial": 0.0, "color": Color("#ffe08a") if randf() < 0.5 else StrikePalette.HOLY_WHITE})

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var state: Dictionary = {}
	var gold: Color = Color("#ffe08a") if s.reaction == &"halo" else StrikePalette.HOLY_WHITE
	s.set_tint(material, gold, 0.75 * clampf(rt / 0.3, 0.0, 1.0))
	material.set_shader_parameter(&"clip_y", Vector2(clampf((rt - 0.25) / 0.5, 0.0, 1.0), 1.0))
	state["jitter"] = 0.0
	apply_state(state, look_value)

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	fx.ring(b.x, b.z, s.cell * 0.6, 0.4, StrikePalette.GOLDEN)

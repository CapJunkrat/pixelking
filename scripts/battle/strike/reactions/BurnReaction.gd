class_name BurnReaction
extends StrikeReaction

## Burns from the top down to ash.

func split_time() -> float:
	return s.burn_time()

func tick() -> void:
	if s.hs > 0.0:
		return
	var rt: float = s.rt
	var b: Vector3 = s.b
	var row: float = 1.0 - clampf(rt / s.split_time(), 0.0, 1.0)
	var front: PackedInt32Array = s.select(func(p: Vector2) -> bool: return absf(p.y - row) < 1.5 / PieceChunks.ROWS)
	for _i: int in range(2):
		if front.is_empty():
			break
		var pick: int = front[randi() % front.size()]
		s.debris(PackedInt32Array([pick]), s.foot_pivot(), s.foot(b), {"vel": Vector3(0.0, 25.0 * s.unit, 0.0), "spread": 6.0, "gravity": -60.0, "life_min": 0.2, "life_max": 0.4, "radial": 0.0, "color": StrikePalette.FIRE[1 + randi() % 3]})

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var split: float = s.split_time()
	var q: float = clampf(rt / split, 0.0, 1.0) if split < INF else 0.0
	var state: Dictionary = {}
	s.set_tint(material, StrikePalette.ASH[2], 0.85 * q)
	state["jitter"] = 0.0
	apply_state(state, look_value)

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var foot: Vector3 = s.foot(b)
	s.debris(whole, s.foot_pivot(), foot, {"vel": Vector3(0.0, 5.0 * s.unit, 0.0), "spread": 12.0, "gravity": 120.0, "life_min": 1.2, "life_max": 1.8, "radial": 0.6, "color": StrikePalette.ASH[randi() % StrikePalette.ASH.size()]})
	fx.puff(s.up(b, 6.0), 6, 0.9)

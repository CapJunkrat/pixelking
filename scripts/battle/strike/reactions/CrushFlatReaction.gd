class_name CrushFlatReaction
extends StrikeReaction

## A crush flattens a light piece.

func split_time() -> float:
	return 0.26

func standing_pixels() -> float:
	return s.victim_height * (1.0 - 0.82 * _flatten_progress())

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var stretch: Vector2 = look_value.stretch
	var jitter: float = look_value.jitter
	var p: float = _flatten_progress()
	stretch = Vector2(1.0 + 0.7 * p, 1.0 - 0.82 * p)
	jitter = 0.0
	look_value.stretch = stretch
	look_value.jitter = jitter

func on_split() -> void:
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	s.debris(whole, s.foot_pivot(), s.foot(s.b), {"vel": Vector3(0.0, 15.0 * s.unit, 0.0), "spread": 45.0, "every": 2, "radial": 3.0})
	s.fx.puff(s.up(s.b, 1.0), 12, 1.1)

func _flatten_progress() -> float:
	return s.ease_out(clampf(s.rt / 0.22, 0.0, 1.0))

class_name CrushSinkReaction
extends StrikeReaction

## A crush sinks a heavy piece into the board.

func split_time() -> float:
	return _sink_duration() + 0.02

func standing_pixels() -> float:
	return s.victim_height - _sink_pixels()

func tick() -> void:
	if s.hs <= 0.0 and randf() < 0.5 and s.victim_chunks.points.size() > 0:
		var index: int = randi() % s.victim_chunks.points.size()
		var origin: Vector3 = s.foot(s.b) + Vector3(randf_range(-6.0, 6.0) * s.unit, 0.0, 0.0)
		s.debris(PackedInt32Array([index]), s.victim_chunks.points[index], origin, {"vel": Vector3(0.0, 30.0 * s.unit, 0.0), "spread": 30.0})

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var ground: Vector3 = s.foot(s.b)
	var position: Vector2 = look_value.position
	var sunk: float = _sink_pixels()
	material.set_shader_parameter(&"clip_y", Vector2(0.0, 1.0 - sunk / s.victim_height))
	position.y += sunk * s.proj.scale_at(ground)
	look_value.position = position

func on_split() -> void:
	var visible_part: float = 1.0 - _sink_pixels() / s.victim_height
	var above: PackedInt32Array = s.select(func(p: Vector2) -> bool: return p.y < visible_part)
	s.debris(above, Vector2(s.victim_chunks.aspect * 0.5, visible_part), s.foot(s.b), {"vel": Vector3(0.0, 50.0 * s.unit, 0.0), "spread": 40.0, "radial": 3.0})
	s.fx.puff(s.up(s.b, 2.0), 12, 1.3)
	s.fx.ring(s.b.x, s.b.z, s.cell * 1.1, 0.45)
	s.fx.crack_decal(s.b.x, s.b.z, 5, s.cell * 1.3)
	s.shake = maxf(s.shake, 0.8)

func _sink_duration() -> float:
	return 0.68 if s.power < 1.0 else 0.48

func _sink_pixels() -> float:
	return s.victim_height * 0.65 * s.ease_out(clampf(s.rt / _sink_duration(), 0.0, 1.0))

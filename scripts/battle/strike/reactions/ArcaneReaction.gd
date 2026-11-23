class_name ArcaneReaction
extends StrikeReaction

## Arcane force lifts the piece and bursts it.

func split_time() -> float:
	return s.arcane_duration()

func tick() -> void:
	if s.hs > 0.0:
		return
	var index: int = s.random_chunk()
	if index >= 0 and randf() < 0.6:
		s.debris(PackedInt32Array([index]), s.foot_pivot(), s.foot(s.b) + Vector3(0.0, s.arcane_lift(), 0.0), {"vel": Vector3(0.0, 15.0 * s.unit, 0.0), "spread": 10.0, "gravity": -40.0, "life_min": 0.2, "life_max": 0.35, "radial": 0.0, "color": Color("#d6f6ff")})

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var ground: Vector3 = s.foot(s.b)
	var position: Vector2 = look_value.position
	var jitter: float = look_value.jitter
	var q: float = clampf(s.rt / s.arcane_duration(), 0.0, 1.0)
	position = s.proj.project(ground + Vector3(0.0, s.arcane_lift(), 0.0))
	s.set_tint(material, StrikePalette.ARCANE_COLOR, (0.25 + 0.5 * q) * (0.7 + 0.3 * sin(s.rt * 60.0)))
	jitter = roundf(randf_range(-1.0, 1.0) * (0.3 + q * 1.6))
	look_value.position = position
	look_value.jitter = jitter

func on_split() -> void:
	var lift: float = s.arcane_lift()
	var centre: Vector2 = Vector2(s.victim_chunks.aspect * 0.5, 0.5)
	s.debris(s.victim_chunks.all_indices(), centre, s.foot(s.b) + Vector3(0.0, lift + s.victim_at(0.5), 0.0), {"vel": Vector3(0.0, 45.0 * s.unit, 0.0), "spread": 60.0, "radial": 7.0, "gravity": 220.0})
	s.fx.spark_burst(Vector3(s.b.x, lift + 8.0 * s.unit, s.b.z), 16, Vector2.ZERO, 0.0, 1.0, StrikePalette.ARCANE_COLOR)
	s.fx.ring(s.b.x, s.b.z, s.cell * 1.5, 0.5, StrikePalette.ARCANE_COLOR)
	s.fx.ring(s.b.x, s.b.z, s.cell * 0.8, 0.32, Color(0.9, 0.98, 1.0))
	s.fx.puff(Vector3(s.b.x, lift + 4.0 * s.unit, s.b.z), 8, 1.1)
	s.flash = maxf(s.flash, 0.7)
	s.shake = maxf(s.shake, 0.9)

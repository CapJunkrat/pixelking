class_name VortexReaction
extends StrikeReaction

## Dragged into the void gate: struggles (heavy only), then spins, shrinks and vanishes.

func split_time() -> float:
	return 0.0

func on_split() -> void:
	var body: StrikeBody = s.make_body({})
	body.kind = &"vortex"
	body.base_y = body.y

func step_body(body: StrikeBody, dt: float) -> bool:
	if body.kind != &"vortex":
		return false
	_step_vortex(body, dt)
	return true

## Dragged into the void gate: struggles (heavy only), then spins, shrinks and vanishes.
func _step_vortex(body: StrikeBody, dt: float) -> void:
	var total: float = s.absorb_duration()
	var heavy: bool = s.victim_weight == PieceDef.WeightClass.HEAVY
	var fight: float = clampf(1.0 - body.age / (total * 0.4), 0.0, 1.0) if heavy else 0.0
	var pull: float = clampf((body.age - total * (0.35 if heavy else 0.1)) / (total * (0.65 if heavy else 0.9)), 0.0, 1.0)
	body.scale_mul = maxf(0.02, 1.0 - s.ease_in(pull) * 0.92)
	body.rot = s.ease_in(pull) * PI * 4.0 * s.face + (sin(body.age * 40.0) * 0.12 if fight > 0.0 else 0.0)
	body.y = body.base_y * body.scale_mul
	body.ox = roundf(randf_range(-1.5, 1.5)) * s.unit if fight > 0.0 else 0.0
	s.set_tint(body.material, StrikePalette.VOID_COLOR, 0.7 * clampf(body.age / total, 0.0, 1.0))
	if randf() < 0.5:
		var angle: float = randf() * TAU
		var radius: float = s.cell * 0.55
		s.fx.add_part(Vector3(s.b.x + cos(angle) * radius, s.unit, s.b.z + s.stand + sin(angle) * radius), Vector3(-cos(angle) * 20.0, 15.0, -sin(angle) * 20.0) * s.unit, StrikePalette.VOID_COLOR if randf() < 0.5 else StrikePalette.VOID_DEEP, s.victim_height / PieceChunks.ROWS, randf_range(0.25, 0.4), -20.0 * s.unit)
	if body.age >= total:
		body.dead = true
		if is_instance_valid(body.sprite):
			body.sprite.queue_free()
		s.fx.ring(s.b.x, s.b.z, s.cell * 0.5, 0.3, StrikePalette.VOID_COLOR)
		s.fx.spark_burst(s.up(s.b, 2.0), 8, Vector2.ZERO, 0.0, 0.35, StrikePalette.VOID_COLOR)
		s.shake = maxf(s.shake, 0.35)

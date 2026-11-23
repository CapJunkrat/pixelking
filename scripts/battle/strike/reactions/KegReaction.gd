class_name KegReaction
extends StrikeReaction

## The Powder Keg's own reaction: it flashes, swells and explodes, taking its attacker
## with it.

func split_time() -> float:
	# The keg flashes and swells before it goes off.
	return 0.5

func look(material: ShaderMaterial, look_value: StrikeLook) -> void:
	var rt: float = s.rt
	var split: float = s.split_time()
	var q: float = clampf(rt / split, 0.0, 1.0) if split < INF else 0.0
	var state: Dictionary = {}
	var blink: float = 0.5 + 0.5 * sin(rt * (22.0 + 70.0 * q))
	s.set_tint(material, Color(1.0, 0.32, 0.18).lerp(Color(1.0, 0.95, 0.8), q), (0.3 + 0.55 * q) * blink)
	var swell: float = 1.0 + 0.32 * s.ease_in01(q)
	state["stretch"] = Vector2(swell, swell)
	state["jitter"] = roundf(randf_range(-1.0, 1.0) * (0.5 + 1.5 * q))
	apply_state(state, look_value)

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var foot: Vector3 = s.foot(b)
	s.fire_debris(whole, foot, 90.0, 70.0, 6.0, 0.5)
	fx.spark_burst(s.up(b, 8.0), 26, Vector2.ZERO, 0.0, 1.3, StrikePalette.ORANGE)
	fx.spark_burst(s.up(b, 8.0), 12, Vector2.ZERO, 0.0, 0.9, Color(1.0, 0.9, 0.55))
	fx.ring(b.x, b.z, s.cell * 1.8, 0.55, StrikePalette.ORANGE)
	fx.ring(b.x, b.z, s.cell * 1.1, 0.4, Color(1.0, 0.9, 0.55))
	fx.ring(b.x, b.z, s.cell * 0.6, 0.3, StrikePalette.ORANGE)
	fx.puff(s.up(b, 4.0), 20, 1.8)
	fx.crack_decal(b.x, b.z, 10, s.cell * 1.3)
	s.flash = 1.0
	s.shake = 1.9
	s.punch = 1.0
	_blow_up_attacker()

## The piece that captured the Powder Keg is blown away with it.
func _blow_up_attacker() -> void:
	if not is_instance_valid(s.attacker):
		return
	s.attacker_gone = true
	var chunks: PieceChunks = PieceChunks.of(s.attacker_texture)
	var height: float = s.attacker_height
	var size: float = height / PieceChunks.ROWS
	for index: int in range(chunks.points.size()):
		var point: Vector2 = chunks.points[index]
		var local: Vector2 = (point - Vector2(chunks.aspect * 0.5, 1.0)) * height
		var at: Vector3 = Vector3(s.pose.x + local.x, maxf(0.0, s.pose.y - s.proj.height_for_pixels(local.y)), s.pose.z + s.stand)
		var velocity: Vector3 = Vector3(-s.dir.x * 90.0 + local.x * 5.0 + randf_range(-40.0, 40.0), randf_range(60.0, 140.0), -s.dir.y * 90.0 + randf_range(-20.0, 20.0)) * s.unit
		s.fx.add_part(at, velocity, chunks.colors[index] if randf() < 0.6 else s.fire_color(), size, randf_range(1.0, 1.6), 260.0 * s.unit)
class_name GlassReaction
extends StrikeReaction

## The Crystal Mage's own reaction (and an Ember Egg's): it shatters into glittering
## glass.

func split_time() -> float:
	return 0.08

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var foot: Vector3 = s.foot(b)
	s.debris(whole, s.foot_pivot(), foot, {"vel": Vector3(s.dir.x * 30.0, 45.0, s.dir.y * 30.0) * s.unit, "spread": 50.0, "radial": 3.0, "gravity": 150.0, "life_min": 1.4, "life_max": 2.2, "color": StrikePalette.GLASS[randi() % StrikePalette.GLASS.size()]})
	fx.spark_burst(s.up(b, 8.0), 14, Vector2.ZERO, 0.0, 0.8, Color(0.9, 0.98, 1.0))
	fx.ring(b.x, b.z, s.cell * 0.8, 0.35, Color(0.9, 0.98, 1.0))

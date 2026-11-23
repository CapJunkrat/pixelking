class_name BlastReaction
extends StrikeReaction

## Blown apart, some chunks burning.

func split_time() -> float:
	return 0.02

func on_split() -> void:
	var b: Vector3 = s.b
	var whole: PackedInt32Array = s.victim_chunks.all_indices()
	var foot: Vector3 = s.foot(b)
	s.fire_debris(whole, foot, 110.0, 70.0, 5.0, 0.45)

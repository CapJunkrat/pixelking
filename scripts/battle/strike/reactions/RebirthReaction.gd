class_name RebirthReaction
extends EmberReaction

## The Flame Phoenix's own reaction: it flares up and its spark flies to where its egg
## is laid.

func split_time() -> float:
	return 0.25

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	fx.spark_burst(s.up(b, 8.0), 16, Vector2.ZERO, 0.0, 0.8, StrikePalette.ORANGE)
	fx.ring(b.x, b.z, s.cell * 0.8, 0.4, StrikePalette.ORANGE)

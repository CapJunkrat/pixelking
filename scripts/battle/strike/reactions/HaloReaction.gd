class_name HaloReaction
extends RadianceReaction

## The Martyr's own reaction: holy light, with a wide golden ring when it goes.

func on_split() -> void:
	var b: Vector3 = s.b
	var fx: StrikeFx = s.fx
	fx.ring(b.x, b.z, s.cell * 0.6, 0.4, StrikePalette.GOLDEN)
	fx.ring(b.x, b.z, s.cell * 1.5, 0.6, StrikePalette.GOLDEN)
